# PROD Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the tag vocabulary, subject layer, category structure and theme that were built on PRE to the production instance, during a staff-writes-only maintenance window.

**Architecture:** No theme code changes until the last task. Everything else is instance configuration, tags and categories on `gestionaavanza.espublico.com`, applied through the Discourse admin API with a Global-scope key created for the window and revoked at the end. There is no test runner: each task measures the live state before, applies, and measures after — the "before" measurement is the failing test, and a task is done when its "after" measurement matches. Several tasks stop for Ricardo's decision mid-flight; those gates are marked and are not optional.

**Tech Stack:** Discourse admin API (`/tags.json`, `/tag_groups.json`, `/tag/<id>/settings.json`, `/tag/<id>/synonyms.json`, `PUT /t/-/<id>.json`, `PUT /topics/bulk.json`, `/admin/site_settings/<name>.json`), Python 3.9 standard library only, `curl` for probes.

**Spec:** `docs/superpowers/specs/2026-09-06-migracion-prod-design.md`

## Global Constraints

- **This is production.** Every write is visible to the whole community. When a step's outcome is not what the plan predicts, STOP and report — do not improvise on a live instance.
- **The window must be `readonly_mode:staff_writes_only`, never full `readonly_mode`.** Under the latter every non-GET is blocked *including ours* and the whole plan fails silently at the first write.
- **Credentials come from `.env.local` via `source`, in the same shell invocation as the command.** The Global PROD key is created for this window under a new variable name — `PROD_DISCOURSE_GLOBAL_API_KEY` — alongside the existing read-only `PROD_DISCOURSE_API_KEY`. **Never print any key value.** `.env.local` has twice had duplicate variable names silently shadow each other; keep the new name distinct and verify by capability, not by position.
- **Rate limit ~1 req/s.** Sleep 1.2–1.3 s between calls; back off 8 s on HTTP 429.
- **Python 3.9 standard library only.** No pip installs — a corporate TLS proxy breaks them.
- **No background jobs.** Run every crawl and write loop inline, printing progress. Four subagents on the PRE plan stalled for ten-plus minutes waiting on notifications from their own background work.
- **`PUT /t/-/<id>.json` replaces a topic's whole tag set.** Always GET the topic's current tags and resend them with the addition. `max_tags_per_topic` is the ceiling; skip and report any topic that would exceed it, never truncate.
- **Renaming a tag does not preserve its old name.** After every rename, recreate the old name as a synonym with `tags[][name]`, or `#old-name` silently degrades to full-text search.
- **Synonyms do not chain.** Merging a tag that already has a synonym fails with `no está permitido mientras existan sinónimos`. Move the child to the final target first.
- **Send no `permissions` parameter when creating a tag group** — supplying one returns HTTP 500; omitting it defaults to `{"0": 1}`.
- **PROD is being tagged by someone else.** Re-measure immediately before each task; never rely on a count from the spec, from the August document, or from an earlier task in this plan.
- **`main` is protected.** Work on a branch, open a PR, let the four required CI checks go green.

## File Structure

| File | Responsibility |
|---|---|
| `docs/superpowers/plans/data/2026-09-06-prod-capture.json` | Create in Task 1. The full pre-window state: every tag with its count, every topic's tag list, the category tree, and the settings read. This is the rollback for everything except category deletion. |
| `docs/superpowers/plans/data/2026-09-06-prod-bulk-tagging.json` | Create in Task 4. The revalidated bulk-tagging table — source category, tags to append, topics affected — as executed. |
| `docs/superpowers/plans/data/2026-09-06-prod-collisions.json` | Create in Task 6. Each spelling-collision family with the canonical form Ricardo chose. |
| `docs/superpowers/plans/data/2026-09-06-prod-module-axis.json` | Create in Task 7. PROD's group→tags mapping, same shape as PRE's, read by the verifier. |
| `bin/prod-verify` | Create in Task 7. PROD's re-runnable assertion, modelled on `bin/tags-verify` but reading PROD's env vars and mapping. |
| `docs/superpowers/plans/data/2026-09-06-prod-batch-decisions.json` | Create in Task 8. Ricardo's approve/exclude decision per batch. |
| `docs/superpowers/specs/2026-09-06-migracion-prod-design.md` | Modify. Append an *As executed* section per task. |

---

### Task 1: Pre-flight capture and the two blocker settings

Runs **before** the window opens, with the existing read-only key where possible. It answers the one question that can invalidate the whole window.

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-06-prod-capture.json`

**Interfaces:**
- Consumes: nothing.
- Produces: the capture file, shape `{"tags": {"<name>": <count>}, "topics": {"<id>": {"cat": <int>, "title": "<str>", "tags": ["<name>", ...]}}, "categories": [{"id": <int>, "name": "<str>", "slug": "<str>", "parent": <int|null>}], "settings": {"<name>": "<value>"}}`.

- [ ] **Step 1: Confirm the Global key exists and works**

```bash
set -a && source .env.local && set +a
for k in PROD_DISCOURSE_GLOBAL_API_KEY PROD_DISCOURSE_API_KEY; do
  eval "v=\$$k"
  code=$(curl -sS -o /dev/null -w "%{http_code}" -H "Api-Key: $v" \
    -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" "$PROD_DISCOURSE_URL/tags.json")
  echo "$k -> /tags.json $code"; sleep 1.3
done
```

Expected: the Global key returns **200**, the read-only key **403**. If the Global key is absent or returns 403, STOP — Task 1 cannot proceed and neither can anything after it.

- [ ] **Step 2: Read the two blocker settings**

```bash
set -a && source .env.local && set +a
curl -sSL -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  "$PROD_DISCOURSE_URL/admin/site_settings.json" -o /tmp/ss.json
python3 -c "
import json
d = json.load(open('/tmp/ss.json'))['site_settings']
want = {'max_tags_per_topic','max_tag_length','max_tag_search_results','min_search_term_length',
        'max_tags_in_filter_list','tagging_enabled','force_lowercase_tags','default_locale',
        'search_ignore_accents','create_tag_allowed_groups','tag_topic_allowed_groups'}
for s in sorted(d, key=lambda x: x['setting']):
    if s['setting'] in want:
        print(f\"  {s['setting']:32} = {s['value']!r}\")"
```

**Record these verbatim.** `max_tags_per_topic` at 3 and `max_tag_length` at 20 are what broke the August bulk tagging on PRE partway. If either is low, Task 2 raises it before anything appends a tag.

- [ ] **Step 3: Capture the full prior state**

```python
import json, os, time, urllib.request
URL = os.environ["PROD_DISCOURSE_URL"]; KEY = os.environ["PROD_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PROD_DISCOURSE_API_USERNAME"]

def get(path):
    r = urllib.request.Request(URL + path, headers={"Api-Key": KEY, "Api-Username": USER})
    for _ in range(4):
        try:
            with urllib.request.urlopen(r, timeout=30) as f:
                return json.load(f)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(8); continue
            return {"__err": e.code}
        except Exception:
            time.sleep(3)
    return {"__err": "fail"}

cats, stack = [], list(get("/categories.json?include_subcategories=true")["category_list"]["categories"])
while stack:
    c = stack.pop()
    cats.append({"id": c["id"], "name": c["name"], "slug": c["slug"], "parent": c.get("parent_category_id")})
    stack.extend(c.get("subcategory_list") or [])
time.sleep(1.2)

topics = {}
for c in sorted(x["id"] for x in cats):
    for page in range(40):
        d = get(f"/c/{c}/l/latest.json?page={page}")
        if "__err" in d:
            print("ERR", c, page, d); break
        rows = d.get("topic_list", {}).get("topics", [])
        if not rows:
            break
        for t in rows:
            topics[t["id"]] = {"cat": t.get("category_id"), "title": t["title"],
                               "tags": [x["name"] for x in (t.get("tags") or [])]}
        time.sleep(1.2)
        if len(rows) < 30:
            break
    print(f"cat {c}: {len(topics)} topics so far", flush=True)

time.sleep(1.2)
tags = {t["name"]: t["count"] for t in get("/tags.json")["tags"]}
settings = {s["setting"]: s["value"] for s in get("/admin/site_settings.json")["site_settings"]}

out = {"tags": tags, "topics": topics, "categories": cats, "settings": settings}
json.dump(out, open("docs/superpowers/plans/data/2026-09-06-prod-capture.json", "w"), ensure_ascii=False)
print(f"captured {len(tags)} tags, {len(topics)} topics, {len(cats)} categories, {len(settings)} settings")
```

Expected, within drift: about **218 tags, 1 297 topics, 35 categories**. A materially different figure means PROD moved again — record the new numbers and carry them forward rather than the spec's.

- [ ] **Step 4: Commit the capture**

```bash
git checkout -b feat/prod-migration
git add docs/superpowers/plans/data/2026-09-06-prod-capture.json
git commit -m "chore(prod): capture PROD's pre-migration state

Every tag with its count, every topic's tag list, the category tree and the
instance settings, read before the maintenance window opens. This is the
rollback for every tag operation in the plan — category deletion needs the
database backup instead."
```

- [ ] **Step 5: Report the two blocker settings to Ricardo before the window opens**

State their measured values and whether Task 2 must raise them. This is information he needs before committing to the window, not after.

- [ ] **Step 6: Identify who has been tagging PROD, and tell them**

Someone with admin access has been tagging by hand: `caag` went 40 → 129 in a month with only 3 of those on new topics, and `developers` *lost* tags. Task 3 renames `caag`, which renames their work — the synonym preserves it and `#caag` keeps filtering, but they should hear it from Ricardo beforehand rather than discover it.

```bash
set -a && source .env.local && set +a
curl -sSL -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  "$PROD_DISCOURSE_URL/admin/logs/staff_action_logs.json?limit=100" -o /tmp/sal.json
python3 -c "
import json
from collections import Counter
rows = json.load(open('/tmp/sal.json')).get('staff_action_logs', [])
print(Counter(r.get('acting_user', {}).get('username', '?') for r in rows))
for r in rows[:25]:
    print(f\"  {r.get('created_at','')[:19]}  {r.get('acting_user',{}).get('username','?'):16} {r.get('action_name','?')}\")"
```

**The acting username is not proof of a person.** Any API call this project makes is logged under `PROD_DISCOURSE_API_USERNAME`, which is `RicardoPG` — the same signature our own writes will carry. Read the log for *actions* and *timing*, and confirm with Ricardo who it was; do not infer identity from the actor field. This exact confusion cost a fix round on the PRE plan.

---

### Task 2: Open the window and raise the tag ceilings

**Files:**
- Modify: `docs/superpowers/specs/2026-09-06-migracion-prod-design.md` (start an *As executed* section)

**Interfaces:**
- Consumes: Task 1's settings reading.
- Produces: `max_tags_per_topic` ≥ 7 and `max_tag_length` ≥ 30 on PROD; a confirmed staff-writes-only window.

- [ ] **Step 1: Confirm the window mode with Ricardo, and that our writes still work**

The window is enabled by Ricardo in admin, not by this plan. Once he says it is on, prove writes reach the API before doing anything that matters:

```bash
set -a && source .env.local && set +a
curl -sS -o /tmp/probe.json -w "%{http_code}\n" -X PUT \
  -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "max_tags_in_filter_list=30" \
  "$PROD_DISCOURSE_URL/admin/site_settings/max_tags_in_filter_list.json"
```

Expected: **200 or 204**. A 503 with a read-only message means full `readonly_mode` is on instead of staff-writes-only — STOP and tell Ricardo to switch modes. This probe deliberately uses a harmless setting so a failure costs nothing.

- [ ] **Step 2: Raise the two ceilings**

```bash
set -a && source .env.local && set +a
for pair in "max_tags_per_topic=7" "max_tag_length=30"; do
  n=${pair%%=*}; v=${pair##*=}
  code=$(curl -sS -o /dev/null -w "%{http_code}" -X PUT \
    -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
    -H "Content-Type: application/x-www-form-urlencoded" -d "$n=$v" \
    "$PROD_DISCOURSE_URL/admin/site_settings/$n.json")
  echo "$n -> $v : $code"; sleep 1.3
done
```

- [ ] **Step 3: Read them back**

```bash
set -a && source .env.local && set +a
curl -sSL -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  "$PROD_DISCOURSE_URL/admin/site_settings.json" -o /tmp/ss.json
python3 -c "
import json
d = {s['setting']: s['value'] for s in json.load(open('/tmp/ss.json'))['site_settings']}
for k in ('max_tags_per_topic','max_tag_length'):
    print(f'  {k} = {d[k]}')"
```

Expected: `7` and `30`. A PUT that returns 200 but does not change the value is the failure this step exists to catch.

- [ ] **Step 4: Record and commit**

```bash
git add docs/superpowers/specs/2026-09-06-migracion-prod-design.md
git commit -m "chore(prod): raise the tag ceilings before any bulk tagging

max_tags_per_topic 3 -> 7 and max_tag_length 20 -> 30. At the old values the
August bulk tagging on PRE failed partway on ~100 topics and truncated
administracion-avanzada (23 chars) on entry."
```

---

### Task 3: Rename `caag` and `posters`

**Files:**
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: Task 2's raised `max_tag_length` — `administracion-avanzada` is 23 characters and truncates at 20.
- Produces: on PROD, `administracion-avanzada` carrying `caag`'s topics with `caag` as a synonym, and `poster-evf` carrying `posters`' topics with `posters` as a synonym.

- [ ] **Step 1: Capture the before-state**

```bash
set -a && source .env.local && set +a
for t in caag posters administracion-avanzada poster-evf; do
  curl -sSL -G --data-urlencode "q=#$t" -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" \
    -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" "$PROD_DISCOURSE_URL/search.json" -o /tmp/s.json
  python3 -c "
import json, sys
d = json.load(open('/tmp/s.json'))
print(f'  #{sys.argv[1]:26} -> {len(d.get(\"topics\", []))} topics')" "$t"
  sleep 1.3
done
```

Record the numbers. Expected shape: `caag` and `posters` non-zero, the two targets returning a full-text fallback because they do not exist yet.

- [ ] **Step 2: Rename both, then recreate the old names as synonyms**

```python
import json, os, time, urllib.parse, urllib.request
URL = os.environ["PROD_DISCOURSE_URL"]; KEY = os.environ["PROD_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PROD_DISCOURSE_API_USERNAME"]

def req(method, path, data=None):
    body = urllib.parse.urlencode(data, doseq=True).encode() if data else None
    headers = {"Api-Key": KEY, "Api-Username": USER}
    if body:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    r = urllib.request.Request(URL + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r, timeout=30) as f:
            raw = f.read()
            return f.status, (json.loads(raw) if raw.strip() else {})
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.load(e)
        except Exception:
            return e.code, {}

ids = {t["name"]: t["id"] for t in req("GET", "/tags.json")[1]["tags"]}
time.sleep(1.2)

for old, new in [("caag", "administracion-avanzada"), ("posters", "poster-evf")]:
    if old not in ids:
        print(f"SKIP {old}: not present"); continue
    tid = ids[old]
    st, _ = req("PUT", f"/tag/{tid}/settings.json",
                {"tag_settings[name]": new, "tag_settings[slug]": new})
    print(f"[{st}] renamed {old} -> {new}")
    time.sleep(1.3)
    # The tag keeps its id across a rename, so tid still addresses it.
    st, r = req("POST", f"/tag/{tid}/synonyms.json", [("tags[][name]", old)])
    ok = st == 200 and not r.get("failed_tags")
    print(f"[{'OK ' if ok else 'ERR'}] recreated '{old}' as a synonym of {new}")
    time.sleep(1.3)
```

- [ ] **Step 3: Verify the old names still filter and the counts carried over**

```bash
set -a && source .env.local && set +a
for t in caag posters administracion-avanzada poster-evf; do
  curl -sSL -G --data-urlencode "q=#$t" -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" \
    -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" "$PROD_DISCOURSE_URL/search.json" -o /tmp/s.json
  python3 -c "
import json, sys
print(f'  #{sys.argv[1]:26} -> {len(json.load(open(\"/tmp/s.json\")).get(\"topics\", []))} topics')" "$t"
  sleep 1.3
done
```

Expected: all four now return the same population. A drop to 0 or a jump to the 50-per-page cap on an old name means the synonym did not register and the query fell through to full text.

Also confirm the rename did not truncate:

```bash
set -a && source .env.local && set +a
curl -sSL -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  "$PROD_DISCOURSE_URL/tags.json" -o /tmp/t.json
python3 -c "
import json
a = {t['name']: t['count'] for t in json.load(open('/tmp/t.json'))['tags']}
print('administracion-avanzada:', a.get('administracion-avanzada', 'ABSENT'))
print('truncated variants:', [n for n in a if n.startswith('administracion-avanz') and n != 'administracion-avanzada'])"
```

Expected: the full 23-character name present, no truncated variant. A truncated variant means `max_tag_length` was not actually raised in Task 2.

- [ ] **Step 4: Record and commit**

```bash
git add docs/superpowers/specs/2026-09-06-migracion-prod-design.md
git commit -m "chore(prod): rename caag and posters to their PRE names

caag -> administracion-avanzada and posters -> poster-evf, each with the old
name recreated as a synonym so #caag and #posters keep filtering. Renames, not
merges: neither target existed on PROD."
```

---

### Task 4: Bulk-tag by source category

The phase that broke on PRE. It appends structural tags to whole categories.

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-06-prod-bulk-tagging.json`
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: Task 2's ceilings, Task 3's renamed `administracion-avanzada`.
- Produces: the executed table, shape `{"<category id>": {"name": "<str>", "tags": ["<name>", ...], "topics_before": <int>, "applied": <int>, "skipped": <int>}}`.

- [ ] **Step 1: Revalidate the August table against today's listings**

The source table is in `docs/superpowers/specs/2026-08-25-category-reorganisation-design.md` under *PROD, as originally planned*. **Its counts are a month old and PROD has been tagged since**, so every row must be re-measured. Its Webinars row is known wrong for PROD: it assumes `seminarios`, `webinar` and `seminario` were already merged into `webinars`, which happened only on PRE.

```python
import json, os, time, urllib.request
URL = os.environ["PROD_DISCOURSE_URL"]; KEY = os.environ["PROD_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PROD_DISCOURSE_API_USERNAME"]

PLAN = {
    5:  ["administracion-avanzada"],
    18: ["administracion-avanzada"],
    50: ["analiza"],
    56: ["administracion-avanzada", "tasas"],
    68: ["administracion-avanzada", "pid"],
    69: ["administracion-avanzada", "app-movil"],
    57: ["campana-2024"],
    58: ["campana-febrero-2025"],
    54: ["campana-v9"],
    87: ["cafe-con-certificados"],
    65: ["newsletter"],
    66: ["blog-gestiona"],
    62: ["administracion-avanzada", "trucazo"],
}

def get(path):
    r = urllib.request.Request(URL + path, headers={"Api-Key": KEY, "Api-Username": USER})
    with urllib.request.urlopen(r, timeout=30) as f:
        return json.load(f)

report = {}
for cid, tags in PLAN.items():
    topics = []
    for page in range(40):
        rows = get(f"/c/{cid}/l/latest.json?page={page}").get("topic_list", {}).get("topics", [])
        if not rows:
            break
        topics += [t for t in rows if t.get("category_id") == cid]
        time.sleep(1.2)
        if len(rows) < 30:
            break
    missing = {t: sum(1 for x in topics if t not in [y["name"] for y in (x.get("tags") or [])])
               for t in tags}
    over = [x["id"] for x in topics
            if len(set(y["name"] for y in (x.get("tags") or [])) | set(tags)) > 7]
    report[cid] = {"topics": len(topics), "tags": tags, "missing": missing, "would_exceed_7": over}
    print(f"  cat {cid:3}: {len(topics):4} topics, missing {missing}, would exceed 7: {len(over)}")
json.dump(report, open("/tmp/bulk-plan.json", "w"), ensure_ascii=False, indent=1)
```

**A non-empty `would_exceed_7` on any row is the PRE failure repeating.** Report those topics; they are handled by hand in Step 3, not by truncation.

- [ ] **Step 2: Gate — Ricardo approves the revalidated table**

Present it as category → tags → topics missing the tag → topics that would exceed the ceiling. **Do not write until he approves.** The campaign tag names (`campana-2024`, `campana-febrero-2025`, `campana-v9`) came from PRE's naming and he may prefer the `ideas-*` forms PRE ended up with.

- [ ] **Step 3: Apply, per category, reading each topic first**

```python
import json, os, time, urllib.parse, urllib.request
URL = os.environ["PROD_DISCOURSE_URL"]; KEY = os.environ["PROD_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PROD_DISCOURSE_API_USERNAME"]
plan = json.load(open("/tmp/bulk-plan.json"))

def req(method, path, data=None):
    body = urllib.parse.urlencode(data, doseq=True).encode() if data else None
    headers = {"Api-Key": KEY, "Api-Username": USER}
    if body:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    r = urllib.request.Request(URL + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r, timeout=30) as f:
            raw = f.read()
            return f.status, (json.loads(raw) if raw.strip() else {})
    except urllib.error.HTTPError as e:
        return e.code, {}

applied = skipped = failed = 0
for cid, row in plan.items():
    want = row["tags"]
    for page in range(40):
        st, d = req("GET", f"/c/{cid}/l/latest.json?page={page}")
        rows = d.get("topic_list", {}).get("topics", [])
        if not rows:
            break
        for t in rows:
            if t.get("category_id") != int(cid):
                continue
            st, full = req("GET", f"/t/{t['id']}.json")
            time.sleep(1.2)
            names = [x["name"] for x in (full.get("tags") or [])]
            add = [x for x in want if x not in names]
            if not add:
                skipped += 1; continue
            if len(names) + len(add) > 7:
                print(f"  /t/{t['id']} SKIPPED: {len(names)} tags + {len(add)} exceeds 7")
                skipped += 1; continue
            st2, _ = req("PUT", f"/t/-/{t['id']}.json", [("tags[]", n) for n in names + add])
            applied += 1 if st2 == 200 else 0
            failed += 0 if st2 == 200 else 1
            time.sleep(1.3)
        time.sleep(1.2)
        if len(rows) < 30:
            break
    print(f"cat {cid} done — applied={applied} skipped={skipped} failed={failed}", flush=True)
```

This writes one topic at a time rather than using the admin bulk dialog, because the bulk route fails partway when it meets the ceiling instead of reporting cleanly.

- [ ] **Step 4: Verify the counts moved as predicted**

Re-read `/tags.json` and compare each appended tag's count against its pre-task value plus the `missing` figure from Step 1. Reconcile every discrepancy before continuing; an unexplained gap here propagates into every later measurement.

- [ ] **Step 5: Record and commit**

```bash
git add docs/superpowers/plans/data/2026-09-06-prod-bulk-tagging.json \
        docs/superpowers/specs/2026-09-06-migracion-prod-design.md
git commit -m "feat(prod): bulk-tag the structural layer by source category"
```

---

### Task 5: Recreate the `programa-certificacion` tag group

**Files:**
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: Task 3's `administracion-avanzada`.
- Produces: a tag group named `programa-certificacion` holding `administracion-avanzada`, `analiza`, `developers`, with `one_per_topic: true`.

- [ ] **Step 1: Confirm all three tags exist**

```bash
set -a && source .env.local && set +a
curl -sSL -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  "$PROD_DISCOURSE_URL/tags.json" -o /tmp/t.json
python3 -c "
import json
a = {t['name']: t['count'] for t in json.load(open('/tmp/t.json'))['tags']}
for n in ('administracion-avanzada','analiza','developers'):
    print(f'  {n:26} {a.get(n, \"ABSENT\")}')"
```

All three must be present. `tag_names[]` **creates** any tag it names, so a missing one would be silently invented as an empty tag rather than reported.

- [ ] **Step 2: Create the group**

```bash
set -a && source .env.local && set +a
curl -sS -X POST -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" \
  -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  -d "name=programa-certificacion" \
  -d "tag_names[]=administracion-avanzada" -d "tag_names[]=analiza" -d "tag_names[]=developers" \
  -d "one_per_topic=true" \
  "$PROD_DISCOURSE_URL/tag_groups.json" | python3 -m json.tool | head -20
```

**No `permissions` parameter** — supplying one returns HTTP 500.

- [ ] **Step 3: Verify membership and that nothing was invented**

Read `/tag_groups.json` back and confirm exactly three tags, all with non-zero counts. A member at 0 uses means `tag_names[]` created it.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-09-06-migracion-prod-design.md
git commit -m "feat(prod): recreate the programa-certificacion tag group"
```

---

### Task 6: Merge the spelling collisions

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-06-prod-collisions.json`
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: the post-Task-4 vocabulary.
- Produces: the decisions file, shape `{"<canonical>": {"absorb": ["<name>", ...], "rename_to": "<name>|null"}}`.

- [ ] **Step 1: Re-detect the collisions on today's vocabulary**

```python
import json, os, re, time, unicodedata, urllib.request
from collections import defaultdict
URL = os.environ["PROD_DISCOURSE_URL"]; KEY = os.environ["PROD_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PROD_DISCOURSE_API_USERNAME"]
r = urllib.request.Request(URL + "/tags.json", headers={"Api-Key": KEY, "Api-Username": USER})
with urllib.request.urlopen(r, timeout=30) as f:
    tags = {t["name"]: t["count"] for t in json.load(f)["tags"]}

def root(s):
    s = unicodedata.normalize("NFKD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r"[^a-z0-9]", "", s)
    return re.sub(r"(es|s)$", "", s)

g = defaultdict(list)
for n, c in tags.items():
    g[root(n)].append((n, c))
for v in sorted((v for v in g.values() if len(v) > 1), key=lambda v: -sum(c for _, c in v)):
    print("   " + " | ".join(f"{n}({c})" for n, c in sorted(v, key=lambda x: -x[1])))
```

The spec recorded **11 families** on 2026-09-06. Expect that set to have moved.

- [ ] **Step 2: Gate — Ricardo picks the canonical form for each family**

Present each family with its counts. Convention from PRE: **no accent, hyphenated**. Two rules learned there:

- **Pick as merge target the tag that already carries the right name**, not the most-used one — the topics move to the target either way, and this sidesteps slug collisions.
- If no member has the right name, merge into the most-used and rename afterwards, recreating the old name as a synonym.

- [ ] **Step 3: Apply the merges**

For each family, `POST /tag/<target id>/synonyms.json` with `tags[][id]` for each absorbed tag, sleeping 1.3 s between calls. **If a target already has a synonym**, move that child to the final target first — synonyms do not chain, and the failure message is `no está permitido mientras existan sinónimos`.

- [ ] **Step 4: Verify every old name still filters**

For each absorbed name, `#name` must return the merged population. Zero or the 50-cap means the synonym did not register.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/data/2026-09-06-prod-collisions.json \
        docs/superpowers/specs/2026-09-06-migracion-prod-design.md
git commit -m "feat(prod): merge the spelling-collision families"
```

---

### Task 7: Derive PROD's families, create the eight groups, build the verifier

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-06-prod-module-axis.json`
- Create: `bin/prod-verify`
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: the post-Task-6 vocabulary.
- Produces: the mapping (same shape as PRE's `2026-09-04-module-axis.json`: `{"groups": {"<name>": ["<tag>", ...]}}`) and `bin/prod-verify`, exit 0 only when the mapping holds against PROD.

- [ ] **Step 1: Compute co-occurrence over PROD's corpus, excluding structural tags**

Crawl every category listing, then for each candidate subject tag count how often it shares a topic with each other tag, **excluding** the structural set (`administracion-avanzada`, `analiza`, `developers`, `alumno-certificado`, `ideas`, `mejoras`, `poster-evf`, `webinars`, `academia`, `encuentro`, `evento`, `newsletter`, `blog-gestiona`, `campana-*`, `v9`, `v10`, and whatever else Task 4 amplified). Structural tags co-occur with everything and swamp the signal.

- [ ] **Step 2: Map PROD's subject tags onto Gestiona's eight menu sections**

The eight are fixed, because the product menu is the same: **Inicio, Registro electrónico, Atención a la ciudadanía, Tramitación administrativa, Gestión económica, Aplicaciones y servicios, Analítica de datos, Configuración Gestiona**. Membership is recomputed from PROD's vocabulary. PRE's mapping at `docs/superpowers/plans/data/2026-09-04-module-axis.json` is a **reference for which section a shared tag belongs to**, not a list to copy — 48 of its 57 tags exist on PROD and 9 do not.

- [ ] **Step 3: Gate — Ricardo validates the mapping**

Present it as group → tags with counts, plus the tags that fit no group. This is the same conversation that produced PRE's eight groups and it took several rounds; budget for that.

- [ ] **Step 4: Check every group slug for shadowing BEFORE creating any group**

```python
import json, re, unicodedata

def slug(s):
    s = unicodedata.normalize("NFKD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")

# tags and category slugs come from the Task 1 capture, refreshed
shadows = {}
for name in tags:                      # every base tag name
    shadows.setdefault(slug(name), []).append(f"tag {name}")
for c in categories:                   # every category
    shadows.setdefault(c["slug"], []).append(f"category {c['id']}")
for group in GROUPS:
    if slug(group) in shadows:
        print(f"SHADOWED: {group} on #{slug(group)} by {shadows[slug(group)]}")
```

**On PRE this check did not exist and the group `Configuración` shipped shadowed by its own member tag `configuración`**, returning a subset in silence through two review rounds. Rename any shadowed group before creating it.

- [ ] **Step 5: Create the groups, checking requested count against returned count**

`POST /tag_groups.json` with `name` + `tag_names[]`, no `permissions`. **If a group returns fewer tags than requested, or any member has 0 uses, STOP** — `tag_names[]` invented an empty tag, and the membership check cannot see it because the name is right.

- [ ] **Step 6: Write `bin/prod-verify`**

Copy `bin/tags-verify`, change the env vars to the `PROD_*` names and the mapping path to `2026-09-06-prod-module-axis.json`, and keep all four assertion families:

1. **Group membership** — each group's tag-name set matches the mapping exactly, reporting `missing=` and `extra=`.
2. **The min-uses floor** — no base tag below `MIN_USES` (3), exempting any working queue such as `pendiente-etiquetar`. This is success criterion 4 and the verifier is the only thing that asserts it.
3. **The shadow check** — no group's computed slug equals a tag's or a category's.
4. **Rename integrity** — for every rename this plan performed (`caag`, `posters`, plus whatever Task 6 renamed), the old name is carried as a synonym of the new one, so `#old` still filters.

Known blind spot, carried over from PRE and worth keeping in the comment: the mapping is both the intent and the oracle, so a typo *in the mapping* passes; and the shadow check slugifies base tag names, which covers their unaccented synonyms but not a synonym whose string differs otherwise.

- [ ] **Step 7: Run it; expect PASS**

- [ ] **Step 8: Commit**

```bash
git add docs/superpowers/plans/data/2026-09-06-prod-module-axis.json bin/prod-verify \
        docs/superpowers/specs/2026-09-06-migracion-prod-design.md
git commit -m "feat(prod): eight module groups and a PROD verifier"
```

---

### Task 8: Raise subject coverage

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-06-prod-batch-decisions.json`
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: Task 7's mapping.
- Produces: the decisions file, shape `{"<tag>": {"decision": "approve"|"reject", "excluded": [<topic id>, ...]}}`.

- [ ] **Step 1: Generate title-rule proposals**

For every topic carrying no subject tag, propose each subject tag whose every token appears as a whole word in the **title** — accent-insensitive, crude `(es|s)$` plural stem, title only, never the body. **Synonyms count as their target**: a topic tagged with an absorbed name already has that subject.

- [ ] **Step 2: Gate — Ricardo validates the batches**

Present them **by tag, not by topic** — reviewing "these N topics all receive `tesauro`" is far faster than N separate decisions, because a false positive stands out against its neighbours. Expect the common-word tags to need line-by-line review; on PRE he rejected 13 batches wholesale, mostly the small ones.

- [ ] **Step 3: Apply, grouped by topic**

Group the approved pairs by topic so a topic receiving two tags costs one write, not two. Read each topic's current tags and resend with the additions; skip anything that would exceed 7.

- [ ] **Step 4: Measure coverage with a fresh crawl**

Not derived from the proposal counts — crawl and count. Record the figure and its percentage together.

- [ ] **Step 5: Set the two search settings**

```bash
set -a && source .env.local && set +a
for pair in "min_search_term_length=3" "max_tag_search_results=5"; do
  n=${pair%%=*}; v=${pair##*=}
  curl -sS -o /dev/null -w "$n -> %{http_code}\n" -X PUT \
    -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
    -H "Content-Type: application/x-www-form-urlencoded" -d "$n=$v" \
    "$PROD_DISCOURSE_URL/admin/site_settings/$n.json"
  sleep 1.3
done
```

Read both back. `min_search_term_length` at 6 rejects any query under six characters with an HTTP 400, which is why PRE's `#tag` filter was the only way to reach short terms.

- [ ] **Step 6: Run `bin/prod-verify`; expect PASS. Commit.**

---

### Task 9: The category reorganisation

The visible, irreversible half. **Its rollback is the database backup, not the capture file.**

**Files:**
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: everything above; the structural tagging is already done and this task performs none.
- Produces: PROD's category tree matching the target in `2026-08-25-category-reorganisation-design.md`.

- [ ] **Step 1: Confirm the backup is current and its restore was tested**

Do not start without this. Ask Ricardo explicitly; do not infer it from a backup listing.

- [ ] **Step 2: Re-derive the move set against today's tree**

Read the target tree from `2026-08-25-category-reorganisation-design.md`. For each move, capture the **source listing by topic id** before touching anything — verification is by id, never by count, because counts hide unlisted and definition topics.

- [ ] **Step 3: Gate — Ricardo approves the move set and the deletion list**

Category deletion is the single least reversible operation in this plan. Present source → destination → topic ids, and the categories to delete with their remaining topic counts.

- [ ] **Step 4: Execute the moves, then verify each topic landed by id**

- [ ] **Step 5: Untick the definition topics that rode along**

Definition topics travel with a bulk move, and once the source category is deleted the theme stops filtering the orphan so it surfaces in the latest lane. Read each id from the API rather than hunting the title.

- [ ] **Step 6: Delete the emptied categories, one at a time, verifying each is empty first**

- [ ] **Step 7: Re-read `events_category_id` and `ideas_category_id`**

Category ids survive rename and reparenting but not delete-and-recreate. The theme reads 59 and 18; if either changed, Task 11 must use the new value.

- [ ] **Step 8: Record every departure from the plan, then commit**

PRE's execution departed from its own plan in six recorded ways. Record each rather than smoothing it.

---

### Task 10: Close the window

- [ ] **Step 1: Run `bin/prod-verify`; expect PASS**
- [ ] **Step 2: Re-crawl and record final coverage, vocabulary size and minimum tag uses**
- [ ] **Step 3: Ask Ricardo to take PROD out of staff-writes-only mode**
- [ ] **Step 4: Revoke the Global PROD key and remove `PROD_DISCOURSE_GLOBAL_API_KEY` from `.env.local`**

The key existed for the window. Leaving a Global-scope production key in a dotfile is the risk PRE's equivalent was revoked to avoid.

- [ ] **Step 5: Update `CLAUDE.local.md`** with PROD's final state, and state plainly that the funcionalidad axis was not built there either.

---

### Task 11: Install the theme, forum already open

**Interfaces:**
- Consumes: Task 9 Step 7's confirmed category ids.

- [ ] **Step 1: Install the remote theme**

`git@github.com:gestionatools-org/ddm-discourse-theme.git`, via admin. Do **not** make it the default yet.

- [ ] **Step 2: Verify its settings resolve against PROD**

```bash
set -a && source .env.local && set +a
for t in podcast newsletter nueva-version-gestiona; do
  curl -sSL -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
    "$PROD_DISCOURSE_URL/tag/$t/l/latest.json" -o /tmp/t.json
  python3 -c "
import json, sys
print(f'  {sys.argv[1]:24} -> {len(json.load(open(\"/tmp/t.json\"))[\"topic_list\"][\"topics\"])} topics')" "$t"
  sleep 1.3
done
```

Measured on 2026-09-06: `podcast` 6, `newsletter` 22, **`nueva-version-gestiona` absent**. A zero means that homepage card silently shows its "coming soon" placeholder.

- [ ] **Step 3: Create `nueva-version-gestiona`**

There is no tag-creation endpoint. Create it via a throwaway tag group with `name` + `tag_names[]` and **no `permissions` parameter**, then delete the group — deleting a group destroys memberships, not tags.

- [ ] **Step 4: Tag PROD's release announcements with it**

Identify them by title, split announcements from training-about-the-release (the latter is `academia`/`webinars` content, not a release), and present the split to Ricardo before writing.

- [ ] **Step 5: Preview, then make it the default theme**

Check the homepage's three lanes and the highlights cards against real data before switching the default. This is the first time the theme meets PROD's content.

- [ ] **Step 6: Open the PR and let CI go green**

```bash
git push -u origin feat/prod-migration
gh pr create --title "feat(prod): migrate the tag vocabulary, subject layer and theme to production" \
  --body "Implements docs/superpowers/specs/2026-09-06-migracion-prod-design.md. Instance configuration, tags and categories on PROD; bin/prod-verify passes."
```

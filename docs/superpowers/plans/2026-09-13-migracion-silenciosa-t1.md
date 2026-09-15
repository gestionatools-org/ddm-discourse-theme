# Silent Migration — T1 (Content) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring PROD's tag vocabulary, subject layer and search settings to the state PRE reached, plus the additive tail that creates the three programme rooms closed to staff — all of it invisible to a member signing in.

**Architecture:** Instance work on `gestionaavanza.espublico.com` through the Discourse admin API, with one repository change first: `bin/_discourse.py` learns to point at either instance, so every existing script serves PROD without being copied. There is no test runner for instance work — **each task measures the live state before, applies, and measures after; the "before" measurement is the failing test, and the task is done when the "after" matches.** Several tasks stop for Ricardo's decision mid-flight; those gates are marked and are not optional.

**Tech Stack:** Discourse admin API (`/tags.json`, `/tag_groups.json`, `/tag/<id>/settings.json`, `/tag/<id>/synonyms.json`, `/tag/<id>/info.json`, `PUT /t/-/<id>.json`, `/categories.json`, `/admin/site_settings/<name>.json`, `/admin/logs/staff_action_logs.json`), Python 3.9 standard library only, `curl` for probes, `bin/_discourse.py` for everything else.

**Spec:** `docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md`

## Global Constraints

- **This is production.** Every write is visible to the whole community. When a step's outcome is not what the plan predicts, STOP and report — do not improvise on a live instance.
- **There is no maintenance window, by design.** A `staff_writes_only` notice is the opposite of a silent migration. The protection is that **every batch re-reads the live state immediately before writing** and verifies by topic id, never by count.
- **`DISCOURSE_INSTANCE=PROD` on every command**, and there is deliberately no default: an unset value kills the script on its first API call. Verify the banner each script prints before letting a write run.
- **Credentials come from `.env.local` via `source`, in the same shell invocation as the command.** `PROD_DISCOURSE_GLOBAL_API_KEY` must appear **once**; `.env.local` has twice had a duplicate name silently shadow another, and `source` takes the last. **Never print any key value, not even redacted.**
- **Rate limit ~1 req/s.** Sleep 1.2–1.3 s between calls; back off 8 s on HTTP 429. `bin/_discourse.py` already does both.
- **Python 3.9 standard library only.** No pip installs — the corporate TLS proxy breaks them.
- **No background jobs.** Run every crawl and write loop inline, printing progress. Four subagents on the PRE plan stalled for ten-plus minutes waiting on notifications from their own background work.
- **A topic's tags arrive as objects `{id, name, slug}`, not strings.** Re-sending them unnormalised created 13 junk tags and stripped nine topics of their real ones, with HTTP 200 on all nine. Always normalise through `d.tag_names(topic)`, and **re-read the names after writing** — the 200 says nothing and the per-topic tag *count* was even correct.
- **`PUT /t/-/<id>.json` replaces a topic's whole tag set.** GET the topic, normalise, resend with the addition. `max_tags_per_topic` is the ceiling: skip and report any topic that would exceed it, never truncate.
- **Renaming a tag does not preserve its old name.** After every rename, recreate the old name as a synonym with `tags[][name]`, or `#old-name` silently degrades to full-text search and returns a larger, plausible, wrong set.
- **Synonyms do not chain.** Merging a tag that already has a synonym fails with `no está permitido mientras existan sinónimos`. Move the child to the final target first.
- **Creating a tag group: send no `permissions` as form-encoded** (HTTP 500). As `Content-Type: application/json` it is accepted.
- **Every write to a topic costs it its list thumbnail, permanently.** Both routes, and a rebake does not bring it back. Measure `image_url` before any batch that writes to topics.
- **Captures never enter the repository.** It is public by obligation — the theme is cloned over anonymous HTTPS — so any file holding topic titles or member data is born gitignored.
- **`main` is protected.** Work on a branch, open a PR, and watch the four required CI checks go green before merging; `gh pr merge --auto` does not gate CI from this account.

## Amendments 2026-09-15 (measured after this plan was written)

Sequenced in `2026-09-15-migracion-prod-hoja-de-ruta.md`, which is the entry point from here.

- **Task 1 is done** (`6db5986` on `main`).
- **Task 2 Steps 1–2 are answered**: the Global key exists once as `PROD_DISCOURSE_GLOBAL_API_KEY`;
  PROD runs **2026.9.0-latest**. Re-run them as a check only.
- **Expected counts moved**: ~219 tags, **36** categories (89 "Anuncios" is new). `caag` 130,
  `posters` 171. Ceilings still 3 / 20.
- **Protected topics `/t/2683`, `/t/2690`, `/t/2673`**: every loop that writes to a topic skips them
  (guard added to Tasks 5 and 9). Any other action on them needs Ricardo's explicit yes.
- **Ids after the restore collide**: category 89 and group 98 (`Votacion` on PROD) mean different
  things on each instance. Task 11 resolves `Developers` and the rooms by name; PROD's room ids
  replace 89/90/91 everywhere PROD is concerned.
- **The granular PROD key reads `/t/<id>.json` and listings (200)** but not `/c/<id>/show.json`
  (403) — `d.category()` already uses the Global key.

---

### Task 1: Point the toolchain at an instance

The only repository change in T1, and it comes first because every later task runs a `bin/` script against PROD.

**Files:**
- Modify: `bin/_discourse.py:17-34` (the three env readers)
- Modify: `bin/tags-verify:1-12` (its own env readers and mapping path)
- Create: `bin/selftest-instance`

**Interfaces:**
- Consumes: nothing.
- Produces: `DISCOURSE_INSTANCE` (`"PRE"`|`"PROD"`) honoured by `bin/_discourse.py` and `bin/tags-verify`; `d.banner()` printing instance and URL to stderr once per process. Every later task runs its scripts with `DISCOURSE_INSTANCE=PROD` in the environment.

**Scope note:** `bin/categories-verify` is **not** parameterised here. It asserts PRE's entire genre-reorganisation state and against PROD would fail on every line. It stays PRE-only until the T2 plan; the rooms Task 11 creates get their own assertion in Task 12.

- [ ] **Step 1: Write the failing self-test**

Create `bin/selftest-instance`, executable, stdlib only. It exercises the resolution logic without any credential, which is exactly what `_discourse.py`'s own comment says import must stay free enough to allow.

```python
#!/usr/bin/env python3
"""Assert that instance resolution refuses to guess. No credentials needed.

`_discourse` reads the environment at call time, not at import, so this can import it
with nothing set and still drive every branch.
"""
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402

FAILURES = []


def check(label, fn, expect_exit, contains=None):
    try:
        value = fn()
    except SystemExit as exc:
        if not expect_exit:
            FAILURES.append(f"{label}: unexpected SystemExit({exc})")
        elif contains and contains not in str(exc):
            FAILURES.append(f"{label}: message {str(exc)!r} lacks {contains!r}")
        return
    if expect_exit:
        FAILURES.append(f"{label}: expected SystemExit, got {value!r}")
        return
    return value


os.environ.pop("DISCOURSE_INSTANCE", None)
check("unset dies", d._instance, expect_exit=True, contains="DISCOURSE_INSTANCE")

os.environ["DISCOURSE_INSTANCE"] = "pre"
check("lowercase dies", d._instance, expect_exit=True, contains="PRE or PROD")

os.environ["DISCOURSE_INSTANCE"] = "STAGING"
check("unknown dies", d._instance, expect_exit=True, contains="PRE or PROD")

for instance, url, user, ro, rw in [
    ("PRE", "https://pre.example/", "u-pre", "k-pre-ro", "k-pre-rw"),
    ("PROD", "https://prod.example/", "u-prod", "k-prod-ro", "k-prod-rw"),
]:
    os.environ["DISCOURSE_INSTANCE"] = instance
    os.environ[f"{instance}_DISCOURSE_URL"] = url
    os.environ[f"{instance}_DISCOURSE_API_USERNAME"] = user
    os.environ[f"{instance}_DISCOURSE_API_KEY"] = ro
    os.environ[f"{instance}_DISCOURSE_GLOBAL_API_KEY"] = rw
    if d._url() != url.rstrip("/"):
        FAILURES.append(f"{instance}: _url() -> {d._url()!r}")
    if d._user() != user:
        FAILURES.append(f"{instance}: _user() -> {d._user()!r}")
    if d._key(False) != ro:
        FAILURES.append(f"{instance}: read key resolved to the wrong variable")
    if d._key(True) != rw:
        FAILURES.append(f"{instance}: elevated key resolved to the wrong variable")

os.environ["DISCOURSE_INSTANCE"] = "PROD"
os.environ.pop("PROD_DISCOURSE_GLOBAL_API_KEY", None)
check("missing variable dies", lambda: d._key(True), expect_exit=True, contains="PROD_DISCOURSE_GLOBAL_API_KEY")

if FAILURES:
    print("FAIL")
    for f in FAILURES:
        print("  " + f)
    raise SystemExit(1)
print("PASS  instance resolution refuses to guess, and each instance reads its own variables")
```

- [ ] **Step 2: Run it to verify it fails**

```bash
chmod +x bin/selftest-instance && ./bin/selftest-instance
```

Expected: `AttributeError: module '_discourse' has no attribute '_instance'`. That is the red step — the helper does not exist yet.

- [ ] **Step 3: Implement instance resolution in `bin/_discourse.py`**

Replace the three readers. **Resolution stays at call time**, not import, so the self-test above can import with an empty environment.

```python
PAUSE = 1.3  # both instances rate-limit at roughly 1 req/s

_ANNOUNCED = False


def _instance():
    """Which instance this process talks to. There is deliberately no default.

    A default is how a script meant for PRE ends up writing to production. An unset or
    unknown value dies here rather than silently picking one.
    """
    value = os.environ.get("DISCOURSE_INSTANCE")
    if value not in ("PRE", "PROD"):
        raise SystemExit(
            f"DISCOURSE_INSTANCE={value!r}: set it to PRE or PROD. There is no default — "
            "guessing the instance is how a script meant for PRE writes to production."
        )
    return value


def _env(suffix):
    name = f"{_instance()}_DISCOURSE_{suffix}"
    if name not in os.environ:
        raise SystemExit(f"{name} is not set. Did you `set -a && source .env.local && set +a`?")
    return os.environ[name]


def _url():
    return _env("URL").rstrip("/")


def _user():
    return _env("API_USERNAME")


def _key(elevated):
    """Ask for the key the call needs, so an ordinary read never carries a write-capable
    credential.

    `elevated` is not the same as "writes". Every write needs the Global key, but so do
    several *reads*: /c/<id>/show.json, /tags.json and /tag_groups.json all answer 403
    with the granular read-only key, which is why this flag is named after the key it
    picks rather than after the HTTP verb. Never log either value.
    """
    return _env("GLOBAL_API_KEY" if elevated else "API_KEY")


def banner():
    """Print instance and URL once per process, to stderr, so no log is ambiguous about
    what it ran against. The URL is not a secret; the key never appears here.
    """
    global _ANNOUNCED
    if not _ANNOUNCED:
        print(f"[{_instance()}] {_url()}", file=sys.stderr)
        _ANNOUNCED = True
```

Add `import sys` to the imports at the top of the file, and call `banner()` as the first line of `request()`:

```python
def request(method, path, data=None, elevated=False, retries=4, allow_404=False):
    banner()
    headers = {"Api-Key": _key(elevated), "Api-Username": _user(), "Accept": "application/json"}
```

- [ ] **Step 4: Run the self-test to verify it passes**

```bash
./bin/selftest-instance
```

Expected: `PASS  instance resolution refuses to guess, and each instance reads its own variables`

- [ ] **Step 5: Point `bin/tags-verify` at the shared client**

Replace its header — its own `URL`/`KEY`/`USER` reads and its private `get()` — so it uses `_discourse` and picks its mapping by instance.

```python
import json, pathlib, re, sys, unicodedata

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAPS = {
    "PRE": "2026-09-04-module-axis.json",
    "PROD": "2026-09-13-prod-module-axis.json",
}
MAP = json.loads((ROOT / "docs/superpowers/plans/data" / MAPS[d._instance()]).read_text())
```

Then replace every `get("...")` call in the file with `d.get("...", elevated=True)` and delete the private `get()` definition and the `time.sleep(1.2)` lines — `d.request` already paces itself. `/tags.json`, `/tag_groups.json` and `/tag/<id>/info.json` all need the Global key, which is why `elevated=True` is not optional here.

- [ ] **Step 6: Prove the refactor changed no behaviour on PRE**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PRE ./bin/tags-verify
```

Expected: `[PRE] https://discourse.gestiona4dev.tech` on stderr, then **PASS** — the same result it gives today. A refactor that breaks the verifier is a refactor that removes the only assertion T1 has.

```bash
./bin/tags-verify; echo "exit=$?"
```

Expected: exit non-zero with the `DISCOURSE_INSTANCE` message. An unset instance must not fall back to PRE.

- [ ] **Step 7: Harden `.gitignore` for the files this plan creates**

PROD's captures must be born outside the repository. Append:

```
docs/superpowers/plans/data/*-capture.json
docs/superpowers/plans/data/*-title-proposals.json
```

Then untrack the one that is already committed — 92 KB of topic titles with their ids, from a `login_required` community:

```bash
git rm --cached docs/superpowers/plans/data/2026-09-04-title-proposals.json
```

**This does not remove it from history, and it cannot be removed:** `main` blocks force-pushes and is what every instance pulls. It stops the file growing and stops PROD's equivalent joining it. Say that plainly in the commit message rather than implying a fix.

- [ ] **Step 8: Lint and commit**

```bash
npx pnpm@10.28.0 lint > /tmp/lint.txt 2>&1; code=$?
grep -E "✖|error" /tmp/lint.txt; [ "$code" -eq 0 ] || exit 1
git checkout -b feat/prod-t1-content
git add bin/_discourse.py bin/tags-verify bin/selftest-instance .gitignore
git rm --cached docs/superpowers/plans/data/2026-09-04-title-proposals.json
git commit -m "feat(bin): resolve the Discourse instance from the environment

Every bin/ script reads PRE_* today, so serving PROD meant copying them. They
now read \${DISCOURSE_INSTANCE}_DISCOURSE_*, with no default: an unset value
dies on the first API call, because a default is how a script meant for PRE
writes to production. Each process prints its instance and URL to stderr once.

bin/tags-verify moves onto the shared client and picks its module-axis mapping
by instance, so PROD gets a verifier rather than a copy of one.

Untracks 2026-09-04-title-proposals.json and gitignores its pattern. The repo
is public because the theme is cloned over anonymous HTTPS, and the file is
92 KB of topic titles from a login-required community. This does NOT remove it
from history and history cannot be rewritten here — main blocks force-pushes
and is what every instance pulls. It stops the file growing and keeps PROD's
equivalents out."
```

---

### Task 2: Pre-flight — the key, the version, the ceilings, the capture

Answers the two questions that can invalidate the whole schedule, before anything is written.

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-13-prod-capture.json` (gitignored by Task 1)

**Interfaces:**
- Consumes: Task 1's `DISCOURSE_INSTANCE`.
- Produces: the capture file, shape `{"tags": {"<name>": <count>}, "topics": {"<id>": {"cat": <int>, "title": "<str>", "tags": ["<name>", ...], "image_url": "<str>|null"}}, "categories": [{"id": <int>, "name": "<str>", "slug": "<str>", "parent": <int|null>}], "settings": {"<name>": "<value>"}, "sidebar_sections": [...], "version": "<str>"}`. Every later task reads `tags` and `topics` from it for its before-measurement.

- [ ] **Step 1: Confirm the Global key exists and that the read-only key is not it**

```bash
set -a && source .env.local && set +a
for k in PROD_DISCOURSE_GLOBAL_API_KEY PROD_DISCOURSE_API_KEY; do
  eval "v=\$$k"
  code=$(curl -sS -o /dev/null -w "%{http_code}" -H "Api-Key: $v" \
    -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" "$PROD_DISCOURSE_URL/tags.json")
  echo "$k -> /tags.json $code"; sleep 1.3
done
grep -c '^PROD_DISCOURSE_GLOBAL_API_KEY=' .env.local
```

Expected: the Global key **200**, the read-only key **403**, and the `grep -c` printing exactly **1**. A pair that behaves identically means one is not what its name says. If the Global key is absent or 403, STOP — nothing after this can run, and creating an API key needs the admin UI.

- [ ] **Step 2: Read PROD's Discourse version**

```bash
set -a && source .env.local && set +a
curl -sSL -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  "$PROD_DISCOURSE_URL/about.json" -o /tmp/about.json
python3 -c "
import json
a = json.load(open('/tmp/about.json'))['about']
print('version    ', a.get('version'))
print('latest     ', a.get('latest_version'))
print('title      ', a.get('title'))"
```

`minimum_discourse_version` in `about.json` is **2026.7.0**. Below it the theme does not install and the Blocks API does not exist, which invalidates T3 and therefore the schedule. **Report the value to Ricardo whatever it is** — this is the cheapest question in the plan and the most expensive one to discover late.

- [ ] **Step 3: Read the settings that gate later tasks**

```bash
set -a && source .env.local && set +a
curl -sSL -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  "$PROD_DISCOURSE_URL/admin/site_settings.json" -o /tmp/ss.json
python3 -c "
import json
d = json.load(open('/tmp/ss.json'))['site_settings']
want = {'max_tags_per_topic','max_tag_length','max_tag_search_results','min_search_term_length',
        'max_tags_in_filter_list','tagging_enabled','force_lowercase_tags','default_locale',
        'search_ignore_accents','create_tag_allowed_groups','tag_topic_allowed_groups',
        'slug_generation_method','enable_welcome_banner'}
for s in sorted(d, key=lambda x: x['setting']):
    if s['setting'] in want:
        print(f\"  {s['setting']:32} = {s['value']!r}\")"
```

**Record these verbatim.** `max_tags_per_topic` at 3 and `max_tag_length` at 20 are what broke the August bulk tagging on PRE partway; Task 3 raises them before anything appends a tag.

- [ ] **Step 4: Capture the full prior state, including every topic's thumbnail**

```python
import json, os, sys, pathlib, time
sys.path.insert(0, "bin")
import _discourse as d

OUT = pathlib.Path("docs/superpowers/plans/data/2026-09-13-prod-capture.json")

cats, stack = [], list(d.get("/categories.json?include_subcategories=true",
                             elevated=True)["category_list"]["categories"])
while stack:
    c = stack.pop()
    cats.append({"id": c["id"], "name": c["name"], "slug": c["slug"],
                 "parent": c.get("parent_category_id")})
    stack.extend(c.get("subcategory_list") or [])

topics = {}
for cid in sorted(x["id"] for x in cats):
    found = d.crawl_category(cid)
    for tid, t in found.items():
        topics[tid] = {"cat": t.get("category_id"), "title": t["title"],
                       "tags": d.tag_names(t), "image_url": t.get("image_url")}
    print(f"cat {cid:3}: +{len(found):4}  total {len(topics)}", flush=True)

tags = {t["name"]: t["count"] for t in d.get("/tags.json", elevated=True)["tags"]}
settings = {s["setting"]: s["value"]
            for s in d.get("/admin/site_settings.json", elevated=True)["site_settings"]}
sidebar = d.get("/sidebar_sections.json", elevated=True).get("sidebar_sections", [])
version = d.get("/about.json", elevated=True)["about"].get("version")

OUT.write_text(json.dumps({"tags": tags, "topics": topics, "categories": cats,
                           "settings": settings, "sidebar_sections": sidebar,
                           "version": version}, ensure_ascii=False))
withimg = sum(1 for t in topics.values() if t["image_url"])
print(f"\ncaptured {len(tags)} tags, {len(topics)} topics ({withimg} with a thumbnail), "
      f"{len(cats)} categories, {len(settings)} settings, {len(sidebar)} sidebar sections")
for s in sidebar:
    print(f"  section {s['id']:3} {'public' if s['public'] else 'private'} {s['title']}")
    for l in s["links"]:
        print(f"      -> {l['name']}  {l['value']}")
```

Run it with the instance set:

```bash
set -a && source .env.local && set +a
# Save the Python above as /tmp/capture.py first — it is a throwaway, not a bin/ script:
DISCOURSE_INSTANCE=PROD python3 /tmp/capture.py
```

Expected, within drift: about **218 tags, 1 297 topics, 35 categories**. A materially different figure means PROD moved again — record the new numbers and carry those forward, never the spec's.

**`image_url` is captured because it is the currency every later write spends.** A topic that has one and gets written loses it permanently, and the only way to know what a batch will cost is to have measured it first.

**Two things to look for in the sidebar printout**, neither of which changes a step here but both of which T3 has to settle: a *public* section whose links point at `read_restricted` categories — core does not permission-filter custom section links, so it advertises destinations most members cannot open; and a private section, meaning `public: false`. `/sidebar_sections.json` returns only sections that are public or the caller's own, so **this is `PROD_DISCOURSE_API_USERNAME`'s rail, not everyone's**. Do not report it as "PROD's sidebar".

- [ ] **Step 5: Identify who has been tagging PROD**

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

**The acting username is not proof of a person.** Every call this project makes is logged under `PROD_DISCOURSE_API_USERNAME`, the same signature our own writes will carry. Read the log for *actions* and *timing*; confirm identity with Ricardo. This exact confusion cost a fix round on the PRE plan.

- [ ] **Step 6: Gate — report to Ricardo, and have him warn the tagger**

Report: PROD's Discourse version against the 2026.7.0 floor; the measured ceilings and whether Task 3 must raise them; the capture's three counts against the expected 218/1297/35; and the thumbnail total. Ask him to tell whoever is tagging PROD that `caag` is about to be renamed — the synonym preserves their work and `#caag` keeps filtering, but they should hear it beforehand rather than discover it.

- [ ] **Step 7: Commit the pre-flight record (not the capture — it is gitignored)**

```bash
git add docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "chore(prod): pre-flight measurements before T1

Discourse version, the two tag ceilings, the vocabulary and topic counts, and
every topic's thumbnail — the currency each later write spends. The capture
file itself stays out of the repo: it holds every topic title of a
login-required community."
```

---

### Task 3: Raise the two ceilings

**Files:**
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: Task 2's settings reading.
- Produces: `max_tags_per_topic` ≥ 7 and `max_tag_length` ≥ 30 on PROD. Task 4's rename and Task 5's bulk tagging both depend on these.

- [ ] **Step 1: Prove a write reaches the API, on a setting that does not matter**

```bash
set -a && source .env.local && set +a
curl -sS -o /dev/null -w "probe -> %{http_code}\n" -X PUT \
  -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  -H "Content-Type: application/x-www-form-urlencoded" -d "max_tags_in_filter_list=30" \
  "$PROD_DISCOURSE_URL/admin/site_settings/max_tags_in_filter_list.json"
```

Expected: **200 or 204**. A 503 with a read-only message means somebody put PROD into `readonly_mode` — STOP and tell Ricardo. The probe uses a harmless setting deliberately, so a failure costs nothing.

- [ ] **Step 2: Raise both**

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

Expected: `7` and `30`. **A PUT that returns 200 without changing the value is exactly what this step exists to catch.**

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "chore(prod): raise the tag ceilings before any bulk tagging

max_tags_per_topic 3 -> 7 and max_tag_length 20 -> 30. At the old values the
August bulk tagging on PRE failed partway on ~100 topics and truncated
administracion-avanzada (23 chars) to administracion-avanz on entry."
```

---

### Task 4: Rename `caag` and `posters`

**Files:**
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: Task 3's raised `max_tag_length`.
- Produces: `administracion-avanzada` carrying `caag`'s topics with `caag` as a synonym, and `poster-evf` carrying `posters`' topics with `posters` as a synonym. Task 5 appends `administracion-avanzada` and Task 6 puts it in a tag group.

**Neither is a merge.** Neither target exists on PROD, and `add_or_create_synonyms` needs an existing target — `DiscourseTagging` will not invent one. Both operations are `topic_tags` rewrites at the database level, so **no topic is written and no thumbnail is lost.**

- [ ] **Step 1: Capture the before-state of all four names**

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

Record the numbers. Expected: `caag` and `posters` non-zero (about 129 and 170), the two targets returning a full-text fallback because they do not exist yet.

- [ ] **Step 2: Rename both, then recreate the old names as synonyms**

```python
import sys, time
sys.path.insert(0, "bin")
import _discourse as d

ids = {t["name"]: t["id"] for t in d.get("/tags.json", elevated=True)["tags"]}

for old, new in [("caag", "administracion-avanzada"), ("posters", "poster-evf")]:
    if old not in ids:
        print(f"SKIP {old}: not present"); continue
    if new in ids:
        print(f"SKIP {old}: {new} already exists — this would be a merge, not a rename"); continue
    tid = ids[old]
    d.request("PUT", f"/tag/{tid}/settings.json",
              data=[("tag_settings[name]", new), ("tag_settings[slug]", new)], elevated=True)
    print(f"renamed {old} -> {new}")
    # The tag keeps its id across a rename, so tid still addresses it. Recreating the old
    # name is a SEPARATE call and must follow every rename: the rename does not preserve
    # it, and #old-name silently degrades to full text.
    r = d.request("POST", f"/tag/{tid}/synonyms.json", data=[("tags[][name]", old)], elevated=True)
    print(f"  synonym '{old}' -> {new}: failed_tags={r.get('failed_tags')}")
```

```bash
set -a && source .env.local && set +a
# Save the Python above as /tmp/rename.py first:
DISCOURSE_INSTANCE=PROD python3 /tmp/rename.py
```

- [ ] **Step 3: Verify the old names still filter and nothing truncated**

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
curl -sSL -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  "$PROD_DISCOURSE_URL/tags.json" -o /tmp/t.json
python3 -c "
import json
a = {t['name']: t['count'] for t in json.load(open('/tmp/t.json'))['tags']}
print('administracion-avanzada:', a.get('administracion-avanzada', 'ABSENT'))
print('poster-evf            :', a.get('poster-evf', 'ABSENT'))
print('truncated variants    :', [n for n in a if n.startswith('administracion-avanz') and n != 'administracion-avanzada'])"
```

Expected: all four names returning the same population as their pair; the full 23-character name present; **no truncated variant**. A truncated variant means Task 3 did not actually take. A drop to 0, or a jump to the 50-per-page cap on an old name, means the synonym did not register and the query fell through to full text.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "feat(prod): rename caag and posters to their PRE names

caag -> administracion-avanzada and posters -> poster-evf, each with the old
name recreated as a synonym so #caag and #posters keep filtering. Renames, not
merges: neither target existed on PROD, and a rename costs no thumbnails."
```

---

### Task 5: Bulk-tag the structural layer by source category

The task that broke on PRE. It appends structural tags to whole categories, **against PROD's current 35-category tree** — it tags each topic by the category it is already in, which is why it must run before any reorganisation.

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-13-prod-bulk-tagging.json` (executed record; ids and counts only, no titles)
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: Task 3's ceilings, Task 4's `administracion-avanzada`, Task 2's capture.
- Produces: the record, shape `{"<category id>": {"name": "<str>", "tags": ["<name>", ...], "topics": <int>, "applied": <int>, "skipped": <int>, "failed": <int>, "thumbnails_lost": <int>}}`.

- [ ] **Step 1: Revalidate the August table against today's listings**

The source table is in `docs/superpowers/specs/2026-08-25-category-reorganisation-design.md` under *PROD, as originally planned*. Its counts are a month old **and the instance has been tagged since**, so every row is re-measured. Its Webinars row is known wrong for PROD: it assumes `seminarios`, `webinar` and `seminario` were already merged into `webinars`, which happened only on PRE.

```python
import json, sys
sys.path.insert(0, "bin")
import _discourse as d

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
CEILING = 7

report = {}
for cid, want in PLAN.items():
    topics = d.crawl_category(cid)
    missing, over, cost = {t: 0 for t in want}, [], 0
    for t in topics.values():
        have = set(d.tag_names(t))
        add = [x for x in want if x not in have]
        for x in add:
            missing[x] += 1
        if add and len(have | set(want)) > CEILING:
            over.append(t["id"])
        if add and t.get("image_url"):
            cost += 1
    report[cid] = {"topics": len(topics), "tags": want, "missing": missing,
                   "would_exceed_ceiling": over, "thumbnails_at_risk": cost}
    print(f"  cat {cid:3}: {len(topics):4} topics, missing {missing}, "
          f"over ceiling {len(over)}, thumbnails at risk {cost}")
json.dump(report, open("/tmp/bulk-plan.json", "w"), ensure_ascii=False, indent=1)
```

**Two red flags in that output.** A non-empty `would_exceed_ceiling` is the PRE failure repeating — those topics are handled by hand, never by truncation. And `thumbnails_at_risk` is the permanent bill: every one of those topics loses its list thumbnail for good.

- [ ] **Step 2: Gate — Ricardo approves the revalidated table and its thumbnail bill**

Present it as category → tags → topics missing the tag → topics over the ceiling → **thumbnails that will be lost**. Do not write until he approves. The campaign tag names (`campana-2024`, `campana-febrero-2025`, `campana-v9`) came from PRE's first naming and he may prefer the `ideas-*` forms PRE ended up with.

- [ ] **Step 3: Apply, one topic at a time, reading each first**

```python
import json, sys
sys.path.insert(0, "bin")
import _discourse as d

plan = json.load(open("/tmp/bulk-plan.json"))
CEILING = 7
PROTECTED = {2683, 2690, 2673}  # see CLAUDE.local.md — never written without Ricardo's yes
log = {}

for cid, row in plan.items():
    want = row["tags"]
    applied = skipped = failed = lost = 0
    for tid, t in sorted(d.crawl_category(int(cid)).items()):
        if tid in PROTECTED:
            print(f"  /t/{tid} PROTECTED — skipped, ask Ricardo"); skipped += 1; continue
        full = d.get(f"/t/{tid}.json")
        have = d.tag_names(full)          # objects -> names. Never resend the objects.
        add = [x for x in want if x not in have]
        if not add:
            skipped += 1; continue
        if len(have) + len(add) > CEILING:
            print(f"  /t/{tid} SKIPPED: {len(have)} tags + {len(add)} exceeds {CEILING}")
            skipped += 1; continue
        d.request("PUT", f"/t/-/{tid}.json",
                  data=[("tags[]", n) for n in have + add], elevated=True)
        back = d.tag_names(d.get(f"/t/{tid}.json"))
        if set(back) != set(have + add):
            print(f"  /t/{tid} MISMATCH after write: {back}")
            failed += 1
        else:
            applied += 1
        if t.get("image_url"):
            lost += 1
    log[cid] = {"tags": want, "topics": row["topics"], "applied": applied,
                "skipped": skipped, "failed": failed, "thumbnails_lost": lost}
    print(f"cat {cid} done — applied={applied} skipped={skipped} failed={failed} "
          f"thumbnails_lost={lost}", flush=True)
json.dump(log, open("docs/superpowers/plans/data/2026-09-13-prod-bulk-tagging.json", "w"),
          ensure_ascii=False, indent=1)
```

**The re-read after every write is not optional.** On PRE a defective script got HTTP 200 nine times while writing junk tag names and stripping the real ones; the per-topic tag *count* was correct and only the names gave it away. This writes one topic at a time rather than using the admin bulk dialog, because the bulk route fails partway when it meets the ceiling instead of reporting cleanly.

- [ ] **Step 4: Verify the counts moved as predicted**

```bash
set -a && source .env.local && set +a
curl -sSL -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  "$PROD_DISCOURSE_URL/tags.json" -o /tmp/t.json
python3 -c "
import json
before = json.load(open('docs/superpowers/plans/data/2026-09-13-prod-capture.json'))['tags']
after  = {t['name']: t['count'] for t in json.load(open('/tmp/t.json'))['tags']}
plan   = json.load(open('/tmp/bulk-plan.json'))
expect = {}
for row in plan.values():
    for tag, n in row['missing'].items():
        expect[tag] = expect.get(tag, 0) + n
for tag, n in sorted(expect.items()):
    b, a = before.get(tag, 0), after.get(tag, 0)
    flag = '' if a - b == n else '   <-- RECONCILE'
    print(f'  {tag:28} {b:4} -> {a:4}  (expected +{n}, got +{a-b}){flag}')"
```

Reconcile **every** discrepancy before continuing. An unexplained gap here propagates into every later measurement, including the coverage figure that is a success criterion.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/data/2026-09-13-prod-bulk-tagging.json \
        docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "feat(prod): bulk-tag the structural layer by source category

Applied against PROD's current 35-category tree, because this tags each topic
by the category it is already in — the reason the content tranche has to run
before the reorganisation. Every write re-read by tag name afterwards."
```

---

### Task 6: Recreate the `programa-certificacion` tag group

**Files:**
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: Task 4's `administracion-avanzada`.
- Produces: a tag group `programa-certificacion` holding `administracion-avanzada`, `analiza`, `developers`, with `one_per_topic: true`.

- [ ] **Step 1: Confirm all three tags exist with non-zero counts**

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

All three must be present. **`tag_names[]` creates any tag it names**, so a missing one would be silently invented as an empty tag rather than reported.

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

**No `permissions` parameter here** — form-encoded it returns HTTP 500. (It *is* accepted as `Content-Type: application/json`, which is how `idea-registrada`'s permission group was created on PRE; this group needs none.)

- [ ] **Step 3: Verify membership and that nothing was invented**

```bash
set -a && source .env.local && set +a
curl -sSL -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
  "$PROD_DISCOURSE_URL/tag_groups.json" -o /tmp/tg.json
python3 -c "
import json
for g in json.load(open('/tmp/tg.json'))['tag_groups']:
    if g['name'] == 'programa-certificacion':
        print('one_per_topic:', g.get('one_per_topic'))
        for t in g['tags']:
            print(f\"  {t['name']:26} {t.get('count','?')}\")"
```

Exactly three tags, all with non-zero counts. **A member at 0 uses means `tag_names[]` created it** — the membership check cannot catch that, because the name is right.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "feat(prod): recreate the programa-certificacion tag group"
```

---

### Task 7: Merge the spelling collisions, and give every accented tag an unaccented synonym

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-13-prod-collisions.json`
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: the post-Task-5 vocabulary.
- Produces: the decisions file, shape `{"<canonical>": {"absorb": ["<name>", ...], "rename_to": "<name>|null"}}`, plus one unaccented synonym per accented base tag. Task 8 derives families from the vocabulary this leaves.

**No merge writes to a topic.** `add_or_create_synonyms` is raw SQL — `DELETE` plus `UPDATE topic_tags SET tag_id` — so it never touches `PostRevisor` and **costs no thumbnails**. It is also **not reversible**: `destroy_synonym` unlinks the tag but leaves the topics on the target.

- [ ] **Step 1: Re-detect the collision families on today's vocabulary**

```python
import re, sys, unicodedata
from collections import defaultdict
sys.path.insert(0, "bin")
import _discourse as d

tags = {t["name"]: t["count"] for t in d.get("/tags.json", elevated=True)["tags"]}

def root(s):
    s = unicodedata.normalize("NFKD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"(es|s)$", "", re.sub(r"[^a-z0-9]", "", s))

groups = defaultdict(list)
for name, count in tags.items():
    groups[root(name)].append((name, count))
for members in sorted((m for m in groups.values() if len(m) > 1),
                      key=lambda m: -sum(c for _, c in m)):
    print("   " + " | ".join(f"{n}({c})" for n, c in sorted(members, key=lambda x: -x[1])))
```

The spec recorded **11 families** on 2026-09-06. Expect the set to have moved, and note that Task 5 has just amplified some counts.

- [ ] **Step 2: Gate — Ricardo picks the canonical form for each family**

Present each family with its counts. Convention from PRE: **no accent, hyphenated**. Two rules learned there, both of which cost an attempt:

- **Pick as merge target the tag that already carries the right name**, not the most-used one. The topics move to the target either way, and this sidesteps the slug mangling (`páginas-informativas` becomes `p-ginas-informativas`, but `búsquedas-avanzadas` becomes `busquedas-avanzadas` — `index_tags_on_slug` is not unique, so a collision does not error, it just makes URL lookup ambiguous).
- If no member carries the right name, merge into the most-used and rename afterwards — **and recreating the target's old name as a synonym is a separate call that must follow the rename.** Forgetting it on PRE took `#circuitosresolucion`, an established 34-use name, out of service for minutes.

Three PRE false positives worth not re-proposing if they appear: `ideas-2024`/`ideas-2025` (deliberate campaign years), `congreso`/`congreso-gestiona` (external congresses versus the community's own), and any pair Ricardo has already ruled a genuine distinction.

- [ ] **Step 3: Apply the merges**

```python
import json, sys
sys.path.insert(0, "bin")
import _discourse as d

decisions = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-collisions.json"))
ids = {t["name"]: t["id"] for t in d.get("/tags.json", elevated=True)["tags"]}

for canonical, row in decisions.items():
    target = ids[canonical]
    for name in row["absorb"]:
        if name not in ids:
            print(f"  SKIP {name}: absent"); continue
        r = d.request("POST", f"/tag/{target}/synonyms.json",
                      data=[("tags[][id]", ids[name])], elevated=True)
        print(f"  {name} -> {canonical}: failed_tags={r.get('failed_tags')}")
    if row.get("rename_to"):
        new = row["rename_to"]
        d.request("PUT", f"/tag/{target}/settings.json",
                  data=[("tag_settings[name]", new), ("tag_settings[slug]", new)], elevated=True)
        # A rename drops the old name. Recreating it is a SEPARATE call.
        d.request("POST", f"/tag/{target}/synonyms.json",
                  data=[("tags[][name]", canonical)], elevated=True)
        print(f"  renamed {canonical} -> {new}, old name kept as a synonym")
```

**If a target already has a synonym, move that child to the final target first** — synonyms do not chain, and the failure reads `no está permitido mientras existan sinónimos`.

- [ ] **Step 4: Give every accented base tag an unaccented synonym**

`Tag.where_name` compares `lower(name)` with **no `unaccent`**, so an accented tag is only reachable by typing the accent — and the failure is silent and *generous*: on PRE, `#padron` returned 50 (the page cap, a full-text fallback) where `#padrón` returned 17.

```python
import sys, unicodedata
sys.path.insert(0, "bin")
import _discourse as d

def strip(s):
    s = unicodedata.normalize("NFKD", s)
    return "".join(c for c in s if not unicodedata.combining(c))

tags = {t["name"]: t["id"] for t in d.get("/tags.json", elevated=True)["tags"]}
for name, tid in sorted(tags.items()):
    plain = strip(name)
    if plain == name or plain in tags:
        continue
    r = d.request("POST", f"/tag/{tid}/synonyms.json",
                  data=[("tags[][name]", plain)], elevated=True)
    print(f"  {name} += synonym {plain}: failed_tags={r.get('failed_tags')}")
```

**Do not rename the accented tags to strip their accents.** It changes what readers see, and `tramitacion-reglada` is a misspelling in Spanish. The mangled slugs are not the cause and fixing them changes nothing — tag URLs resolve by name, not slug.

- [ ] **Step 5: Verify every old name and every unaccented form still filters**

```bash
set -a && source .env.local && set +a
# Feed this the absorbed names from the decisions file plus the unaccented forms.
for t in $(python3 -c "
import json, unicodedata
d = json.load(open('docs/superpowers/plans/data/2026-09-13-prod-collisions.json'))
out = [n for row in d.values() for n in row['absorb']]
print(' '.join(out))"); do
  curl -sSL -G --data-urlencode "q=#$t" -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" \
    -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" "$PROD_DISCOURSE_URL/search.json" -o /tmp/s.json
  python3 -c "
import json, sys
n = len(json.load(open('/tmp/s.json')).get('topics', []))
print(f'  #{sys.argv[1]:28} -> {n}' + ('   <-- page cap, likely full-text fallback' if n == 50 else ''))" "$t"
  sleep 1.3
done
```

**Zero means the synonym did not register. Fifty means the same thing** — the query fell through to full text and hit the page cap. Both are failures; only a number matching the merged population is a pass.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/plans/data/2026-09-13-prod-collisions.json \
        docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "feat(prod): merge the spelling collisions, unaccent the tag filter

Every rename keeps its old name as a synonym, and every accented base tag gains
an unaccented one: Tag.where_name does not unaccent, so #padron fell through to
full text and returned a larger, plausible, wrong set. No merge writes to a
topic, so none of this costs a thumbnail."
```

---

### Task 8: Derive PROD's families, create the eight module groups, extend the verifier

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-13-prod-module-axis.json`
- Modify: `bin/tags-verify` (the rename-integrity family)
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: the post-Task-7 vocabulary; Task 1's `MAPS` lookup, which already points `PROD` at this file.
- Produces: the mapping, shape `{"groups": {"<group name>": ["<tag>", ...]}, "delete": ["<name>", ...], "rename": {"<old>": "<new>"}}` — the same shape `bin/tags-verify` already reads for PRE.

- [ ] **Step 1: Compute co-occurrence over PROD's corpus, excluding structural tags**

```python
import json, sys
from collections import Counter, defaultdict
sys.path.insert(0, "bin")
import _discourse as d

cap = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-capture.json"))
# Structural tags co-occur with everything and swamp the signal. This list is PROD's
# after Task 5, not PRE's — extend it with whatever Task 5 actually amplified.
STRUCTURAL = {"administracion-avanzada", "analiza", "developers", "alumno-certificado",
              "ideas", "mejoras", "poster-evf", "webinars", "academia", "encuentro",
              "evento", "newsletter", "blog-gestiona", "cafe-con-certificados",
              "campana-2024", "campana-febrero-2025", "campana-v9", "trucazo",
              "v9", "v10", "pendiente-etiquetar"}

pairs = defaultdict(Counter)
for t in cap["topics"].values():
    subject = [x for x in t["tags"] if x not in STRUCTURAL]
    for a in subject:
        for b in subject:
            if a != b:
                pairs[a][b] += 1

for tag in sorted(pairs, key=lambda x: -sum(pairs[x].values()))[:40]:
    top = ", ".join(f"{b}({n})" for b, n in pairs[tag].most_common(5))
    print(f"  {tag:28} {top}")
```

Re-crawl rather than reusing the capture if Task 5 changed many topics — the capture predates it.

- [ ] **Step 2: Map PROD's subject tags onto Gestiona's eight menu sections**

The eight are fixed, because the product menu is the same: **Inicio, Registro electrónico, Atención a la ciudadanía, Tramitación administrativa, Gestión económica, Aplicaciones y servicios, Analítica de datos, Configuración Gestiona**. Membership is recomputed from PROD's vocabulary. PRE's mapping at `docs/superpowers/plans/data/2026-09-04-module-axis.json` is a **reference for which section a shared tag belongs to**, not a list to copy — 48 of its 57 tags exist on PROD and 9 do not. A tag may belong to more than one group; PRE's `tesauro` and `markdown` each sit in two.

- [ ] **Step 3: Gate — Ricardo validates the mapping**

Present it as group → tags with counts, plus the tags that fit no group. This is the conversation that produced PRE's eight groups and it took several rounds; budget for that.

- [ ] **Step 4: Check every group slug for shadowing BEFORE creating any group**

```python
import json, re, sys, unicodedata
sys.path.insert(0, "bin")
import _discourse as d

def slug(s):
    s = unicodedata.normalize("NFKD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")

mapping = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-module-axis.json"))
tags = [t["name"] for t in d.get("/tags.json", elevated=True)["tags"]]
cap = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-capture.json"))

shadows = {}
for name in tags:
    shadows.setdefault(slug(name), []).append(f"tag {name}")
for c in cap["categories"]:
    shadows.setdefault(c["slug"], []).append(f"category {c['id']}")

bad = False
for group in mapping["groups"]:
    if slug(group) in shadows:
        print(f"SHADOWED: {group} on #{slug(group)} by {shadows[slug(group)]}")
        bad = True
print("clear" if not bad else "RENAME the shadowed groups before creating them")
```

Resolution order is **category slug → exact tag name → tag group slug**, so a group loses to both. On PRE the group `Configuración` shipped shadowed by its own member tag `configuración` and returned a subset in silence through two review rounds; it had to be renamed to `Configuración Gestiona`.

- [ ] **Step 5: Create the groups, checking requested count against returned count**

```python
import json, sys
sys.path.insert(0, "bin")
import _discourse as d

mapping = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-module-axis.json"))
existing = {g["name"] for g in d.get("/tag_groups.json", elevated=True)["tag_groups"]}

for name, members in mapping["groups"].items():
    if name in existing:
        print(f"exists: {name}"); continue
    payload = [("name", name)] + [("tag_names[]", t) for t in members]
    created = d.request("POST", "/tag_groups.json", data=payload, elevated=True)
    got = created["tag_group"]["tags"]
    print(f"created {name}: requested {len(members)}, returned {len(got)}")
    if len(got) != len(members):
        raise SystemExit(f"STOP: {name} returned {len(got)} of {len(members)} tags")
```

**If a group returns fewer tags than requested, or any member has 0 uses, STOP** — `tag_names[]` invented an empty tag, and the membership check cannot see it because the name is right.

- [ ] **Step 6: Extend `bin/tags-verify`'s rename family to cover PROD's renames**

The verifier already asserts group membership, the `MIN_USES` floor with its `USE_EXEMPT` queue, the shadow check and rename integrity. PROD's mapping supplies its own `rename` block — at minimum `{"caag": "administracion-avanzada", "posters": "poster-evf"}` plus whatever Task 7 renamed — and its own `delete` block, which for T1 is empty (**T1 deletes no tags**).

Keep the two blind spots in the file's comment, because they are still true: the mapping is both the intent and the oracle, so a typo *in the mapping* passes; and the shadow check slugifies base tag names, which happens to cover their unaccented synonyms but not a synonym whose string differs otherwise.

- [ ] **Step 7: Watch it fail, then pass**

Run it once with a deliberately wrong member in the mapping, confirm it reports `missing=`/`extra=`, restore the mapping, and run it clean:

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/tags-verify
```

Expected: `[PROD] https://gestionaavanza.espublico.com` on stderr, then **PASS**. Verifying it fails first is what caught the `#configuracion` shadow on PRE after two green rounds.

- [ ] **Step 8: Commit**

```bash
git add docs/superpowers/plans/data/2026-09-13-prod-module-axis.json bin/tags-verify \
        docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "feat(prod): eight module groups, asserted by the shared verifier

Membership recomputed from PROD's own co-occurrence rather than copied from
PRE, and every group slug checked against the tag and category vocabulary
before creation — the check PRE did not have when Configuración shipped
shadowed by its own member tag."
```

---

### Task 9: Raise subject coverage

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-13-prod-title-proposals.json` (gitignored by Task 1)
- Create: `docs/superpowers/plans/data/2026-09-13-prod-batch-decisions.json`
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: Task 8's mapping.
- Produces: the decisions file, shape `{"<tag>": {"decision": "approve"|"reject", "excluded": [<topic id>, ...]}}`, and a measured coverage figure.

- [ ] **Step 1: Generate title-rule proposals**

```python
import json, re, sys, unicodedata
sys.path.insert(0, "bin")
import _discourse as d

mapping = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-module-axis.json"))
subject = sorted({t for members in mapping["groups"].values() for t in members})

def fold(s):
    s = unicodedata.normalize("NFKD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", s).strip()

def stem(w):
    return re.sub(r"(es|s)$", "", w)

# Synonyms count as their target: a topic tagged with an absorbed name already has the
# subject. Build the reverse map before proposing anything.
syn = {}
for t in d.get("/tags.json", elevated=True)["tags"]:
    info = d.get(f"/tag/{t['id']}/info.json", elevated=True).get("tag_info", {})
    for s in info.get("synonyms", []):
        syn[s["name"]] = t["name"]

proposals = {}
topics = {}
cap = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-capture.json"))
for cid in sorted({x["cat"] for x in cap["topics"].values() if x["cat"]}):
    topics.update(d.crawl_category(cid))

for tid, t in sorted(topics.items()):
    have = {syn.get(n, n) for n in d.tag_names(t)}
    if have & set(subject):
        continue                              # already classified
    words = {stem(w) for w in fold(t["title"]).split()}
    for tag in subject:
        tokens = {stem(w) for w in fold(tag).split()}
        if tokens and tokens <= words:
            proposals.setdefault(tag, []).append({"topic": tid, "title": t["title"]})

json.dump(proposals, open("docs/superpowers/plans/data/2026-09-13-prod-title-proposals.json", "w"),
          ensure_ascii=False, indent=1)
print(f"{sum(len(v) for v in proposals.values())} proposals across {len(proposals)} tags")
```

Every token of the tag must appear as a whole word in the **title** — accent-insensitive, crude `(es|s)$` stem, title only, **never the body**. The body pass is a separate decision and is not in this plan.

- [ ] **Step 2: Gate — Ricardo validates the batches**

Present them **by tag, not by topic**: reviewing "these N topics all receive `tesauro`" is far faster than N separate decisions, because a false positive stands out against its neighbours. Expect the common-word tags to need line-by-line review; on PRE he rejected 13 batches wholesale, mostly the small ones. Record approve/reject and per-batch exclusions in the decisions file.

- [ ] **Step 3: Measure the thumbnail bill of the approved set, and report it**

```python
import json
cap = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-capture.json"))
props = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-title-proposals.json"))
dec = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-batch-decisions.json"))

touched = set()
for tag, rows in props.items():
    d0 = dec.get(tag, {})
    if d0.get("decision") != "approve":
        continue
    touched |= {r["topic"] for r in rows if r["topic"] not in set(d0.get("excluded", []))}
cost = [t for t in touched if (cap["topics"].get(str(t)) or {}).get("image_url")]
print(f"{len(touched)} topics will be written; {len(cost)} of them lose a thumbnail: {sorted(cost)}")
```

If the count is non-trivial, put it to Ricardo before writing. On PRE category 18 had none, which is why the equivalent pass was free — that is a measurement, not a rule.

- [ ] **Step 4: Apply, grouped by topic**

```python
import json, sys
sys.path.insert(0, "bin")
import _discourse as d

props = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-title-proposals.json"))
dec = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-batch-decisions.json"))
CEILING = 7
PROTECTED = {2683, 2690, 2673}  # see CLAUDE.local.md — never written without Ricardo's yes

by_topic = {}
for tag, rows in props.items():
    d0 = dec.get(tag, {})
    if d0.get("decision") != "approve":
        continue
    excluded = set(d0.get("excluded", []))
    for r in rows:
        if r["topic"] not in excluded:
            by_topic.setdefault(r["topic"], []).append(tag)

applied = skipped = failed = 0
for tid, add in sorted(by_topic.items()):
    if tid in PROTECTED:
        print(f"  /t/{tid} PROTECTED — skipped, ask Ricardo"); skipped += 1; continue
    have = d.tag_names(d.get(f"/t/{tid}.json"))
    new = [t for t in add if t not in have]
    if not new:
        skipped += 1; continue
    if len(have) + len(new) > CEILING:
        print(f"  /t/{tid} SKIPPED: {len(have)} + {len(new)} exceeds {CEILING}")
        skipped += 1; continue
    d.request("PUT", f"/t/-/{tid}.json", data=[("tags[]", n) for n in have + new], elevated=True)
    back = d.tag_names(d.get(f"/t/{tid}.json"))
    if set(back) != set(have + new):
        print(f"  /t/{tid} MISMATCH after write: {back}"); failed += 1
    else:
        applied += 1
print(f"applied={applied} skipped={skipped} failed={failed}")
```

Grouping by topic means a topic receiving two tags costs **one** write, not two — and one thumbnail, not two.

- [ ] **Step 5: Measure coverage with a fresh crawl**

```python
import json, sys
sys.path.insert(0, "bin")
import _discourse as d

mapping = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-module-axis.json"))
subject = {t for members in mapping["groups"].values() for t in members}
cap = json.load(open("docs/superpowers/plans/data/2026-09-13-prod-capture.json"))

total = covered = 0
for cid in sorted({x["cat"] for x in cap["topics"].values() if x["cat"]}):
    for t in d.crawl_category(cid).values():
        total += 1
        if set(d.tag_names(t)) & subject:
            covered += 1
print(f"coverage: {covered} of {total} topics = {100*covered/total:.2f}%")
```

**Crawled, not derived from the proposal counts.** Record the topic count and the percentage **as two separate figures** — PRE's result beat its target topic count while missing the strict percentage by one topic, and reporting only one of them would have been misleading either way.

- [ ] **Step 6: Run the verifier and commit**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/tags-verify
git add docs/superpowers/plans/data/2026-09-13-prod-batch-decisions.json \
        docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "feat(prod): raise subject coverage with the title rule

Proposals reviewed batch by batch and applied grouped by topic, so a topic
taking two tags costs one write and one thumbnail. Coverage measured by a
fresh crawl, reported as a topic count and a percentage separately."
```

---

### Task 10: The instance settings that are not tags

**Files:**
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: nothing from earlier tasks — it is independent and could run first, but it sits here so that a member noticing the lighter posting rules meets an already-tidy vocabulary.
- Produces: `min_search_term_length` 3, `max_tag_search_results` 5, `auto_close_hours` cleared on 4, 5, 14 and 18, `minimum_required_tags` 0 on the same four.

- [ ] **Step 1: Set the two search settings**

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

- [ ] **Step 2: Prove a short term now resolves**

```bash
set -a && source .env.local && set +a
for q in tasas v10 ia; do
  code=$(curl -sSL -G --data-urlencode "q=$q" -o /tmp/s.json -w "%{http_code}" \
    -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" \
    "$PROD_DISCOURSE_URL/search.json")
  echo "  q=$q -> HTTP $code"; sleep 1.3
done
```

Expected: `tasas` and `v10` **200** where they answered **400** before. `ia` is two characters and stays unreachable at a floor of 3 — that is expected, not a failure.

- [ ] **Step 3: Clear `auto_close_hours` and the two-tag toll on 4, 5, 14, 18**

`PUT /categories/<id>.json` replaces the record, so this reads each category and sends it back with only these fields changed. `d.update_category` already does exactly that, and deliberately does not resend `description`.

```python
import sys
sys.path.insert(0, "bin")
import _discourse as d

for cid in (4, 5, 14, 18):
    before = d.category(cid)
    print(f"  cat {cid} before: auto_close_hours={before.get('auto_close_hours')!r} "
          f"minimum_required_tags={before.get('minimum_required_tags')!r}")
    after = d.update_category(cid, changes={"auto_close_hours": "", "minimum_required_tags": 0})
    print(f"  cat {cid} after : auto_close_hours={after.get('auto_close_hours')!r} "
          f"minimum_required_tags={after.get('minimum_required_tags')!r}")
```

**Already-closed topics stay closed.** That was decided explicitly: the setting alone, for future topics. Roughly 650 topics on PRE were closed across three categories; PROD's own figure is unmeasured and reopening them is out of scope.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "feat(prod): unblock short searches and stop closing new topics

min_search_term_length 6 -> 3, so a term under six characters stops answering
HTTP 400; max_tag_search_results 3 -> 5, because at 3 the autocomplete
manufactured duplicate spellings. auto_close_hours cleared and the two-tag
toll dropped on 4, 5, 14 and 18. Topics already closed stay closed."
```

---

### Task 11: The additive tail — the `Developers` group and three rooms born closed to staff

The head of T2, pulled forward because it moves no topic and nobody can see it. It fixes the room ids weeks before T3 needs them.

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-13-prod-rooms.json`
- Modify: `bin/categories-create-rooms` (a permission override for birth)
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: Task 1's instance resolution.
- Produces: `{"administracion_avanzada": <id>, "analitica": <id>, "developers": <id>}` — the ids T2 opens and T3 writes into `header_room_category_ids`.

- [ ] **Step 1: Confirm the four cohort groups exist on PROD**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD python3 -c "
import sys; sys.path.insert(0, 'bin')
import _discourse as d
for name in ('Developers01','Developers02','Developers03','Developers04',
             'AdminDevelopers','Certificación','Analiza'):
    g = d.group(name)
    print(f'  {name:18} {\"id \" + str(g[\"id\"]) if g else \"ABSENT\"}')"
```

`bin/groups-sync-developers` derives `Developers` from the four cohorts and refuses to run without them. An absent cohort is a STOP: PROD is a different instance and its group names have never been read.

- [ ] **Step 2: Derive the `Developers` group**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/groups-sync-developers
```

It creates the group and re-derives its membership from the four cohorts on every run — an invariant, not a capture. It prints counts only; usernames are member data and never reach the repo or a log line. **Expect PROD's union to differ from PRE's 49**: 16+14+17+15 is a sum, and developers repeat promotions.

- [ ] **Step 3: Teach `bin/categories-create-rooms` to birth a room closed**

Add an optional `--closed-to` argument. Without it the script behaves exactly as today.

```python
import argparse

# permission_types: full=1, create_post=2, readonly=3 (CategoryGroup.permission_types).
def main(closed_to=None):
    known = existing_names()
    rooms = json.loads(OUT.read_text()) if OUT.exists() else {}
    for key, name, groups, color, text_color, slug in ROOMS:
        if name in known:
            print(f"exists: {name} -> {known[name]}")
            rooms[key] = known[name]
            continue
        # A room born closed is walled to one staff group instead of its programme
        # group, so it is absent from the category list and the composer's picker for
        # everyone else. T2 opens it by resending the real permission rows.
        wall = (closed_to,) if closed_to else groups
        for group in wall:
            if d.group(group) is None:
                raise SystemExit(
                    f"group {group} does not exist — create it first. A room created with"
                    f" an unresolvable permission row may well be born with no wall, and"
                    f" an unwalled room is visible to everyone until somebody notices."
                )
        payload = [
            ("name", name),
            ("slug", slug),
            ("color", color),
            ("text_color", text_color),
            ("minimum_required_tags", 0),
        ] + [(f"permissions[{group}]", 1) for group in wall]
        created = d.request("POST", "/categories.json", data=payload, elevated=True)
        rooms[key] = created["category"]["id"]
        print(f"created: {name} -> {rooms[key]} (#{created['category']['slug']}, "
              f"{' + '.join(wall)} at permission 1)")
    OUT.write_text(json.dumps(rooms, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--closed-to", help="wall every new room to this group instead of its "
                                       "programme group, so it is born invisible")
    a = p.parse_args()
    main(a.closed_to)
```

Also make `OUT` instance-aware, so PROD's ids never overwrite PRE's:

```python
ROOM_FILES = {
    "PRE": "2026-09-11-rooms.json",
    "PROD": "2026-09-13-prod-rooms.json",
}
OUT = ROOT / "docs/superpowers/plans/data" / ROOM_FILES[d._instance()]
```

- [ ] **Step 4: Check the three room slugs against PROD's vocabulary before creating anything**

```bash
set -a && source .env.local && set +a
for s in foro-administracion-avanzada foro-analitica-de-datos foro-gestiona-for-developers; do
  curl -sSL -G --data-urlencode "q=#$s" -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" \
    -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" "$PROD_DISCOURSE_URL/search.json" -o /tmp/s.json
  python3 -c "
import json, sys
print(f'  #{sys.argv[1]:32} -> {len(json.load(open(\"/tmp/s.json\")).get(\"topics\", []))} topics today')" "$s"
  sleep 1.3
done
```

A non-zero result means that slug already resolves to something — a tag or a tag group — and creating the category would hijack it silently. On PRE the bare names did exactly that: `#administracion-avanzada` stopped reaching its 700-topic tag on creation day. **The `foro-` prefix is why these three are safe; verify rather than assume.**

- [ ] **Step 5: Create the three rooms, born closed**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/categories-create-rooms --closed-to administradores
```

Use the group name PROD actually has — automatic groups carry **translated** names, so this instance's staff group may be `personal`(3) and its admin group `administradores`(1). `/g/staff.json` and `/g/admins.json` answer 404 on a Spanish instance; `/groups/search.json` is the listing that returns them all. Confirm the name in Step 1's output before running this.

- [ ] **Step 6: Verify the rooms are invisible and empty**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD python3 -c "
import json, sys; sys.path.insert(0, 'bin')
import _discourse as d
rooms = json.load(open('docs/superpowers/plans/data/2026-09-13-prod-rooms.json'))
for key, cid in rooms.items():
    c = d.category(cid)
    perms = {g['group_name']: g['permission_type'] for g in c.get('group_permissions') or []}
    print(f'  {key:24} id={cid:3} slug={c[\"slug\"]:32} topics={c.get(\"topic_count\")} perms={perms}')"
```

Expected: three ids, the `foro-` slugs, `topic_count` 0, and **exactly one permission row each, naming the staff group** — no programme group yet. A room carrying `Certificación` at this point is visible to all 374 members and must be closed immediately.

- [ ] **Step 7: Commit**

```bash
npx pnpm@10.28.0 lint > /tmp/lint.txt 2>&1; code=$?
grep -E "✖|error" /tmp/lint.txt; [ "$code" -eq 0 ] || exit 1
git add bin/categories-create-rooms docs/superpowers/plans/data/2026-09-13-prod-rooms.json \
        docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "feat(prod): derive the Developers group and create three rooms born closed

The additive head of T2, pulled into T1 because it moves no topic and nobody
can see it: each room is walled to staff at birth, so it is absent from the
category list and the composer's picker until T2 opens it. Fixes the room ids
weeks before header_room_category_ids needs them.

bin/categories-create-rooms gains --closed-to and writes its ids to a
per-instance file, so PROD's never overwrite PRE's."
```

---

### Task 12: Close T1

**Files:**
- Modify: `docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md` (an *As executed* section)
- Modify: `CLAUDE.local.md` (PROD's state)
- Modify: `traceability.md`

**Interfaces:**
- Consumes: every task above.
- Produces: a recorded, verified end state and the inputs T2's plan will be written from.

- [ ] **Step 1: Run every assertion**

```bash
set -a && source .env.local && set +a
./bin/selftest-instance
DISCOURSE_INSTANCE=PRE  ./bin/tags-verify
DISCOURSE_INSTANCE=PROD ./bin/tags-verify
DISCOURSE_INSTANCE=PRE  ./bin/categories-verify
```

All four must pass. **PRE's two are not ceremony**: Task 1 refactored the client and the verifier that PRE depends on, and nothing else would notice if that refactor had broken them.

- [ ] **Step 2: Re-measure and record the success criteria**

Vocabulary size; the minimum tag uses across the vocabulary; subject coverage as a count *and* a percentage; `#caag` and `#posters` still filtering; each of the eight `#slug` filters returning its union; a three-letter query returning 200. Record each with the number measured, not the number expected.

- [ ] **Step 3: Write the *As executed* section, departures included**

PRE's reorganisation departed from its own plan in six recorded ways and every one was written down. Record each departure here rather than smoothing it — especially any row of the August bulk-tagging table that turned out wrong for PROD, and the real thumbnail bill against the predicted one.

- [ ] **Step 4: Update `CLAUDE.local.md` with PROD's state**

PROD's Discourse version, its vocabulary size, its coverage, the three room ids, and the fact that the `Developers` group now exists there with its measured membership. **State plainly that the funcionalidad axis was not built on PROD either** — it was Approach C on PRE, chosen deliberately, and a reader who finds `#tramitacion-administrativa` returning a large undifferentiated set should meet that sentence rather than re-derive it as a defect.

- [ ] **Step 5: Open the PR and watch CI go green**

```bash
git push -u origin feat/prod-t1-content
gh pr create --title "feat(prod): T1 — the content tranche of the silent migration" \
  --body "Implements T1 of docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md.

Instance work on PROD plus one repository change: bin/ scripts now resolve their instance from DISCOURSE_INSTANCE, with no default.

bin/tags-verify passes against both instances; bin/categories-verify still passes against PRE.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

**Watch the four required checks report green before merging.** `gh pr merge --auto` does not gate CI from this account — it merges on the spot, because branch protection does not apply to an administrator.

- [ ] **Step 6: Report to Ricardo that T1 is closed, and what T2 needs**

T2's plan is written when T2 starts, from measurements taken that week. What it will need from here: the three room ids, PROD's post-T1 vocabulary, and the capture file — which lives on disk and not in the repository.

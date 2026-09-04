# Subject Layer for the Tag Vocabulary — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Gestiona Avanza tag vocabulary a subject layer — eight tag groups mirroring Gestiona's main menu — and raise subject-tag coverage from 47% to at least 66% of topics.

**Architecture:** This plan touches **no theme code**. It is instance configuration and topic tags on PRE, applied through the Discourse admin API with the Global-scope key. The unit of verification is a re-runnable assertion script (`bin/tags-verify`) that reads live state and exits non-zero until the target state holds — that is the red/green cycle here, in place of a test runner. One-off application scripts live in the scratchpad and are not committed; what gets committed is the verifier, the batch decisions, and an *As executed* record appended to the spec.

**Tech Stack:** Discourse admin API (`/tag_groups.json`, `/tag/<id>/synonyms.json`, `/tag/<id>/settings.json`, `PUT /t/-/<id>.json`), Python 3.9 standard library only (no `requests` — the corporate proxy makes dependency installs unreliable), `curl` for probes.

**Spec:** `docs/superpowers/specs/2026-09-04-capa-materia-etiquetas-design.md`

## Global Constraints

- **Credentials come from `.env.local` via `source`.** `PRE_DISCOURSE_GLOBAL_API_KEY` is the only key that reaches `/tag_groups.json`, `/tags.json` and topic writes. `PRE_DISCOURSE_API_KEY` is read-only and returns 403 on all of them. **Never print a key value.**
- **Rate limit ~1 req/s.** Sleep 1.2–1.3 s between calls and back off 8 s on HTTP 429.
- **Renames must precede group creation.** `TagGroup#tag_names=` creates any tag it names that does not exist, so a group naming `integracion-pid` before the rename creates an empty duplicate instead of adopting `pid`(9).
- **Send no `permissions` parameter when creating a tag group.** Supplying one returns HTTP 500; omitting it defaults to `{"0": 1}` (everyone).
- **Renaming a tag does not preserve its old name.** After every rename, recreate the old name as a synonym with `tags[][name]`, or `#old-name` silently degrades to full-text search.
- **Synonyms do not chain.** Merging a tag that already has a synonym fails with `no está permitido mientras existan sinónimos`. Move the child to the final target first.
- **`PUT /t/-/<id>.json` replaces the whole tag set.** Always read the topic's current tags and resend them with the addition. `max_tags_per_topic` is **7**; skip and report any topic already at 7.
- **A topic write clears the topic's `image_url`.** No visible consequence since #73 removed the showcase grid, but state it in the record.
- **A tag's `topic_count` counts unlisted topics; `#tag` search does not.** Reconcile against `/tag/<name>/l/latest.json` (paginates at 30), never against a search result.
- **`main` is protected.** Work on a branch, open a PR, let `ci / linting`, `ci / backend_tests`, `ci / frontend_tests` and `ci / system_tests` go green before merging.

## File Structure

| File | Responsibility |
|---|---|
| `bin/tags-verify` | Create. Re-runnable assertion of the target state: the 8 groups and their exact membership, the 3 deletions, the 2 renames plus their synonyms. Exits 0 only when everything holds. This is the plan's test. |
| `docs/superpowers/plans/data/2026-09-04-module-axis.json` | Create. The authoritative group→tags mapping, read by `bin/tags-verify` and by the application scripts, so the mapping exists in exactly one place. |
| `docs/superpowers/plans/data/2026-09-04-title-proposals.json` | Create in Task 5. Generated proposals, tag → [(topic id, title)], the input to validation. |
| `docs/superpowers/plans/data/2026-09-04-batch-decisions.json` | Create in Task 6. Ricardo's approve/exclude decision per batch — the audit trail for what was written and why. |
| `docs/superpowers/specs/2026-09-04-capa-materia-etiquetas-design.md` | Modify. Append an *As executed* section per task, following the precedent of the category-reorganisation spec. |

---

### Task 1: The verification harness

Build the assertion first so every later task has a red/green signal. It must fail now.

**Files:**
- Create: `bin/tags-verify`
- Create: `docs/superpowers/plans/data/2026-09-04-module-axis.json`

**Interfaces:**
- Consumes: nothing.
- Produces: `bin/tags-verify` (executable, no arguments, exit 0 = target state holds, exit 1 = does not, prints a per-assertion table). `2026-09-04-module-axis.json` with shape `{"groups": {"<group name>": ["<tag name>", ...]}, "delete": [...], "rename": {"<old>": "<new>"}}`.

- [ ] **Step 1: Write the mapping file**

Create `docs/superpowers/plans/data/2026-09-04-module-axis.json` with exactly this content:

```json
{
  "groups": {
    "Tramitación administrativa": ["tramitación-reglada", "tesauro", "expedientes", "circuitos-resolucion", "markdown", "tramitación", "gestiona-code", "procedimientos", "circuitos-tramitacion", "órganos-colegiados", "integracion-pid", "plantillas", "expedientes-apertura", "subprocesos", "gestiona-envia", "relacionados"],
    "Configuración": ["tesauro", "configuración", "markdown", "usuario-perfil", "integraciones", "serie-documental"],
    "Atención a la ciudadanía": ["sede-electrónica", "terceros", "paginas-informativas", "representante", "cita-previa", "carpeta-ciudadana", "transparencia", "canal-denuncias", "tablón-anuncios", "interesados", "temas-y-categorias"],
    "Registro electrónico": ["registro", "tramites-externos", "ventanilla-única"],
    "Inicio": ["tareas", "firma", "tareas-regladas", "asignaciones", "app-movil", "fechas", "tareas-personal", "asignado-a", "plazos"],
    "Gestión económica": ["tasas", "contratación", "subvenciones", "ayudas", "ayudas-personal", "dietas", "menor"],
    "Analítica de datos": ["analítica", "busquedas-avanzadas", "auditoria"],
    "Aplicaciones y servicios": ["padrón", "urbanismo", "facturas", "sello-de-organo"]
  },
  "delete": ["interoperabilidad", "desarrollo-software", "debate-técnico"],
  "rename": {"pid": "integracion-pid", "seriesdocumentales": "serie-documental"}
}
```

- [ ] **Step 2: Write the verifier**

Create `bin/tags-verify`:

```python
#!/usr/bin/env python3
"""Assert the subject-layer target state on PRE. Exit 0 only if it all holds."""
import json, os, pathlib, sys, time, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAP = json.loads((ROOT / "docs/superpowers/plans/data/2026-09-04-module-axis.json").read_text())
URL = os.environ["PRE_DISCOURSE_URL"]
KEY = os.environ["PRE_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PRE_DISCOURSE_API_USERNAME"]


def get(path):
    req = urllib.request.Request(URL + path, headers={"Api-Key": KEY, "Api-Username": USER})
    for _ in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as f:
                return json.load(f)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(8)
                continue
            return {"__err": e.code}
        except Exception:
            time.sleep(3)
    return {"__err": "fail"}


def main():
    failures = []
    tags = {t["name"]: t for t in get("/tags.json")["tags"]}
    time.sleep(1.2)
    groups = {g["name"]: g for g in get("/tag_groups.json")["tag_groups"]}

    for name, want in MAP["groups"].items():
        got = groups.get(name)
        if not got:
            failures.append(f"group missing: {name}")
            continue
        have = sorted(t["name"] for t in got["tags"])
        if have != sorted(want):
            failures.append(
                f"group {name}: missing={sorted(set(want) - set(have))} extra={sorted(set(have) - set(want))}"
            )

    for name in MAP["delete"]:
        if name in tags:
            failures.append(f"still present, should be deleted: {name}")

    for old, new in MAP["rename"].items():
        if old in tags:
            failures.append(f"old name still a base tag, rename not done: {old}")
        if new not in tags:
            failures.append(f"renamed tag absent: {new}")
            continue
        time.sleep(1.2)
        info = get(f"/tag/{tags[new]['id']}/info.json").get("tag_info", {})
        syns = [s["name"] for s in info.get("synonyms", [])]
        if old not in syns:
            failures.append(f"{new} does not carry '{old}' as a synonym — #{old} no longer filters")

    if failures:
        print(f"FAIL — {len(failures)} assertion(s)")
        for f in failures:
            print(f"  ✗ {f}")
        return 1
    print(f"PASS — {len(MAP['groups'])} groups, {len(MAP['delete'])} deletions, {len(MAP['rename'])} renames")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: Make it executable and run it to verify it fails**

```bash
chmod +x bin/tags-verify
set -a && source .env.local && set +a && ./bin/tags-verify
```

Expected: exit 1 with **15 assertions** — 8 `group missing:`, 3 `still present, should be deleted:`, and **4** from the rename block. Each pending rename produces *two* failures, because the old name is still a base tag *and* the new name does not exist yet:

```
✗ old name still a base tag, rename not done: pid
✗ renamed tag absent: integracion-pid
✗ old name still a base tag, rename not done: seriesdocumentales
✗ renamed tag absent: serie-documental
```

If the count or the assertion kinds differ from this, stop: the preconditions have drifted since the plan was written.

- [ ] **Step 4: Commit**

```bash
git checkout -b feat/tag-subject-layer
git add bin/tags-verify docs/superpowers/plans/data/2026-09-04-module-axis.json
git commit -m "feat(tags): add the subject-layer verifier and its mapping

The mapping is the single source of truth for the eight module groups;
bin/tags-verify reads it and asserts live state on PRE. Red until the
groups exist."
```

---

### Task 2: Deletions and renames

Must run before Task 3 — see Global Constraints.

**Files:**
- Modify: `docs/superpowers/specs/2026-09-04-capa-materia-etiquetas-design.md` (append *As executed*)

**Interfaces:**
- Consumes: `2026-09-04-module-axis.json` (`delete`, `rename`).
- Produces: on PRE, `pid`→`integracion-pid` and `seriesdocumentales`→`serie-documental`, each with the old name recreated as a synonym; `interoperabilidad`, `desarrollo-software`, `debate-técnico` gone.

- [ ] **Step 1: Capture the before-state**

```bash
set -a && source .env.local && set +a
for t in interoperabilidad desarrollo-software debate-técnico pid seriesdocumentales; do
  curl -sSL -G --data-urlencode "q=#$t" -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" \
    -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" "$PRE_DISCOURSE_URL/search.json" \
    -o /tmp/s.json -w "$t -> %{http_code} "
  python3 -c "import json;print(len(json.load(open('/tmp/s.json')).get('topics',[])),'topics')"
  sleep 1.3
done
```

Record the counts. Expected: `pid` 9, `seriesdocumentales` 3, and the three deletion candidates 4/3/4.

- [ ] **Step 2: Run the verifier to confirm these assertions are red**

```bash
set -a && source .env.local && set +a && ./bin/tags-verify
```

Expected: FAIL, including `still present, should be deleted: interoperabilidad` and `old name still a base tag, rename not done: pid`.

- [ ] **Step 3: Apply**

Write to the scratchpad (not the repo) and run:

```python
import json, os, time, urllib.parse, urllib.request
URL = os.environ["PRE_DISCOURSE_URL"]; KEY = os.environ["PRE_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PRE_DISCOURSE_API_USERNAME"]

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

for name in ["interoperabilidad", "desarrollo-software", "debate-técnico"]:
    st, _ = req("DELETE", f"/tag/{ids[name]}.json")
    print(f"[{st}] deleted {name}")
    time.sleep(1.3)

for old, new in [("pid", "integracion-pid"), ("seriesdocumentales", "serie-documental")]:
    st, _ = req("PUT", f"/tag/{ids[old]}/settings.json",
                {"tag_settings[name]": new, "tag_settings[slug]": new})
    print(f"[{st}] renamed {old} -> {new}")
    time.sleep(1.3)
    st, r = req("POST", f"/tag/{ids[old]}/synonyms.json", [("tags[][name]", old)])
    ok = st == 200 and not r.get("failed_tags")
    print(f"[{'OK ' if ok else 'ERR'}] recreated '{old}' as a synonym of {new}")
    time.sleep(1.3)
```

The tag keeps its id across a rename, so `ids[old]` addresses the renamed tag correctly in the synonym call.

- [ ] **Step 4: Run the verifier to confirm these assertions are green**

```bash
set -a && source .env.local && set +a && ./bin/tags-verify
```

Expected: still FAIL overall (the 8 groups do not exist yet), but **no deletion or rename failures remain** — 8 assertions, all of the form `group missing:`.

- [ ] **Step 5: Confirm the old names still filter**

```bash
set -a && source .env.local && set +a
for t in pid seriesdocumentales; do
  curl -sSL -G --data-urlencode "q=#$t" -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" \
    -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" "$PRE_DISCOURSE_URL/search.json" -o /tmp/s.json
  python3 -c "import json,sys;print(sys.argv[1],'->',len(json.load(open('/tmp/s.json')).get('topics',[])))" "$t"
  sleep 1.3
done
```

Expected: `pid` 9, `seriesdocumentales` 3 — unchanged from Step 1. A drop to 0 or a jump to 50 means the synonym did not register and the query fell through to full text.

- [ ] **Step 6: Record and commit**

Append to the spec, under a new `## As executed` heading, a table of the five operations with their before/after counts and the Step 5 result.

```bash
git add docs/superpowers/specs/2026-09-04-capa-materia-etiquetas-design.md
git commit -m "chore(tags): delete three tags and rename two on PRE

interoperabilidad(4), desarrollo-software(3) and debate-técnico(4) deleted.
pid -> integracion-pid and seriesdocumentales -> serie-documental, each with
the old name recreated as a synonym so #pid and #seriesdocumentales keep
filtering."
```

---

### Task 3: The eight tag groups

**Files:**
- Modify: `docs/superpowers/specs/2026-09-04-capa-materia-etiquetas-design.md` (append to *As executed*)

**Interfaces:**
- Consumes: `2026-09-04-module-axis.json` (`groups`); the renames from Task 2.
- Produces: eight tag groups on PRE with the exact membership in the mapping. `bin/tags-verify` exits 0 after this task.

- [ ] **Step 1: Run the verifier to confirm 8 group assertions are red**

```bash
set -a && source .env.local && set +a && ./bin/tags-verify
```

Expected: FAIL with exactly 8 lines, all `group missing: …`.

- [ ] **Step 2: Create the groups**

```python
import json, os, pathlib, time, urllib.parse, urllib.request
URL = os.environ["PRE_DISCOURSE_URL"]; KEY = os.environ["PRE_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PRE_DISCOURSE_API_USERNAME"]
MAP = json.loads(pathlib.Path("docs/superpowers/plans/data/2026-09-04-module-axis.json").read_text())

def post(path, data):
    body = urllib.parse.urlencode(data, doseq=True).encode()
    r = urllib.request.Request(URL + path, data=body, method="POST", headers={
        "Api-Key": KEY, "Api-Username": USER,
        "Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(r, timeout=30) as f:
            return f.status, json.load(f)
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.load(e)
        except Exception:
            return e.code, {}

for name, tags in MAP["groups"].items():
    # No permissions parameter: supplying one returns 500.
    data = [("name", name)] + [("tag_names[]", t) for t in tags]
    st, r = post("/tag_groups.json", data)
    got = [t["name"] for t in (r.get("tag_group") or {}).get("tags", [])]
    ok = st == 200 and sorted(got) == sorted(tags)
    print(f"[{'OK ' if ok else 'ERR'}] {st} {name}: {len(got)}/{len(tags)} tags")
    if not ok:
        print("   missing:", sorted(set(tags) - set(got)))
    time.sleep(1.5)
```

**Every tag in the mapping already exists** after Task 2, so no group creation should invent a tag. If the `missing` line is ever non-empty, or a group reports more tags than requested, stop and investigate before continuing — an invented empty tag is the failure mode this ordering exists to prevent.

- [ ] **Step 3: Run the verifier to confirm it passes**

```bash
set -a && source .env.local && set +a && ./bin/tags-verify
```

Expected: `PASS — 8 groups, 3 deletions, 2 renames`, exit 0.

- [ ] **Step 4: Confirm each group works as a search filter**

```bash
set -a && source .env.local && set +a
for g in tramitacion-administrativa configuracion atencion-a-la-ciudadania registro-electronico inicio gestion-economica analitica-de-datos aplicaciones-y-servicios; do
  curl -sSL -G --data-urlencode "q=#$g" -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" \
    -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" "$PRE_DISCOURSE_URL/search.json" -o /tmp/s.json
  python3 -c "import json,sys;print(f'{sys.argv[1]:28} -> {len(json.load(open(\"/tmp/s.json\")).get(\"topics\",[]))}')" "$g"
  sleep 1.3
done
```

Expected: every group returns a non-zero count. **A zero means the group's slug is not what this loop guessed** — read the real slug from `/tag_groups.json` and correct the list; do not conclude the group is broken. Counts hit the 50-per-page cap for the larger groups; that is the cap, not the true size.

- [ ] **Step 5: Record and commit**

Append the eight groups with their tag counts and the Step 4 filter results to *As executed*.

```bash
git add docs/superpowers/specs/2026-09-04-capa-materia-etiquetas-design.md
git commit -m "feat(tags): create the eight module tag groups on PRE

Eight groups mirroring Gestiona's main menu plus Configuración, holding the
57 subject tags. bin/tags-verify passes. tesauro and markdown each sit in two
groups, so the axis is deliberately not a partition."
```

---

### Task 4: Restore the two `cies` topics

`cies`(2) was the *Impresión y ensobrado* submenu and was deleted during the depuration. Its two topics are recoverable from the committed capture.

**Files:**
- Read: `docs/superpowers/specs/2026-09-04-tags-deleted-recovery.json`
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: the recovery capture.
- Produces: `/t/1498` and `/t/1458` carry `registro` — the Registro electrónico tag closest to the submenu that no longer has one.

- [ ] **Step 1: Read the capture and confirm the two topic ids**

```bash
python3 -c "
import json
d = json.load(open('docs/superpowers/specs/2026-09-04-tags-deleted-recovery.json'))
for r in d['cies']: print(r['topic'], r['title'])"
```

Expected exactly:

```
1498 SEMINARIO: Los servicios de impresión, ensobrado y envío de SMS
1458 Nuevo curso en la Academia: Servicios de impresión, ensobrado y envío de SMS
```

- [ ] **Step 2: Read their current tags**

```bash
set -a && source .env.local && set +a
for i in 1498 1458; do
  curl -sSL -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" \
    "$PRE_DISCOURSE_URL/t/$i.json" -o /tmp/t.json
  python3 -c "
import json,sys
d=json.load(open('/tmp/t.json'))
print(sys.argv[1], [t['name'] for t in (d.get('tags') or [])], '|', d.get('title','')[:50])" "$i"
  sleep 1.3
done
```

Both are seminar/course announcements, so they are expected to carry `academia` or `webinars` already. Note the exact lists — Step 3 resends them.

- [ ] **Step 3: Add `registro`, preserving existing tags**

```python
import json, os, time, urllib.parse, urllib.request
URL = os.environ["PRE_DISCOURSE_URL"]; KEY = os.environ["PRE_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PRE_DISCOURSE_API_USERNAME"]

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

for topic_id in (1498, 1458):
    st, r = req("GET", f"/t/{topic_id}.json")
    time.sleep(1.2)
    names = [t["name"] for t in (r.get("tags") or [])]
    if "registro" in names:
        print(f"/t/{topic_id} already tagged")
        continue
    if len(names) + 1 > 7:
        print(f"/t/{topic_id} SKIPPED: already at {len(names)} tags (max 7)")
        continue
    st2, _ = req("PUT", f"/t/-/{topic_id}.json", [("tags[]", n) for n in names + ["registro"]])
    print(f"[{'OK ' if st2 == 200 else 'ERR'}] {st2} /t/{topic_id}  {names} + registro")
    time.sleep(1.3)
```

- [ ] **Step 4: Verify both carry it and kept their originals**

```bash
set -a && source .env.local && set +a
for i in 1498 1458; do
  curl -sSL -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" \
    "$PRE_DISCOURSE_URL/t/$i.json" -o /tmp/t.json
  python3 -c "
import json,sys
n=sorted(t['name'] for t in (json.load(open('/tmp/t.json')).get('tags') or []))
print(sys.argv[1], n, 'OK' if 'registro' in n else 'MISSING')" "$i"
  sleep 1.3
done
```

Expected: both lists contain `registro` **and** every tag recorded in Step 2.

- [ ] **Step 5: Record and commit**

```bash
git add docs/superpowers/specs/2026-09-04-capa-materia-etiquetas-design.md
git commit -m "chore(tags): restore the two cies topics into Registro electrónico

/t/1498 and /t/1458 were the Impresión y ensobrado submenu until cies(2) was
deleted. Recovered from the committed capture and tagged registro. Two topic
writes; both lost their list thumbnail, which nothing renders since #73."
```

---

### Task 5: Generate the title-rule proposals

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-04-title-proposals.json`

**Interfaces:**
- Consumes: `2026-09-04-module-axis.json` (the union of all group members is the matchable vocabulary).
- Produces: `2026-09-04-title-proposals.json` with shape `{"<tag name>": [{"topic": <int>, "title": "<str>"}, ...]}`, ordered by descending batch size. No writes to PRE.

- [ ] **Step 1: Crawl every topic's current tags**

The proposal set depends on which topics lack a subject tag *now*, so it must be recomputed rather than reused from the spec's measurement.

```python
import json, os, time, urllib.request
URL = os.environ["PRE_DISCOURSE_URL"]; KEY = os.environ["PRE_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PRE_DISCOURSE_API_USERNAME"]
CATEGORIES = [3, 4, 5, 14, 18, 59, 73, 75, 78, 79, 80, 81, 82, 83, 84, 85, 88]

def get(path):
    r = urllib.request.Request(URL + path, headers={"Api-Key": KEY, "Api-Username": USER})
    for _ in range(4):
        try:
            with urllib.request.urlopen(r, timeout=30) as f:
                return json.load(f)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(8)
                continue
            return {"__err": e.code}
        except Exception:
            time.sleep(3)
    return {"__err": "fail"}

topics = {}
for c in CATEGORIES:
    for page in range(40):
        d = get(f"/c/{c}/l/latest.json?page={page}")
        if "__err" in d:
            print("ERR", c, page, d)
            break
        rows = d.get("topic_list", {}).get("topics", [])
        if not rows:
            break
        for t in rows:
            topics[t["id"]] = {
                "cat": t.get("category_id"),
                "tags": [x["name"] for x in (t.get("tags") or [])],
                "title": t["title"],
            }
        time.sleep(1.2)
        if len(rows) < 30:
            break
json.dump(topics, open("topics-now.json", "w"), ensure_ascii=False)
print("topics:", len(topics))
```

Expected: about 1 261 topics. A category listing carries its children's topics, so ids repeat harmlessly into the same dict.

- [ ] **Step 2: Generate the proposals**

```python
import json, pathlib, re, unicodedata
from collections import defaultdict

MAP = json.loads(pathlib.Path("docs/superpowers/plans/data/2026-09-04-module-axis.json").read_text())
SUBJECT = sorted({t for tags in MAP["groups"].values() for t in tags})
topics = json.load(open("topics-now.json"))

def strip_accents(s):
    s = unicodedata.normalize("NFKD", (s or "").lower())
    return "".join(c for c in s if not unicodedata.combining(c))

def stem(w):
    return re.sub(r"(es|s)$", "", w) if len(w) > 4 else w

TOKENS = {t: [stem(x) for x in re.split(r"[-_]", strip_accents(t)) if x] for t in SUBJECT}
SUBJECT_SET = set(SUBJECT)

proposals = defaultdict(list)
for tid, v in topics.items():
    if any(t in SUBJECT_SET for t in v["tags"]):
        continue  # already has a subject tag
    words = {stem(w) for w in re.findall(r"[a-z0-9]+", strip_accents(v["title"]))}
    for tag, toks in TOKENS.items():
        if toks and all(x in words for x in toks):
            proposals[tag].append({"topic": int(tid), "title": v["title"]})

ordered = dict(sorted(proposals.items(), key=lambda kv: -len(kv[1])))
out = pathlib.Path("docs/superpowers/plans/data/2026-09-04-title-proposals.json")
out.write_text(json.dumps(ordered, ensure_ascii=False, indent=1))
covered = sum(1 for v in topics.values() if any(t in SUBJECT_SET for t in v["tags"]))
touched = len({p["topic"] for v in ordered.values() for p in v})
print(f"batches: {len(ordered)}  topics proposed: {touched}")
print(f"coverage {covered}/{len(topics)} -> {covered + touched}/{len(topics)}")
```

Expected, within a few either way of the spec's measurement: **around 30-40 batches, ~233 topics, coverage 47% → 66%**. A wildly different number means the vocabulary drifted between planning and execution — stop and reconcile before writing anything.

- [ ] **Step 3: Print the batches for review**

```python
import json
d = json.load(open("docs/superpowers/plans/data/2026-09-04-title-proposals.json"))
for tag, rows in d.items():
    print(f"\n=== {tag} — {len(rows)} topics ===")
    for r in rows:
        print(f"   /t/{r['topic']:<6} {r['title'][:78]}")
```

- [ ] **Step 4: Commit the proposals unapplied**

```bash
git add docs/superpowers/plans/data/2026-09-04-title-proposals.json
git commit -m "chore(tags): generate title-rule tag proposals

Whole-word token match of each subject tag against topic titles, over the
topics that carry no subject tag. Nothing applied — this is the input to
batch validation."
```

---

### Task 6: Validate and apply the batches

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-04-batch-decisions.json`
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: `2026-09-04-title-proposals.json`.
- Produces: `2026-09-04-batch-decisions.json` with shape `{"<tag>": {"decision": "approve"|"reject", "excluded": [<topic id>, ...]}}`, and the corresponding tags applied on PRE.

- [ ] **Step 1: Present each batch to Ricardo and record the decision**

Work through the batches largest-first, one message per batch, using the Step 3 output of Task 5. For each, Ricardo returns approve, approve-with-exclusions, or reject. Write the answers into `2026-09-04-batch-decisions.json` as they come.

**Watch the six high-volume, common-word batches especially** — `tesauro`(~52), `configuración`(~52), `tramitación`(~44), `expedientes`(~39), `registro`(~30), `fechas`(~23). These need line-by-line review; *"Reasignación de registros de forma rápida"* proposes `registro`, where "registros" means database rows. The specific tags (`circuitos-resolucion`, `paginas-informativas`) can be approved at a glance.

**Do not write anything until a batch is approved.**

- [ ] **Step 2: Apply the approved batches**

```python
import json, os, time, urllib.parse, urllib.request
from collections import defaultdict
URL = os.environ["PRE_DISCOURSE_URL"]; KEY = os.environ["PRE_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PRE_DISCOURSE_API_USERNAME"]
proposals = json.load(open("docs/superpowers/plans/data/2026-09-04-title-proposals.json"))
decisions = json.load(open("docs/superpowers/plans/data/2026-09-04-batch-decisions.json"))

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

# Group by topic so each topic is written once even when several tags apply.
wanted = defaultdict(set)
for tag, rows in proposals.items():
    d = decisions.get(tag, {})
    if d.get("decision") != "approve":
        continue
    excluded = set(d.get("excluded", []))
    for r in rows:
        if r["topic"] not in excluded:
            wanted[r["topic"]].add(tag)

print(f"topics to write: {len(wanted)}")
applied = skipped = failed = 0
for topic_id, tags in sorted(wanted.items()):
    st, r = req("GET", f"/t/{topic_id}.json")
    time.sleep(1.2)
    names = [t["name"] for t in (r.get("tags") or [])]
    add = [t for t in sorted(tags) if t not in names]
    if not add:
        skipped += 1
        continue
    if len(names) + len(add) > 7:
        print(f"  /t/{topic_id} SKIPPED: {len(names)} tags + {len(add)} exceeds max 7")
        skipped += 1
        continue
    st2, _ = req("PUT", f"/t/-/{topic_id}.json", [("tags[]", n) for n in names + add])
    if st2 == 200:
        applied += 1
    else:
        failed += 1
        print(f"  [ERR] {st2} /t/{topic_id}")
    time.sleep(1.3)
print(f"applied={applied} skipped={skipped} failed={failed}")
```

Grouping by topic matters: a topic proposed for both `expedientes` and `busquedas-avanzadas` gets **one** write, not two, which halves the thumbnail cost and the runtime.

- [ ] **Step 3: Verify coverage rose**

```python
import json, os, pathlib, time, urllib.request
URL = os.environ["PRE_DISCOURSE_URL"]; KEY = os.environ["PRE_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PRE_DISCOURSE_API_USERNAME"]
MAP = json.loads(pathlib.Path("docs/superpowers/plans/data/2026-09-04-module-axis.json").read_text())
SUBJECT = {t for tags in MAP["groups"].values() for t in tags}
CATEGORIES = [3, 4, 5, 14, 18, 59, 73, 75, 78, 79, 80, 81, 82, 83, 84, 85, 88]

def get(path):
    r = urllib.request.Request(URL + path, headers={"Api-Key": KEY, "Api-Username": USER})
    with urllib.request.urlopen(r, timeout=30) as f:
        return json.load(f)

topics = {}
for c in CATEGORIES:
    for page in range(40):
        rows = get(f"/c/{c}/l/latest.json?page={page}").get("topic_list", {}).get("topics", [])
        if not rows:
            break
        for t in rows:
            topics[t["id"]] = [x["name"] for x in (t.get("tags") or [])]
        time.sleep(1.2)
        if len(rows) < 30:
            break
covered = sum(1 for tags in topics.values() if any(t in SUBJECT for t in tags))
print(f"coverage: {covered}/{len(topics)} = {covered / len(topics):.0%}")
```

Expected: **at least 66%**. Below that, count how many batches were rejected before concluding the rule underperformed.

- [ ] **Step 4: Record and commit**

```bash
git add docs/superpowers/plans/data/2026-09-04-batch-decisions.json \
        docs/superpowers/specs/2026-09-04-capa-materia-etiquetas-design.md
git commit -m "feat(tags): apply the validated title-rule batches on PRE

Subject coverage rises to the measured figure recorded in the spec. Decisions
per batch are committed alongside, so every write has a recorded reason."
```

---

### Task 7: The residual — genre split and `pendiente-etiquetar`

**Files:**
- Modify: the spec (*As executed*)

**Interfaces:**
- Consumes: the post-Task-6 topic state.
- Produces: `pendiente-etiquetar` on PRE, carrying only the topics that are genuinely unclassified, plus a recorded count that is the starting point for the next pass.

- [ ] **Step 1: Recompute the residual and split it by genre**

**Re-run Task 5 Step 1 first to regenerate `topics-now.json`.** Task 6 wrote tags to roughly
200 topics, so the copy from Task 5 is stale and would put already-tagged topics back into the
residual.

```python
import json, pathlib, re, unicodedata
MAP = json.loads(pathlib.Path("docs/superpowers/plans/data/2026-09-04-module-axis.json").read_text())
SUBJECT = {t for tags in MAP["groups"].values() for t in tags}
topics = json.load(open("topics-now.json"))  # regenerated moments ago, not the Task 5 copy

def strip_accents(s):
    s = unicodedata.normalize("NFKD", (s or "").lower())
    return "".join(c for c in s if not unicodedata.combining(c)).replace("ñ", "n")

GENRES = [
    ("Certification announcements", r"(nuev[ao]s?\s+(companer|alumn|usuari|certificad)|certificad[ao]\s+caag|nueva\s+certificad|alumna?\s+certificad|se\s+incorpora|bienvenid)"),
    ("Events and seminars", r"(cafe con|encuentro|jornada|congreso|webinar|seminario|hackathon|reto del mes|masterclass|taller|evento)"),
    ("Release notes", r"(novedades\s+v|version\s+\d|v\s?\d+\.\d|despliegue de gestiona|desplegada|actualizacion)"),
    ("Legal and forum documents", r"(politica de privacidad|terminos del servicio|preguntas frecuentes|normas|acerca de la categoria|guia del administrador|faq)"),
    ("Newsletters", r"(newsletter|boletin)"),
    ("Idea campaigns and podcast", r"(#\d{4}|modulo de ejemplo|vota|campana|episodio|podcast)"),
]

residual = {tid: v for tid, v in topics.items() if not any(t in SUBJECT for t in v["tags"])}
counts, unclassified = {g: 0 for g, _ in GENRES}, []
for tid, v in residual.items():
    title = strip_accents(v["title"])
    for genre, rx in GENRES:
        if re.search(rx, title):
            counts[genre] += 1
            break
    else:
        unclassified.append({"topic": int(tid), "title": v["title"]})

print(f"residual: {len(residual)}")
for g, n in sorted(counts.items(), key=lambda kv: -kv[1]):
    print(f"   {g:34}{n:5}")
print(f"   {'No genre — real candidates':34}{len(unclassified):5}")
json.dump(unclassified, open("unclassified.json", "w"), ensure_ascii=False, indent=1)
```

Expected shape: about 61% genre, the rest real candidates. **The genre topics get nothing** — they are correctly without a subject tag, and tagging them `pendiente-etiquetar` would build a queue nobody ever empties.

- [ ] **Step 2: Run the body pass over the unclassified only**

```python
import json, os, re, time, unicodedata, urllib.request
URL = os.environ["PRE_DISCOURSE_URL"]; KEY = os.environ["PRE_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PRE_DISCOURSE_API_USERNAME"]
import pathlib
MAP = json.loads(pathlib.Path("docs/superpowers/plans/data/2026-09-04-module-axis.json").read_text())
SUBJECT = sorted({t for tags in MAP["groups"].values() for t in tags})
unclassified = json.load(open("unclassified.json"))

def strip_accents(s):
    s = unicodedata.normalize("NFKD", (s or "").lower())
    return "".join(c for c in s if not unicodedata.combining(c))

def stem(w):
    return re.sub(r"(es|s)$", "", w) if len(w) > 4 else w

TOKENS = {t: [stem(x) for x in re.split(r"[-_]", strip_accents(t)) if x] for t in SUBJECT}

def get(path):
    r = urllib.request.Request(URL + path, headers={"Api-Key": KEY, "Api-Username": USER})
    try:
        with urllib.request.urlopen(r, timeout=30) as f:
            return json.load(f)
    except Exception:
        return {}

out = []
for row in unclassified:
    d = get(f"/t/{row['topic']}.json")
    time.sleep(1.2)
    posts = d.get("post_stream", {}).get("posts", [])
    body = re.sub(r"<[^>]+>", " ", posts[0].get("cooked", "")) if posts else ""
    words = [stem(w) for w in re.findall(r"[a-z0-9]+", strip_accents(body))]
    ws = set(words)
    hits = {t: min(words.count(x) for x in toks)
            for t, toks in TOKENS.items() if toks and all(x in ws for x in toks)}
    out.append({**row, "hits": {k: v for k, v in hits.items() if v >= 3}})
json.dump(out, open("body-proposals.json", "w"), ensure_ascii=False, indent=1)
print("with a proposal at >=3 mentions:", sum(1 for r in out if r["hits"]))
```

**Threshold 3, not 2.** The spec measured threshold 2 producing visibly wrong results (*"Nueva alumna Certificada CAAG 29"* → `tramitación` ×5). The genre filter in Step 1 removes the worst offenders, but precision here still matters more than recall, and **every proposal from this pass goes to Ricardo individually — none is applied in bulk.**

- [ ] **Step 3: Present the body proposals and apply only what is approved**

Present as topic → proposed tags with the mention counts, in batches of at most 20. Apply approved ones with the read-modify-write loop from Task 6 Step 2.

- [ ] **Step 4: Create `pendiente-etiquetar` and apply it to what is left**

Create the tag through a throwaway group — there is no tag-creation endpoint, and this avoids a topic write to bring it into existence:

```python
import json, os, time, urllib.parse, urllib.request
URL = os.environ["PRE_DISCOURSE_URL"]; KEY = os.environ["PRE_DISCOURSE_GLOBAL_API_KEY"]
USER = os.environ["PRE_DISCOURSE_API_USERNAME"]

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

# No permissions parameter — supplying one returns 500.
st, r = req("POST", "/tag_groups.json",
            [("name", "tmp-create-tag"), ("tag_names[]", "pendiente-etiquetar")])
gid = (r.get("tag_group") or {}).get("id")
print(f"[{st}] temporary group {gid}")
time.sleep(1.3)
if gid:
    print("[%s] temporary group deleted" % req("DELETE", f"/tag_groups/{gid}.json")[0])
```

`pendiente-etiquetar` is **structural, not subject**: it goes in no module group, and `bin/tags-verify` must keep passing after this task. Then apply it to every topic still in `unclassified.json` that received no approved tag in Step 3, using the read-modify-write loop.

- [ ] **Step 5: Verify and record the queue size**

```bash
set -a && source .env.local && set +a
curl -sSL -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" \
  "$PRE_DISCOURSE_URL/tag/pendiente-etiquetar/l/latest.json" -o /tmp/t.json
python3 -c "import json;print('pendiente-etiquetar:',len(json.load(open('/tmp/t.json'))['topic_list']['topics']),'topics (listing paginates at 30)')"
./bin/tags-verify
```

Expected: the listing count matches the number written in Step 4, and `tags-verify` still exits 0.

- [ ] **Step 6: Record and commit**

Append to *As executed*: the genre split, the body-pass yield at threshold 3, how many proposals were approved, and the final `pendiente-etiquetar` count — that count is the success metric for the next pass.

```bash
git add docs/superpowers/specs/2026-09-04-capa-materia-etiquetas-design.md
git commit -m "feat(tags): resolve the residual and open the pendiente-etiquetar queue

Genre topics left untagged on purpose; the body pass ran at threshold 3 over
the unclassified only, with every proposal individually approved. What
survived carries pendiente-etiquetar, whose count is the next pass's metric."
```

---

### Task 8: Close out

**Files:**
- Modify: the spec (*As executed* summary), `CLAUDE.local.md`

- [ ] **Step 1: Run the verifier one final time**

```bash
set -a && source .env.local && set +a && ./bin/tags-verify
```

Expected: `PASS`, exit 0.

- [ ] **Step 2: Check no tag fell below three uses**

Success criterion 3 of the spec. The depuration left nothing below 3 uses; nothing in this
plan should have undone that.

```bash
set -a && source .env.local && set +a
curl -sSL -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" \
  "$PRE_DISCOURSE_URL/tags.json" -o /tmp/tags.json
python3 -c "
import json
a = {x['name']: x['count'] for x in json.load(open('/tmp/tags.json'))['tags']}
queue = a.pop('pendiente-etiquetar', None)
low = sorted((c, n) for n, c in a.items() if c < 3)
print(f'tags: {len(a)} (excluding the queue)  minimum uses: {min(a.values())}')
print('below 3:', low or 'none')
print('pendiente-etiquetar:', queue, '(a working queue — exempt)')"
```

Expected: `below 3: none`. The two renamed tags keep their topics, so the only way this
regresses is if a group creation invented an empty tag — which Task 3 Step 2 is written to
catch. If one appears, delete it and re-run `bin/tags-verify`.

**`pendiente-etiquetar` is exempt from this assertion** and reported separately: its count is
data about how much remains unclassified, not a signal about vocabulary quality, and it can
legitimately land below 3.

- [ ] **Step 3: Check the theme's three tag settings still resolve**

```bash
set -a && source .env.local && set +a
for t in podcast newsletter nueva-version-gestiona; do
  curl -sSL -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" \
    "$PRE_DISCOURSE_URL/tag/$t/l/latest.json" -o /tmp/t.json
  python3 -c "import json,sys;print(f'{sys.argv[1]:24} -> {len(json.load(open(\"/tmp/t.json\"))[\"topic_list\"][\"topics\"])} topics')" "$t"
  sleep 1.3
done
```

Expected: all three non-zero. These back `highlights_podcast_tag`, `highlights_newsletter_tag` and `highlights_news_tag`; a zero means a homepage card silently shows its "coming soon" placeholder.

- [ ] **Step 4: Update `CLAUDE.local.md`**

Update the *Tag depuration* entry under **Pending** with the final coverage figure, the eight groups, and the `pendiente-etiquetar` count. State plainly that the **funcionalidad axis was never built** — `#tramitacion-administrativa` still returns ~414 topics — so nobody later reads the module axis as a narrowing mechanism it was never meant to be.

- [ ] **Step 5: Open the PR**

```bash
git push -u origin feat/tag-subject-layer
gh pr create --title "feat(tags): subject layer for the tag vocabulary" \
  --body "Implements docs/superpowers/specs/2026-09-04-capa-materia-etiquetas-design.md. Instance configuration and topic tags on PRE; no theme code changed. bin/tags-verify passes."
```

Let `ci / linting`, `ci / backend_tests`, `ci / frontend_tests` and `ci / system_tests` go green before merging.

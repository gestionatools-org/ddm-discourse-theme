# PROD Migration T2 — Categories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Tasks 1–8 are tooling and may run in any sitting; Tasks 9–15 write to production and each is one sitting, run by Ricardo's go.**

**Goal:** Take PROD's 39 categories to PRE's map — plaza plus three programme rooms under 5, August's consolidation, 17 surplus categories emptied and closed, none deleted — moving every topic once and verifying each by id.

**Architecture:** A committed **target map** (`docs/superpowers/plans/data/2026-09-17-prod-category-map.json`, ids and names only) is both the intent Ricardo approves and the oracle the verifier reads. Move lists are **proposed** by rules from a fresh capture, **decided** by Ricardo, and **applied** by a mover that re-reads every topic before and after its batch. Pure helpers shared by the applier and the verifier live in one module, `bin/_category_map.py`.

**Tech Stack:** Discourse admin API through `bin/_discourse.py` with `DISCOURSE_INSTANCE=PROD` and `PROD_DISCOURSE_GLOBAL_API_KEY`; Python 3.9 stdlib; `curl`.

**Spec:** `docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md` (binding), section *T2 — Categories*. Roadmap: `docs/superpowers/plans/2026-09-15-migracion-prod-hoja-de-ruta.md`, S7–S8. Rules reused from `2026-09-11-reorganizacion-generos-design.md` (*Phase 1*) and `2026-08-25-category-reorganisation-design.md` (*Every category, and what happens to it*).

## Global Constraints

- **Protected topics `/t/2683` (cat 86), `/t/2690` (cat 89), `/t/2673` (cat 59).** No write, move or bulk operation that includes them **without naming them to Ricardo and getting his explicit yes**. The mover refuses them unless passed `--allow <id>`. `/t/2683` moves only **after 2026-09-25 13:00Z**, when its poll closes (D2).
- **Ids after the restore (~2026-07-27) are not shared.** PROD rooms are **90 AA · 91 Analítica · 92 Developers**; PROD 89 is "Anuncios"; `Developers` is PROD group **101**. Never use a PRE id on PROD.
- **Production, no maintenance window.** When an outcome differs from the prediction, STOP and report; do not improvise.
- **Verify by topic id, never by count.** `PUT /topics/bulk.json` lists a category's definition topic among the ids it "changed" while leaving it in place.
- **Measure thumbnails and bumps per batch** by re-reading each topic before and after. On PROD 2026.9.0 tag writes kept thumbnails; moves have not been measured here.
- **Nothing is deleted.** Surplus categories are emptied, then closed to staff (`moderadores`, which holds all 11 admins and the 3 moderators), out of the default sidebar.
- **Core refuses a child whose groups are absent from its parent** (`Category#check_permissions_compatibility`). Every ordering below exists because of it; a 422 mid-sequence means the order was broken.
- **Rate limit ~1 req/s; no background jobs against PROD; credentials only via `source .env.local` in the same invocation; never print a key.**
- **Captures never enter the repo.** Born gitignored by suffix: `*-prior-state.json`, `*-move-proposals.json`. Decisions and logs hold ids only and are committed.
- **Nothing is announced** to members before T3.
- **Watch the four required CI checks go green before merging.** `gh pr merge --auto` does not wait from this account.

## Decisions taken 2026-09-17, before this plan

| # | Question | Decision |
|---|---|---|
| E1 | Surplus categories: readable by members or staff-only? | **Staff-only** (`moderadores` 1; 86 `administradores` 1, see Task 14). Their old URLs stop resolving for members; every topic URL `/t/<slug>/<id>` still does |
| E2 | Campaign ideas 58 (103), 57 (21), 54 (2) are staff-only today; moving them to 18 shows them to 379 members | **Move to 18**, as on PRE |
| E3 | 85 "Comparte" on PRE is admin-only; on PROD members read and post there | **Replicate PRE: admin-only.** Its content — 34's resources and the Hackathon, `/t/2683` included — disappears for members |
| E4 | Topics tagged `analiza` (90) go to the Analítica room, walled to `Analiza` (82): 298 certified members stop seeing them | **As on PRE** |

Consequences of E3 that fix the order: **86 must be closed before 85 narrows**, and 86 cannot be emptied before `/t/2683` moves. So **85's permissions change after 2026-09-25 13:00Z** (Task 14), and until then 85 keeps today's rows.

## Measured 2026-09-17 (inputs to the map)

- **PROD tree, 39 categories**: 1, 3, 4, 5, 14, 18, 34, 49, 50, 53, 54, 56, 57, 58, 59, 62, 65, 66, 67, 68, 69, 71, 73, 75, 78, 79–88, 89, 90, 91, 92. Children today: 4 → 65, 66, 78, 87; 5 → 18, 34, 54, 58; 14 → 62, 67; 49 → 56, 68, 69; 53 → 57; 73 → 79–84, 88; 85 → 86.
- **Old slugs redirect.** On PRE `/c/grupos-de-trabajo/5`, `/c/ideas-gestiona/18`, `/c/comunidad-expertos/4` all answer **301** to the new slug, JSON listings too. Renaming a slug breaks no link.
- **New slugs shadow nothing.** `noticias` and `comparte` are neither tags nor synonyms (`/tag/<name>/info.json` 404) — their `#` searches return 27 and 50 only because they fall through to full text. After the rename they resolve to the categories, as on PRE.
- **Category 5 carries a 457-character `topic_template`** inherited from "Proyectos piloto", the same defect PRE removed.
- **`default_navigation_menu_categories` is `4|5|14|18|59`**; `default_categories_tracking` `18|49|59|85|73|75|65`, `..._watching_first_post` `4|5|87|62|67`, `..._normal` `66|78|56|68|69`.
- **Group overlaps**: `Tributaria` (49) and `UsuariosPID` (52) are wholly inside `Certificación`; `AppMóvil` (14) has 1 outside; `Analiza` (82) has 1 outside and `Certificación` has 298 outside `Analiza`.

## The map, in words

The JSON is authoritative; this is the reading of it.

| PROD id | Today | T2 |
|---|---|---|
| 4 | Te contamos... | **Noticias**, slug `noticias`; receives 65, 66, release notes from 18; loses member posts to the AA room |
| 5 | El foro del Certificado | **Foro del Certificado**, slug `foro-del-certificado`; + `Analiza`/`Developers`/`AdminDevelopers` read-only; `default_list_filter: none`; template deleted; keeps arrival announcements, receives 78's |
| 90 / 91 / 92 | rooms, closed | opened to `Certificación` / `Analiza` / `Developers`+`AdminDevelopers`, under 5 |
| 18 | Tengo una idea (under 5) | promoted to top level, slug `tengo-una-idea`; receives 54, 57, 58 |
| 14 | Aula de formación | unchanged; receives 62, 67 |
| 59 | Eventos certificación | **Eventos**; receives 87 |
| 73 + 79–82, 84, 88 | Recursos Certificación Analítica | **Recursos Analítica**, slug `recursos-analitica`; `Analiza` 1 only, children first |
| 83 | Comparte tu conocimiento: Analiza (under 73) | **Analítica de datos** under **85**, `administradores` 1 |
| 75 | DocDevelopers | **Recursos Developers**, slug `recursos-developers` |
| 78 | Nuevos usuarios certificados · Pósters (under 4) | **Primeros pasos**, slug `primeros-pasos`, top level, **after** its announcements leave |
| 85 | Recursos y proyectos compartidos | **Comparte**, slug `comparte`, `administradores` 1 — **after the poll**; receives 34 now and 86 after the poll |
| *new* ×2 | — | "Gestiona for developers" and "Administración Avanzada" under 85, `administradores` 1, PRE's slugs |
| 34, 49, 50, 53, 54, 56, 57, 58, 62, 65, 66, 67, 68, 69, 71, 87 | various | emptied, closed to `moderadores`; 67's slug → `seminarios-archivo` (it shadows `#seminarios`) |
| 86 | Proyectos 360 - Hackathon | emptied **after the poll**, closed to `administradores` |
| 1, 3, 89 | | untouched |

**Two divergences from PRE, both deliberate:** `default_navigation_menu_categories` keeps **59** (PROD has it today and removing it would take Eventos out of every member's sidebar), and category **3 is untouched** (PRE's archiving of `expertos-espublico` topics was a departure, not part of the map).

---

## File structure

| File | Responsibility |
|---|---|
| `bin/_category_map.py` *(create)* | Pure helpers: resolve a map reference to an id, compute the changes a category needs, date guard. No I/O. Self-test inside |
| `bin/_discourse.py` *(modify)* | `update_category` gains `permissions=` (replace rows) |
| `bin/categories-capture` *(modify)* | Per-instance capture; PROD captures every category and every topic; refuses to overwrite |
| `bin/categories-propose` *(modify)* | PROD destination rule over every source category; self-test extended |
| `bin/categories-apply-map` *(create)* | Applies map entries, closes, creates, site settings — dry run unless `--write` |
| `bin/categories-move` *(modify)* | Per-instance decisions; protected and date guards; per-topic before/after measurement |
| `bin/groups-sync-developers` *(modify)* | `--reveal` makes the group public |
| `bin/categories-verify` *(modify)* | PROD path driven by the map; PRE path unchanged |
| `docs/superpowers/plans/data/2026-09-17-prod-category-map.json` | Target map (committed in S7) |
| `docs/superpowers/plans/data/2026-09-17-prod-t2-prior-state.json` | Capture (gitignored) |
| `docs/superpowers/plans/data/2026-09-17-prod-t2-move-proposals.json` | Proposals with titles (gitignored) |
| `docs/superpowers/plans/data/2026-09-17-prod-t2-move-decisions.json` | Approved ids per list (committed) |
| `docs/superpowers/plans/data/2026-09-17-prod-t2-move-log.json` | Per-batch record, ids only (committed) |
| `docs/superpowers/plans/data/2026-09-17-prod-t2-created.json` | Ids of the two categories created under 85 (committed) |

---

### Task 1: Shared map helpers and replaceable permissions

**Files:**
- Create: `bin/_category_map.py`
- Modify: `bin/_discourse.py` (`update_category`)

**Interfaces:**
- Produces: `resolve(ref, rooms, created) -> int`; `perms_of(category) -> dict[str, int]`; `plan_changes(current: dict, entry: dict) -> tuple[dict, dict | None]` (fields to send, and the full permission rows to send or `None` to leave them); `not_yet(iso: str | None) -> bool`; `self_test() -> list[str]` (failure messages).
- Produces: `_discourse.update_category(cid, changes=None, add_permissions=None, permissions=None)` — `permissions` replaces every row.

- [ ] **Step 1: Write the module with its self-test and no implementation**

```python
"""Pure helpers for the category target map. No I/O: the applier and the verifier both
import this, so the question "does this category match the map?" has one answer."""
import datetime

FIELDS = ("name", "slug", "color", "text_color", "default_list_filter", "topic_template")
CASE_INSENSITIVE = ("color", "text_color")


def resolve(ref, rooms, created):
    raise NotImplementedError


def perms_of(category):
    raise NotImplementedError


def plan_changes(current, entry):
    raise NotImplementedError


def not_yet(iso):
    raise NotImplementedError


def self_test():
    bad = []

    def expect(label, got, want):
        if got != want:
            bad.append(f"{label}: got {got!r}, expected {want!r}")

    rooms, created = {"analitica": 91}, {"developers_85": 95}
    expect("resolve int", resolve(85, rooms, created), 85)
    expect("resolve str", resolve("85", rooms, created), 85)
    expect("resolve room", resolve("room:analitica", rooms, created), 91)
    expect("resolve created", resolve("created:developers_85", rooms, created), 95)

    base = {"name": "Te contamos...", "slug": "te-contamos", "color": "12A89D",
            "text_color": "FFFFFF", "topic_template": None, "parent_category_id": None,
            "group_permissions": [{"group_name": "todos", "permission_type": 1}]}
    expect("rename", plan_changes(base, {"name": "Noticias", "slug": "noticias"}),
           ({"name": "Noticias", "slug": "noticias"}, None))
    expect("already there", plan_changes(base, {"name": "Te contamos..."}), ({}, None))
    expect("colour case", plan_changes(base, {"color": "12a89d"}), ({}, None))
    expect("template None vs empty", plan_changes(base, {"topic_template": ""}), ({}, None))
    child = {**base, "parent_category_id": 5}
    expect("promote", plan_changes(child, {"parent": None}), ({"parent_category_id": ""}, None))
    expect("reparent", plan_changes(base, {"parent": 5}), ({"parent_category_id": 5}, None))
    two = {**base, "group_permissions": [{"group_name": "Certificación", "permission_type": 1},
                                         {"group_name": "Analiza", "permission_type": 1}]}
    expect("add never lowers", plan_changes(two, {"add_permissions": {"Analiza": 3, "Developers": 3}}),
           ({}, {"Certificación": 1, "Analiza": 1, "Developers": 3}))
    expect("add already present", plan_changes(two, {"add_permissions": {"Analiza": 3}}), ({}, None))
    expect("replace", plan_changes(two, {"permissions": {"moderadores": 1}}), ({}, {"moderadores": 1}))
    expect("replace equal", plan_changes(two, {"permissions": {"Analiza": 1, "Certificación": 1}}), ({}, None))
    expect("past date", not_yet("2020-01-01T00:00:00Z"), False)
    expect("future date", not_yet("2999-01-01T00:00:00Z"), True)
    expect("no date", not_yet(None), False)
    return bad


if __name__ == "__main__":
    failures = self_test()
    print("\n".join(failures) if failures else "self-test OK")
    raise SystemExit(1 if failures else 0)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `python3 bin/_category_map.py`
Expected: `NotImplementedError` from the first `resolve` call.

- [ ] **Step 3: Implement the four helpers**

```python
def resolve(ref, rooms, created):
    """A map reference to a category id: 85, "85", "room:<key>", "created:<key>"."""
    if isinstance(ref, int):
        return ref
    ref = str(ref)
    if ref.startswith("room:"):
        return rooms[ref[len("room:"):]]
    if ref.startswith("created:"):
        return created[ref[len("created:"):]]
    return int(ref)


def perms_of(category):
    return {g["group_name"]: g["permission_type"] for g in (category.get("group_permissions") or [])}


def plan_changes(current, entry):
    """What `entry` still needs on `current`. `entry["parent"]` must already be an id or None.

    `add_permissions` adds groups at a level but never lowers or removes a row a group
    already holds; `permissions` replaces every row. Returns the permission rows to send
    in full, or None when the rows already match.
    """
    changes = {}
    for field in FIELDS:
        if field not in entry:
            continue
        have, want = current.get(field) or "", entry[field] or ""
        if field in CASE_INSENSITIVE:
            have, want = have.lower(), want.lower()
        if have != want:
            changes[field] = entry[field]
    if "parent" in entry and current.get("parent_category_id") != entry["parent"]:
        changes["parent_category_id"] = "" if entry["parent"] is None else entry["parent"]
    have = perms_of(current)
    if "permissions" in entry:
        want = dict(entry["permissions"])
    elif "add_permissions" in entry:
        want = {**entry["add_permissions"], **have}
    else:
        want = have
    return changes, (None if want == have else want)


def not_yet(iso):
    if not iso:
        return False
    when = datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))
    return datetime.datetime.now(datetime.timezone.utc) < when
```

- [ ] **Step 4: Run it and watch it pass**

Run: `python3 bin/_category_map.py`
Expected: `self-test OK`.

- [ ] **Step 5: Let `update_category` replace rows**

In `bin/_discourse.py`, change the signature and the permission block of `update_category`:

```python
def update_category(cid, changes=None, add_permissions=None, permissions=None):
```

```python
    perms = {g["group_name"]: g["permission_type"] for g in (c.get("group_permissions") or [])}
    if permissions is not None:
        # Replace every row. Core rejects a set incompatible with the parent or the
        # children with a 422, which is loud and leaves the category untouched.
        perms = dict(permissions)
    for group, level in (add_permissions or {}).items():
        perms.setdefault(group, level)
```

Add to its docstring: ``permissions`` replaces every row; ``add_permissions`` still never lowers one.

- [ ] **Step 6: Confirm nothing else broke**

Run: `./bin/selftest-instance && python3 bin/_category_map.py`
Expected: both PASS / OK.

- [ ] **Step 7: Commit**

```bash
git add bin/_category_map.py bin/_discourse.py
git commit -m "feat(bin): shared category-map helpers and replaceable permission rows"
```

---

### Task 2: Capture PROD's prior state

**Files:**
- Modify: `bin/categories-capture`
- Create (gitignored): `docs/superpowers/plans/data/2026-09-17-prod-t2-prior-state.json`

**Interfaces:**
- Produces: `{"captured_at", "categories": {"<id>": {name, slug, parent, read_restricted, topic_count, definition_topic_id, permissions, default_list_filter, topic_template_length}}, "topics": {"<id>": {category_id, title, tags, author, created_at, bumped_at, image_url, visible}}}`. Tasks 3, 8 and 15 read it.

- [ ] **Step 1: Make the capture per instance and refuse to overwrite**

Replace the constants and `main` in `bin/categories-capture`:

```python
import datetime
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "docs/superpowers/plans/data"
# (file, topic sources, categories). "all" walks the whole tree: PROD's T2 empties or
# splits 20 categories, and a capture that misses one is a move with no way back.
CAPTURES = {
    "PRE": ("2026-09-11-prior-state.json", [4, 5, 18], [3, 4, 5, 14, 18, 59, 73, 75, 78, 85]),
    "PROD": ("2026-09-17-prod-t2-prior-state.json", "all", "all"),
}


def all_category_ids():
    data = d.get("/categories.json?include_subcategories=true")

    def walk(nodes):
        for c in nodes:
            yield c["id"]
            yield from walk(c.get("subcategory_list") or [])

    return sorted(walk(data["category_list"]["categories"]))


def main():
    name, sources, cats = CAPTURES[d._instance()]
    out = DATA / name
    if out.exists() and "--force" not in sys.argv:
        raise SystemExit(f"{out.name} exists. It is the rollback: refusing to overwrite without --force.")
    everything = all_category_ids()
    sources = everything if sources == "all" else sources
    cats = everything if cats == "all" else cats

    categories = {}
    for cid in cats:
        c = d.category(cid)
        categories[str(cid)] = {
            "name": c["name"],
            "slug": c["slug"],
            "parent": c.get("parent_category_id"),
            "read_restricted": c["read_restricted"],
            # `topic_count` excludes unlisted topics AND the definition topic, so it never
            # equals the length of a crawl. Both are captured so later checks can say
            # which number they mean.
            "topic_count": c["topic_count"],
            "definition_topic_id": d.definition_topic_id(cid),
            "minimum_required_tags": c.get("minimum_required_tags"),
            "auto_close_hours": c.get("auto_close_hours"),
            "default_list_filter": c.get("default_list_filter"),
            "topic_template_length": len(c.get("topic_template") or ""),
            "permissions": {
                g["group_name"]: g["permission_type"] for g in (c.get("group_permissions") or [])
            },
        }

    topics = {}
    for cid in sources:
        for tid, t in d.crawl_category(cid).items():
            topics[str(tid)] = {
                "category_id": t["category_id"],
                "title": t["title"],
                "tags": d.tag_names(t),
                "author": t["_author"],
                "created_at": t["created_at"],
                "bumped_at": t.get("bumped_at"),
                "image_url": t.get("image_url"),
                # Unlisted topics are invisible in every listing but still crawl and still
                # move. Recorded so a decision about one is taken knowingly.
                "visible": t.get("visible", True),
            }

    out.write_text(json.dumps({
        "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "categories": categories,
        "topics": topics,
    }, ensure_ascii=False, indent=1))
    print(f"captured {len(categories)} categories and {len(topics)} topics -> {out.name}")
```

- [ ] **Step 2: Confirm the file is born ignored**

Run: `git check-ignore docs/superpowers/plans/data/2026-09-17-prod-t2-prior-state.json`
Expected: the path is printed. **If nothing prints, STOP** — it would publish titles and usernames.

- [ ] **Step 3: Run the capture**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/categories-capture
```

Expected: `captured 39 categories and ~1 313 topics`. The topic figure is S6b's crawl; a few more is ordinary activity. Fewer is a STOP.

- [ ] **Step 4: Count thumbnails and protected topics in the capture**

```bash
python3 - <<'EOF'
import json, collections
cap = json.load(open("docs/superpowers/plans/data/2026-09-17-prod-t2-prior-state.json"))
t = cap["topics"]
thumbs = collections.Counter(v["category_id"] for v in t.values() if v["image_url"])
print("topics", len(t), "with thumbnail", sum(thumbs.values()), dict(sorted(thumbs.items())))
for tid in ("2683", "2690", "2673"):
    print("protected", tid, "category", t.get(tid, {}).get("category_id"))
print("unlisted", sum(1 for v in t.values() if not v["visible"]))
EOF
```

Expected: protected in 86, 89, 59. Record the thumbnail total: it is the ceiling on T2's bill.

- [ ] **Step 5: Commit the script only**

```bash
git add bin/categories-capture
git commit -m "feat(bin): per-instance category capture that refuses to overwrite its rollback"
```

---

### Task 3: Propose PROD's move lists

**Files:**
- Modify: `bin/categories-propose`
- Create (gitignored): `docs/superpowers/plans/data/2026-09-17-prod-t2-move-proposals.json`

**Interfaces:**
- Consumes: `CEREMONIAL`, `RELEASE_NOTE`, `is_ceremonial`, `is_release_note`, `staff_usernames`, `row`, `content_topics` already in the script.
- Produces: `destination(cid: int, title: str, tags: list[str], staff_author: bool) -> tuple[int | str | None, str]` — target is a category id, `"room:<key>"`, or `None` (stays); the string names the rule. Proposals file: `{"staff_count": int, "lists": {"<source>-><target|stays>": [row + {"rule", "protected"}]}}`.

- [ ] **Step 1: Add PROD destination cases to the self-test**

Append to `self_test()` before the `bad = []` line, and extend the loop:

```python
    AA, AN = "room:administracion_avanzada", "room:analitica"
    destination_cases = [
        # (cid, title, tags, staff_author, expected target)
        (5, "Nuevo Alumno Certificado · José Jiménez · CAAG 27", [], False, None),
        (5, "Registrar oficio de salida", [], False, AA),
        (5, "Fórmula de fechas en un informe", ["analiza"], False, AN),
        (49, "Nueva compañera certificada · Rocío Villarreal", [], False, 5),
        (56, "Liquidación de tasas por ocupación", ["tasas"], False, AA),
        (50, "Cuadro de mando de expedientes", [], False, AN),  # the Analiza category, tag or not
        (71, "Reflexión sobre el día a día", [], False, AA),
        (4, "Newsletter 14 · julio 2026", ["newsletter"], True, None),
        (4, "Pequeña reflexión que nos puede pasar a cualquiera", [], False, AA),
        (4, "Newsletter analítica", ["analiza"], True, AN),
        (65, "Newsletter 3", ["newsletter"], True, 4),
        (66, "Entrada del blog", [], True, 4),
        (18, "Nueva versión Gestiona 10.0.3.325", [], True, 4),
        (18, "Propuesta: filtros en el tesauro", [], False, None),
        (58, "# 08 - CONFIGURACIÓN · 08.09 - TESAURO", ["ideas-2025"], False, 18),
        (57, "Ajustes versión 9.1.3.226.2", [], True, 4),
        (18, "Idea para cuadros de mando", ["analiza"], False, AN),
        (62, "Trucazo: atajos", ["analiza"], False, 14),  # consolidation beats the tag
        (67, "Webinar de novedades", [], True, 14),
        (87, "Café con certificados · marzo", [], True, 59),
        (34, "Plantilla compartida", [], False, 85),
        (86, "Votación del I Hackathon Gestiona", [], True, 85),
        (78, "Nuevo Alumno Certificado · Ana Ruiz · CAAG 30", ["poster-evf"], False, 5),
        (78, "Cómo funciona la comunidad", [], True, None),
        (14, "Curso de padrón", [], True, None),  # not a source: untouched
    ]
```

```python
    for cid, title, tags, staff, expected in destination_cases:
        got = destination(cid, title, tags, staff)[0]
        if got != expected:
            bad.append(f"destination({cid}, {title!r}, {tags!r}, staff={staff}) -> {got!r}, expected {expected!r}")
```

And the final count: `len(ceremonial_cases) + len(release_cases) + len(destination_cases)`.

- [ ] **Step 2: Run the self-test and watch it fail**

Run: `./bin/categories-propose --self-test`
Expected: `NameError: name 'destination' is not defined`.

- [ ] **Step 3: Implement `destination`**

Add below `is_release_note`:

```python
# PROD T2. Every category that is emptied or split, and the rule that decides each topic.
# Consolidation first — a category that disappears into 14, 59 or 85 takes all its topics,
# whatever their tags, because those three are untouched on PRE. Then the analytics tag,
# which PRE applied across news, plaza and ideas. Then the genre rules of 2026-09-11.
PROD_SOURCES = (4, 5, 18, 34, 49, 50, 54, 56, 57, 58, 62, 65, 66, 67, 68, 69, 71, 78, 86, 87)
PLAZA_LIKE = (5, 49, 56, 68, 69, 71)  # August dissolved these into 5
CAMPAIGNS = (54, 57, 58)  # August dissolved these into 18
AA_ROOM, ANALITICA_ROOM = "room:administracion_avanzada", "room:analitica"


def destination(cid, title, tags, staff_author):
    """(target, rule) for one topic. target None means it stays where it is."""
    if cid in (62, 67):
        return 14, "consolidate-aula"
    if cid == 87:
        return 59, "consolidate-events"
    if cid in (34, 86):
        return 85, "consolidate-comparte"
    if cid == 78:
        return (5, "ceremonial") if is_ceremonial(title, tags) else (None, "welcome-stays")
    if cid == 50:
        return ANALITICA_ROOM, "analiza-category"
    if cid not in PROD_SOURCES:
        return None, "not-a-source"
    if "analiza" in tags:
        return ANALITICA_ROOM, "analiza-tag"
    if cid == 4:
        return (None, "staff-news-stays") if staff_author else (AA_ROOM, "member-authored-news")
    if cid in (65, 66):
        return 4, "consolidate-news"
    if cid == 18 or cid in CAMPAIGNS:
        if is_release_note(title):
            return 4, "release-note"
        return (None, "idea-stays") if cid == 18 else (18, "consolidate-ideas")
    if cid in PLAZA_LIKE:
        if is_ceremonial(title, tags):
            return (None, "ceremonial-stays") if cid == 5 else (5, "ceremonial")
        return AA_ROOM, "consultation"
    return None, "untouched"
```

- [ ] **Step 4: Run the self-test and watch it pass**

Run: `./bin/categories-propose --self-test`
Expected: `self-test OK: 50 cases` (8 + 17 + 25).

- [ ] **Step 5: Add the PROD run**

```python
PROTECTED = {2683, 2690, 2673}
PROPOSALS = {"PRE": "2026-09-11-move-proposals.json", "PROD": "2026-09-17-prod-t2-move-proposals.json"}


def main_prod():
    out = ROOT / "docs/superpowers/plans/data" / PROPOSALS["PROD"]
    staff = staff_usernames()
    lists = {}
    for cid in PROD_SOURCES:
        for t in content_topics(cid):
            tags = d.tag_names(t)
            target, rule = destination(cid, t["title"], tags, t["_author"] in staff)
            r = {**row(t), "rule": rule, "protected": t["id"] in PROTECTED}
            lists.setdefault(f"{cid}->{target if target is not None else 'stays'}", []).append(r)
    for rows in lists.values():
        rows.sort(key=lambda r: r["created_at"])
    out.write_text(json.dumps({"staff_count": len(staff), "lists": lists}, ensure_ascii=False, indent=1))
    print(f"proposals -> {out.name}  (staff usernames: {len(staff)})")
    for key in sorted(lists, key=lambda k: (int(k.split('->')[0]), k)):
        rows = lists[key]
        flags = [r["id"] for r in rows if r["protected"] or r["unlisted"]]
        print(f"  {key:28} {len(rows):4}" + (f"   protected/unlisted: {flags}" if flags else ""))
```

Point the existing `OUT` at `PROPOSALS["PRE"]` and make the entry point dispatch:

```python
if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    elif d._instance() == "PROD":
        main_prod()
    else:
        main()
```

- [ ] **Step 6: Confirm the proposals file is born ignored, then run it**

```bash
git check-ignore docs/superpowers/plans/data/2026-09-17-prod-t2-move-proposals.json || { echo STOP; exit 1; }
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/categories-propose
```

Expected: one line per `source->target` with its count; `/t/2683` flagged under `86->85`; no protected id anywhere else.

- [ ] **Step 7: Commit the script only**

```bash
git add bin/categories-propose
git commit -m "feat(bin): propose PROD's T2 move lists from the August and genre rules"
```

---

### Task 4: Gate — Ricardo decides every list

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-17-prod-t2-move-decisions.json`

**Interfaces:**
- Consumes: the proposals file.
- Produces: `{"lists": {"<key>": {"target": int | "room:<key>", "from": [int], "ids": [int], "not_before"?: str}}, "stays": {"<cid>": [int]}}`. Task 6's mover reads `lists`; Task 8's verifier reads both.

- [ ] **Step 1: Present each list to Ricardo, titles and all, in the conversation — never in a file that is committed**

Order, heaviest review first: `4->room:administracion_avanzada` (every title; PRE sent 3 of 36 to the plaza instead), `5->room:administracion_avanzada` plus `5->stays` (community-life topics the ceremonial pattern cannot see), `71->…` (PRE rescued a Café into 59), `18->4` and `54/57/58->4` (release notes; the pattern's known hole), `78->stays` (what "Primeros pasos" keeps), every `->room:analitica` (tag applied in S3 by source category — check it means analytics). Consolidation lists (`62/67->14`, `87->59`, `34->85`, `65/66->4`, `58/57/54->18`) by count and a sample.

For each list record Ricardo's answer as approve, or approve with overrides `{topic_id: target | null}`.

- [ ] **Step 2: Build the decisions file from the proposals plus the overrides**

```python
import json, pathlib
DATA = pathlib.Path("docs/superpowers/plans/data")
proposals = json.loads((DATA / "2026-09-17-prod-t2-move-proposals.json").read_text())["lists"]
OVERRIDES = {}  # {topic_id: target or None}, exactly as Ricardo gave them in Step 1
LABELS = {5: "to_plaza", 4: "to_news", 18: "to_ideas", 14: "to_aula", 59: "to_events", 85: "to_comparte",
          "room:administracion_avanzada": "to_room_aa", "room:analitica": "to_room_analitica"}

lists, stays = {}, {}
for key, rows in proposals.items():
    source, proposed = key.split("->")
    for r in rows:
        target = OVERRIDES.get(r["id"], None if proposed == "stays" else
                               (proposed if proposed.startswith("room:") else int(proposed)))
        if target is None:
            stays.setdefault(source, []).append(r["id"])
            continue
        label = LABELS[target] + ("_hackathon" if source == "86" else "")
        entry = lists.setdefault(label, {"target": target, "from": [], "ids": []})
        if source == "86":
            entry["not_before"] = "2026-09-25T13:00:00Z"
        entry["ids"].append(r["id"])
        if int(source) not in entry["from"]:
            entry["from"].append(int(source))
for entry in lists.values():
    entry["ids"].sort(); entry["from"].sort()
(DATA / "2026-09-17-prod-t2-move-decisions.json").write_text(
    json.dumps({"lists": lists, "stays": {k: sorted(v) for k, v in stays.items()}}, indent=1) + "\n")
print({k: len(v["ids"]) for k, v in lists.items()})
```

- [ ] **Step 3: Assert the file against the guards**

```bash
python3 - <<'EOF'
import json
dec = json.load(open("docs/superpowers/plans/data/2026-09-17-prod-t2-move-decisions.json"))
cap = json.load(open("docs/superpowers/plans/data/2026-09-17-prod-t2-prior-state.json"))
defs = {c["definition_topic_id"] for c in cap["categories"].values()}
seen = {}
for key, e in dec["lists"].items():
    for i in e["ids"]:
        assert i not in seen, f"{i} in {seen.get(i)} and {key}"
        seen[i] = key
        assert i not in defs, f"{i} is a definition topic ({key})"
        assert cap["topics"][str(i)]["category_id"] in e["from"], f"{i} not in {e['from']}"
assert set(seen) & {2690, 2673} == set(), "protected topic in a list"
assert seen.get(2683) in (None, "to_comparte_hackathon"), "2683 outside the date-guarded list"
print("OK", len(seen), "topics in", len(dec["lists"]), "lists")
EOF
```

Expected: `OK`. Any assertion is a STOP.

- [ ] **Step 4: Commit the decisions (ids only)**

```bash
git add docs/superpowers/plans/data/2026-09-17-prod-t2-move-decisions.json
git commit -m "chore(prod): T2 move decisions, approved list by list"
```

---

### Task 5: The map applier

**Files:**
- Create: `bin/categories-apply-map`

**Interfaces:**
- Consumes: `_category_map.resolve`, `plan_changes`, `perms_of`, `not_yet`; `_discourse.update_category(..., permissions=)`.
- Produces: CLI. Dry run unless `--write`. `categories-apply-map [--write] <map-key> ...` applies `categories` entries in the order given; `--close <id> ...`; `--create <key> ...`; `--site-settings`; `--self-test`.

- [ ] **Step 1: Write the script**

```python
#!/usr/bin/env python3
"""Bring an instance's categories to its target map, one entry at a time, in the order the
caller gives. Dry run unless --write: it prints what it would send, which is how every
sitting of T2 starts.

Order is the caller's job and it is load-bearing: core refuses a child whose groups are
absent from its parent, so parents gain groups before children and children lose them
before parents. A 422 means the order was wrong; it changes nothing.
"""
import json
import pathlib
import re
import sys
import unicodedata

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _category_map as cm  # noqa: E402
import _discourse as d  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "docs/superpowers/plans/data"
MAPS = {"PROD": "2026-09-17-prod-category-map.json"}


def load():
    name = MAPS.get(d._instance())
    if not name:
        raise SystemExit(f"no category map for {d._instance()}")
    m = json.loads((DATA / name).read_text())
    rooms = json.loads((DATA / m["rooms_file"]).read_text())
    created_path = DATA / m["created_file"]
    created = json.loads(created_path.read_text()) if created_path.exists() else {}
    return m, rooms, created, created_path


def slugify(text):
    text = unicodedata.normalize("NFKD", text.lower())
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")


def slug_is_free(slug):
    """A category slug wins over a tag and a tag group on the # filter, silently."""
    taken = {slugify(t["name"]) for t in d.get("/tags.json", elevated=True)["tags"]}
    taken |= {slugify(g["name"]) for g in d.get("/tag_groups.json", elevated=True)["tag_groups"]}
    synonym = d.request("GET", f"/tag/{slug}/info.json", elevated=True, allow_404=True)
    return slug not in taken and synonym is None


def apply_entry(label, cid, entry, write):
    entry = dict(entry)
    if cm.not_yet(entry.pop("not_before", None)):
        raise SystemExit(f"STOP: {label} is dated; not before its date")
    current = d.category(cid)
    changes, perms = cm.plan_changes(current, entry)
    print(f"{label} ({cid}) {current['name']!r}: changes={changes} "
          f"permissions={'unchanged' if perms is None else perms}")
    if not changes and perms is None:
        print("  already there")
        return
    if "slug" in changes and not slug_is_free(changes["slug"]):
        raise SystemExit(f"STOP: slug {changes['slug']!r} is a tag, synonym or tag group")
    if not write:
        return
    after = d.update_category(cid, changes, permissions=perms)
    left, left_perms = cm.plan_changes(after, entry)
    if left or left_perms is not None:
        raise SystemExit(f"FAIL: {label} reads back still needing {left} {left_perms}")
    print("  OK")


def categories(keys, write):
    m, rooms, created, _ = load()
    for key in keys:
        entry = dict(m["categories"][key])
        if "parent" in entry and entry["parent"] is not None:
            entry["parent"] = cm.resolve(entry["parent"], rooms, created)
        apply_entry(key, cm.resolve(key, rooms, created), entry, write)


def close(ids, write):
    m, _, _, _ = load()
    rules = m["close"]
    for cid in ids:
        if cid not in rules["order"]:
            raise SystemExit(f"STOP: {cid} is not a surplus category in the map")
        if cm.not_yet(rules.get("not_before", {}).get(str(cid))):
            raise SystemExit(f"STOP: {cid} is dated; not before {rules['not_before'][str(cid)]}")
        definition = d.definition_topic_id(cid)
        left = sorted(t for t in d.crawl_category(cid) if t != definition)
        if left:
            raise SystemExit(f"STOP: category {cid} still holds {len(left)} topics {left[:10]} — "
                             f"closing it would hide them from every member")
        entry = {"permissions": rules.get("permissions_override", {}).get(str(cid), m["closed_to"])}
        if str(cid) in rules.get("slug", {}):
            entry["slug"] = rules["slug"][str(cid)]
        apply_entry(f"close {cid}", cid, entry, write)


def create(keys, write):
    m, rooms, created, created_path = load()
    for key in keys:
        spec = m["create"][key]
        parent = cm.resolve(spec["parent"], rooms, created)
        if key in created:
            print(f"create {key}: exists as {created[key]}")
            continue
        print(f"create {key}: {spec['name']!r} under {parent}, slug {spec['slug']!r}, {spec['permissions']}")
        if not slug_is_free(spec["slug"]):
            raise SystemExit(f"STOP: slug {spec['slug']!r} is a tag, synonym or tag group")
        if not write:
            continue
        payload = [("name", spec["name"]), ("slug", spec["slug"]), ("color", spec["color"]),
                   ("text_color", spec["text_color"]), ("parent_category_id", parent),
                   ("minimum_required_tags", 0)]
        payload += [(f"permissions[{g}]", p) for g, p in spec["permissions"].items()]
        result = d.request("POST", "/categories.json", data=payload, elevated=True)
        created[key] = result["category"]["id"]
        created_path.write_text(json.dumps(created, indent=1) + "\n")
        left, left_perms = cm.plan_changes(d.category(created[key]), {**spec, "parent": parent})
        if left or left_perms is not None:
            raise SystemExit(f"FAIL: created {key} ({created[key]}) reads back still needing {left} {left_perms}")
        print(f"  created {created[key]}")


def site_settings(write):
    m, rooms, created, _ = load()

    def current():
        return {x["setting"]: x["value"] for x in d.get("/admin/site_settings.json", elevated=True)["site_settings"]}

    now = current()
    for name, spec in m["site_settings"].items():
        value = "|".join(str(cm.resolve(p, rooms, created)) for p in spec["value"].split("|"))
        print(f"{name}: {now.get(name)!r} -> {value!r} (backfill {spec['backfill']})")
        if now.get(name) == value or not write:
            continue
        data = [(name, value)] + ([("update_existing_user", "true")] if spec["backfill"] else [])
        d.request("PUT", f"/admin/site_settings/{name}", data=data, elevated=True)
        got = current().get(name)
        if got != value:
            raise SystemExit(f"FAIL: {name} reads back {got!r}")
        print("  OK")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--self-test" in args:
        failures = cm.self_test()
        print("\n".join(failures) if failures else "self-test OK")
        raise SystemExit(1 if failures else 0)
    write = "--write" in args
    rest = [a for a in args if a != "--write"]
    if rest[:1] == ["--close"]:
        close([int(a) for a in rest[1:]], write)
    elif rest[:1] == ["--create"]:
        create(rest[1:], write)
    elif rest[:1] == ["--site-settings"]:
        site_settings(write)
    else:
        categories(rest, write)
    if not write:
        print("(dry run — nothing written; add --write)")
```

- [ ] **Step 2: Make it executable and run the self-test**

Run: `chmod +x bin/categories-apply-map && ./bin/categories-apply-map --self-test`
Expected: `self-test OK`.

- [ ] **Step 3: Dry-run every map entry against PROD**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map 5 room:administracion_avanzada room:analitica room:developers 4 18 59 75 83 79 80 81 82 84 88 73
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --site-settings
```

Expected: one line of intended changes per entry, `(dry run — nothing written)`, and **no STOP**. `85` and `78` are not dry-run here: 85 is dated and 78's promotion follows its moves. A slug STOP means the map is wrong: back to Ricardo.

- [ ] **Step 4: Commit**

```bash
git add bin/categories-apply-map
git commit -m "feat(bin): apply the category target map, dry run by default"
```

---

### Task 6: A mover for PROD

**Files:**
- Modify: `bin/categories-move`

**Interfaces:**
- Consumes: decisions file (Task 4); rooms file.
- Produces: `DISCOURSE_INSTANCE=PROD bin/categories-move <list> [--batch N] [--max-batches N] [--allow <id>]`. Log entries `{key, target, requested, changed, reported, not_moved, skipped, thumbnails_lost, bumped, new_on_latest, errors}`; `changed` is **re-read**, not reported.

- [ ] **Step 1: Replace the module body**

```python
#!/usr/bin/env python3
"""Apply one approved move list, in batches, verifying each topic by re-reading it.

Reads ONLY the human-authored decisions file — the review gate expressed in code. On PROD
it also re-reads every topic before and after its batch: the category it is in (a topic
someone moved meanwhile is skipped, not dragged), its thumbnail, and its bump. The ids
`PUT /topics/bulk.json` reports are logged but never trusted — it lists a definition topic
it did not move.
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _category_map as cm  # noqa: E402
import _discourse as d  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "docs/superpowers/plans/data"
FILES = {
    "PRE": ("2026-09-11-move-decisions.json", "2026-09-11-rooms.json", "2026-09-11-move-log.json"),
    "PROD": ("2026-09-17-prod-t2-move-decisions.json", "2026-09-13-prod-rooms.json", "2026-09-17-prod-t2-move-log.json"),
}
PROTECTED = {2683, 2690, 2673}


def lists():
    decisions_name, rooms_name, _ = FILES[d._instance()]
    decisions = json.loads((DATA / decisions_name).read_text())
    rooms = json.loads((DATA / rooms_name).read_text())
    if d._instance() == "PRE":
        targets = {"to_news": 4, "to_plaza": 5,
                   "to_aa_room_from_4": rooms["administracion_avanzada"],
                   "to_aa_room_from_5": rooms["administracion_avanzada"],
                   "to_analitica_room": rooms["analitica"]}
        return {k: {"target": t, "from": None, "ids": decisions[k], "not_before": None}
                for k, t in targets.items()}
    return {k: {"target": cm.resolve(e["target"], rooms, {}), "from": e["from"], "ids": e["ids"],
                "not_before": e.get("not_before")} for k, e in decisions["lists"].items()}


def measure(tid):
    t = d.get(f"/t/{tid}.json", elevated=True)
    return {"category_id": t["category_id"], "image_url": t.get("image_url"), "bumped_at": t.get("bumped_at")}


def latest_ids():
    return {t["id"] for t in d.get("/latest.json", elevated=True)["topic_list"]["topics"]}


def main(key, batch_size, max_batches, allow):
    all_lists = lists()
    if key not in all_lists:
        raise SystemExit(f"unknown list {key!r}; expected one of {sorted(all_lists)}")
    spec = all_lists[key]
    if cm.not_yet(spec["not_before"]):
        raise SystemExit(f"STOP: {key} is not before {spec['not_before']}")
    blocked = sorted((set(spec["ids"]) & PROTECTED) - set(allow))
    if blocked:
        raise SystemExit(f"STOP: {key} holds protected topics {blocked}. Name them to Ricardo; "
                         f"with his yes, re-run with --allow <id>.")
    target = spec["target"]
    log_path = DATA / FILES[d._instance()][2]
    log = json.loads(log_path.read_text()) if log_path.exists() else []
    done = {i for entry in log if entry["key"] == key for i in entry["changed"]}
    todo = [i for i in spec["ids"] if i not in done]
    print(f"{key} -> category {target}: {len(todo)} to move ({len(done)} already done)")

    for n, start in enumerate(range(0, len(todo), batch_size)):
        if n >= max_batches:
            print(f"  stopping after {max_batches} batches; re-run to continue")
            return
        chunk = todo[start:start + batch_size]
        before = {tid: measure(tid) for tid in chunk}
        skipped = [tid for tid in chunk if spec["from"] and before[tid]["category_id"] not in spec["from"]]
        chunk = [tid for tid in chunk if tid not in skipped]
        on_latest = latest_ids()
        result = {}
        if chunk:
            payload = [("topic_ids[]", i) for i in chunk]
            payload += [("operation[type]", "change_category"), ("operation[category_id]", target)]
            result = d.request("PUT", "/topics/bulk.json", data=payload, elevated=True)
        after = {tid: measure(tid) for tid in chunk}
        entry = {
            "key": key, "target": target, "requested": chunk,
            "changed": [t for t in chunk if after[t]["category_id"] == target],
            "reported": result.get("topic_ids") or [],
            "not_moved": [t for t in chunk if after[t]["category_id"] != target],
            "skipped": skipped,
            "thumbnails_lost": [t for t in chunk if before[t]["image_url"] and not after[t]["image_url"]],
            "bumped": [t for t in chunk if after[t]["bumped_at"] != before[t]["bumped_at"]],
            "new_on_latest": sorted(latest_ids() - on_latest),
            "errors": result.get("errors"),
        }
        log.append(entry)
        log_path.write_text(json.dumps(log, indent=1) + "\n")
        print(f"  batch {n}: moved {len(entry['changed'])}/{len(chunk)}, skipped {skipped}, "
              f"thumbnails lost {entry['thumbnails_lost']}, bumped {entry['bumped']}, "
              f"new on /latest {entry['new_on_latest']}")
        if entry["not_moved"] or entry["bumped"] or skipped:
            raise SystemExit("STOP: read the log entry before anything else. A re-run resumes from "
                             "`changed`, so nothing moves twice — but a skipped topic (moved by "
                             "someone meanwhile) is skipped again until Ricardo decides it and "
                             "the decisions file drops or re-targets it.")


if __name__ == "__main__":
    argv = sys.argv[1:]

    def option(name, default):
        return int(argv[argv.index(name) + 1]) if name in argv else default

    allow = [int(argv[i + 1]) for i, a in enumerate(argv) if a == "--allow"]
    positional = [a for i, a in enumerate(argv)
                  if not a.startswith("--") and (i == 0 or argv[i - 1] not in ("--batch", "--max-batches", "--allow"))]
    main(positional[0], option("--batch", 50), option("--max-batches", 1), allow)
```

**`new_on_latest` is reported, not a STOP**: a member posting during the batch lands there legitimately. Compare it against `requested` before reading it as a leak.

- [ ] **Step 2: Check PRE's path still resolves its lists, without writing**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PRE python3 -c "
import importlib.machinery, sys; sys.path.insert(0, 'bin')
m = importlib.machinery.SourceFileLoader('mv', 'bin/categories-move').load_module()
print({k: (v['target'], len(v['ids'])) for k, v in m.lists().items()})"
```

Expected: PRE's five lists with targets 4, 5, 89, 89, 90 and their historical counts.

- [ ] **Step 3: Commit**

```bash
git add bin/categories-move
git commit -m "feat(bin): PROD mover re-reads every topic and guards protected and dated lists"
```

---

### Task 7: Reveal the `Developers` group

**Files:**
- Modify: `bin/groups-sync-developers`

**Interfaces:**
- Produces: `--reveal` sets `visibility_level` and `members_visibility_level` to 0 on the existing group and reads back that nothing else changed.

- [ ] **Step 1: Add the flag**

```python
PUBLIC = 0
UNCHANGED = ("public_admission", "public_exit", "allow_membership_requests", "primary_group",
             "mentionable_level", "messageable_level")


def reveal():
    """Make the group public, for the sitting its room opens. Born hidden on PROD because the
    group directory is on there; see --hidden."""
    g = d.group(NAME)
    if g is None:
        raise SystemExit(f"{NAME} does not exist")
    was = {k: g.get(k) for k in UNCHANGED}
    d.request("PUT", f"/groups/{g['id']}.json", elevated=True,
              data=[("group[visibility_level]", PUBLIC), ("group[members_visibility_level]", PUBLIC)])
    g = d.group(NAME)
    now = {k: g.get(k) for k in UNCHANGED}
    if (g["visibility_level"], g["members_visibility_level"]) != (PUBLIC, PUBLIC) or now != was:
        raise SystemExit(f"FAIL: {NAME} reads back visibility {g['visibility_level']}/"
                         f"{g['members_visibility_level']}, other fields {now} (were {was})")
    print(f"OK: {NAME} ({g['id']}) is public; nothing else changed")
```

In the entry point: `p.add_argument("--reveal", action="store_true", help="make the existing group public")`, and `reveal() if args.reveal else main(args.hidden)`.

- [ ] **Step 2: Commit**

```bash
git add bin/groups-sync-developers
git commit -m "feat(bin): reveal the Developers group when its room opens"
```

---

### Task 8: The verifier learns PROD, and is watched failing

**Files:**
- Modify: `bin/categories-verify`

**Interfaces:**
- Consumes: map, rooms, created, decisions, capture; `_category_map`.
- Produces: `DISCOURSE_INSTANCE=PROD bin/categories-verify` → exit 0 with `OK` when everything not dated holds; dated items print as `PENDING` and fail only once their date has passed.

- [ ] **Step 1: Extract the two checks both instances share**

Move the `Developers` block and the room-slug block out of `main()` into functions, and call them from `main()` where they were:

```python
def check_developers_union(visibility=None):
    union = set()
    for cohort in DEVELOPER_COHORTS:
        union |= set(d.group_members(cohort))
    developers = d.group("Developers")
    check(developers is not None, "group Developers does not exist")
    if not developers:
        return
    have = set(d.group_members("Developers"))
    check(have == union, f"group Developers has {len(have)} members, expected the cohort union of"
                         f" {len(union)} (extra {len(have - union)}, missing {len(union - have)})")
    for field in ("public_admission", "public_exit", "allow_membership_requests"):
        check(not developers.get(field), f"group Developers: {field} is on, expected off")
    check(not developers.get("primary_group"), "group Developers is a primary group")
    if visibility is not None:
        check(developers.get("visibility_level") == visibility,
              f"group Developers visibility {developers.get('visibility_level')}, expected {visibility}")


def taken_slugs():
    def slugify(text):
        text = unicodedata.normalize("NFKD", text.lower())
        text = "".join(c for c in text if not unicodedata.combining(c))
        return re.sub(r"[^a-z0-9]+", "-", text).strip("-")

    taken = {slugify(t["name"]) for t in d.get("/tags.json", elevated=True)["tags"]}
    return taken | {slugify(g["name"]) for g in d.get("/tag_groups.json", elevated=True)["tag_groups"]}
```

In `main()`, the inline `taken = {...}` pair becomes `taken = taken_slugs()`. Replace the final `if failures: … print("OK: genre …")` of `main()` with `finish("OK: genre reorganisation target state holds")`:

```python
def finish(ok_message, pending=()):
    for p in pending:
        print("  PENDING", p)
    if failures:
        print("FAIL")
        for f in failures:
            print("  -", f)
        sys.exit(1)
    print(ok_message)
```

- [ ] **Step 2: Run PRE and confirm the refactor changed nothing**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PRE ./bin/categories-verify
```

Expected: `OK: genre reorganisation target state holds`.

- [ ] **Step 3: Add the PROD path**

```python
import _category_map as cm  # noqa: E402  (with the other imports)

PROD_DATA = {
    "map": "2026-09-17-prod-category-map.json",
    "decisions": "2026-09-17-prod-t2-move-decisions.json",
    "prior": "2026-09-17-prod-t2-prior-state.json",
}


def verify_prod():
    m = load(DATA / PROD_DATA["map"])
    rooms = load(DATA / m["rooms_file"]) or {}
    created = load(DATA / m["created_file"]) or {}
    decisions = load(DATA / PROD_DATA["decisions"])
    prior = load(DATA / PROD_DATA["prior"])
    pending = []

    def expect(ok, message, not_before=None):
        if ok:
            return
        (pending if cm.not_yet(not_before) else failures).append(
            message + (f" (not before {not_before})" if cm.not_yet(not_before) else ""))

    # 1. Every category the map names looks the way the map says.
    for key, entry in m["categories"].items():
        entry = dict(entry)
        not_before = entry.pop("not_before", None)
        try:
            cid = cm.resolve(key, rooms, created)
        except KeyError:
            check(False, f"{key}: not created")
            continue
        if entry.get("parent") is not None:
            entry["parent"] = cm.resolve(entry["parent"], rooms, created)
        changes, perms = cm.plan_changes(d.category(cid), entry)
        expect(not changes and perms is None, f"category {key} ({cid}) still needs {changes} {perms}", not_before)

    # 2. The categories created under 85.
    for key, spec in m["create"].items():
        check(key in created, f"create {key}: not created")
        if key in created:
            changes, perms = cm.plan_changes(d.category(created[key]),
                                             {**spec, "parent": cm.resolve(spec["parent"], rooms, created)})
            check(not changes and perms is None, f"create {key} ({created[key]}) still needs {changes} {perms}")

    # 3. Surplus categories: empty and closed, never deleted.
    rules = m["close"]
    for cid in rules["order"]:
        not_before = rules.get("not_before", {}).get(str(cid))
        c = d.request("GET", f"/c/{cid}/show.json", elevated=True, allow_404=True)
        check(c is not None, f"category {cid} no longer exists — T2 deletes nothing")
        if c is None:
            continue
        definition = d.definition_topic_id(cid)
        left = sorted(t for t in d.crawl_category(cid) if t != definition)
        entry = {"permissions": rules.get("permissions_override", {}).get(str(cid), m["closed_to"])}
        if str(cid) in rules.get("slug", {}):
            entry["slug"] = rules["slug"][str(cid)]
        changes, perms = cm.plan_changes(c["category"], entry)
        expect(not left, f"category {cid} still holds {len(left)} topics {left[:8]}", not_before)
        expect(not changes and perms is None, f"category {cid} not closed: {changes} {perms}", not_before)

    # 4. Every decided id is in its destination; every kept id is where it was.
    if decisions:
        crawled = {}

        def ids_in(cid):
            if cid not in crawled:
                crawled[cid] = set(d.crawl_category(cid))
            return crawled[cid]

        for key, spec in decisions["lists"].items():
            target = cm.resolve(spec["target"], rooms, created)
            missing = [i for i in spec["ids"] if i not in ids_in(target)]
            expect(not missing, f"list {key}: {len(missing)} of {len(spec['ids'])} not in {target} {missing[:8]}",
                   spec.get("not_before"))
        for source, ids in decisions["stays"].items():
            gone = [i for i in ids if i not in ids_in(int(source))]
            check(not gone, f"stays in {source}: {len(gone)} left it {gone[:8]}")
    else:
        check(False, "move decisions missing")

    # 5. Protected topics are where the map allows.
    for tid, home in m["protected_topics"].items():
        now = d.get(f"/t/{tid}.json", elevated=True)["category_id"]
        allowed = {home} | ({85} if tid == "2683" else set())
        check(now in allowed, f"protected /t/{tid} is in {now}, expected {sorted(allowed)}")

    # 6. The group behind room 92.
    check_developers_union(visibility=m["developers_group"]["visibility_level"])

    # 7. No renamed or created slug shadows a tag or a tag group.
    taken = taken_slugs()
    slugs = [e["slug"] for e in m["categories"].values() if "slug" in e]
    slugs += [e["slug"] for e in m["create"].values()] + list(rules.get("slug", {}).values())
    for slug in slugs:
        check(slug not in taken, f"slug #{slug} shadows a tag or tag group")

    # 8. Sidebar and notification defaults.
    settings = {x["setting"]: x["value"] for x in d.get("/admin/site_settings.json", elevated=True)["site_settings"]}
    for name, spec in m["site_settings"].items():
        want = "|".join(str(cm.resolve(p, rooms, created)) for p in spec["value"].split("|"))
        check(settings.get(name) == want, f"{name} is {settings.get(name)!r}, expected {want!r}")

    # 9. The categories the map keeps are as captured.
    if prior:
        for cid in m["keep"]:
            c = d.category(int(cid))
            was = prior["categories"][cid]
            check(c["name"] == was["name"] and cm.perms_of(c) == was["permissions"],
                  f"category {cid} changed (kept by the map)")
    else:
        check(False, "T2 prior-state capture missing")

    finish("OK: PROD T2 target state holds", pending)
```

Entry point: `verify_prod() if d._instance() == "PROD" else main()`.

- [ ] **Step 4: Watch it fail on PROD before any T2 write**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/categories-verify; echo "exit $?"
```

Expected: **exit 1**, with failures for categories 4, 5, 18, 59, 73, 75, 83, the three rooms, both creates, every surplus category, every list, the Developers visibility and the four site settings — and **PENDING** lines for 85, 86 and `to_comparte_hackathon`. A check that passes now either measures nothing or finds work already done: read it before going on.

- [ ] **Step 5: Lint and commit**

```bash
npx pnpm@10.28.0 lint > /tmp/lint.txt 2>&1; code=$?
grep -E "✖|error" /tmp/lint.txt; [ "$code" -eq 0 ] || exit 1
git add bin/categories-verify
git commit -m "feat(bin): categories-verify asserts PROD's T2 map, watched red first"
```

- [ ] **Step 6: Open the PR for Tasks 1–8 and merge only on green**

```bash
git push -u origin HEAD
gh pr create --title "feat(prod): T2 tooling — map applier, mover and verifier for PROD" --body "Tasks 1–8 of docs/superpowers/plans/2026-09-17-migracion-silenciosa-t2.md. No write to PROD beyond reads; bin/categories-verify is green on PRE and red on PROD by design.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
gh pr checks --watch
```

Merge only when `ci / linting`, `ci / backend_tests`, `ci / frontend_tests` and `ci / system_tests` all pass.

---

### Task 9: Sitting 1 — open the rooms under the plaza

**The moment T2 becomes visible**: members of each programme see a room under "Foro del Certificado". Run Task 10 in the same sitting or the next, so the rooms do not sit empty.

**Files:** instance state; record in the spec.

- [ ] **Step 1: Re-read the live state and dry-run**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map 5 room:administracion_avanzada room:analitica room:developers
```

Expected: 5 gains `Analiza`/`Developers`/`AdminDevelopers` at 3, name, slug, `default_list_filter: none`, template `""`; each room drops `administradores`, gains its groups at 1 and parent 5. If anything else appears, STOP.

- [ ] **Step 2: Reveal the group, then write in this order — parent first**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/groups-sync-developers --reveal
DISCOURSE_INSTANCE=PROD ./bin/groups-sync-developers
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --write 5
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --write room:administracion_avanzada room:analitica room:developers
```

Expected: `OK` after each; the membership re-sync prints 49 and `added 0, removed 0` unless a cohort changed.

- [ ] **Step 3: Confirm nothing else moved**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD python3 -c "
import sys; sys.path.insert(0, 'bin'); import _discourse as d
print('latest head', [t['id'] for t in d.get('/latest.json', elevated=True)['topic_list']['topics'][:6]])
for cid in (5, 90, 91, 92):
    c = d.category(cid); print(cid, c['name'], c['slug'], c.get('parent_category_id'), c.get('topic_count'))"
```

Expected: rooms under 5 with 0 topics; `/latest` head unchanged in kind (no old topic surfaced).

- [ ] **Step 4: Record in the spec's *As executed* and commit**

```bash
git add docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "chore(prod): T2 sitting 1 opens the three rooms under the plaza"
```

---

### Task 10: Sittings 2…n — move, pilot first

**Files:** `docs/superpowers/plans/data/2026-09-17-prod-t2-move-log.json`; spec.

- [ ] **Step 1: Pilot — one batch of 10 from the smallest list**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/categories-move to_events --batch 10 --max-batches 1
```

Expected: `moved n/n`, `bumped []`, `new on /latest []`. **Report the thumbnail figure to Ricardo before any other list** — it is the first measurement of what a move costs on 2026.9.0.

- [ ] **Step 2: The lists, in this order, 50 per batch, up to 3 batches per call**

`to_events`, `to_aula`, `to_news`, `to_ideas`, `to_comparte`, `to_room_analitica`, `to_room_aa`, `to_plaza`.

Three batches per call: each topic costs two reads at ~1.3 s, so 3 × 50 stays under the 10-minute limit of one invocation.

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/categories-move <list> --batch 50 --max-batches 3
```

Repeat each until it prints `0 to move`. **Before each list, say to Ricardo which list, how many topics and how many carry a thumbnail** (from the capture). `to_room_aa` is the loud one: it empties 5, 49, 56, 68, 69, 71 and member posts out of 4.

**`to_plaza` runs last**: it carries 78's announcements, and Task 11 promotes 78 only once they have left.

`to_comparte_hackathon` does not run here: Task 14.

- [ ] **Step 3: Verify by id after the last list**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/categories-verify
```

Expected: the section-4 failures gone except `to_comparte_hackathon` (PENDING). Remaining failures belong to Tasks 11–13.

- [ ] **Step 4: Record and commit the log**

Thumbnail bill (sum of `thumbnails_lost`), `skipped`, `new_on_latest`, per list.

```bash
git add docs/superpowers/plans/data/2026-09-17-prod-t2-move-log.json docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "chore(prod): T2 moves, verified by id"
```

---

### Task 11: Renames, promotions, the resource trees

- [ ] **Step 1: Dry-run, then write in this order**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map 4 18 59 75 78
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --write 4 18 59 75
```

**78 is promoted only once `to_plaza` has finished** — confirm it holds nothing but what was decided to stay, then write it:

```bash
DISCOURSE_INSTANCE=PROD python3 -c "
import sys, json; sys.path.insert(0, 'bin'); import _discourse as d
dec = json.load(open('docs/superpowers/plans/data/2026-09-17-prod-t2-move-decisions.json'))
left = set(d.crawl_category(78)) - {d.definition_topic_id(78)} - set(dec['stays'].get('78', []))
print('78 unexpected:', sorted(left))"
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --write 78
```

Expected: `78 unexpected: []` before the write; a non-empty list is a STOP.

**Order for the analytics tree** — 83 leaves 73 before 73 narrows, and 73's children narrow before 73:

```bash
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --write 83
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --write 79 80 81 82 84 88
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --write 73
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --create developers_85 administracion_avanzada_85
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --create --write developers_85 administracion_avanzada_85
```

`83`'s entry sets permissions, parent and name in one PUT. **If core answers 422**, split it: `permissions` first (its groups must already be a subset of 85's, and `administradores` is), then the parent.

Expected: `OK` after each.

- [ ] **Step 2: Old URLs still land**

```bash
set -a && source .env.local && set +a
for p in /c/te-contamos/4 /c/el-foro-del-certificado/5 /c/ideas-gestiona/18 /c/nuevos-usuarios-certificados/78 /c/documentacion-analiza/73 /c/doc-developers/75; do
  curl -s -o /dev/null -w "$p -> %{http_code} %{redirect_url}\n" -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" "$PROD_DISCOURSE_URL$p"; sleep 1.3
done
```

Expected: `301` to the new slug for each.

- [ ] **Step 3: Record and commit**

```bash
git add docs/superpowers/plans/data/2026-09-17-prod-t2-created.json docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "chore(prod): T2 renames, promotions and the resource trees"
```

---

### Task 12: Close the surplus, retune the defaults

- [ ] **Step 1: Close, children before parents, dry run first**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --close 34 54 58 56 68 69 49 50 57 53 62 67 65 66 87 71
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --write --close 34 54 58 56 68 69 49 50 57 53 62 67 65 66 87 71
```

Expected: each `OK`. A `STOP … still holds` is a topic posted after its list ran: name it to Ricardo, add it to a list, move it, re-run. **65, 66 and 87 are children of 4, whose only row is `todos`**: if core rejects `moderadores` there, STOP and report — do not change 4.

- [ ] **Step 2: Defaults, with the backfill only on the sidebar**

```bash
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --site-settings
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --write --site-settings
```

Expected: `default_navigation_menu_categories` = `4|5|14|18|59|90|91|92` and the three `default_categories_*` values from the map. The backfill adds the rooms to existing members' sidebars; a member sees only the rooms their groups open.

- [ ] **Step 3: `#seminarios` now reaches its synonym**

```bash
set -a && source .env.local && set +a
curl -sSL -G --data-urlencode "q=#seminarios" -H "Api-Key: $PROD_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME" "$PROD_DISCOURSE_URL/search.json" | python3 -c "import json,sys; t=json.load(sys.stdin).get('topics',[]); print(len(t), sorted({x['category_id'] for x in t}))"
```

Expected: the same topics as `#webinars`, now in 14 — no longer 67's listing.

- [ ] **Step 4: Verify, record, commit**

```bash
DISCOURSE_INSTANCE=PROD ./bin/categories-verify
git add docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "chore(prod): T2 closes the surplus categories and retunes the defaults"
```

Expected: `OK: PROD T2 target state holds` with PENDING lines for 85, 86 and `to_comparte_hackathon` only.

---

### Task 13: Theme settings that name categories

**Files:** none; the theme is not installed on PROD until T3.

- [ ] **Step 1: The three ids the theme's defaults name still exist, with the right role**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD python3 -c "
import sys; sys.path.insert(0, 'bin'); import _discourse as d
for setting, cid in (('events_category_id', 59), ('ideas_category_id', 18), ('hero_default_category_id', 5)):
    c = d.category(cid); print(setting, cid, c['name'], 'parent', c.get('parent_category_id'), 'topics', c.get('topic_count'))"
```

Expected: 59 Eventos, 18 Tengo una idea (top level), 5 Foro del Certificado — each with topics. Record for T3; `header_room_category_ids` is `90|91|92` there.

---

### Task 14: After 2026-09-25 13:00Z — the Hackathon and Comparte

**Name `/t/2683` to Ricardo and wait for his yes before Step 2.** Confirm first that its poll is closed.

- [ ] **Step 1: Poll state**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD python3 -c "
import sys; sys.path.insert(0, 'bin'); import _discourse as d
t = d.get('/t/2683.json', elevated=True); p = t['post_stream']['posts'][0]
print('category', t['category_id'], 'pinned_globally', t.get('pinned_globally'),
      'polls', [(x.get('name'), x.get('status'), x.get('close')) for x in p.get('polls') or []])"
```

Expected: poll `status: closed`. Open → STOP.

- [ ] **Step 2: Move the Hackathon with the explicit allowance**

```bash
DISCOURSE_INSTANCE=PROD ./bin/categories-move to_comparte_hackathon --batch 50 --max-batches 1 --allow 2683
```

Expected: all moved, `/t/2683` among them, `bumped []`.

- [ ] **Step 3: Close 86, then narrow and rename 85**

```bash
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --write --close 86
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map 85
DISCOURSE_INSTANCE=PROD ./bin/categories-apply-map --write 85
```

Expected: `OK`. 85's children (83, 86 and the two created) all hold `administradores` only, so the narrowing is compatible.

- [ ] **Step 4: Verify with nothing pending, record, commit**

```bash
DISCOURSE_INSTANCE=PROD ./bin/categories-verify
```

Expected: `OK: PROD T2 target state holds` and **no PENDING line**.

```bash
git add docs/superpowers/plans/data/2026-09-17-prod-t2-move-log.json docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "chore(prod): T2 moves the Hackathon after the poll and closes Comparte to admins"
```

---

### Task 15: Close T2

- [ ] **Step 1: Every assertion**

```bash
set -a && source .env.local && set +a
./bin/selftest-instance && python3 bin/_category_map.py && ./bin/categories-propose --self-test
DISCOURSE_INSTANCE=PRE  ./bin/tags-verify
DISCOURSE_INSTANCE=PROD ./bin/tags-verify
DISCOURSE_INSTANCE=PRE  ./bin/categories-verify
DISCOURSE_INSTANCE=PROD ./bin/categories-verify
```

All pass. **`tags-verify` on PROD matters here**: a category slug can shadow a tag group, and the rename of 73 → `recursos-analitica` sits next to the `Analítica de datos` group.

- [ ] **Step 2: Success criteria, measured**

Every moved id located in its destination (verifier section 4); no category deleted, surplus empty and closed (section 3); the three theme-keyed categories alive (Task 13); the thumbnail bill per batch from the log, against the capture's ceiling.

- [ ] **Step 3: *As executed*, `CLAUDE.local.md`, `traceability.md`, the roadmap checkboxes, and a PR with CI green before merge.**

- [ ] **Step 4: Report to Ricardo what T3 needs:** rooms 90/91/92 for `header_room_category_ids`; the sidebar and site texts that do not travel; and the **non-admin session**, which is the only way to see what E1, E3 and E4 cost a member.

---

## Rollback

- **Moves**: every list's log names the topics that changed and the capture names where each came from, as long as the source category still exists — and none is deleted. Moving back costs a second thumbnail per topic.
- **Renames and slugs**: re-apply the captured name and slug; old slugs redirect either way.
- **Permissions**: the capture holds every row of every category; `update_category(permissions=…)` restores them, children and parents in compatible order.
- **Closing**: reopening is resending the captured rows.

## Self-review against the spec

| Spec requirement (T2) | Task |
|---|---|
| Derive lists from rules, never from PRE's lists; release-note hole | 3 (`RELEASE_NOTE` already allows tokens between keyword and version; self-test covers *"Nueva versión Gestiona 10.0.3.325"*) |
| Ricardo approves every list | 4 |
| 5 receives programme groups before any room hangs under it | 9 Step 2 (5 before rooms) |
| Rooms opened and reparented, no topic moves, no id changes | 9 |
| Move in batches, verified by id; bulk's reported ids not trusted | 6, 10 |
| Thumbnails measured before each batch | 6 (`measure` before/after), 10 |
| 78 renamed with slug after its announcements left | 10 (`to_plaza` last), 11 |
| Surplus emptied and closed, never deleted | 5 (`close` refuses non-empty), 12, 8 section 3 |
| `default_navigation_menu_categories` with backfill, plus the `default_categories_*` family | 12 |
| Three category-keyed theme settings re-read | 13 |
| 86 only after the poll, naming `/t/2683` | 14 |
| 92/93 equivalents under 85, 83 reparented | 11 |
| 67's slug shadows `#seminarios` | map `close.slug`, 12 Step 3 |

**Departures from the spec's *Tooling* table, deliberate:** `forum-rooms-apply` is not given PROD data. Its category half (5's readers and list filter, the rooms' parent) is map entries in `categories-apply-map`; its sidebar half is T3's chrome. And `categories-verify` is parameterised by dispatching on the instance with shared helpers, not by one code path — PRE's assertions are about a reorganisation PROD never had.

# Genre reorganisation — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split PRE's content by scope — a common zone open to every member and walled rooms per certification programme — by creating two categories, moving ~256 topics and changing two category settings.

**Architecture:** Six single-purpose scripts in `bin/`, Python stdlib only, sharing one API client module. They are sequenced capture → propose → *human review* → create → move → settings → verify. The review gate is enforced mechanically: `categories-move` reads only the human-authored decisions file and cannot read the machine-authored proposals. `categories-verify` is written **before** any change, fails on today's state, and is the completion test.

**Tech Stack:** Python 3.9 stdlib (`urllib.request`, `json`, `re`), Discourse admin API on PRE. No new dependencies — the repo has no Python test harness, so the one script with real logic carries a `--self-test` flag over measured fixtures, in the spirit of `bin/tags-verify` ("exit 0 only if it all holds").

**Spec:** `docs/superpowers/specs/2026-09-11-reorganizacion-generos-design.md`

## Global Constraints

- **PRE only.** `https://discourse.gestiona4dev.tech`. Nothing here touches PROD; its migration window is postponed.
- **Credentials by capability.** Reads use `PRE_DISCOURSE_API_KEY` (read-only). Writes use `PRE_DISCOURSE_GLOBAL_API_KEY` — the only key that reaches `/topics/bulk.json`. **Never print a key**, not even redacted: a 2026-08-11 redacted dump leaked one because the hash key was the site URL.
- **Rate limit ~1 req/s.** Sleep 1.3 s between calls, exponential backoff on 429.
- **Verify by topic id, never by count.** A count is not a verification.
- **No unattended classification.** Every move list is approved by Ricardo before any write. The subject-layer body pass produced 10 false positives in 43 proposals; only human review caught them.
- **Each move costs the topic its list thumbnail**, by both routes, permanently. Verified harmless for these topics in the spec.
- **Do not touch** categories 73, 75 and 85, nor `auto_close_hours`, nor `solved_topics_auto_close_hours`. Four deliberate out-of-scope decisions, asserted as unchanged rather than merely intended.
- **Permission levels:** `full: 1`, `create_post: 2`, `readonly: 3` (`CategoryGroup.permission_types`).
- Code, comments and commits in English; conversation with the maintainer in Spanish.
- Branch for the whole plan: `feat/genre-reorganisation`.

---

### Task 1: API client and prior-state capture

**Files:**
- Create: `bin/_discourse.py`
- Create: `bin/categories-capture`
- Output: `docs/superpowers/plans/data/2026-09-11-prior-state.json`

**Interfaces:**
- Consumes: nothing.
- Produces: `_discourse.request(method, path, data=None, write=False) -> dict`, `_discourse.get(path) -> dict`, `_discourse.category(cid) -> dict`, `_discourse.crawl_category(cid) -> dict[int, dict]` (topic id → topic dict carrying an extra `_author` key), `_discourse.tag_names(topic) -> list[str]`.

- [ ] **Step 1: Write the shared client**

Create `bin/_discourse.py`:

```python
"""Minimal Discourse API client for the category work. Stdlib only, like bin/tags-verify."""
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

URL = os.environ["PRE_DISCOURSE_URL"].rstrip("/")
USER = os.environ["PRE_DISCOURSE_API_USERNAME"]
PAUSE = 1.3  # PRE rate-limits at roughly 1 req/s


def _key(write):
    """Ask for the key the call needs, so a read never carries a write-capable credential.

    The read-only key answers 403 on every write; the Global key is the only one that
    reaches /topics/bulk.json. Never log either value.
    """
    return os.environ["PRE_DISCOURSE_GLOBAL_API_KEY" if write else "PRE_DISCOURSE_API_KEY"]


def request(method, path, data=None, write=False, retries=4):
    """One API call. `data` is a list of (key, value) pairs, form-encoded.

    Rails wants repeated keys for arrays (`topic_ids[]`) and bracketed keys for nested
    hashes (`operation[type]`), which a plain dict cannot express — hence the pair list.
    """
    headers = {"Api-Key": _key(write), "Api-Username": USER, "Accept": "application/json"}
    body = None
    if data is not None:
        body = urllib.parse.urlencode(data).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    for attempt in range(retries):
        req = urllib.request.Request(URL + path, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as response:
                payload = response.read()
            time.sleep(PAUSE)
            return json.loads(payload or b"{}")
        except urllib.error.HTTPError as exc:
            if exc.code == 429 and attempt < retries - 1:
                time.sleep(PAUSE * 2 ** (attempt + 1))
                continue
            detail = exc.read()[:300].decode("utf-8", "replace")
            raise SystemExit(f"{method} {path} -> HTTP {exc.code}: {detail}")


def get(path):
    return request("GET", path)


def category(cid):
    """`/c/<id>/show.json` is the working shape; the slug form genuinely errors."""
    return get(f"/c/{cid}/show.json")["category"]


def tag_names(topic):
    """Tags arrive as strings on older serializers and as objects on newer ones."""
    return [t["name"] if isinstance(t, dict) else t for t in (topic.get("tags") or [])]


def _original_author(topic, users):
    """The poster flagged as author. Discourse localises the description, so match on the
    substring both locales share: 'Autor original' (es) and 'Original Poster' (en).
    """
    for poster in topic.get("posters") or []:
        if "original" in (poster.get("description") or "").lower():
            return users.get(poster["user_id"])
    return None


def crawl_category(cid, max_pages=40):
    """Every topic whose own category is `cid`, across all listing pages.

    A category's listing carries its children's topics too, so filter on category_id
    before counting anything. The listing 301-redirects; urllib follows that for GET.
    """
    out = {}
    for _page in range(max_pages):
        data = get(f"/c/{cid}/l/latest.json?page={_page}")
        topics = data["topic_list"]["topics"]
        if not topics:
            break
        users = {u["id"]: u["username"] for u in data.get("users", [])}
        for topic in topics:
            if topic["category_id"] != cid or topic["id"] in out:
                continue
            topic["_author"] = _original_author(topic, users)
            out[topic["id"]] = topic
    return out
```

- [ ] **Step 2: Write the capture script**

Create `bin/categories-capture` (mode 755):

```python
#!/usr/bin/env python3
"""Dump the recoverable prior state before the first write. This is the only rollback
for the moves: a category move is reversible only while the source category still
exists, and nothing else records where each topic came from."""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/superpowers/plans/data/2026-09-11-prior-state.json"
SOURCES = [4, 5, 18]
ALL_CATEGORIES = [3, 4, 5, 14, 18, 59, 73, 75, 78, 85]


def main():
    categories = {}
    for cid in ALL_CATEGORIES:
        c = d.category(cid)
        categories[str(cid)] = {
            "name": c["name"],
            "read_restricted": c["read_restricted"],
            "topic_count": c["topic_count"],
            "minimum_required_tags": c.get("minimum_required_tags"),
            "auto_close_hours": c.get("auto_close_hours"),
            "topic_template": c.get("topic_template") or "",
            "permissions": {
                g["group_name"]: g["permission_type"] for g in (c.get("group_permissions") or [])
            },
        }

    topics = {}
    for cid in SOURCES:
        for tid, t in d.crawl_category(cid).items():
            topics[str(tid)] = {
                "category_id": t["category_id"],
                "title": t["title"],
                "tags": d.tag_names(t),
                "author": t["_author"],
                "created_at": t["created_at"],
                "image_url": t.get("image_url"),
            }

    OUT.write_text(
        json.dumps({"categories": categories, "topics": topics}, ensure_ascii=False, indent=1)
    )
    print(f"captured {len(categories)} categories and {len(topics)} topics -> {OUT}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Run the capture**

```bash
set -a && source .env.local && set +a && ./bin/categories-capture
```

Expected: `captured 10 categories and 1014 topics` (120 + 366 + 528). **If the total is materially below 1014, stop** — a short crawl means a listing page returned early and the capture is worthless as a rollback.

- [ ] **Step 4: Assert the capture is usable as a rollback**

```bash
python3 -c "
import json
d=json.load(open('docs/superpowers/plans/data/2026-09-11-prior-state.json'))
t=d['topics']
assert len(t)>1000, len(t)
assert all(v['category_id'] in (4,5,18) for v in t.values())
assert sum(1 for v in t.values() if v['author'] is None)==0, 'topics with no author'
assert d['categories']['5']['topic_template'], 'category 5 template not captured'
assert d['categories']['4']['minimum_required_tags']==2
print('rollback capture OK:', len(t), 'topics')
"
```

Expected: `rollback capture OK: 1014 topics`. A non-zero count of authorless topics means `_original_author` failed against this instance's locale, and Task 3's category-4 rule would then classify every topic as member-authored — the single most damaging silent failure in this plan.

- [ ] **Step 5: Commit**

```bash
git checkout -b feat/genre-reorganisation
git add bin/_discourse.py bin/categories-capture docs/superpowers/plans/data/2026-09-11-prior-state.json
git commit -m "feat(bin): Discourse API client and prior-state capture

The capture is the only rollback for the moves: a category move is reversible
only while the source category still exists, and nothing else records where each
topic came from."
```

---

### Task 2: The verifier, written red

**Files:**
- Create: `bin/categories-verify`

**Interfaces:**
- Consumes: `_discourse.category`, `_discourse.crawl_category`, `_discourse.tag_names`.
- Produces: an executable that exits 0 only when the whole target state holds. It derives expected counts from `2026-09-11-prior-state.json` and `2026-09-11-move-decisions.json` rather than carrying them hardcoded, so Ricardo's actual split is what it checks.

- [ ] **Step 1: Write the verifier against the target state**

Create `bin/categories-verify` (mode 755):

```python
#!/usr/bin/env python3
"""Assert the genre-reorganisation target state on PRE. Exit 0 only if it all holds.

Written before any change, so it is expected to FAIL until the plan is executed.
Re-run it after any category work.

Blind spot, stated rather than hidden: it reads with an administrator's key, and
/c/<id>/show.json answers with that user's own permissions. It can assert which
group_permissions rows exist; it cannot assert what a member actually sees. That half
is checked by signing in — see the plan's final task.
"""
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "docs/superpowers/plans/data"
PRIOR = DATA / "2026-09-11-prior-state.json"
DECISIONS = DATA / "2026-09-11-move-decisions.json"
ROOMS = DATA / "2026-09-11-rooms.json"

# Must stay byte-identical to bin/categories-propose's CEREMONIAL: the two decide the
# same question from opposite ends, and a divergence would let the verifier pass on a
# plaza the proposer would have emptied.
CEREMONIAL = re.compile(
    r"nuev[oa]s?\s+(?:\w+\s+){0,2}(alumn|compañer|miembr|certificad)"
    r"|certificad[oa]s?\s*[·\-:]"
    r"|enhorabuena|bienvenid",
    re.I,
)

# Out-of-scope categories: their settings must be exactly what the capture recorded.
UNTOUCHED = ("73", "75", "85")

failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


def load(path):
    return json.loads(path.read_text()) if path.exists() else None


def main():
    prior = load(PRIOR)
    decisions = load(DECISIONS)
    rooms = load(ROOMS)
    check(prior is not None, "prior-state capture missing")
    check(decisions is not None, "move decisions missing")
    check(rooms is not None, "rooms file missing — the two rooms have not been created")

    if prior and decisions:
        # Expected counts derive from the approved decisions, not from a hardcoded guess.
        out_of_4 = len(decisions["to_aa_room_from_4"]) + len(decisions["to_plaza"])
        expected = {
            4: prior["categories"]["4"]["topic_count"] - out_of_4 + len(decisions["to_news"]),
            5: prior["categories"]["5"]["topic_count"]
            - len(decisions["to_aa_room_from_5"])
            + len(decisions["to_plaza"]),
            18: prior["categories"]["18"]["topic_count"] - len(decisions["to_news"]),
        }
        for cid, want in expected.items():
            got = d.category(cid)["topic_count"]
            check(got == want, f"category {cid}: topic_count {got}, expected {want}")

    if rooms and decisions:
        room_expected = {
            "administracion_avanzada": len(decisions["to_aa_room_from_4"])
            + len(decisions["to_aa_room_from_5"]),
            "analitica": 0,
        }
        for key, group in (("administracion_avanzada", "Certificación"), ("analitica", "Analiza")):
            c = d.category(rooms[key])
            perms = {
                g["group_name"]: g["permission_type"] for g in (c.get("group_permissions") or [])
            }
            check(c["read_restricted"], f"room {key} is not read_restricted")
            check(perms.get(group) == 1, f"room {key}: {group} should hold permission 1, has {perms}")
            check(
                c["topic_count"] == room_expected[key],
                f"room {key}: topic_count {c['topic_count']}, expected {room_expected[key]}",
            )
            check(
                c.get("minimum_required_tags") == 0,
                f"room {key}: minimum_required_tags {c.get('minimum_required_tags')}, expected 0",
            )

    # The tag toll is gone from every conversational category.
    for cid in (4, 5, 14, 18):
        got = d.category(cid).get("minimum_required_tags")
        check(got == 0, f"category {cid}: minimum_required_tags {got}, expected 0")

    # Category 5's topic_template was inherited from the dissolved "Proyectos piloto".
    template = (d.category(5).get("topic_template") or "").strip()
    check(not template, "category 5 still has a topic_template")

    # Out-of-scope categories must be exactly as captured, settings and permissions.
    if prior:
        for cid in UNTOUCHED:
            c = d.category(int(cid))
            was = prior["categories"][cid]
            perms = {
                g["group_name"]: g["permission_type"] for g in (c.get("group_permissions") or [])
            }
            check(c["name"] == was["name"], f"category {cid} was renamed (out of scope)")
            check(perms == was["permissions"], f"category {cid} permissions changed (out of scope)")
            check(
                c.get("minimum_required_tags") == was["minimum_required_tags"],
                f"category {cid} minimum_required_tags changed (out of scope)",
            )
    # auto_close is deferred by decision: it must still be set on all four.
    for cid in (4, 5, 14, 18):
        got = d.category(cid).get("auto_close_hours")
        check(got == 720.0, f"category {cid}: auto_close_hours {got}, expected 720.0 (deferred)")

    # Nothing but arrival announcements and the approved exceptions may remain in the plaza.
    if decisions:
        allowed = set(decisions["stays_in_plaza"]) | set(decisions["to_plaza"])
        strays = sorted(
            t["id"]
            for t in d.crawl_category(5).values()
            if "poster-evf" not in d.tag_names(t)
            and not CEREMONIAL.search(t["title"])
            and t["id"] not in allowed
        )
        check(not strays, f"unapproved non-ceremonial topics left in the plaza: {strays}")

    if failures:
        print("FAIL")
        for f in failures:
            print("  -", f)
        sys.exit(1)
    print("OK: genre reorganisation target state holds")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it and verify it fails**

```bash
set -a && source .env.local && set +a && ./bin/categories-verify; echo "exit=$?"
```

Expected: `exit=1`, listing the missing decisions and rooms files, four `minimum_required_tags 2, expected 0`, and `category 5 still has a topic_template`. The `auto_close_hours` checks should already **pass** — they assert the deferred decision was respected.

**This red run is the point of the task.** If it exits 0 the assertions are not testing anything.

- [ ] **Step 3: Commit**

```bash
git add bin/categories-verify
git commit -m "test(bin): assert the genre-reorganisation target state, red

Fails on today's state by design. Expected counts derive from the approved
decisions rather than from hardcoded figures, and the deferred auto_close and the
three out-of-scope categories are asserted as unchanged."
```

---

### Task 3: Derive the move proposals

**Files:**
- Create: `bin/categories-propose`
- Output: `docs/superpowers/plans/data/2026-09-11-move-proposals.json`

**Interfaces:**
- Consumes: `_discourse.crawl_category`, `_discourse.tag_names`, `_discourse.get`.
- Produces: `is_ceremonial(title, tags) -> bool`, `is_release_note(title) -> bool`, and a proposals file with keys `cat5_candidates`, `cat4_candidates`, `cat18_candidates`, each a list of `{id, title, author, tags, created_at, replies}`.

- [ ] **Step 1: Write the script with its self-test**

Create `bin/categories-propose` (mode 755):

```python
#!/usr/bin/env python3
"""Propose the three move lists. Output is a PROPOSAL, never an instruction:
bin/categories-move reads only the human-authored decisions file, by design.

Run the rules over fixtures first: ./bin/categories-propose --self-test
"""
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/superpowers/plans/data/2026-09-11-move-proposals.json"

# An arrival announcement. Poster and ceremonial announcement are the same genre, so the
# tag alone is not enough and neither is a narrow wording: the noun between "Nueva" and
# the role varies, and sometimes there is none — "Nueva Certificado CAAG 31 Xavier
# García". Measured 2026-09-11: this catches all 60 `poster-evf` topics by text alone,
# plus 100 announcements that carry no tag at all.
CEREMONIAL = re.compile(
    r"nuev[oa]s?\s+(?:\w+\s+){0,2}(alumn|compañer|miembr|certificad)"
    r"|certificad[oa]s?\s*[·\-:]"
    r"|enhorabuena|bienvenid",
    re.I,
)

# A product release note. Three things this had to survive, all found by running it over
# the real 528 titles rather than by reading them:
#   - the separator is \W* because "Nueva versión: 10.0.3.332" puts a colon there;
#   - up to two tokens sit between keyword and number, because the product name does:
#     "Novedades Gestiona 10.0.3.326.1";
#   - a version-like number (\d+\.\d) is REQUIRED. Without it "Seminario de novedades,
#     martes 15 de julio" matches, and so does anything containing "conversión" — which
#     contains "versión". A bare digit gave 22 candidates, three of them wrong.
RELEASE_NOTE = re.compile(
    r"(?:novedades?|versi[óo]n|ajustes)\W*(?:\S+\s+){0,2}v?\d+\.\d"
    r"|pr[óo]ximas\s+mejoras"
    r"|aviso\s+de\s+mantenimiento",
    re.I,
)

# Official communication comes from these groups; everything else in category 4 is a
# member post. The author discriminates where the title cannot: Spanish titles are noun
# phrases, so a question heuristic classified 171 of 206 topics as "neither".
STAFF_GROUPS = ("esPublico", "administradores", "personal", "Producto")


def is_ceremonial(title, tags):
    return "poster-evf" in tags or bool(CEREMONIAL.search(title))


def is_release_note(title):
    return bool(RELEASE_NOTE.search(title))


def self_test():
    ceremonial_cases = [
        ("Nuevo Alumno Certificado · José Jiménez Alcaraz · CAAG 27", [], True),
        ("Nueva compañera certificada · Rocío Villarreal Gato", [], True),
        ("Nueva Certificado CAAG 31 Xavier García", [], True),
        ("Los pósteres del III Encuentro", ["poster-evf"], True),  # tag without the wording
        ("Registrar oficio de salida", [], False),
        ("Tesauro Fecha en tramite externo", [], False),
        ("Reflexiones sobre nuestra Comunidad: ¿Hacia dónde vamos con Gestiona?", [], False),
        ("Nueva versión 10.0.3.332", [], False),  # "Nueva …" must not read as an arrival
    ]
    release_cases = [
        ("Novedades versión 10.0.3.336", True),
        ("Nueva versión: 10.0.3.332", True),
        ("Novedades Gestiona. Versión 10.0.3.333.0", True),
        ("Nueva versión Gestiona 10.0.3.325", True),  # escaped the stricter pattern before
        ("Novedades Gestiona 10.0.3.326.1", True),  # and this one
        ("Novedades v10.0.3.313.0", True),  # the version number may carry a v prefix
        ("Ajustes versión 9.1.3.226.2", True),
        ("Próximas mejoras en el módulo de Padrón", True),
        ("Aviso de mantenimiento en sede electrónica", True),
        ("Mejoras en GESTIONA CODE", False),
        ("Novedades Órganos Colegiados", False),  # product news with no version number
        ("Propuesta: Sistema de Gestión de Incidencias Ciudadanas (GIC)", False),
        # Every one of these matched a looser pattern and is a proposal, not a note.
        ("Seminario de novedades, martes 15 de julio", False),
        ("Conversión de un numero a texto", False),  # "conversión" contains "versión"
        ("Sugerencia: Informar de la causa del error de conversión", False),
        ("Versión 10 (feedback)", False),
        ("Versión 10 - Tesauros", False),
    ]
    bad = []
    for title, tags, expected in ceremonial_cases:
        if is_ceremonial(title, tags) != expected:
            bad.append(f"is_ceremonial({title!r}, {tags!r}) != {expected}")
    for title, expected in release_cases:
        if is_release_note(title) != expected:
            bad.append(f"is_release_note({title!r}) != {expected}")
    if bad:
        print("SELF-TEST FAIL")
        for b in bad:
            print("  -", b)
        sys.exit(1)
    print(f"self-test OK: {len(ceremonial_cases) + len(release_cases)} cases")


def staff_usernames():
    names = set()
    for group in STAFF_GROUPS:
        data = d.get(f"/groups/{group}/members.json?limit=100")
        for member in data.get("members", []) + data.get("owners", []):
            names.add(member["username"])
    return names


def row(t):
    return {
        "id": t["id"],
        "title": t["title"],
        "author": t["_author"],
        "tags": d.tag_names(t),
        "created_at": t["created_at"][:10],
        "replies": t["posts_count"] - 1,
    }


def main():
    staff = staff_usernames()
    proposals = {
        # Everything in the plaza that is not an arrival announcement. Review for the
        # community-life topics that must stay: they carry no pattern of their own.
        "cat5_candidates": [
            row(t)
            for t in d.crawl_category(5).values()
            if not is_ceremonial(t["title"], d.tag_names(t))
        ],
        # Every member-authored topic in Noticias. Three of these are community life and
        # belong in the plaza, not in the room — no rule can tell which.
        "cat4_candidates": [t for t in (row(x) for x in d.crawl_category(4).values())
                            if t["author"] not in staff],
        "cat18_candidates": [
            row(t) for t in d.crawl_category(18).values() if is_release_note(t["title"])
        ],
        "staff_count": len(staff),
    }
    for key in ("cat5_candidates", "cat4_candidates", "cat18_candidates"):
        proposals[key].sort(key=lambda r: r["created_at"])
    OUT.write_text(json.dumps(proposals, ensure_ascii=False, indent=1))
    print(
        f"proposals -> {OUT}\n"
        f"  cat5 -> AA room: {len(proposals['cat5_candidates'])}\n"
        f"  cat4 -> AA room or plaza: {len(proposals['cat4_candidates'])}\n"
        f"  cat18 -> Noticias: {len(proposals['cat18_candidates'])}\n"
        f"  staff usernames: {len(staff)}"
    )


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        main()
```

- [ ] **Step 2: Run the self-test and verify it passes**

```bash
./bin/categories-propose --self-test
```

Expected: `self-test OK: 25 cases`. It needs no credentials — the rules are pure functions. **If a case fails, fix the pattern, not the case**: every case is a title measured on the instance, and the negative cases are titles that an earlier, looser version of these patterns got wrong.

- [ ] **Step 3: Generate the proposals**

```bash
set -a && source .env.local && set +a && ./bin/categories-propose
```

Expected, against the 2026-09-11 measurement: `cat5 → 206`, `cat4 → 36`, `cat18 → 19`, `staff usernames: 18`. Small drift is normal — the forum is live. **A large divergence means the rule changed meaning, not that the forum moved**; stop and re-measure.

- [ ] **Step 4: Commit**

```bash
git add bin/categories-propose docs/superpowers/plans/data/2026-09-11-move-proposals.json
git commit -m "feat(bin): derive the three move proposals from measured rules

Proposals, not instructions: categories-move reads only the human-authored
decisions file. The release-note pattern allows two tokens between keyword and
version number, which is the hole that let two notes escape in the subject-layer
work."
```

---

### Task 4: Human review gate

**Files:**
- Create: `docs/superpowers/plans/data/2026-09-11-move-decisions.json`

**Interfaces:**
- Consumes: `2026-09-11-move-proposals.json`.
- Produces: the decisions file with keys `to_aa_room_from_5`, `to_aa_room_from_4`, `to_plaza`, `to_news`, `stays_in_plaza` — each a list of topic ids, and the only input `categories-move` will read.

**This task writes no code and must not be delegated.** It is the gate the whole plan is built around. The lists are split by source so each move can be verified against its own origin; a single combined list would make a category 5 misclassification invisible until everything had moved.

- [ ] **Step 1: Present the three lists to Ricardo, in batches**

Render the proposals as review tables — id, date, replies, author, title — and walk them with him:

- **cat5 (~206):** the rule is sound; what needs eyes is the handful of community-life topics with no pattern of their own. Known members of that set, to confirm and place in `stays_in_plaza`: `2224` *Reflexiones sobre nuestra Comunidad*, `2451` *Hasta aquí llego*, *Encuesta de experiencia y mejora de la Comunidad*, *Reflexión sobre el día a día de los certificados*. Everything else goes to `to_aa_room_from_5`.
- **cat4 (36):** review all 36 and place each in `to_aa_room_from_4` or `to_plaza`. Expected roughly 33/3; the three known community-life ones are *Pequeña reflexión que nos puede pasar a cualquiera*, *Felicitaciones a los equipos del Hackathon*, *COMUNICADO OFICIAL (Y Extraoficial) de la resistencia*.
- **cat18 (19):** read all 19 titles; they go to `to_news` unless one is a proposal that merely mentions a version. Two need an explicit call, and both were found by running the rule over the real corpus:
  - *Curso novedades Versión 10.0.3.317 y siguientes* — a **course**, so arguably Aula de formación (14) rather than Noticias. Moving it to 14 is out of this plan's scope; either send it to `to_news` anyway or leave it in 18 and note it.
  - *Novedades gestiona: Uniformidad de ajustes* — reads like a release note but carries no version number, so the rule excludes it. If it belongs in Noticias, add its id to `to_news` by hand: the check in step 3 allows `to_news` to be a superset of the candidates and prints the additions, precisely so a human can add one without fighting the assertion.

- [ ] **Step 2: Write the approved decisions file**

```json
{
  "approved_by": "Ricardo",
  "approved_on": "2026-09-11",
  "to_aa_room_from_5": [],
  "to_aa_room_from_4": [],
  "to_plaza": [],
  "to_news": [],
  "stays_in_plaza": []
}
```

Fill each list with the approved ids.

- [ ] **Step 3: Assert the decisions partition the proposals**

```bash
python3 -c "
import json,pathlib
P=pathlib.Path('docs/superpowers/plans/data')
p=json.loads((P/'2026-09-11-move-proposals.json').read_text())
d=json.loads((P/'2026-09-11-move-decisions.json').read_text())
c5={r['id'] for r in p['cat5_candidates']}; c4={r['id'] for r in p['cat4_candidates']}; c18={r['id'] for r in p['cat18_candidates']}
r5=set(d['to_aa_room_from_5']); r4=set(d['to_aa_room_from_4']); plaza=set(d['to_plaza']); news=set(d['to_news']); stays=set(d['stays_in_plaza'])
assert r5|stays == c5, f'cat5 undecided: {sorted(c5^(r5|stays))}'
assert not (r5 & stays), 'a cat5 topic is both moving and staying'
assert r4|plaza == c4, f'cat4 undecided: {sorted(c4^(r4|plaza))}'
assert not (r4 & plaza), 'a cat4 topic has two destinations'
dropped = c18 - news
assert not dropped, f'cat18 candidates silently dropped: {sorted(dropped)}'
added = news - c18
assert not (r5 & r4), 'the two room lists overlap'
assert not (news & (r5|r4|plaza)), 'a topic is going to Noticias and somewhere else'
print('partition OK:',len(r5),'from 5 /',len(r4),'from 4 /',len(plaza),'plaza /',len(news),'news /',len(stays),'stay')
if added: print('  note:',len(added),'ids added to to_news by hand:',sorted(added))
"
```

Expected: `partition OK: 201 from 5 / 33 from 4 / 3 plaza / 19 news / 5 stay`, approximately — the exact split is Ricardo's, and the assertion is that it is *complete and disjoint*, not that it matches these numbers. A candidate may be **added** to `to_news` by hand (the rule under-matches by design on titles with no version number) but never silently dropped.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/data/2026-09-11-move-decisions.json
git commit -m "docs(data): approved move decisions for the genre reorganisation

Reviewed batch by batch. Lists are split by source category so each move is
verifiable against its own origin. The mover reads this file and never the
proposals."
```

---

### Task 5: Create the two rooms

**Files:**
- Create: `bin/categories-create-rooms`
- Output: `docs/superpowers/plans/data/2026-09-11-rooms.json`

**Interfaces:**
- Consumes: `_discourse.request`, `_discourse.get`, `_discourse.category`.
- Produces: `2026-09-11-rooms.json` = `{"administracion_avanzada": <id>, "analitica": <id>}`, read by `categories-verify` and `categories-move`.

- [ ] **Step 1: Write the script**

Create `bin/categories-create-rooms` (mode 755):

```python
#!/usr/bin/env python3
"""Create the two programme rooms. Idempotent: it refuses to create a room whose name
already exists, so a re-run after a partial failure cannot produce a duplicate."""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/superpowers/plans/data/2026-09-11-rooms.json"

# permission_types: full=1, create_post=2, readonly=3 (CategoryGroup.permission_types).
# `Certificación` is 374 people — every member — so the AA room is separated from the
# plaza without anybody losing access relative to today.
ROOMS = [
    ("administracion_avanzada", "Administración Avanzada", "Certificación", "0088CC"),
    ("analitica", "Analítica de datos", "Analiza", "3AB54A"),
]


def existing_names():
    data = d.get("/categories.json?include_subcategories=true")

    def walk(nodes):
        for c in nodes:
            yield c["name"], c["id"]
            yield from walk(c.get("subcategory_list") or [])

    return dict(walk(data["category_list"]["categories"]))


def main():
    known = existing_names()
    rooms = json.loads(OUT.read_text()) if OUT.exists() else {}
    for key, name, group, color in ROOMS:
        if name in known:
            print(f"exists: {name} -> {known[name]}")
            rooms[key] = known[name]
            continue
        payload = [
            ("name", name),
            ("color", color),
            ("text_color", "FFFFFF"),
            ("minimum_required_tags", 0),
            (f"permissions[{group}]", 1),
        ]
        created = d.request("POST", "/categories.json", data=payload, write=True)
        rooms[key] = created["category"]["id"]
        print(f"created: {name} -> {rooms[key]} ({group} at permission 1)")
    OUT.write_text(json.dumps(rooms, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Create them**

```bash
set -a && source .env.local && set +a && ./bin/categories-create-rooms
```

Expected: two `created:` lines with fresh ids. **Record them** — they will be different on PROD. Each new category also gets an automatic definition topic, which `topic_count` does not count.

- [ ] **Step 3: Verify the walls landed**

```bash
set -a && source .env.local && set +a && python3 -c "
import json,pathlib,sys
sys.path.insert(0,'bin'); import _discourse as d
rooms=json.loads(pathlib.Path('docs/superpowers/plans/data/2026-09-11-rooms.json').read_text())
for key,group in (('administracion_avanzada','Certificación'),('analitica','Analiza')):
    c=d.category(rooms[key])
    perms={g['group_name']:g['permission_type'] for g in c.get('group_permissions') or []}
    assert c['read_restricted'], f'{key} is NOT restricted — the wall did not apply'
    assert perms.get(group)==1, f'{key} permissions are {perms}'
    assert set(perms) <= {group,'administradores','moderadores','esPublico'}, f'{key} opened to {perms}'
    assert c.get('minimum_required_tags')==0
    print(key, c['id'], c['name'], perms)
"
```

Expected: two lines, each restricted, its group at permission 1, no unexpected group. **A room that is not `read_restricted` is the failure that matters**: it means the wall silently did not apply and the room is open to everyone.

- [ ] **Step 4: Commit**

```bash
git add bin/categories-create-rooms docs/superpowers/plans/data/2026-09-11-rooms.json
git commit -m "feat(bin): create the two walled programme rooms

Idempotent by name, so a re-run after a partial failure cannot duplicate a
category. Records the assigned ids: they will differ on PROD."
```

---

### Task 6: The mover, proved on the smallest batch (18 → Noticias, 19 topics)

**Files:**
- Create: `bin/categories-move`
- Output: `docs/superpowers/plans/data/2026-09-11-move-log.json`

**Interfaces:**
- Consumes: `2026-09-11-move-decisions.json`, `2026-09-11-rooms.json`, `_discourse.request`.
- Produces: `./bin/categories-move <key> [--batch N]` where `<key>` is one of `to_news`, `to_plaza`, `to_aa_room_from_4`, `to_aa_room_from_5`; appends `{key, target, requested, changed, missing, errors}` to the move log and resumes from it.

- [ ] **Step 1: Write the mover**

Create `bin/categories-move` (mode 755):

```python
#!/usr/bin/env python3
"""Apply one approved move list, in batches, verifying by topic id.

Reads ONLY the human-authored decisions file. It has no access to the proposals, which
is the review gate expressed in code rather than in a promise.

`PUT /topics/bulk.json` answers with the ids it actually changed, and the bulk revision
runs with bypass_bump, so a move does not reflate the topic into /latest. Each move does
cost the topic its list thumbnail, permanently — verified harmless for these topics.
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "docs/superpowers/plans/data"
DECISIONS = DATA / "2026-09-11-move-decisions.json"
ROOMS = DATA / "2026-09-11-rooms.json"
LOG = DATA / "2026-09-11-move-log.json"

PLAZA = 5
NEWS = 4
KEYS = ("to_news", "to_plaza", "to_aa_room_from_4", "to_aa_room_from_5")


def destination(key):
    room = json.loads(ROOMS.read_text())["administracion_avanzada"]
    return {
        "to_news": NEWS,
        "to_plaza": PLAZA,
        "to_aa_room_from_4": room,
        "to_aa_room_from_5": room,
    }[key]


def main(key, batch_size):
    if key not in KEYS:
        raise SystemExit(f"unknown list {key!r}; expected one of {KEYS}")
    ids = json.loads(DECISIONS.read_text())[key]
    target = destination(key)
    log = json.loads(LOG.read_text()) if LOG.exists() else []
    done = {i for entry in log if entry["key"] == key for i in entry["changed"]}
    todo = [i for i in ids if i not in done]
    print(f"{key} -> category {target}: {len(todo)} to move ({len(done)} already done)")

    for start in range(0, len(todo), batch_size):
        chunk = todo[start : start + batch_size]
        payload = [("topic_ids[]", i) for i in chunk]
        payload += [("operation[type]", "change_category"), ("operation[category_id]", target)]
        result = d.request("PUT", "/topics/bulk.json", data=payload, write=True)
        changed = result.get("topic_ids") or []
        missing = sorted(set(chunk) - set(changed))
        log.append(
            {
                "key": key,
                "target": target,
                "requested": chunk,
                "changed": changed,
                "missing": missing,
                "errors": result.get("errors"),
            }
        )
        LOG.write_text(json.dumps(log, ensure_ascii=False, indent=1))
        print(
            f"  batch {start // batch_size}: requested {len(chunk)}, "
            f"changed {len(changed)}, missing {missing}"
        )
        if missing:
            raise SystemExit(
                "STOP: some topics did not move. Do not re-run blindly — read the errors "
                "in the log first. A re-run resumes from `changed`, so nothing is moved twice."
            )


if __name__ == "__main__":
    positional = [a for a in sys.argv[1:] if not a.startswith("--")]
    size = 50
    if "--batch" in sys.argv:
        size = int(sys.argv[sys.argv.index("--batch") + 1])
    main(positional[0], size)
```

- [ ] **Step 2: Move the 19 release notes**

```bash
set -a && source .env.local && set +a && ./bin/categories-move to_news
```

Expected: `to_news -> category 4: 19 to move (0 already done)` then `batch 0: requested 19, changed 19, missing []`.

This is the smallest list on purpose: it proves the mechanism, the id-level verification and the resumable log on the batch whose misclassification would cost least.

- [ ] **Step 3: Verify independently, by id, from both ends**

```bash
set -a && source .env.local && set +a && python3 -c "
import json,pathlib,sys
sys.path.insert(0,'bin'); import _discourse as d
moved=set(json.loads(pathlib.Path('docs/superpowers/plans/data/2026-09-11-move-decisions.json').read_text())['to_news'])
there=set(d.crawl_category(4)); gone=set(d.crawl_category(18))
assert moved <= there, f'not in Noticias: {sorted(moved-there)}'
assert not (moved & gone), f'still in Tengo una idea: {sorted(moved & gone)}'
print('all',len(moved),'release notes located in Noticias and absent from 18')
"
```

Expected: `all 19 release notes located in Noticias and absent from 18`. The API's own `topic_ids` response is not enough — this re-reads both listings, which is what catches a move that reported success and did not land.

- [ ] **Step 4: Commit**

```bash
git add bin/categories-move docs/superpowers/plans/data/2026-09-11-move-log.json
git commit -m "feat(bin): move approved topics in verified, resumable batches

Proved on the 19 release notes from 18 to Noticias. Reads only the decisions file
and verifies by topic id from both listings, not by count."
```

---

### Task 7: Empty category 4 of member posts (36)

**Files:**
- Append: `docs/superpowers/plans/data/2026-09-11-move-log.json`

**Interfaces:**
- Consumes: `bin/categories-move`.
- Produces: nothing new.

- [ ] **Step 1: Move the three community-life topics to the plaza**

```bash
set -a && source .env.local && set +a && ./bin/categories-move to_plaza
```

Expected: `batch 0: requested 3, changed 3, missing []`. This goes first: if the two category 4 lists ever overlapped, the mistake is visible while it is still three topics.

- [ ] **Step 2: Move the 33 consultations into the AA room**

```bash
set -a && source .env.local && set +a && ./bin/categories-move to_aa_room_from_4
```

Expected: `batch 0: requested 33, changed 33, missing []`.

- [ ] **Step 3: Verify Noticias now holds only staff communication**

```bash
set -a && source .env.local && set +a && python3 -c "
import json,pathlib,sys
sys.path.insert(0,'bin'); import _discourse as d
P=pathlib.Path('docs/superpowers/plans/data')
dec=json.loads((P/'2026-09-11-move-decisions.json').read_text())
rooms=json.loads((P/'2026-09-11-rooms.json').read_text())
news=set(d.crawl_category(4)); room=set(d.crawl_category(rooms['administracion_avanzada'])); plaza=set(d.crawl_category(5))
out=set(dec['to_plaza'])|set(dec['to_aa_room_from_4'])
assert not (news & out), f'still in Noticias: {sorted(news & out)}'
assert set(dec['to_aa_room_from_4']) <= room, 'consultations did not reach the room'
assert set(dec['to_plaza']) <= plaza, 'community-life topics did not reach the plaza'
print('Noticias:',len(news),'| AA room:',len(room),'| plaza:',len(plaza))
"
```

Expected: `Noticias: 103` (120 − 36 + 19), `AA room: 33`, `plaza: 369` (366 + 3, before Task 8 empties it).

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/data/2026-09-11-move-log.json
git commit -m "chore(data): log the category 4 split into the AA room and the plaza"
```

---

### Task 8: Empty the plaza of consultations (~201)

**Files:**
- Append: `docs/superpowers/plans/data/2026-09-11-move-log.json`

**Interfaces:**
- Consumes: `bin/categories-move`.
- Produces: nothing new.

- [ ] **Step 1: Move in batches of 50**

```bash
set -a && source .env.local && set +a && ./bin/categories-move to_aa_room_from_5 --batch 50
```

Expected: five batches, each `missing []`, the last one short. Batches of 50 keep each `PUT` reviewable; `MAX_BULK_TOPIC_IDS` is 1 000, so the limit is not the constraint — reviewability is. If any batch reports `missing`, the script stops and the log records exactly where.

- [ ] **Step 2: Verify the plaza holds only announcements and the approved exceptions**

```bash
set -a && source .env.local && set +a && python3 -c "
import json,pathlib,re,sys
sys.path.insert(0,'bin'); import _discourse as d
P=pathlib.Path('docs/superpowers/plans/data')
dec=json.loads((P/'2026-09-11-move-decisions.json').read_text())
rooms=json.loads((P/'2026-09-11-rooms.json').read_text())
CER=re.compile(r'nuev[oa]s?\s+(?:\w+\s+){0,2}(alumn|compañer|miembr|certificad)|certificad[oa]s?\s*[·\-:]|enhorabuena|bienvenid',re.I)
allowed=set(dec['stays_in_plaza'])|set(dec['to_plaza'])
plaza=d.crawl_category(5); room=set(d.crawl_category(rooms['administracion_avanzada']))
strays=sorted(t['id'] for t in plaza.values() if 'poster-evf' not in d.tag_names(t) and not CER.search(t['title']) and t['id'] not in allowed)
assert not strays, f'unapproved topics left in the plaza: {strays}'
assert set(dec['to_aa_room_from_5']) <= room, 'some consultations never arrived'
assert not (set(dec['to_aa_room_from_5']) & set(plaza)), 'some consultations are in both places'
print('plaza:',len(plaza),'| AA room:',len(room))
"
```

Expected: `plaza: 168 | AA room: 234`.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/plans/data/2026-09-11-move-log.json
git commit -m "chore(data): log the plaza's consultations moving into the AA room"
```

---

### Task 9: Settings — the tag toll and the inherited template

**Files:**
- Create: `bin/categories-settings`

**Interfaces:**
- Consumes: `_discourse.request`, `_discourse.category`.
- Produces: nothing read by later tasks.

- [ ] **Step 1: Write the script**

Create `bin/categories-settings` (mode 755):

```python
#!/usr/bin/env python3
"""Drop the two-tag toll on the conversational categories and delete category 5's
inherited topic_template.

`PUT /categories/<id>.json` replaces the record, so a field not resent can revert to a
default. This reads each category first and sends it back with only the intended fields
changed — it never composes a payload from scratch.

Out of scope and deliberately untouched: auto_close_hours (720) and
solved_topics_auto_close_hours (1), deferred to after the production migration.
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
ROOMS = ROOT / "docs/superpowers/plans/data/2026-09-11-rooms.json"

CONVERSATIONAL = [4, 5, 14, 18]


def update(cid, changes):
    c = d.category(cid)
    base = {
        "name": c["name"],
        "color": c["color"],
        "text_color": c["text_color"],
        "slug": c["slug"],
        "auto_close_hours": c.get("auto_close_hours") or "",
        "auto_close_based_on_last_post": str(bool(c.get("auto_close_based_on_last_post"))).lower(),
        "minimum_required_tags": c.get("minimum_required_tags") or 0,
        "topic_template": c.get("topic_template") or "",
    }
    base.update(changes)
    payload = list(base.items())
    for g in c.get("group_permissions") or []:
        payload.append((f"permissions[{g['group_name']}]", g["permission_type"]))
    d.request("PUT", f"/categories/{cid}.json", data=payload, write=True)
    after = d.category(cid)
    print(
        f"  {cid} {after['name']}: min_tags={after.get('minimum_required_tags')} "
        f"template={'yes' if (after.get('topic_template') or '').strip() else 'no'} "
        f"auto_close={after.get('auto_close_hours')}"
    )


def main():
    rooms = json.loads(ROOMS.read_text())
    for cid in CONVERSATIONAL + list(rooms.values()):
        changes = {"minimum_required_tags": 0}
        if cid == 5:
            changes["topic_template"] = ""
        update(cid, changes)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Apply**

```bash
set -a && source .env.local && set +a && ./bin/categories-settings
```

Expected: six lines, each `min_tags=0`, category 5 with `template=no`, and **`auto_close=720.0` unchanged** on 4, 5, 14 and 18. An `auto_close=None` in that output means the resend dropped a field and the deferred decision was executed by accident — restore it from `2026-09-11-prior-state.json` before continuing.

- [ ] **Step 3: Verify nothing else moved**

```bash
set -a && source .env.local && set +a && python3 -c "
import json,pathlib,sys
sys.path.insert(0,'bin'); import _discourse as d
prior=json.loads(pathlib.Path('docs/superpowers/plans/data/2026-09-11-prior-state.json').read_text())['categories']
for cid in ('4','5','14','18','73','75','85','59','78','3'):
    now=d.category(int(cid)); was=prior[cid]
    assert now['name']==was['name'], f'{cid} renamed'
    assert (now.get('auto_close_hours') or None)==(was.get('auto_close_hours') or None), f'{cid} auto_close changed'
    perms={g['group_name']:g['permission_type'] for g in now.get('group_permissions') or []}
    assert perms==was['permissions'], f'{cid} permissions changed: {was[\"permissions\"]} -> {perms}'
print('names, auto_close and permissions unchanged on all ten')
"
```

Expected: `names, auto_close and permissions unchanged on all ten`. This is the guard against `PUT /categories/<id>.json` quietly resetting a field nobody meant to touch.

- [ ] **Step 4: Commit**

```bash
git add bin/categories-settings
git commit -m "feat(bin): drop the two-tag toll and category 5's inherited template

The template was 457 characters of 'Proyectos piloto' text about early access to
in-development versions, inherited when that category was dissolved in August.
auto_close stays untouched: deferred to after the production migration."
```

---

### Task 10: Green the verifier, check the walls by hand, record

**Files:**
- Modify: `docs/superpowers/specs/2026-09-11-reorganizacion-generos-design.md`
- Modify: `docs/superpowers/specs/2026-09-06-migracion-prod-design.md`
- Modify: `CLAUDE.local.md`

**Interfaces:**
- Consumes: everything above.
- Produces: the executed record.

- [ ] **Step 1: Run the verifier and require green**

```bash
set -a && source .env.local && set +a && ./bin/categories-verify; echo "exit=$?"
```

Expected: `OK: genre reorganisation target state holds`, `exit=0`. Every failure it prints is a real divergence — fix the instance, not the assertion.

- [ ] **Step 2: Run the tag verifier, which must still be green**

```bash
set -a && source .env.local && set +a && ./bin/tags-verify
```

Expected: green. This work touches no tags; red here means a move or a settings write altered tagging.

- [ ] **Step 3: Check the walls with a non-admin account**

The half neither CI nor the API can measure: `/c/<id>/show.json` answers with the permissions of the key's own user, an administrator who reads everything. Sign in to PRE as a member of `Certificación` who is **not** in `Analiza` and confirm:

1. **Administración Avanzada** is listed, readable and writable.
2. **Analítica de datos** is not listed, and its URL is not reachable.
3. `/` still shows three lanes and the four bento cards.
4. "Nueva publicación" in the band opens the composer on category 5, the plaza.
5. Opening a new topic no longer demands two tags.

- [ ] **Step 4: Record what was actually executed**

Amend the spec with an *"As executed"* section: the two assigned category ids, the real count of each list, every departure from this plan — August's phase 4 had six and recorded each — and any topic that failed to move. Amend `2026-09-06-migracion-prod-design.md` to state that its Phase 2 is void and why. Update `CLAUDE.local.md`'s category census, permission table and pending list.

- [ ] **Step 5: Commit and open the PR**

```bash
git add docs/ CLAUDE.local.md
git commit -m "docs: record the genre reorganisation as executed

Final category ids, real counts and every departure from the plan. Voids Phase 2
of the PROD migration spec."
git push -u origin feat/genre-reorganisation
gh pr create --title "Genre reorganisation: one plaza, three walled rooms" \
  --body "Executes docs/superpowers/specs/2026-09-11-reorganizacion-generos-design.md on PRE. Two categories created, ~256 topics moved, the two-tag toll dropped and category 5's inherited template deleted. bin/categories-verify is green and re-runnable; the walls were checked from a non-admin account, which is the half the API cannot measure."
```

---

## Self-review

**Spec coverage.** Phase 0 → Task 1. Phase 1 (derive lists) → Tasks 3 and 4. Phase 2 (create rooms) → Task 5. Phase 3 (move, verified by id) → Tasks 6, 7 and 8. Phase 4 (settings) → Task 9. Phase 5 (record) → Task 10. Verification points 1–6 → Task 2 written red, then Task 10 steps 1–3. The spec's out-of-scope items are asserted as *unchanged* by `categories-verify` and by Task 9 step 3, so leaving them alone is tested rather than merely intended.

**Known gaps, stated rather than hidden.**

- `categories-verify` reads with an administrator's key, so it asserts which permission rows exist, not what a member sees. Task 10 step 3 is the only check of that, and it is manual. This is the same gap the `canCreateTopic` and `hero_default_category_id` guards already carry.
- `_original_author` matches the substring `original`, which both the Spanish and English poster descriptions contain. A locale change would silently make every category 4 topic look member-authored. Task 1 step 4 asserts no topic has a null author, which is what catches it before the rule is ever used.
- The rooms are created with a colour picked here, not from the brand tokens. If the palette matters, set it in admin afterwards; `categories-verify` does not assert colour.
- **`CEREMONIAL` is duplicated in three places** — `categories-propose`, `categories-verify` and Task 8's inline check — because `categories-verify` must be readable on its own as the standing assertion. They were validated together and must be changed together; a divergence lets the verifier pass on a plaza the proposer would have emptied.

**Both patterns were run against the real corpus before this plan was finished**, which is how their two defects were found rather than discovered mid-execution. `CEREMONIAL` originally missed *"Nueva Certificado CAAG 31 Xavier García"* — a real announcement, saved only by its tag; it now catches all 60 tagged announcements by text alone, plus 100 untagged ones. `RELEASE_NOTE` originally returned 22 candidates instead of 19, admitting *"Seminario de novedades, martes 15 de julio"* and — the trap worth remembering — two topics about **conversión**, which contains *versión*. Requiring a version-like number fixed all three, and the eight near-misses it now excludes were each read and confirmed to be proposals.

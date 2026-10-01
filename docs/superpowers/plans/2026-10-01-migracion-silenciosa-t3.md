# PROD Migration T3 — Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Tasks 2–4 are tooling and may run in any sitting. Tasks 1 and 5–9 write to an instance; each is one sitting, run by Ricardo's go. Task 8 (the flip) is the only step members see.**

**Goal:** Put Espublico Theme on PROD — measured first, installed hidden, its ten settings resolving against PROD's real data, the chrome that does not travel applied, a non-admin session signed off — then make it the default, keeping a one-week rollback.

**Architecture:** Two pure modules judge, three scripts act. `bin/_theme_check.py` decides whether an install holds (no I/O, self-test inside). `bin/theme-verify` gathers the live state and asks it; `bin/theme-apply` installs the theme hidden and sets the instance overrides; `bin/chrome-apply` writes the sidebar section and the login texts. Every writer is a dry run unless `--write`, and reads back what it wrote. A committed **expectation file per instance** (`docs/superpowers/plans/data/2026-10-01-<inst>-theme-expect.json`) is both the intent and the oracle — the same shape as T2's target map.

**Tech Stack:** Discourse admin API through `bin/_discourse.py` (`DISCOURSE_INSTANCE=PRE|PROD`, Global keys); Python 3.9 stdlib; `curl`; `git ls-remote`.

**Spec:** `docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md` (binding), section *T3 — The launch*, plus *Success criteria → T3* and *Rollback → T3*. Roadmap: `docs/superpowers/plans/2026-09-15-migracion-prod-hoja-de-ruta.md`, S9–S14.

## Global Constraints

- **The leak is measured on PRE before anything is installed on PROD** (Task 1). If a `theme_site_settings` row acts while its theme is not active, `theme_site_settings` leaves `about.json` until the flip.
- **The theme enters PROD hidden** — not default, not user-selectable — and is checked with `?preview_theme_id=` before the flip.
- **Ids after the restore (~2026-07-27) are not shared.** PROD rooms are **90 · 91 · 92**; **PROD 89 is "Anuncios"**, so `header_room_category_ids` on PROD is never the default `89|90|91`. PROD 93/94 ≠ PRE 93/94.
- **User fields 2 and 4 are verified by name, every run** — field 1 is a NIF and 3 a CIF, both `show_on_profile: false`, and an administrator's session receives them. A field id that resolves to anything but `Nombre y tipo de entidad` / `Cargo`, or to a hidden field, stops the line.
- **A tag setting that names a missing or empty tag empties its lane in silence.** Every tag setting must resolve to a tag with topics before the flip.
- **Protected topics** `/t/2690` (89) and `/t/2673` (59): no write to them. `/t/2683` already moved in T2. Any topic write (Task 5's `idea-registrada`) checks `wiki` first — a tag write on a wiki first post bumps it.
- **Production. When an outcome differs from the prediction, STOP and report; do not improvise.**
- **Rate limit ~1 req/s; credentials only via `source .env.local` in the same invocation; never print a key.**
- **Nothing is announced** before the flip. The flip itself is Ricardo's explicit go.
- **After the flip every merge to `main` reaches PROD**: watch the four required CI checks go green before merging, always. `gh pr merge --auto` does not wait from this account.
- **Rollback is uninstalling** (or re-defaulting the previous theme). Themes 1 "Gestiona avanza" and 2 "Air Theme" stay installed for one week after the flip.

## Measured 2026-10-01 (inputs to this plan)

- **PROD runs Discourse 2026.10.0-latest** (`028d988`), above the theme's `minimum_discourse_version` 2026.7.0. **It is in staff-writes-only mode** (`isStaffWritesOnly: true`), set by Ricardo for the migration.
- **PROD's default theme is "Gestiona avanza" (1)**, not Air (2) as measured on 2026-09-14. Components on PROD: 3, 4, 5, 6, 7, 9, 12. Espublico Theme is not installed.
- **`enable_welcome_banner` and `search_experience` are themeable** on both instances. PROD theme 1 holds `false` / `search_icon` — exactly what our `about.json` declares — while theme 2 holds `true` / `search_icon`. The values are per theme already, so **a leak, if it exists, could not change PROD's behaviour today**. Task 1 is a confirmation, not a gate that can block.
- **User fields on PROD, read by name**: 1 NIF (hidden), 2 Nombre y tipo de entidad, 3 CIF Entidad (hidden), 4 Cargo — identical to PRE.
- **Tags on PROD**: `podcast` 6, `newsletter` 30, `nuevas-versiones` 14. *Re-measured after Ricardo's F1/F2, same day:* `idea-registrada` (339) 10 topics in 18, in no tag group; `nueva-version-gestiona` (340) a synonym of `nuevas-versiones`. On PRE, `idea-registrada` (9) sits in tag group 14 "Estado de idea" with permissions `{staff: 1, everyone: 3}` (staff apply, everyone sees); `nueva-version-gestiona` (39) carries `nuevas-versiones` as a synonym.
- **Sidebar section 3 exists on both** (id pre-dates the restore). PRE: "Recursos de apoyo", public, five links. **PROD: "Herramientas", private**, two links (`/c/documentacion-analiza/73`, `/c/doc-developers/75`, both 301 to the new slugs). PROD's "Community" section carries a **Wiki** link to `/c/documentacion-analiza/74` — category 74 exists on neither instance.
- **Login texts on PROD are core's defaults**; PRE overrides all three (values in Task 4).
- **PRE theme 15**: default, not user-selectable, color schemes 28/29, one child component "Sidebar Theme Toggle" (17), no setting overrides. `academy_url` is no longer a theme setting (#129) — it lives in the sidebar links.

## Decisions for Ricardo (asked before the task that needs them)

| # | Question | Recommendation | Needed by |
|---|---|---|---|
| F1 | Which PROD topics get `idea-registrada`? | **Done by Ricardo** before 2026-10-01: tag 339, **10 topics, all in 18**. It sits in **no tag group**, so any member can apply it — Task 5 Step 1 still creates "Estado de idea" | — |
| F2 | `nueva-version-gestiona` on PROD | **Done by Ricardo, inverted**: `nueva-version-gestiona` (340) is a *synonym* of `nuevas-versiones` (61, 14 topics). A synonym's listing answers **301 to `/tag/nuevas-versiones/61.json`**, not the `l/latest` listing the card fetches, so **PROD sets `highlights_news_tag` = `nuevas-versiones`** as an instance override (expectation file) — no tag write | — |
| F3 | Child components for the theme on PROD | **None at first**, matching PRE minus "Sidebar Theme Toggle" (not installed on PROD). Theme 1's components stay on theme 1 | Task 8 |
| F4 | The dead **Wiki** link (`/c/documentacion-analiza/74`) in PROD's Community section | **Done 2026-10-01** by hand (see Task 4's note on `_destroy`). `DROP` stays in `chrome-apply` so a re-run asserts it | — |

## Review Focus

- **The theme pulls a compat branch or a stale commit.** `remote_compat_ref` non-null or `local_version` ≠ `main` must fail the verifier, not pass it — Task 2 self-test cases `compat ref` and `behind main`.
- **A tag setting naming a tag that exists with zero topics.** Must fail as "has no topics", distinct from "does not exist" — Task 2 self-test cases `empty tag` and `missing tag`.
- **A member-field setting resolving to a hidden field** (the NIF has id 1, one keystroke from 2). Must fail on name *and* on `show_on_profile` — Task 2 self-test cases `hidden field` and `wrong field name`.
- **The sidebar update dropping or reordering existing links.** The whole array is sent with ids; a link the script does not own must survive with its id, in place — Task 4 self-test case `keeps foreign links in order`.
- **A room id that exists but is not a room** (PROD 89 "Anuncios" is top level). Must fail — Task 2 self-test case `room not under 5`.

---

## File structure

| File | Responsibility |
|---|---|
| `bin/_theme_check.py` *(create)* | Pure judgement: `problems(state, expect)`, `setting_changes(current, wanted)`. Self-test on `__main__` |
| `bin/_discourse.py` *(modify)* | `theme_id_by_remote(url)` |
| `bin/theme-verify` *(create)* | Gather live state, print problems, exit 1 on any. `--flipped` expects the theme to be default |
| `bin/theme-apply` *(create)* | Import hidden if absent; set the expectation's settings; read back. Dry run unless `--write` |
| `bin/chrome-apply` *(create)* | Sidebar section 3 and the three login texts, per instance. Dry run unless `--write`. `--self-test` |
| `docs/superpowers/plans/data/2026-10-01-pre-theme-expect.json` | PRE's expectation (the theme as it runs there) |
| `docs/superpowers/plans/data/2026-10-01-prod-theme-expect.json` | PROD's expectation |

---

### Task 1: S9 — measure the `theme_site_settings` leak on PRE

**Files:** none; record in the spec.

The probe is a throwaway theme with both rows set to the **opposite** of PRE's live values (`enable_welcome_banner: true`, `search_experience: search_field`). Three readings: the admin site-settings listing, the preloaded `themeSiteSettingOverrides` an anonymous visitor gets on `/login`, and the same an admin gets on `/`. **Positive control**: the same admin read with `?preview_theme_id=<probe>` must show the probe's values — otherwise the probe proves nothing.

- [ ] **Step 1: Baseline**

```bash
cd /Users/ricardoespublico/Documents/proyectos-espublico/theme-discourse
cat > "$TMPDIR/leak_read.py" <<'EOF'
import json, re, sys, urllib.request, os
sys.path.insert(0, "bin"); import _discourse as d
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/140.0 Safari/537.36"
KEYS = ("enable_welcome_banner", "search_experience")
def preload(path, admin):
    h = {"User-Agent": UA}
    if admin:
        h.update({"Api-Key": d._key(True), "Api-Username": d._user()})
    html = urllib.request.urlopen(urllib.request.Request(d._url() + path, headers=h)).read().decode()
    # Themeable settings are not in `siteSettings`: the client gets them per active theme
    # in `themeSiteSettingOverrides` (measured on PRE 2026-10-01). Preload values arrive
    # JSON-encoded.
    raw = json.loads(re.search(r'preloaded">(\{.*?\})</script>', html, re.S).group(1))["themeSiteSettingOverrides"]
    s = json.loads(raw) if isinstance(raw, str) else raw
    return {k: s.get(k) for k in KEYS}
admin_list = {x["setting"]: x["value"] for x in d.get("/admin/site_settings.json", elevated=True)["site_settings"] if x["setting"] in KEYS}
probe = sys.argv[1] if len(sys.argv) > 1 else None
print("admin listing ", admin_list)
print("anon /login   ", preload("/login", False))
print("admin /       ", preload("/", True))
if probe:
    print("admin preview ", preload(f"/?preview_theme_id={probe}", True))
EOF
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PRE python3 "$TMPDIR/leak_read.py"
```

Expected: every reading `enable_welcome_banner` false and `search_experience` `search_icon` (theme 15's rows). A different baseline is a STOP.

- [ ] **Step 2: Create the probe theme, not default, with the two opposite rows**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PRE python3 - <<'EOF'
import sys; sys.path.insert(0, "bin"); import _discourse as d
t = d.request("POST", "/admin/themes.json", data=[("theme[name]", "t3-leak-probe")], elevated=True)["theme"]
tid = t["id"]
for name, value in (("enable_welcome_banner", "true"), ("search_experience", "search_field")):
    d.request("PUT", f"/admin/themes/{tid}/site-setting", data=[("name", name), ("value", value)], elevated=True)
back = d.get(f"/admin/themes/{tid}.json", elevated=True)["theme"]
print("probe", tid, "default", back.get("default"), {s["setting"]: s["value"] for s in back["themeable_site_settings"]})
EOF
```

Expected: `probe <id> default False {'enable_welcome_banner': 'true', 'search_experience': 'search_field'}`. Note `<id>`.

- [ ] **Step 3: Read all four views**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PRE python3 "$TMPDIR/leak_read.py" <id>
```

Expected, no leak: the first three lines identical to the baseline; the preview line `{'enable_welcome_banner': True, 'search_experience': 'search_field'}` (positive control). **If the preview line matches the baseline, the probe failed — STOP.** If any of the first three moved, **the leak exists**: record it, and Task 3's PROD expectation is unaffected (PROD's default theme already holds our values) but the finding goes to Ricardo before Task 5.

- [ ] **Step 4: Delete the probe and re-read**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PRE python3 -c "
import sys; sys.path.insert(0, 'bin'); import _discourse as d
d.request('DELETE', '/admin/themes/<id>.json', elevated=True)
print([t['id'] for t in d.get('/admin/themes.json', elevated=True)['themes'] if t['name'] == 't3-leak-probe'])"
DISCOURSE_INSTANCE=PRE python3 "$TMPDIR/leak_read.py"
rm -f "$TMPDIR/leak_read.py"
```

Expected: `[]`, and the three readings equal the baseline.

- [ ] **Step 5: Record and commit**

Append `### T3 · S9 — the theme_site_settings leak, measured on PRE` under the spec's *As executed*: probe id, the four readings, verdict.

```bash
git add docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "docs(prod): T3 S9 measures the theme_site_settings leak on PRE"
```

---

### Task 2: The judgement module and the verifier

**Files:**
- Create: `bin/_theme_check.py`, `bin/theme-verify`, `docs/superpowers/plans/data/2026-10-01-pre-theme-expect.json`, `docs/superpowers/plans/data/2026-10-01-prod-theme-expect.json`
- Modify: `bin/_discourse.py` (add `theme_id_by_remote`)

**Interfaces:**
- Produces: `_theme_check.problems(state: dict, expect: dict) -> list[str]`; `_theme_check.setting_changes(current: dict, wanted: dict) -> dict`; constants `CATEGORY_SETTINGS`, `TAG_SETTINGS`, `FIELD_SETTINGS`, `ROOMS_SETTING`; `_discourse.theme_id_by_remote(url: str) -> int | None`; expectation files with keys `remote_url, default, rooms_parent, settings, site_settings, user_fields`.
- `state` shape: `{"main_sha": str, "theme": None | {"id", "default": bool, "remote_url", "remote_compat_ref", "local_version", "settings": {name: value}, "site_settings": {name: value}}, "categories": {cid: None | {"parent": int|None, "topic_count": int}}, "tags": {name: None | int}, "user_fields": {id: {"name": str, "show_on_profile": bool}}}`.

- [ ] **Step 1: Write the self-test first**

`bin/_theme_check.py`, test half only:

```python
#!/usr/bin/env python3
"""Pure judgement of a theme install. No I/O: theme-verify gathers state, this decides.

Every check here exists because its failure is silent on the instance: a missing tag or a
dead category id empties a homepage lane with a 200 and no error, and a member-field id one
off reads a national ID onto the front page.
"""
import copy

CATEGORY_SETTINGS = ("events_category_id", "ideas_category_id", "hero_default_category_id")
TAG_SETTINGS = ("ideas_tag", "highlights_podcast_tag", "highlights_newsletter_tag", "highlights_news_tag")
FIELD_SETTINGS = ("highlights_member_entity_field_id", "highlights_member_role_field_id")
ROOMS_SETTING = "header_room_category_ids"


def setting_changes(current, wanted):
    raise NotImplementedError


def problems(state, expect):
    raise NotImplementedError


def _good():
    expect = {
        "remote_url": "https://github.com/gestionatools-org/ddm-discourse-theme.git",
        "default": False,
        "rooms_parent": 5,
        "settings": {"header_room_category_ids": "90|91|92"},
        "site_settings": {"enable_welcome_banner": "false", "search_experience": "search_icon"},
        "user_fields": {
            "highlights_member_entity_field_id": "Nombre y tipo de entidad",
            "highlights_member_role_field_id": "Cargo",
        },
    }
    state = {
        "main_sha": "a" * 40,
        "theme": {
            "id": 20, "default": False, "remote_url": expect["remote_url"],
            "remote_compat_ref": None, "local_version": "a" * 40,
            "settings": {
                "events_category_id": 59, "ideas_category_id": 18, "hero_default_category_id": 5,
                "header_room_category_ids": "90|91|92",
                "ideas_tag": "idea-registrada", "highlights_podcast_tag": "podcast",
                "highlights_newsletter_tag": "newsletter", "highlights_news_tag": "nueva-version-gestiona",
                "highlights_member_entity_field_id": 2, "highlights_member_role_field_id": 4,
            },
            "site_settings": {"enable_welcome_banner": "false", "search_experience": "search_icon"},
        },
        "categories": {
            59: {"parent": None, "topic_count": 50}, 18: {"parent": None, "topic_count": 445},
            5: {"parent": None, "topic_count": 169}, 90: {"parent": 5, "topic_count": 0},
            91: {"parent": 5, "topic_count": 0}, 92: {"parent": 5, "topic_count": 0},
        },
        "tags": {"idea-registrada": 10, "podcast": 6, "newsletter": 30, "nueva-version-gestiona": 14},
        "user_fields": {
            1: {"name": "NIF", "show_on_profile": False},
            2: {"name": "Nombre y tipo de entidad", "show_on_profile": True},
            3: {"name": "CIF Entidad", "show_on_profile": False},
            4: {"name": "Cargo", "show_on_profile": True},
        },
    }
    return state, expect


def self_test():
    state, expect = _good()
    assert problems(state, expect) == [], problems(state, expect)

    def case(label, mutate, needle):
        s, e = copy.deepcopy(state), copy.deepcopy(expect)
        mutate(s, e)
        found = problems(s, e)
        assert any(needle in p for p in found), f"{label}: {needle!r} not in {found}"

    case("not installed", lambda s, e: s.update(theme=None), "theme not installed")
    case("compat ref", lambda s, e: s["theme"].update(remote_compat_ref="d-compat/2026.10"), "following d-compat/2026.10")
    case("behind main", lambda s, e: s["theme"].update(local_version="b" * 40), "is not main")
    case("wrong remote", lambda s, e: s["theme"].update(remote_url="https://example.com/x.git"), "remote_url")
    case("default too early", lambda s, e: s["theme"].update(default=True), "default is True")
    case("rooms default", lambda s, e: s["theme"]["settings"].update(header_room_category_ids="89|90|91"), "header_room_category_ids is")
    case("room not under 5", lambda s, e: (s["theme"]["settings"].update(header_room_category_ids="89|90|91"),
                                            e["settings"].update(header_room_category_ids="89|90|91"),
                                            s["categories"].update({89: {"parent": None, "topic_count": 1}})),
         "89 is not a room under 5")
    case("site setting", lambda s, e: s["theme"]["site_settings"].update(enable_welcome_banner="true"), "enable_welcome_banner")
    case("missing category", lambda s, e: s["categories"].update({59: None}), "events_category_id 59 does not exist")
    case("nested category", lambda s, e: s["categories"].update({18: {"parent": 5, "topic_count": 445}}), "ideas_category_id 18 is not top level")
    case("empty category", lambda s, e: s["categories"].update({5: {"parent": None, "topic_count": 0}}), "hero_default_category_id 5 has no topics")
    case("missing tag", lambda s, e: s["tags"].update({"idea-registrada": None}), "ideas_tag 'idea-registrada' does not exist")
    case("empty tag", lambda s, e: s["tags"].update({"nueva-version-gestiona": 0}), "highlights_news_tag 'nueva-version-gestiona' has no topics")
    case("hidden field", lambda s, e: s["theme"]["settings"].update(highlights_member_entity_field_id=1), "field 1")
    case("wrong field name", lambda s, e: s["user_fields"].update({4: {"name": "Puesto", "show_on_profile": True}}), "field 4")

    # An emptied tag setting and a zeroed field setting are the documented "drop it" values.
    s = copy.deepcopy(state)
    s["theme"]["settings"].update(highlights_news_tag="", highlights_member_role_field_id=0)
    assert problems(s, expect) == [], problems(s, expect)
    assert setting_changes({"a": 1, "b": "x"}, {"a": "1", "b": "y", "c": "z"}) == {"b": "y", "c": "z"}
    print("self-test OK: 18 checks")


if __name__ == "__main__":
    self_test()
```

- [ ] **Step 2: Run it and watch it fail**

Run: `python3 bin/_theme_check.py`
Expected: `NotImplementedError` from `problems`.

- [ ] **Step 3: Implement the two functions**

Replace the two `raise NotImplementedError` bodies:

```python
def setting_changes(current, wanted):
    """{name: wanted value} for every wanted setting whose current value differs.

    Compared as strings: the API returns integers for integer settings and strings for the
    rest, and an expectation file cannot tell the two apart.
    """
    return {k: v for k, v in wanted.items() if str(current.get(k)) != str(v)}


def problems(state, expect):
    theme = state.get("theme")
    if theme is None:
        return ["theme not installed"]
    out = []
    if theme["remote_url"] != expect["remote_url"]:
        out.append(f"remote_url is {theme['remote_url']!r}, expected {expect['remote_url']!r}")
    if theme["remote_compat_ref"]:
        out.append(f"following {theme['remote_compat_ref']}, not main")
    if theme["local_version"] != state["main_sha"]:
        out.append(f"local_version {theme['local_version'][:7]} is not main {state['main_sha'][:7]}")
    if theme["default"] != expect["default"]:
        out.append(f"default is {theme['default']}, expected {expect['default']}")
    settings = theme["settings"]
    for name, value in setting_changes(settings, expect["settings"]).items():
        out.append(f"setting {name} is {settings.get(name)!r}, expected {value!r}")
    for name, value in setting_changes(theme["site_settings"], expect["site_settings"]).items():
        out.append(f"theme site setting {name} is {theme['site_settings'].get(name)!r}, expected {value!r}")

    cats = state["categories"]
    for name in CATEGORY_SETTINGS:
        cid = int(settings[name])
        c = cats.get(cid)
        if c is None:
            out.append(f"{name} {cid} does not exist")
        elif c["parent"] is not None:
            out.append(f"{name} {cid} is not top level")
        elif not c["topic_count"]:
            out.append(f"{name} {cid} has no topics")
    for cid in (int(x) for x in str(settings[ROOMS_SETTING]).split("|") if x):
        c = cats.get(cid)
        if c is None or c["parent"] != expect["rooms_parent"]:
            out.append(f"{ROOMS_SETTING}: {cid} is not a room under {expect['rooms_parent']}")

    for name in TAG_SETTINGS:
        tag = settings[name]
        if not tag:
            continue
        count = state["tags"].get(tag)
        if count is None:
            out.append(f"{name} {tag!r} does not exist")
        elif count == 0:
            out.append(f"{name} {tag!r} has no topics")

    for name in FIELD_SETTINGS:
        fid = int(settings[name])
        if fid == 0:
            continue
        field = state["user_fields"].get(fid)
        wanted = expect["user_fields"][name]
        if field is None or field["name"] != wanted or not field["show_on_profile"]:
            out.append(f"{name}: field {fid} is {field!r}, expected visible {wanted!r}")
    return out
```

- [ ] **Step 4: Run the self-test**

Run: `python3 bin/_theme_check.py`
Expected: `self-test OK: 18 checks`

- [ ] **Step 5: The two expectation files**

`docs/superpowers/plans/data/2026-10-01-prod-theme-expect.json`:

```json
{
 "remote_url": "https://github.com/gestionatools-org/ddm-discourse-theme.git",
 "default": false,
 "rooms_parent": 5,
 "settings": {"header_room_category_ids": "90|91|92", "highlights_news_tag": "nuevas-versiones"},
 "site_settings": {"enable_welcome_banner": "false", "search_experience": "search_icon"},
 "user_fields": {
  "highlights_member_entity_field_id": "Nombre y tipo de entidad",
  "highlights_member_role_field_id": "Cargo"
 }
}
```

`docs/superpowers/plans/data/2026-10-01-pre-theme-expect.json` — identical except `"default": true` and `"settings": {"header_room_category_ids": "89|90|91"}`.

- [ ] **Step 6: `theme_id_by_remote` in `bin/_discourse.py`**, after `category()`:

```python
def theme_id_by_remote(url):
    """The id of the installed theme pulled from `url`, or None.

    By remote, not by name: a theme can be renamed in admin, and two installs of the same
    repository were what PRE carried until 2026-08-16.
    """
    for theme in get("/admin/themes.json", elevated=True)["themes"]:
        if (theme.get("remote_theme") or {}).get("remote_url") == url:
            return theme["id"]
    return None
```

- [ ] **Step 7: `bin/theme-verify`**

```python
#!/usr/bin/env python3
"""Assert the theme's install on an instance against its expectation file. Read-only.

    DISCOURSE_INSTANCE=PROD bin/theme-verify            # before the flip: hidden
    DISCOURSE_INSTANCE=PROD bin/theme-verify --flipped  # after: default

`main` is read from the remote, not the local checkout, because what the instance pulls is
GitHub's main — a stale local branch would make a current install look behind.
"""
import json
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402
import _theme_check as tc  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXPECT = ROOT / "docs/superpowers/plans/data/2026-10-01-{}-theme-expect.json"


def main_sha():
    out = subprocess.run(["git", "ls-remote", "origin", "refs/heads/main"], capture_output=True, text=True, check=True)
    return out.stdout.split()[0]


def gather(expect):
    state = {"main_sha": main_sha(), "categories": {}, "tags": {}, "user_fields": {}, "theme": None}
    tid = d.theme_id_by_remote(expect["remote_url"])
    if tid is None:
        return state
    t = d.get(f"/admin/themes/{tid}.json", elevated=True)["theme"]
    rt = t["remote_theme"]
    settings = {s["setting"]: s["value"] for s in t["settings"]}
    state["theme"] = {
        "id": tid,
        "default": bool(t.get("default")),
        "remote_url": rt["remote_url"],
        "remote_compat_ref": rt.get("remote_compat_ref"),
        "local_version": rt.get("local_version") or "",
        "settings": settings,
        "site_settings": {s["setting"]: s["value"] for s in t.get("themeable_site_settings") or []},
    }
    ids = [int(settings[n]) for n in tc.CATEGORY_SETTINGS]
    ids += [int(x) for x in str(settings[tc.ROOMS_SETTING]).split("|") if x]
    for cid in ids:
        c = d.request("GET", f"/c/{cid}/show.json", elevated=True, allow_404=True)
        state["categories"][cid] = None if c is None else {
            "parent": c["category"].get("parent_category_id"),
            "topic_count": c["category"].get("topic_count"),
        }
    for name in tc.TAG_SETTINGS:
        tag = settings[name]
        if tag:
            info = d.request("GET", f"/tag/{tag}/info.json", elevated=True, allow_404=True)
            state["tags"][tag] = None if info is None else info["tag_info"]["topic_count"]
    for f in d.get("/site.json", elevated=True).get("user_fields", []):
        state["user_fields"][f["id"]] = {"name": f["name"], "show_on_profile": bool(f.get("show_on_profile"))}
    return state


def main():
    instance = d._instance().lower()
    expect = json.loads(pathlib.Path(str(EXPECT).format(instance)).read_text())
    if "--flipped" in sys.argv:
        expect["default"] = True
    state = gather(expect)
    found = tc.problems(state, expect)
    theme = state["theme"]
    if theme:
        print(f"theme {theme['id']} local_version {theme['local_version'][:7]} main {state['main_sha'][:7]}")
    if found:
        print("FAIL")
        for p in found:
            print(f"  - {p}")
        raise SystemExit(1)
    print(f"OK: theme install on {instance.upper()} holds")


if __name__ == "__main__":
    main()
```

`chmod +x bin/theme-verify`.

- [ ] **Step 8: Green on PRE, red on PROD — watched**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PRE ./bin/theme-verify
DISCOURSE_INSTANCE=PROD ./bin/theme-verify
```

Expected: PRE `OK: theme install on PRE holds` (if PRE is behind `main`, force its pull first — `PUT /admin/themes/15.json` with `{"theme":{"remote_update":true}}` — and re-run); PROD `FAIL` with exactly `- theme not installed`.

- [ ] **Step 9: Lint and commit**

```bash
npx pnpm@10.28.0 lint > /tmp/lint.txt 2>&1; code=$?; grep -E "✖|error" /tmp/lint.txt; [ "$code" -eq 0 ]
git add bin/_theme_check.py bin/theme-verify bin/_discourse.py docs/superpowers/plans/data/2026-10-01-*-theme-expect.json
git commit -m "feat(bin): theme-verify judges an install by its ten settings, green on PRE, red on PROD"
```

---

### Task 3: The installer

**Files:** Create `bin/theme-apply`.

**Interfaces:**
- Consumes: `_theme_check.setting_changes`, `_discourse.theme_id_by_remote`, the expectation file of Task 2.
- Produces: an installed, non-default theme on the instance with `expect["settings"]` applied.

- [ ] **Step 1: Write `bin/theme-apply`**

```python
#!/usr/bin/env python3
"""Install the theme on an instance, hidden, and set the overrides its expectation names.

    DISCOURSE_INSTANCE=PROD bin/theme-apply          # dry run
    DISCOURSE_INSTANCE=PROD bin/theme-apply --write

Never makes the theme default — that is the flip, a separate decision. Idempotent: a
re-run after a partial failure imports nothing twice and rewrites only what differs.
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402
import _theme_check as tc  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXPECT = ROOT / "docs/superpowers/plans/data/2026-10-01-{}-theme-expect.json"


def settings_of(tid):
    return {s["setting"]: s["value"] for s in d.get(f"/admin/themes/{tid}.json", elevated=True)["theme"]["settings"]}


def main():
    write = "--write" in sys.argv
    expect = json.loads(pathlib.Path(str(EXPECT).format(d._instance().lower())).read_text())
    url = expect["remote_url"]
    tid = d.theme_id_by_remote(url)
    if tid is None:
        print(f"import {url} (not default)")
        if not write:
            print(f"then set {expect['settings']}")
            print("(dry run — nothing written; add --write)")
            return
        d.request("POST", "/admin/themes/import.json", data=[("remote", url)], elevated=True)
        tid = d.theme_id_by_remote(url)
        if tid is None:
            raise SystemExit("FAIL: import answered but no theme carries that remote")
    theme = d.get(f"/admin/themes/{tid}.json", elevated=True)["theme"]
    if theme.get("default"):
        raise SystemExit(f"STOP: theme {tid} is already default")
    print(f"theme {tid} {theme['name']!r} default={theme.get('default')} user_selectable={theme.get('user_selectable')}")
    changes = tc.setting_changes(settings_of(tid), expect["settings"])
    for name, value in changes.items():
        print(f"  setting {name} -> {value!r}")
        if write:
            d.request("PUT", f"/admin/themes/{tid}/setting.json", data=[("name", name), ("value", str(value))], elevated=True)
    if not changes:
        print("  settings already set")
    if not write:
        print("(dry run — nothing written; add --write)")
        return
    left = tc.setting_changes(settings_of(tid), expect["settings"])
    if left:
        raise SystemExit(f"FAIL: settings read back differ: {left}")
    print("OK")


if __name__ == "__main__":
    main()
```

`chmod +x bin/theme-apply`.

- [ ] **Step 2: Dry run on both instances**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PRE ./bin/theme-apply
DISCOURSE_INSTANCE=PROD ./bin/theme-apply
```

Expected: PRE ends in `STOP: theme 15 is already default` — the guard is the point: this script never touches a default theme, and PRE's is. PROD prints `import https://github.com/gestionatools-org/ddm-discourse-theme.git (not default)`, `then set {'header_room_category_ids': '90|91|92', 'highlights_news_tag': 'nuevas-versiones'}` and the dry-run line.

- [ ] **Step 3: Lint and commit**

```bash
npx pnpm@10.28.0 lint > /tmp/lint.txt 2>&1; code=$?; grep -E "✖|error" /tmp/lint.txt; [ "$code" -eq 0 ]
git add bin/theme-apply
git commit -m "feat(bin): theme-apply installs the theme hidden and sets its instance overrides"
```

---

### Task 4: The chrome that does not travel

**Files:** Create `bin/chrome-apply`.

**Interfaces:**
- Produces: `sidebar_links(section_links, renames, new_links, drop) -> list[dict]` (pure), and the per-instance writes.

- [ ] **Step 1: Write the pure half with its self-test**

```python
#!/usr/bin/env python3
"""Sidebar section 3 and the three login texts — instance state the theme cannot carry.

    DISCOURSE_INSTANCE=PROD bin/chrome-apply            # dry run
    DISCOURSE_INSTANCE=PROD bin/chrome-apply --write
    bin/chrome-apply --self-test

On PRE it is a regression check: everything already holds, so a dry run lists nothing.
Section 3 and its first two links pre-date the restore, so their ids are shared.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402

SECTION = 3
TITLE = "Recursos de apoyo"
RENAMES = {"/c/documentacion-analiza/73": "Recursos Analítica", "/c/doc-developers/75": "Recursos Developers"}
# Icons from core's default subset, matched literally: sidebar link icons never reach the
# sprite, and `book-open` (absent) rendered blank on PRE while a word-boundary grep said fine.
NEW_LINKS = [
    {"name": "Academy", "value": "https://espublico.gestiona.academy", "icon": "book"},
    {"name": "Demo Gestiona", "value": "https://demo-a.gestiona.espublico.com", "icon": "desktop"},
    {"name": "Primeros pasos", "value": "/c/primeros-pasos/78", "icon": "flag"},
]
COMMUNITY = 1
DROP = {"/c/documentacion-analiza/74"}  # category 74 exists on neither instance (F4)
TEXTS = {
    "login_required.welcome_message": "# Bienvenid@s a la comunidad %{title}\n\n"
    "Plataforma online para alumnos de los programas de certificación de Gestiona.",
    "js.log_in": "Accede a la comunidad",
    "js.login.header_title": "Bienvenid@",
}


def sidebar_links(section_links, renames, new_links, drop):
    """The full wanted link list: existing links in order, renamed, then new ones.

    A dropped link is NOT omitted: core keeps a link the payload leaves out and re-positions
    it — measured on PROD 2026-10-01, the omitted Wiki link jumped to the top of Community.
    It goes last, with its id and `_destroy`, which is what nested attributes delete on.
    """
    links = [
        {"id": link["id"], "name": renames.get(link["value"], link["name"]), "value": link["value"],
         "icon": link["icon"], "segment": link.get("segment") or "primary"}
        for link in section_links if link["value"] not in drop
    ]
    doomed = [
        {"id": link["id"], "name": link["name"], "value": link["value"], "icon": link["icon"],
         "segment": link.get("segment") or "primary", "_destroy": True}
        for link in section_links if link["value"] in drop
    ]
    icons = {link["value"]: link["icon"] for link in new_links}
    for link in links:
        if link["value"] in icons:
            link["icon"] = icons[link["value"]]
    present = {link["value"] for link in links}
    return links + [{**link, "segment": "primary"} for link in new_links if link["value"] not in present] + doomed


def self_test():
    prod = [{"id": 16, "name": "Analítica de Datos", "value": "/c/documentacion-analiza/73", "icon": "file"},
            {"id": 19, "name": "Gestiona for Developers", "value": "/c/doc-developers/75", "icon": "file"}]
    got = sidebar_links(prod, RENAMES, NEW_LINKS, set())
    assert [l["name"] for l in got] == ["Recursos Analítica", "Recursos Developers", "Academy", "Demo Gestiona", "Primeros pasos"], got
    assert [l.get("id") for l in got[:2]] == [16, 19]
    # keeps foreign links in order
    foreign = [{"id": 7, "name": "X", "value": "/x", "icon": "file"}] + prod
    assert [l["value"] for l in sidebar_links(foreign, RENAMES, NEW_LINKS, set())][:3] == ["/x", "/c/documentacion-analiza/73", "/c/doc-developers/75"]
    # idempotent: PRE's final list produces itself
    pre = [{**l, "id": i} for i, l in enumerate(got)]
    assert [(l["name"], l["value"], l["icon"]) for l in sidebar_links(pre, RENAMES, NEW_LINKS, set())] == \
        [(l["name"], l["value"], l["icon"]) for l in got]
    # a wrong icon on an owned link is corrected, not kept
    bad = pre[:2] + [{**pre[2], "icon": "book-open"}] + pre[3:]
    assert sidebar_links(bad, RENAMES, NEW_LINKS, set())[2]["icon"] == "book"
    # drop removes only what it names
    wiki = prod + [{"id": 30, "name": "Wiki", "value": "/c/documentacion-analiza/74", "icon": "anchor"}]
    dropped = sidebar_links(wiki, {}, [], DROP)
    assert [l["value"] for l in dropped if not l.get("_destroy")] == [l["value"] for l in prod]
    assert dropped[-1] == {**wiki[-1], "segment": "primary", "_destroy": True}
    print("self-test OK: 5 cases")


if __name__ == "__main__" and "--self-test" in sys.argv:
    self_test()
    raise SystemExit(0)
```

- [ ] **Step 2: Run the self-test — red, then green**

Before `sidebar_links` exists the call raises `NameError`; write the test block first, run `python3 bin/chrome-apply --self-test`, watch it fail, then add the function above and re-run.
Expected after: `self-test OK: 5 cases`.

- [ ] **Step 3: The I/O half**, appended to the same file

```python
def section(sid):
    return next(s for s in d.get("/sidebar_sections.json", elevated=True)["sidebar_sections"] if s["id"] == sid)


def apply_section(sid, title, renames, new_links, drop, write):
    s = section(sid)
    wanted = sidebar_links(s["links"], renames, new_links, drop)
    key = lambda links: [(l["name"], l["value"], l["icon"]) for l in links if not l.get("_destroy")]  # noqa: E731
    if key(s["links"]) == key(wanted) and s["title"] == title and s.get("public"):
        print(f"sidebar section {sid}: already set")
        return
    print(f"sidebar section {sid}: {s['title']!r} public={s.get('public')} {key(s['links'])}")
    print(f"                 -> {title!r} public=True {key(wanted)}")
    if not write:
        return
    # The whole array goes, ids included: the updater re-derives order from it. `name` leads
    # each element because Rails starts a new hash when a `links[][...]` key repeats.
    payload = [("title", title), ("public", "true")]
    for link in wanted:
        payload += [("links[][name]", link["name"]), ("links[][value]", link["value"]),
                    ("links[][icon]", link["icon"]), ("links[][segment]", link["segment"])]
        if "id" in link:
            payload.append(("links[][id]", link["id"]))
        if link.get("_destroy"):
            payload.append(("links[][_destroy]", "true"))
    d.request("PUT", f"/sidebar_sections/{sid}.json", data=payload, elevated=True)
    after = section(sid)
    if key(after["links"]) != key(wanted) or after["title"] != title:
        raise SystemExit(f"FAIL: section {sid} reads back {after['title']!r} {key(after['links'])}")
    print("  OK")


def apply_texts(write):
    for key, value in TEXTS.items():
        now = d.get(f"/admin/customize/site_texts/{key}?locale=es", elevated=True)["site_text"]["value"]
        if now == value:
            print(f"text {key}: already set")
            continue
        print(f"text {key}: {now!r} -> {value!r}")
        if not write:
            continue
        # `locale` inside site_text, never as a sibling: core reads params.dig(:site_text, :locale).
        d.request("PUT", f"/admin/customize/site_texts/{key}",
                  data=[("site_text[value]", value), ("site_text[locale]", "es")], elevated=True)
        back = d.get(f"/admin/customize/site_texts/{key}?locale=es", elevated=True)["site_text"]["value"]
        if back != value:
            raise SystemExit(f"FAIL: {key} reads back {back!r}")
        print("  OK")


def main():
    write = "--write" in sys.argv
    community = section(COMMUNITY)
    apply_section(COMMUNITY, community["title"], {}, [], DROP, write) if any(
        l["value"] in DROP for l in community["links"]) else print(f"sidebar section {COMMUNITY}: nothing to drop")
    apply_section(SECTION, TITLE, RENAMES, NEW_LINKS, set(), write)
    apply_texts(write)
    if not write:
        print("(dry run — nothing written; add --write)")


if __name__ == "__main__":
    main()
```

Note: `apply_section` for section 1 must keep `public` as it is — Community is core's public section — so its `public` check is satisfied and it sends `public=true`, which it already is.

- [ ] **Step 4: Dry run — PRE lists nothing, PROD lists everything**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PRE ./bin/chrome-apply
DISCOURSE_INSTANCE=PROD ./bin/chrome-apply
```

Expected: PRE `nothing to drop`, `sidebar section 3: already set`, three `already set` texts. PROD: section 1 `nothing to drop` (F4 done by hand); section 3 `'Herramientas' public=False` → `'Recursos de apoyo' public=True` with five links; three texts from core's defaults to PRE's values. Anything else is a STOP.

- [ ] **Step 5: Lint and commit**

```bash
npx pnpm@10.28.0 lint > /tmp/lint.txt 2>&1; code=$?; grep -E "✖|error" /tmp/lint.txt; [ "$code" -eq 0 ]
chmod +x bin/chrome-apply
git add bin/chrome-apply
git commit -m "feat(bin): chrome-apply carries the sidebar section and login texts to an instance"
```

---

### Task 5: S10 — tags, then the theme hidden on PROD

F1, F2 and F4 are done (see *Decisions*). Then the tag group, then the install.

- [ ] **Step 1: `idea-registrada` and its staff-only group** (tag created by the group, no topic written)

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD python3 - <<'EOF'
import sys; sys.path.insert(0, "bin"); import _discourse as d
names = [g["name"] for g in d.get("/tag_groups.json", elevated=True)["tag_groups"]]
if "Estado de idea" not in names:
    d.request("POST", "/tag_groups.json", data=[("name", "Estado de idea"), ("tag_names[]", "idea-registrada"),
              ("permissions[staff]", "1"), ("permissions[everyone]", "3")], elevated=True)
g = next(g for g in d.get("/tag_groups.json", elevated=True)["tag_groups"] if g["name"] == "Estado de idea")
print(g["id"], [t if isinstance(t, str) else t["name"] for t in g["tags"]], g["permissions"])
print("idea-registrada", d.get("/tag/idea-registrada/info.json", elevated=True)["tag_info"]["topic_count"])
EOF
```

Expected: `… ['idea-registrada'] {'staff': 1, 'everyone': 3}` (keys may come back as group ids `'3'`/`'0'`), and `idea-registrada 0`. **If `permissions` answers 500** (recorded on 2026-09-04 for a throwaway group), create the group without it and set it with `PUT /tag_groups/<id>.json` the same way, reading back.

- [ ] **Step 2: The two news tags, read — no write** (F2 was done by Ricardo, inverted)

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD python3 -c "
import sys; sys.path.insert(0, 'bin'); import _discourse as d
i = d.get('/tag/nuevas-versiones/info.json', elevated=True)['tag_info']
print(i['id'], i['topic_count'], [x['name'] for x in i.get('synonyms', [])])"
DISCOURSE_INSTANCE=PROD ./bin/tags-verify
```

Expected: `61 14 ['nueva-version-gestiona']` (count may have grown); `tags-verify` PASS, `no shadowed slug`. The theme reads `nuevas-versiones` on PROD through its expectation file.

- [ ] **Step 3: Install hidden**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/theme-apply
DISCOURSE_INSTANCE=PROD ./bin/theme-apply --write
DISCOURSE_INSTANCE=PROD ./bin/theme-verify
```

Expected: `OK` from the installer; the verifier `FAIL` with **exactly one** line, `ideas_tag 'idea-registrada' has no topics` — that is F1, and it stays red until Ricardo tags. Any other line is a STOP. Also read the record: `remote_compat_ref` None is already asserted; note the theme id.

- [ ] **Step 4: Preview, for Ricardo**

Send him `https://gestionaavanza.espublico.com/?preview_theme_id=<id>` to open in his admin session: three lanes, the bento, the header rooms, the band, the colours. The ideas lane is empty until F1.

- [ ] **Step 5: Record and commit**

*As executed → T3 · S10*: tag group id, rename, theme id, verifier output, Ricardo's preview verdict.

```bash
git add docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md
git commit -m "chore(prod): T3 S10 installs the theme hidden on PROD"
```

---

### Task 6: S11 — the chrome on PROD

- [ ] **Step 1: Dry run, then write**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/chrome-apply
DISCOURSE_INSTANCE=PROD ./bin/chrome-apply --write
DISCOURSE_INSTANCE=PROD ./bin/chrome-apply
```

Expected: the dry run as in Task 4 Step 4; `OK` after each write; the second dry run all `already set`.

**Visible to members immediately** — section 3 becomes public and the login page changes — so it runs only on Ricardo's go, ideally next to the flip.

- [ ] **Step 2: Icons by eye** in the preview: Academy (`book`), Demo Gestiona (`desktop`), Primeros pasos (`flag`) each render a glyph. A blank is a missing sprite symbol, which no check catches.

- [ ] **Step 3: Record and commit** (*As executed → T3 · S11*).

---

### Task 7: S12 — one non-admin session (Ricardo)

**PROD must be out of staff-writes-only mode**, or a member sees no composer and the "Nueva publicación" check is void. Ricardo lifts it first.

Checklist, in `?preview_theme_id=<id>` with a non-admin account:

1. **Walls**: a `Certificación` member outside `Analiza` sees room 90 and not 91 or 92; Comparte (85) and the closed surplus categories are invisible.
2. **Header**: only the rooms the account can enter are linked.
3. **"Nueva publicación"** in the band opens the composer on **5 Foro del Certificado**.
4. **Plaza**: category 5's own listing shows only arrival announcements.
5. **`idea-registrada`** is visible on tagged ideas and not offered in the composer's tag chooser.

*Gate:* Ricardo signs off each line. Record in *As executed → T3 · S12*.

---

### Task 8: S13 — the flip (Ricardo's explicit go)

- [ ] **Step 1: Gates, all read in the same sitting**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD ./bin/theme-verify
```

Expected: `OK: theme install on PROD holds` — which needs F1 done (`idea-registrada` with topics). Task 7 signed off. F3 decided.

- [ ] **Step 2: Flip**

```bash
set -a && source .env.local && set +a
DISCOURSE_INSTANCE=PROD python3 - <<'EOF'
import sys; sys.path.insert(0, "bin"); import _discourse as d
tid = d.theme_id_by_remote("https://github.com/gestionatools-org/ddm-discourse-theme.git")
d.request("PUT", f"/admin/themes/{tid}.json", data=[("theme[default]", "true")], elevated=True)
print([(t["id"], t["name"]) for t in d.get("/admin/themes.json", elevated=True)["themes"] if t.get("default")])
EOF
DISCOURSE_INSTANCE=PROD ./bin/theme-verify --flipped
```

Expected: the default is our theme alone; `OK` with `--flipped`. Themes 1 and 2 remain installed.

- [ ] **Step 3: Colour schemes** — read the theme's `color_scheme_id` / `dark_color_scheme_id`; if they do not point at "Gestiona Avanza" / "Gestiona Avanza Oscuro", set them as on PRE (28/29 there; PROD's ids are its own, resolve by name).

- [ ] **Step 4: The repository rule changes.** Add to `CLAUDE.md` → *Conventions*: the theme is live on PROD since <date>, every merge to `main` reaches both instances. Commit with the record (*As executed → T3 · S13*).

**Rollback, for one week:** `PUT /admin/themes/1.json` with `theme[default]=true`.

---

### Task 9: S14 — close T3

- [ ] **Step 1:** Ricardo revokes `PROD_DISCOURSE_GLOBAL_API_KEY` in admin; its line is deleted from `.env.local`; a probe with it answers 403/401.
- [ ] **Step 2:** *As executed → T3 closed*, roadmap S9–S14 ticked, `traceability.md`, `CLAUDE.local.md`.
- [ ] **Step 3:** Decide, with Ricardo, the real deletion of T2's emptied categories (spec: decided after the launch) and the removal of themes 1 and 2 after the week.
- [ ] **Step 4:** PR, four checks green, merge.

---

## Self-review against the spec

| Spec requirement (T3) | Task |
|---|---|
| Leak measured on PRE before anything on PROD | 1 (with a positive control) |
| Theme enters PROD hidden, verified in preview against real data | 3, 5 |
| Ten settings resolve: 3 category ids, rooms, 4 tags, 2 user fields | 2 (`problems`), 5 |
| `header_room_category_ids` overridden on PROD | expectation file, 3 |
| `idea-registrada` created, restricted to staff via tag group | 5 Step 1; F1 for topics |
| `nueva-version-gestiona` exists | 5 Step 2 (F2) |
| User fields 2/4 verified by name before the flip | 2 (every run), 8 Step 1 |
| Chrome: sidebar section, link renames, login texts, sidebar order check | 4, 6 |
| One non-admin session, five checks | 7 |
| Every merge to `main` reaches PROD afterwards | 8 Step 4 |
| Global key revoked | 9 |
| Rollback is uninstalling / re-defaulting | Global Constraints, 8 |

**Departures from the roadmap, deliberate:** `academy_url` is no longer a theme setting (#129) and is carried as a sidebar link; `nueva-version-gestiona` is a **rename with synonym** rather than create + merge (F2), which reaches PRE's end state with one tag and no topic write; the default theme being replaced is **1 "Gestiona avanza"**, not Air.

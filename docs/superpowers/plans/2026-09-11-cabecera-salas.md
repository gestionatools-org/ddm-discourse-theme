# Header links to the programme rooms — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The three programme rooms become subcategories of category 5 and the site
header's three links; the search collapses behind the magnifier.

**Architecture:** Two halves that ship independently. PRE instance state (category tree,
permissions, sidebar section, two site settings) is applied by an idempotent script and
asserted by `bin/categories-verify`. The theme half rewrites one Glimmer component to
resolve room ids against `site.categories`, plus SCSS placement and settings/locales.

**Tech Stack:** Python 3 stdlib scripts against the Discourse admin API (`bin/`),
Glimmer `.gjs`, SCSS, QUnit (CI only).

**Spec:** `docs/superpowers/specs/2026-09-11-cabecera-salas-design.md`

## Global Constraints

- Room ids: `89` Administración Avanzada, `90` Analítica de datos, `91` Gestiona for Developers. Parent: `5`.
- Groups added to category 5 at permission `3` (read-only): `Analiza`, `Developers`, `AdminDevelopers`. Never lower or remove an existing row.
- Category 5 `default_list_filter`: `none`.
- `search_experience`: `search_icon`. `default_navigation_menu_categories`: `4|5|14|18|89|90|91`, sent with `update_existing_user=true`.
- Sidebar section `3`: rename link `16` → `Recursos Analítica`, `19` → `Recursos Developers`; add `Academy` (`https://espublico.gestiona.academy`, `book-open`), `Demo Gestiona` (`https://demo-a.gestiona.espublico.com`, `desktop`), `Primeros pasos` (`/c/primeros-pasos/78`, `flag`). Icons only from core's default subset.
- Theme setting `header_room_category_ids`: `type: list`, `list_type: category`, default `"89|90|91"`. Deletes `academy_url`, `demo_url`, `first_steps_url`.
- `theme_version` `0.57.0` → `0.58.0`.
- Code, commits, comments in English; display strings only in `locales/*.yml`.
- Never print usernames or API keys. Credentials come from `.env.local` via `set -a && source .env.local && set +a`.
- QUnit runs only in CI. `npx pnpm@10.28.0 lint` is the only local gate. Watch CI green **before** merging — `gh pr merge --auto` does not wait from this account.

---

### Task 1: Shared category update, and the verifier's new assertions (red)

**Files:**
- Modify: `bin/_discourse.py` (add `update_category` after `category`)
- Modify: `bin/categories-reparent` (use it; stop resending `description`)
- Modify: `bin/categories-verify` (three new assertion groups)

**Interfaces:**
- Produces: `d.update_category(cid: int, changes: dict | None = None, add_permissions: dict[str, int] | None = None) -> dict` — the category as read back after the write.

- [ ] **Step 1: Add `update_category` to `bin/_discourse.py`**, directly after `def category(cid)`:

```python
def update_category(cid, changes=None, add_permissions=None):
    """Read a category and send it back with only `changes` applied.

    `PUT /categories/<id>.json` has always been driven here by read-and-resend rather
    than by finding out which absent fields revert. `description` is deliberately not
    resent: the API exposes only `description_excerpt`, a truncated rendering, and
    sending it back risks replacing the definition topic's text with its own excerpt.

    `add_permissions` adds groups at a level but never lowers or removes a row a group
    already holds. Returns the category as read back after the write.
    """
    c = category(cid)
    fields = {
        "name": c["name"],
        "slug": c["slug"],
        "color": c["color"],
        "text_color": c["text_color"],
        "auto_close_hours": c.get("auto_close_hours") or "",
        "auto_close_based_on_last_post": str(bool(c.get("auto_close_based_on_last_post"))).lower(),
        "minimum_required_tags": c.get("minimum_required_tags") or 0,
        "topic_template": c.get("topic_template") or "",
        "default_list_filter": c.get("default_list_filter") or "all",
    }
    fields.update(changes or {})
    perms = {g["group_name"]: g["permission_type"] for g in (c.get("group_permissions") or [])}
    for group, level in (add_permissions or {}).items():
        perms.setdefault(group, level)
    payload = list(fields.items()) + [(f"permissions[{g}]", p) for g, p in perms.items()]
    request("PUT", f"/categories/{cid}.json", data=payload, elevated=True)
    return category(cid)
```

- [ ] **Step 2: Rewrite `main` in `bin/categories-reparent`** to use it, and drop the local payload:

```python
def main(cid, parent):
    was = d.category(cid)
    target = parent or None
    print(f"cat {cid} {was['name']!r}: parent {was.get('parent_category_id')} -> {target}")
    if was.get("parent_category_id") == target:
        print("  already there")
        return
    after = d.update_category(cid, {"parent_category_id": parent or ""})
    perms = {g["group_name"]: g["permission_type"] for g in (after.get("group_permissions") or [])}
    print(f"  now: parent={after.get('parent_category_id')} slug={after['slug']!r} perms={perms}")
    if after.get("parent_category_id") != target:
        raise SystemExit(f"FAIL: parent is {after.get('parent_category_id')}, expected {target}")
    print("OK")
```

Update its docstring: replace the "`PUT /categories/<id>.json` replaces the record…" paragraph with "The read-and-resend lives in `_discourse.update_category`." and add a line: "`description` is not resent — an earlier version sent `description_excerpt` back, which would have overwritten a definition topic with its own excerpt; it never ran against a category that has one."

- [ ] **Step 3: Add the forum assertions to `bin/categories-verify`.** After `DEVELOPER_COHORTS`:

```python
# Since 2026-09-11 the three rooms are subcategories of the certificate's forum. Core
# refuses a child whose groups are absent from its parent (at any level), so the
# programme groups hold read-only there; and the forum's own listing shows only its
# announcements, not the rooms' topics.
FORUM = 5
FORUM_READERS = ("Analiza", "Developers", "AdminDevelopers")
```

And in `main()`, immediately before the `# \`Developers\` must be exactly the union` block:

```python
    if rooms:
        for key in ROOM_GROUPS:
            if key in rooms:
                parent = d.category(rooms[key]).get("parent_category_id")
                check(parent == FORUM, f"room {key}: parent {parent}, expected {FORUM}")
    forum = d.category(FORUM)
    check(
        forum.get("default_list_filter") == "none",
        f"category {FORUM}: default_list_filter {forum.get('default_list_filter')!r},"
        f" expected 'none' — the plaza would list every room's topics",
    )
    forum_perms = {
        g["group_name"]: g["permission_type"] for g in (forum.get("group_permissions") or [])
    }
    for group in FORUM_READERS:
        check(
            forum_perms.get(group) == 3,
            f"category {FORUM}: {group} holds {forum_perms.get(group)}, expected 3 (read-only)",
        )
```

- [ ] **Step 4: Watch it fail**

Run: `python3 -c "import ast;[ast.parse(open(f).read()) for f in ('bin/_discourse.py','bin/categories-reparent','bin/categories-verify')]" && set -a && source .env.local && set +a && ./bin/categories-verify`
Expected: `FAIL` with exactly seven lines — three `room …: parent None, expected 5`, one `default_list_filter 'all'`, three `holds None, expected 3`. Any other line means the prior state drifted: stop.

- [ ] **Step 5: Commit**

```bash
git add bin/_discourse.py bin/categories-reparent bin/categories-verify
git commit -m "feat(bin): assert the rooms hang under the certificate's forum"
```

---

### Task 2: Apply the PRE instance configuration (green)

**Files:**
- Create: `bin/forum-rooms-apply`

**Interfaces:**
- Consumes: `d.update_category`, `d.category`, `d.get`, `d.request` (Task 1); `docs/superpowers/plans/data/2026-09-11-rooms.json` → `{"administracion_avanzada": 89, "analitica": 90, "developers": 91}`.

- [ ] **Step 1: Write `bin/forum-rooms-apply`**

```python
#!/usr/bin/env python3
"""Hang the three programme rooms under category 5 and reshape the chrome around them.

PRE instance state only — none of this travels with the theme. Idempotent: every step
reads first and writes only what differs, so a re-run after a partial failure is safe.

Order is load-bearing between steps 1 and 2: core's
`Category#check_permissions_compatibility` refuses a child whose groups are absent from
its parent, so the programme groups must be on 5 before any room moves under it.
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _discourse as d  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
ROOMS = json.loads((ROOT / "docs/superpowers/plans/data/2026-09-11-rooms.json").read_text())

FORUM = 5
FORUM_READERS = {"Analiza": 3, "Developers": 3, "AdminDevelopers": 3}

SECTION = 3
RENAMES = {16: "Recursos Analítica", 19: "Recursos Developers"}
# academy_url and demo_url as the theme held them on PRE, read 2026-09-11 before the
# theme dropped the settings. first_steps_url held an absolute PRE URL, which would not
# have survived PROD; the relative path does. Icons come from core's default subset,
# because SvgSprite.all_icons never reads sidebar links: anything else renders blank.
NEW_LINKS = [
    {"name": "Academy", "value": "https://espublico.gestiona.academy", "icon": "book-open"},
    {"name": "Demo Gestiona", "value": "https://demo-a.gestiona.espublico.com", "icon": "desktop"},
    {"name": "Primeros pasos", "value": "/c/primeros-pasos/78", "icon": "flag"},
]

# (value, backfill existing users). The sidebar default only seeds new accounts unless
# backfilled: core creates each user's sidebar links once, at signup.
SITE_SETTINGS = {
    "search_experience": ("search_icon", False),
    "default_navigation_menu_categories": ("4|5|14|18|89|90|91", True),
}


def perms_of(category):
    return {g["group_name"]: g["permission_type"] for g in (category.get("group_permissions") or [])}


def forum():
    c = d.category(FORUM)
    changes = {} if c.get("default_list_filter") == "none" else {"default_list_filter": "none"}
    missing = {g: level for g, level in FORUM_READERS.items() if g not in perms_of(c)}
    if not changes and not missing:
        print(f"forum {FORUM}: already set")
        return
    after = d.update_category(FORUM, changes, add_permissions=missing)
    print(f"forum {FORUM}: default_list_filter={after.get('default_list_filter')} perms={perms_of(after)}")


def rooms():
    for key, cid in ROOMS.items():
        if d.category(cid).get("parent_category_id") == FORUM:
            print(f"room {key} ({cid}): already under {FORUM}")
            continue
        after = d.update_category(cid, {"parent_category_id": FORUM})
        if after.get("parent_category_id") != FORUM:
            raise SystemExit(f"FAIL: room {key} parent is {after.get('parent_category_id')}")
        print(f"room {key} ({cid}): now under {FORUM}, slug {after['slug']!r}, perms {perms_of(after)}")


def sidebar_section():
    return next(
        s for s in d.get("/sidebar_sections.json", elevated=True)["sidebar_sections"] if s["id"] == SECTION
    )


def sidebar():
    section = sidebar_section()
    links = [
        {
            "id": link["id"],
            "name": RENAMES.get(link["id"], link["name"]),
            "value": link["value"],
            "icon": link["icon"],
            "segment": link.get("segment") or "primary",
        }
        for link in section["links"]
    ]
    present = {link["value"] for link in links}
    links += [{**link, "segment": "primary"} for link in NEW_LINKS if link["value"] not in present]
    before = [(link["name"], link["value"], link["icon"]) for link in section["links"]]
    wanted = [(link["name"], link["value"], link["icon"]) for link in links]
    if before == wanted:
        print(f"sidebar section {SECTION}: already set")
        return
    # The whole array goes, ids included: the updater re-derives order from it, and an
    # omitted link would be dropped or jump. `name` leads every element because Rails
    # splits `links[][...]` into a new hash when a key repeats, and new links carry no id.
    payload = [("title", section["title"]), ("public", "true")]
    for link in links:
        payload += [
            ("links[][name]", link["name"]),
            ("links[][value]", link["value"]),
            ("links[][icon]", link["icon"]),
            ("links[][segment]", link["segment"]),
        ]
        if "id" in link:
            payload.append(("links[][id]", link["id"]))
    d.request("PUT", f"/sidebar_sections/{SECTION}.json", data=payload, elevated=True)
    after = [(link["name"], link["value"], link["icon"]) for link in sidebar_section()["links"]]
    print(f"sidebar section {SECTION}: {after}")
    if after != wanted:
        raise SystemExit(f"FAIL: sidebar section {SECTION} reads back {after}, expected {wanted}")


def site_settings():
    def current():
        return {x["setting"]: x["value"] for x in d.get("/admin/site_settings.json", elevated=True)["site_settings"]}

    now = current()
    for name, (value, backfill) in SITE_SETTINGS.items():
        if now.get(name) == value:
            print(f"{name}: already {value!r}")
            continue
        data = [(name, value)] + ([("update_existing_user", "true")] if backfill else [])
        d.request("PUT", f"/admin/site_settings/{name}", data=data, elevated=True)
    after = current()
    for name, (value, _) in SITE_SETTINGS.items():
        print(f"{name} = {after.get(name)!r}")
        if after.get(name) != value:
            raise SystemExit(f"FAIL: {name} reads back {after.get(name)!r}, expected {value!r}")


def main():
    forum()
    rooms()
    sidebar()
    site_settings()
    print("OK: forum rooms applied")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it**

Run: `chmod +x bin/forum-rooms-apply && set -a && source .env.local && set +a && ./bin/forum-rooms-apply`
Expected: forum line with `default_list_filter=none` and the three groups at 3; three `now under 5` lines; the sidebar line listing five links; both settings read back; `OK: forum rooms applied`. On any `FAIL` or HTTP error: stop, read it, do not re-run blindly.

- [ ] **Step 3: Re-run it to prove idempotence**

Run: `./bin/forum-rooms-apply`
Expected: every step prints `already …`; no write.

- [ ] **Step 4: Watch the verifiers go green, and the `#` filter survive**

Run: `./bin/categories-verify && ./bin/tags-verify`
Expected: `OK: genre reorganisation target state holds` and `PASS — …`.

Then check that each room's slug still resolves as a subcategory:

```bash
python3 - <<'PY'
import sys, pathlib, urllib.parse
sys.path.insert(0, str(pathlib.Path("bin").resolve()))
import _discourse as d
for slug, cid in (("foro-administracion-avanzada", 89), ("foro-analitica-de-datos", 90), ("foro-gestiona-for-developers", 91)):
    topics = d.get(f"/search.json?q={urllib.parse.quote('#' + slug)}", elevated=True).get("topics") or []
    cats = {t["category_id"] for t in topics}
    print(f"#{slug}: {len(topics)} topics, categories {sorted(cats)}", "OK" if cats <= {cid} else "UNEXPECTED")
PY
```
Expected: each line `OK` (91 returns only its definition topic).

- [ ] **Step 5: Commit**

```bash
git add bin/forum-rooms-apply
git commit -m "feat(bin): hang the three rooms under the certificate's forum on PRE"
```

---

### Task 3: The header component, its settings and strings (TDD, CI)

**Files:**
- Create: `test/integration/header-links-test.gjs`
- Modify: `test/acceptance/header-links-test.js` (rewrite), `test/acceptance/topbar-test.js`
- Modify: `javascripts/discourse/components/header-links.gjs`, `javascripts/discourse/api-initializers/before-header-panel.gjs` (comment)
- Delete: `javascripts/discourse/lib/destination-links.js`
- Modify: `settings.yml` (the `--- Header links ---` block, lines 93–128), `locales/en.yml`, `locales/es.yml`, `stylesheets/app/header.scss`, `about.json`

**Interfaces:**
- Consumes: `parseCategoryIds(value: string) -> number[]` from `javascripts/discourse/lib/category-topics.js`; the `site` service's `categories` (objects with `id`, `name`, `url`).
- Produces: `.header-links` `<nav>` with `.header-links__link` anchors, rendered into `before-header-panel`.

- [ ] **Step 1: Write the integration test** `test/integration/header-links-test.gjs`:

```gjs
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import HeaderLinks from "../../discourse/components/header-links";

// Which rooms, in what order, with which label and href. Placement in the real
// header is asserted in test/acceptance/header-links-test.js.
//
// `site.categories` holds only the categories the viewer may see — core's
// Site#categories is guardian-scoped — so "a member outside the room" is a
// category absent from this list. Stubbed by mutating the real service, as
// page-hero-test does, and restored after: `settings` and the site service are
// shared across the whole QUnit run.
const ROOMS = [
  { id: 89, name: "Administración Avanzada", url: "/c/foro-del-certificado/foro-administracion-avanzada/89" },
  { id: 90, name: "Analítica de datos", url: "/c/foro-del-certificado/foro-analitica-de-datos/90" },
  { id: 91, name: "Gestiona for Developers", url: "/c/foro-del-certificado/foro-gestiona-for-developers/91" },
];

function textsOf(selector) {
  return [...document.querySelectorAll(selector)].map((el) => el.textContent.trim());
}

module("Integration | Component | header-links", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.site = this.owner.lookup("service:site");
    this.originalCategories = this.site.categories;
    this.site.categories = ROOMS;
    settings.header_room_category_ids = "89|90|91";
  });

  hooks.afterEach(function () {
    this.site.categories = this.originalCategories;
    settings.header_room_category_ids = "89|90|91";
  });

  test("renders one link per configured room", async function (assert) {
    await render(<template><HeaderLinks /></template>);

    assert.dom(".header-links__link").exists({ count: 3 });
  });

  test("keeps the setting's order, not the site list's", async function (assert) {
    this.site.categories = [...ROOMS].reverse();
    settings.header_room_category_ids = "89|91";

    await render(<template><HeaderLinks /></template>);

    assert.deepEqual(textsOf(".header-links__link"), [
      "Administración Avanzada",
      "Gestiona for Developers",
    ]);
  });

  test("a room the viewer cannot see renders nothing", async function (assert) {
    this.site.categories = [ROOMS[0], ROOMS[2]];

    await render(<template><HeaderLinks /></template>);

    assert.deepEqual(
      textsOf(".header-links__link"),
      ["Administración Avanzada", "Gestiona for Developers"],
      "a member outside Analiza never gets a link into its room"
    );
  });

  test("label and href are the category's own", async function (assert) {
    settings.header_room_category_ids = "90";

    await render(<template><HeaderLinks /></template>);

    assert.dom(".header-links__link").hasText("Analítica de datos");
    assert.dom(".header-links__link").hasAttribute("href", ROOMS[1].url);
  });

  test("no visible room renders no nav at all", async function (assert) {
    this.site.categories = [];

    await render(<template><HeaderLinks /></template>);

    assert.dom(".header-links").doesNotExist("an empty nav would still take header space");
  });

  test("an empty setting renders no nav", async function (assert) {
    settings.header_room_category_ids = "";

    await render(<template><HeaderLinks /></template>);

    assert.dom(".header-links").doesNotExist();
  });
});
```

- [ ] **Step 2: Rewrite `test/acceptance/header-links-test.js`**

```js
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import siteFixtures from "discourse/tests/fixtures/site-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

// Where the nav lands in the booted header. Which rooms render, in what order and
// with what label, is covered in test/integration/header-links-test.gjs.
//
// `needs.site` REPLACES the preloaded category list, and /latest's fixture topics
// point at core's fixture categories — so the rooms are appended to that list
// rather than substituted for it.
const CATEGORIES = [
  ...cloneJSON(siteFixtures["site.json"].site.categories),
  { id: 5, name: "Foro del Certificado", slug: "foro-del-certificado", color: "0088CC", text_color: "FFFFFF" },
  {
    id: 90,
    name: "Analítica de datos",
    slug: "foro-analitica-de-datos",
    parent_category_id: 5,
    color: "3AB54A",
    text_color: "FFFFFF",
  },
];

// The band above the header loads this on every route. Stubbed so these tests
// assert on the header alone and never depend on the figures arriving.
function stubAbout(server, helper) {
  server.get("/about.json", () =>
    helper.response({ about: { stats: { users_count: 1240 } } })
  );
}

acceptance("Header links", function (needs) {
  needs.user();
  needs.site({ categories: CATEGORIES });
  needs.pretender(stubAbout);

  needs.hooks.beforeEach(function () {
    settings.header_room_category_ids = "90";
  });

  needs.hooks.afterEach(function () {
    settings.header_room_category_ids = "89|90|91";
  });

  test("renders in the header, in the slot before the icons panel", async function (assert) {
    await visit("/latest");

    assert
      .dom(".d-header .before-header-panel-outlet .header-links")
      .exists("the links live in the header itself");
  });

  test("links the room by its own name and URL", async function (assert) {
    await visit("/latest");

    assert.dom(".header-links__link").hasText("Analítica de datos");
    assert.dom(".header-links__link").hasAttribute("href", /\/90$/);
  });

  test("stays out of the band above the header", async function (assert) {
    await visit("/latest");

    assert.dom(".topbar .header-links").doesNotExist("the band carries figures only");
  });

  test("renders no nav when no configured room resolves", async function (assert) {
    settings.header_room_category_ids = "91";

    await visit("/latest");

    assert.dom(".header-links").doesNotExist();
  });
});
```

- [ ] **Step 3: Update `test/acceptance/topbar-test.js`.** Replace `clearLinkSettings` with a version that clears the new setting, and restore the default wherever it is used as an `afterEach`:

```js
function clearLinkSettings() {
  settings.header_room_category_ids = "";
}
```

In `renders no band even when header links are configured`, replace `settings.academy_url = "https://academy.example.com";` with a room the fixture carries:

```js
    settings.header_room_category_ids = "3";
```

Core's site fixture carries category `3` ("meta"), so exactly one link renders. Keep the `{ count: 1 }` assertion. Change every `needs.hooks.afterEach(clearLinkSettings)` in this file to:

```js
  needs.hooks.afterEach(() => {
    settings.header_room_category_ids = "89|90|91";
  });
```

and keep the explicit `clearLinkSettings()` calls at the top of the tests that need no links.

- [ ] **Step 4: Push the tests alone and watch CI fail (red)**

```bash
git add test/integration/header-links-test.gjs test/acceptance/header-links-test.js test/acceptance/topbar-test.js
git commit -m "test(header): rooms resolved against the viewer's categories"
git push -u origin feat/header-room-links
gh pr create --draft --base main --head feat/header-room-links --title "Header links to the three programme rooms" --body "Draft: red step. Spec docs/superpowers/specs/2026-09-11-cabecera-salas-design.md"
```

Expected: `ci / frontend_tests` FAILS on the new header tests (the component still reads the URL settings, so the integration tests find no links and the topbar test finds none for category 3). `ci / linting` passes. If frontend fails for any other reason — a bundle compile error, unrelated tests — stop and read it.

- [ ] **Step 5: Rewrite `javascripts/discourse/components/header-links.gjs`**

```gjs
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import { parseCategoryIds } from "../lib/category-topics";

// One link per programme room, in the site header beside the search icon.
//
// Each configured id is looked up in `site.categories`, which core scopes to what
// the viewer may see (Site#categories is guardian-scoped, and /site.json on PRE
// carries every category — no lazy loading). So a member outside a room's group
// simply gets no link to it: no permission logic lives here, and nobody is sent
// to an access error. `page-hero` relies on the same fact.
//
// Label and href are the category's own name and URL, never a theme string or a
// hand-built path: a rename or a slug change in admin reaches the header without
// a deploy. The order is the setting's, not the site list's.
export default class HeaderLinks extends Component {
  @service site;

  get rooms() {
    const categories = this.site.categories || [];
    return parseCategoryIds(settings.header_room_category_ids)
      .map((id) => categories.find((category) => category.id === id))
      .filter(Boolean);
  }

  <template>
    {{#if this.rooms}}
      <nav
        class="header-links"
        aria-label={{i18n (themePrefix "header.links.aria_label")}}
      >
        {{#each this.rooms as |room|}}
          <a class="header-links__link" href={{room.url}}>{{room.name}}</a>
        {{/each}}
      </nav>
    {{/if}}
  </template>
}
```

- [ ] **Step 6: Delete `javascripts/discourse/lib/destination-links.js`**

Run: `git rm javascripts/discourse/lib/destination-links.js && grep -rn "destination-links\|destinationLinks" javascripts test`
Expected: no output.

- [ ] **Step 7: Replace the header block in `settings.yml`** — everything from `# --- Header links ---` down to and including `first_steps_url:`'s `default: ""`, with:

```yaml
# --- Header links -----------------------------------------------------------
# One link per programme room, in the site header beside the search icon. Each
# id is resolved against the categories the viewer can see (`site.categories`),
# so a member outside a room's group never gets its link — no permission logic
# lives in the theme. The label is the category's own name and the href its own
# URL, so a rename or a slug change in admin reaches the header with no deploy.
#
# The default is PRE's room ids. The rooms do not exist on PROD yet: set this
# there once they are created — it is part of the category-id parity check that
# gates installing the theme on PROD.
#
# Below lg the nav is hidden; the rooms are in the default sidebar instead.
header_room_category_ids:
  type: list
  list_type: category
  default: "89|90|91"
```

- [ ] **Step 8: Update both locales.** In `locales/en.yml`, delete the three `academy_url` / `demo_url` / `first_steps_url` lines under `theme_metadata.settings` and add, in their place:

```yaml
      header_room_category_ids: "Programme rooms linked from the site header, in order. Each link shows only to members who can see that category, and is labelled with the category's name. Empty hides the links."
```

and replace the `header.links` block with:

```yaml
  header:
    links:
      aria_label: "Certification forums"
```

In `locales/es.yml`, the same three deletions, then:

```yaml
      header_room_category_ids: "Salas de los programas enlazadas desde la cabecera, en orden. Cada enlace solo lo ve quien puede ver esa categoría, y lleva su nombre. Vacío oculta los enlaces."
```

```yaml
  header:
    links:
      aria_label: "Foros de las certificaciones"
```

- [ ] **Step 9: Placement in `stylesheets/app/header.scss`.** Replace the comment above `.header-links` ("Destination links, rendered into `before-header-panel` — between the search field and the user icons.") with:

```scss
// Links to the programme rooms, rendered into `before-header-panel`.
```

In the `@include viewport.until(lg)` comment, replace "the header is already carrying a logo, a search field and the user icons; three more labels push the search down to nothing. They stay reachable from the sidebar, which is where navigation lives on narrow viewports." with "three room names do not fit beside the logo and the icons. The rooms are in the default sidebar, which is where navigation lives on narrow viewports."

Then append, directly after the `.header-links { … }` block:

```scss
// The links sit on the right, beside the search icon.
//
// With `search_experience: search_icon` the search slot between the logo and
// this outlet is empty, and core gives `.panel` `margin-left: auto`, so the
// links would hug the logo. An auto start margin on the outlet alone is not
// enough: with two auto margins on one flex line the free space is split and
// the links float in the middle. So the outlet takes the auto margin and the
// panel gives its own up — only while links render, which `:has()` keeps
// self-limiting.
//
// (0,3,0) against core's `.d-header .panel` at (0,2,0): this outranks core
// rather than tying it, per the cascade note in CLAUDE.md.
.before-header-panel-outlet:has(.header-links) {
  margin-inline-start: auto;

  + .panel {
    margin-inline-start: 0;
  }
}
```

- [ ] **Step 10: Update the initializer's comment** in `javascripts/discourse/api-initializers/before-header-panel.gjs`: replace the paragraph starting "`before-header-panel` sits between the search field and the icons panel" with:

```js
// `before-header-panel` sits between the search slot and the icons panel
// (header/contents.gjs: logo, search, THIS, panel, after-header-panel). With
// `search_experience: search_icon` the search slot is empty and the magnifier
// lives in the panel, so header.scss pushes the links right, beside it.
```

- [ ] **Step 11: Bump `about.json`** `"theme_version": "0.57.0"` → `"0.58.0"`.

- [ ] **Step 12: Lint**

Run: `npx pnpm@10.28.0 lint`
Expected: all five `exited with code 0`. On a failure, `npx pnpm@10.28.0 lint:fix`, then read the diff it made before keeping it (it has rewritten markup before).

- [ ] **Step 13: Commit and push; watch CI go green**

```bash
git add -A javascripts settings.yml locales stylesheets about.json
git commit -m "feat(header): link the three programme rooms, beside the search icon"
git push
```

Expected: all five checks `pass` on the PR. Do not proceed on anything else.

---

### Task 4: Record, merge, pull onto PRE, measure

**Files:**
- Modify: `docs/superpowers/specs/2026-09-11-cabecera-salas-design.md` (append *As executed*), `traceability.md`, `CLAUDE.local.md` (not committed)

- [ ] **Step 1: Append *As executed* to the spec** — what ran, what the verifiers said, the red and green CI runs, and any departure. Append a `traceability.md` entry with the same facts. In `CLAUDE.local.md`: withdraw the third Cloud ask (`max_category_nesting` — superseded, the rooms took the second level), record category 5's new role and children, the header setting, and the instance state to repeat on PROD.

- [ ] **Step 2: Commit, mark ready, wait for green, merge**

```bash
git add docs traceability.md
git commit -m "docs: record the header rooms as executed"
git push
gh pr ready
gh pr checks --watch
gh pr merge --squash --delete-branch
```

Only merge after `gh pr checks` shows all five `pass` for the last commit.

- [ ] **Step 3: Force PRE's pull and read the record**

```bash
set -a && source .env.local && set +a
curl -s -X PUT -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" \
  -H "Content-Type: application/json" -d '{"theme":{"remote_update":true}}' \
  "$PRE_DISCOURSE_URL/admin/themes/15.json" >/dev/null
curl -s -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" \
  "$PRE_DISCOURSE_URL/admin/themes/15.json" | python3 -c "import json,sys; t=json.load(sys.stdin)['theme']; rt=t['remote_theme']; print({k: rt[k] for k in ['remote_compat_ref','local_version','remote_version','commits_behind','updated_at']}); print('header_room_category_ids =', {s['setting']: s['value'] for s in t['settings']}.get('header_room_category_ids'))"
```

Expected: `remote_compat_ref: None`, `local_version` == `git rev-parse origin/main`, `updated_at` after the merge, setting `89|90|91`.

- [ ] **Step 4: Measure the layout on PRE at 1024 and 1280px** with Playwright on `/login` (the header renders there with the real compiled sheet). Inject the component's markup into `.before-header-panel-outlet` with the three real names, then read `getBoundingClientRect()` of the logo, the nav and `.panel`. Pass when: the nav's right edge sits within `--space-4` of `.panel`'s left edge, nothing overlaps the logo, and `document.documentElement.scrollWidth <= innerWidth`. Screenshots, if any, to the scratchpad only.

- [ ] **Step 5: Hand over to Ricardo** what only a signed-in account can check: the three links per membership, the magnifier, the five sidebar links and their icons, and the plaza listing showing only announcements.

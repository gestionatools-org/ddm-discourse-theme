# Header links to the three programme rooms — design

**Date:** 2026-09-11 · **Status:** approved in conversation, awaiting spec review
**Scope:** PRE instance configuration + one theme component. PROD is out of scope and
listed under *Consequences for PROD*.

## Why

The header carries three destination links — Academy, Demo Gestiona, Primeros pasos — and
a full-width search field between the logo and the icons. The genre reorganisation left
the community with three walled programme rooms, one per certification, and nothing in
the chrome that leads to them:

| room | id | walled to |
|---|---|---|
| Administración Avanzada | 89 | `Certificación` (374) |
| Analítica de datos | 90 | `Analiza` (82) |
| Gestiona for Developers | 91 | `Developers` (49) + `AdminDevelopers` (3) |

Ricardo's request: the search collapses behind the magnifier on the right, and the three
links become the three rooms, acting as the sub-forum menu of each certification.

## Decisions, each taken in conversation

1. **The rooms become subcategories of category 5 "Foro del Certificado"**, and that is the
   second and last level. Category 5 finally has a role that matches its name: the forum
   of the certificate, with a room per programme. This also closes the pending note that
   5's name "describes neither its content nor its role".
2. **Category 5's own listing shows only its announcements** — `default_list_filter: none`.
   Each room is entered through its own link.
3. **Academy, Demo Gestiona and Primeros pasos move to the sidebar section "Recursos de
   apoyo"**, and that section's two existing links are renamed so they stop colliding with
   the header.
4. **A member sees only the rooms they can enter.** No link leads to an access error.
5. **The links sit on the right, beside the magnifier**, not next to the logo.

### What was measured to reach them

- **Search is not a theme concern.** `search_experience` is a site setting, `search_field`
  on PRE against core's default `search_icon`. The field vs. the icon is decided there.
- **Nesting.** Core validates `height_of_ancestors + 1 + depth_of_descendants <=
  max_category_nesting`, which is 2 on PRE (hidden; default 2, max 3). Rooms under 5 are
  exactly 2 and have no children: allowed today, without Discourse Cloud.
  **It rules out the earlier plan of hanging 73 under 90**: 5 → 90 → 73 → 73's children is
  4 levels, over the maximum even if Cloud raised it. Decision 1 supersedes that plan, and
  the `max_category_nesting` ask is withdrawn from the Cloud ticket.
- **Permissions.** `Category#check_permissions_compatibility` compares group *presence*,
  not permission level: every group on a child must appear on the parent, at any level.
  Category 5 today holds `Certificación`, `esPublico` and `moderadores`, so `Analiza`,
  `Developers` and `AdminDevelopers` must be added — **read-only (3)** is enough.
  Measured membership: `Developers` 49/49 and `AdminDevelopers` 3/3 are already in
  `Certificación`, so they add nobody. **`Analiza` has 1 member outside `Certificación`,
  who gains read access to the plaza.** Accepted.
- **Visibility is free.** `/site.json` carries all 21 categories the admin key can see —
  no lazy loading (`lazy_load_categories_groups` is hidden, default empty) — and core's
  `Site#categories` is secured by the guardian. So `site.categories` holds exactly the
  rooms a member may enter, with no extra request. `hero_default_category_id` already
  relies on the same fact.
- **Search `#` resolution survives.** `lib/search.rb` matches a bare `#slug` against any
  category and only prefers the top-level one on a tie, so `#foro-analitica-de-datos` keeps
  resolving once it is a subcategory. One change: a non-exact `#foro-del-certificado` will
  include the three rooms, because it adds `subcategory_ids`. Results stay permission-scoped.
- **The sidebar already names two of the rooms, wrongly.** Section 3 "Recursos de apoyo"
  (public) holds `Analítica de Datos` → 73 (link id 16) and `Gestiona for Developers` → 75
  (link id 19). Those are the resource trees, not the rooms the header will name.
- **`default_navigation_menu_categories` is `4|5|14|18|30`, and category 30 does not exist.**

## Design

### 1 · PRE instance configuration (not theme; must be repeated on PROD)

| change | how |
|---|---|
| `search_experience` → `search_icon` | `PUT /admin/site_settings/search_experience` |
| 89, 90, 91 → `parent_category_id: 5` | `bin/categories-reparent`, one room at a time; ids unchanged, no topic moves |
| Category 5 gains `Analiza`, `Developers`, `AdminDevelopers` at read-only | category update resending the full record; must land **before** the reparenting, or core refuses it |
| Category 5 → `default_list_filter: none` | same update |
| "Recursos de apoyo": add Academy, Demo Gestiona (external), Primeros pasos (`/c/primeros-pasos/78`); rename 16 → "Recursos Analítica", 19 → "Recursos Developers" | `PUT /sidebar_sections/3.json` with the **full** links array, ids included — `SidebarSectionUpdater` re-derives order from it and an omitted link jumps to the front |
| `default_navigation_menu_categories` → `4|5|14|18|89|90|91`, with `update_existing_user=true` | drops the non-existent 30. **Without the backfill it reaches no current member**: core creates each user's sidebar links once, at signup (`User#set_default_sidebar_section_links`, `after_create`), so the default only seeds new accounts. `SidebarSiteSettingsBackfiller` adds the new ids to every non-staged user's sidebar — customised ones included — and a room a member cannot see never shows, because the sidebar reads `secured_sidebar_category_ids` |

The Academy and Demo URLs are the values the theme settings hold today on PRE
(`https://espublico.gestiona.academy`, `https://demo-a.gestiona.espublico.com`), read
before the settings are removed. `first_steps_url` held an **absolute PRE URL**, which
would have broken on PROD; the sidebar link uses the relative path instead.

**Icons, chosen from core's default subset: `book-open` (Academy), `desktop` (Demo
Gestiona), `flag` (Primeros pasos)**; the two renamed resource links keep `file`. A sidebar
link requires an icon (`validates :icon, presence: true`), and core does **not** add sidebar
link icons to the sprite: `SvgSprite.all_icons` merges settings, plugin, badge, group, theme
and custom icons plus the default subset, and nothing reads `SidebarUrl`. An icon outside
the subset would render as nothing, silently — the same family as the `dIcon` note in
`CLAUDE.local.md`. Picking from the subset keeps this instance configuration independent of
the theme's `svg_icons` modifier. All five are checked rendering on PRE after the update.

The sidebar is also the path to the rooms on narrow viewports, where the header shows no
links — hence adding the rooms to the default sidebar.

### 2 · Theme: the header

**`javascripts/discourse/components/header-links.gjs`** renders one link per room:

- **Source:** new setting `header_room_category_ids`, `type: list`, default `89|90|91`,
  parsed with the existing `parseCategoryIds` (a `type: list` arrives as a pipe-separated
  string). Replaces `academy_url`, `demo_url` and `first_steps_url`, which are deleted
  together with their locale descriptions.
- **Resolution, at render time:** each id is looked up in `site.categories`. An id the
  user cannot see is simply absent from that list, so it drops out — that is decision 4,
  with no permission logic in the theme. No ids left → no `<nav>` at all.
- **Label:** the category's own name. A category name is instance data, like a topic
  title, not a theme string; reading it means a rename in admin reaches the header with
  no deploy, and it removes the two-names-for-one-thing confusion this community has had.
  The `aria-label` of the `<nav>` stays an i18n key, reworded to "Certification forums" /
  "Foros de las certificaciones".
- **Href:** the category's own URL (`category.url`), never a hand-built path, so a slug
  change cannot break it.

**`lib/destination-links.js`** loses its only consumer and is deleted. Its header comment
already said it was "kept as a unit against the next consumer"; this change is not one.

**Placement — right, beside the magnifier.** The links still render into
`before-header-panel` (between the search slot and `.panel`). With `search_icon` the
search slot is empty, and core gives `.panel` `margin-left: auto`, which on its own would
leave the links hugging the logo. Adding `margin-inline-start: auto` to the outlet alone
is not enough: with two auto margins on one line, flex splits the free space between them
and the links float in the middle. So:

```scss
.before-header-panel-outlet:has(.header-links) {
  margin-inline-start: auto;

  + .panel {
    margin-inline-start: 0;
  }
}
```

The `:has()` guard makes it self-limiting: with no links rendered, core's layout is
untouched. It is tested in the compiled theme sheet on PRE, never from a console-injected
`<style>`, per the cascade note in `CLAUDE.md`.

Below `lg` the links stay hidden, as today. Two of the three labels are long
("Administración Avanzada", "Gestiona for Developers"); the width they need at 1024px is
measured on PRE rather than assumed.

`theme_version` 0.57.0 → **0.58.0**.

### 3 · Verification

- **`bin/categories-verify`** gains: each room's `parent_category_id` is 5; category 5 has
  `default_list_filter: none`; category 5 holds `Analiza`, `Developers` and
  `AdminDevelopers`. Watched failing first, then run after the instance changes.
- **`test/acceptance/header-links-test.js`** is rewritten: one link per configured room
  present in `site.categories`; an id absent from it renders nothing; label and `href`
  come from the category; no rooms → no `<nav>`; the nav lives in `.d-header`, not in the
  topbar. **`test/acceptance/topbar-test.js`** is updated where it sets the old URL
  settings.
- **Layout on PRE at 1024px and 1280px**, measured with `getBoundingClientRect` on the
  real compiled sheet (Playwright on `/login` is enough — the header renders there),
  screenshots to the scratchpad only.
- `npx pnpm@10.28.0 lint`, and CI green **watched before merging** — `--auto` does not
  gate CI from this account.

## Out of scope

- **The resource trees 73 and 75** stay top-level. Their permission faults (`Analiza`
  read-only on 73, the developers with nothing on 75) are unchanged.
- **An active-room state** in the header (`aria-current`). Cheap, not asked for.
- **A dropdown** per room. Rooms have no children, and decision 1 makes them the last
  level, so a link is the whole menu.
- **The wall check from a non-admin account** is still pending and now also covers the
  header: a member outside `Analiza` must not see "Analítica de datos".

## Consequences for PROD

Everything in section 1 is instance state and does not travel with the theme:
`search_experience`, the reparenting, category 5's permissions and list filter, the
sidebar section and the default sidebar categories. **The three rooms do not exist on
PROD yet**, so `header_room_category_ids` must be set to PROD's ids once they are
created — it joins the category-id parity diff that gates installing the theme there.
Until then the default `89|90|91` resolves to whatever PROD holds at those ids, if
anything, and a member only ever sees ids present in their own `site.categories`.

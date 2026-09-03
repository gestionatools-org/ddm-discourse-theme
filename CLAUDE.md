# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **full Discourse theme** (`"component": false` in `about.json`) for an es|public Discourse **Cloud** instance. It is a *remote theme*: the Discourse instance pulls it from `git@github.com:gestionatools-org/ddm-discourse-theme.git`. There is no build step — Discourse compiles the SCSS/JS itself at install time.

**An instance can stop following `main` without anyone touching anything.** On 2026-08-26 a `d-compat/2026.8` branch was cut automatically at 01:08 UTC and PRE moved onto it by itself, freezing at `0.17.0` while six PRs landed on `main`. The workflow that cut it has been deleted — see *Why this repo no longer cuts compatibility branches* under **CI** — but the lesson outlives it: before concluding that anything merged is live on an instance, read that instance's `remote_theme` record rather than trusting its admin page.

Scaffolded from `discourse/discourse-theme-skeleton`, so upstream conventions apply verbatim.

## Read the vendored skills first

`.claude/skills/` contains **Discourse's own authoring skills**, copied from `discourse/discourse-theme-skills`. They are the authoritative spec and far more detailed than this file:

| Skill | Covers |
|---|---|
| `discourse-theme-authoring/SKILL.md` | SCSS architecture, BEM, viewport lib, settings types, modifiers, icons, transformers, testing |
| `discourse-theme-authoring/css-variables.md` | The ~400 core CSS custom properties |
| `discourse-theme-authoring/icons.md` | Default FontAwesome icon subset |
| `discourse-theme-authoring/transformers.md` | Every value/behavior transformer |
| `discourse-block-authoring/SKILL.md` | `@block` decorator, `api.renderBlocks`, outlets, conditions, containers |

Consult them before writing SCSS, a `.gjs` component, or a `settings.yml` entry. Re-sync them from upstream with `./bin/sync-skills` when Discourse ships changes.

## Commands

pnpm is **not** on PATH. Corepack cannot install it — the corporate Fortinet TLS proxy breaks its registry fetch — so always go through `npx` with the pinned version:

```bash
npx pnpm@10.28.0 install        # install devDependencies
npx pnpm@10.28.0 lint           # stylelint + eslint + prettier + ember-tsc, in parallel
npx pnpm@10.28.0 lint:fix       # autofix all of the above
npx pnpm@10.28.0 lint:css       # stylelint only
npx pnpm@10.28.0 lint:js        # eslint only
npx pnpm@10.28.0 lint:types     # glint/ember-tsc only
```

`lint` is the only local gate that matters — it is exactly what CI runs.

### Live development against the Discourse instance

`discourse_theme` (Ruby gem) syncs the working tree to a live site on every save. It needs the Homebrew Ruby, not macOS system Ruby 2.6 — and the **RubyGems executable dir**, which on Homebrew is *not* the same as the Ruby bindir (`/opt/homebrew/opt/ruby/bin` holds `ruby`/`gem`; installed gem binaries land under `$(gem environment gemdir)/bin`):

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$(/opt/homebrew/opt/ruby/bin/gem environment gemdir)/bin:$PATH"
discourse_theme watch .          # first run prompts for site URL + Global-scope API key
discourse_theme watch . --reset  # change site URL or API key
```

**The first run needs a real terminal.** `discourse_theme` drives `tty-prompt`, including arrow-key `UI.select` menus, so it cannot be driven from an agent harness or any non-TTY context: the prompts auto-answer empty, the URL becomes `http://` with a blank host, and the run dies with `EOFError: end of file reached` inside `is_https_redirect?`. Answer the URL prompt with the scheme included (`https://…`) — without it the gem assumes port 80 and takes that same branch.

Once the config holds url + api_key + theme_id, `watch` is fully non-interactive and runs anywhere.

Credentials land in **`~/.discourse_theme`**, a global YAML keyed by project path — *not* in the repo, so `.gitignore` gives no protection (the skeleton's `.discourse-site` entry is vestigial). Never print that file, even redacted. Prefer a staging site or theme-creator.io over production for iteration.

### Tests

`spec/system/core_features_spec.rb` runs Discourse core's shared "core features" examples against the theme. It **only runs inside a Discourse development checkout** (Rails + RSpec + Capybara), not here — CI executes it. When the theme intentionally breaks a core flow (e.g. a custom homepage removes the Create Topic button), narrow it rather than deleting the spec:

```ruby
it_behaves_like "having working core features", skip_examples: %i[topics:create]
```

Valid keys: `login`, `likes`, `profile`, `topics`, `topics:read`, `topics:reply`, `topics:create`, `search`, `search:quick_search`, `search:full_page`.

### CI

`.github/workflows/discourse-theme.yml` calls Discourse's shared reusable workflow (lint + system specs against core). It is the only workflow left: `d-compat-branch.yml` was **deleted on 2026-08-26** for the reason below.

### Why this repo no longer cuts compatibility branches

`d-compat-branch.yml` was deleted on 2026-08-26 after it froze PRE for nine hours. The whole
episode is worth keeping, because the failure is silent and the reasoning is not obvious.

**What the workflow did.** It cut `d-compat/<core-version>` from a fixed base and never
advanced it — the shared workflow's own source says `Branch #{branch} already exists on
origin. Skipping.`, so every later run is a no-op. The 01:08 UTC run on 2026-08-26 logged
`Cutting d-compat/2026.8 from 760df745 (2026-08-25T10:52:10Z)`, the first compat branch this
repo ever had, and `main` was already a commit past that base. **The branch was born behind
and stayed there.**

**How an instance gets captured.** The theme has no branch pinned — `branch: None` on the
`remote_theme` record. Discourse looks for a `d-compat/<its own core version>` branch on the
remote and prefers it over the default branch, recording the result in `remote_compat_ref`.
PRE reported `remote_compat_ref: d-compat/2026.8`, `commits_behind: 0`, `theme_version
0.17.0` — perfectly up to date with a branch nobody chose.

**The version it matches is the *current* one, not an older one.** Discourse's latest tag was
`v2026.8.0` and PRE ran `2026.8.0-latest.1`. So there is no core upgrade that escapes the
branch: it captures every instance, including one that is fully current. An earlier draft of
this note claimed the opposite and it was wrong.

**Why deletion rather than management.** This theme serves instances that track latest core,
and `minimum_discourse_version` in `about.json` already states what it needs. A compat branch
therefore protects nothing here and costs the one thing that matters on a development target:
seeing merged work. Deleting the branch alone would not have held — the nightly run recreates
it, since the condition is "already exists", not "ever existed" — so the workflow had to go
with it.

**What is given up.** If an instance ever has to sit on an older core, the mechanism for that
is `.discourse-compatibility`, which maps core versions to theme commits and is currently
empty (comments only). That is the deliberate, explicit tool; the branch was the implicit one
that fired on its own.

**The symptom, so it is recognisable.** A feature demonstrably on `main` and demonstrably
absent from the site, with no error anywhere. A whole homepage lane failed to appear this way,
and the missing icon it was hunted through was a red herring — neither the lane nor its
`svg_icons` entry existed in the compiled theme. Before concluding anything about what an
instance runs, read its `remote_theme` record:

```bash
curl -s -H "Api-Key: $KEY" -H "Api-Username: $USER" "$URL/admin/themes/<id>.json" |
  python3 -c "import json,sys; rt=json.load(sys.stdin)['theme']['remote_theme']; \
    print({k: rt[k] for k in ['branch','remote_compat_ref','local_version','commits_behind']})"
```

`remote_compat_ref` being non-null means the instance is not following `main`, whatever the
admin page says.

### `commits_behind: 0` is not proof of currency

Same family of failure, met again on 2026-08-27 and worth its own note because the reassuring
number is the one that lies. **A remote theme does not pull when a PR merges.** It pulls when
Discourse next checks, and `commits_behind` reports the result of *that* check — whose time is
in `updated_at`, right beside it.

PRE sat on `149fab6` for two hours reporting `commits_behind: 0`, because its last check ran at
10:46 and the commit that mattered merged at 11:20. In between, a tag was renamed on the
instance and the theme kept filtering the homepage's showcase lane by the old name: **zero
results, no error, an empty lane, and a theme record that said everything was up to date.**

So read `updated_at` alongside `commits_behind`, and force the pull rather than trusting the
number:

```bash
curl -s -X PUT -H "Api-Key: $KEY" -H "Api-Username: $USER" \
  -H "Content-Type: application/json" -d '{"theme":{"remote_update":true}}' \
  "$URL/admin/themes/<id>.json"
```

`POST /admin/themes/<id>/update.json` is a 404 — that route does not exist.

**And a setting written straight onto the instance becomes an override.** Fixing the lane by
`PUT /admin/themes/<id>/setting.json` works instantly and outlives the theme update, but if a
later release changes that setting's default and the instance does not follow, this is why.

## Architecture

### The four layers a theme can touch

1. **`about.json`** — metadata, `color_schemes`, and `modifiers`. Modifiers are the *only* way to change server-side behavior (`serialize_topic_excerpts`, `custom_homepage`, `svg_icons`, `only_theme_color_schemes`, …). If the frontend needs data core doesn't serialize, the fix is a modifier here, not a client-side fetch.
2. **SCSS** — `common/common.scss` is an import manifest and holds **zero rules**.
3. **`javascripts/discourse/`** — Glimmer components + `api-initializers`.
4. **`locales/*.yml`** — all user-visible strings.

### SCSS

```
common/common.scss          → @use "lib/viewport"; then @import "brand"/"app"/"blocks"/"layouts"
stylesheets/brand/          → colors.scss, fonts.scss   (design tokens)
stylesheets/app/            → variables.scss + one file per core surface (header, sidebar, topic-list…)
stylesheets/blocks/         → one file per block component, named after the block
stylesheets/layouts/        → page-level composition (homepage, sidebar-discovery…)
```

Rules that are enforced by review, not by tooling:
- `common.scss` imports **folders only**, never individual files. Each folder's `_index.scss` imports its own files, so adding a file touches exactly one `_index.scss`.
- Only `_index.scss` carries the underscore prefix.
- **Never write a raw media query.** Use `viewport.from(lg)` / `viewport.until(sm)` / `viewport.between(sm, md)`. Breakpoints: `sm` 640px, `md` 768px, `lg` 1024px, `xl` 1280px, `2xl` 1536px.
- BEM with standalone `--modifier` classes (`.topic-card__title.--highlighted`, not `.topic-card__title--highlighted`) and `is-`/`has-` state prefixes. One BEM block per Ember component — **except a shared base**: when several components render the same surface, the root may carry two blocks, a base (`highlight-card`) styled once for the shared chrome and a component-specific block (`highlight-content` / `highlight-podcast` / `highlight-member`) for what differs. The base owns `__body`, `__title`, `__media`, `__cta`, `__placeholder`; the variant blocks add only their own elements. The homepage highlights section is the precedent (`stylesheets/blocks/block-highlights.scss`). Do not reach for this to avoid a modifier — it is for a genuine shared surface across three-plus components, not a single component with states.
- Prefer overriding core CSS custom properties over redeclaring rules. Use `light-dark()` for brand tokens so one token serves both palettes.

#### Test a cascade override in the compiled theme sheet, never from the console

The theme's compiled stylesheet is unlayered and is the **last** `<link>` on the
page, so a theme rule that ties core on specificity **wins**. Measured on PRE
2026-08-28: `body.has-sidebar-page .wrap { max-width: 555px }` inserted into the
theme sheet via `CSSStyleSheet.insertRule` takes effect; core's own rule at the
same (0,2,1) loses.

**The same rule injected as a `<style>` appended to `<head>` loses** — even
though it is later in document order, and even with no `@layer` anywhere on the
page. The mechanism is unexplained. What matters is the consequence: a
console-injected `<style>` is **not** a faithful preview of a theme rule, and
measuring one produced a confident, wrong conclusion about this instance's
cascade that reached a commit message (`0959c2c`). Prototype geometry that way
if it helps — it is how `layout.scss` was designed — but test any rule whose
outcome depends on the cascade by inserting it into the theme's own sheet.

Preferring a selector that outranks core rather than ties it sidesteps the whole
question, and costs one class. `layout.scss` does that.

### JavaScript: prefer Blocks over plugin outlets

Two composition systems coexist:

- **Plugin outlets** (`api.renderInOutlet`) — insertion points that splice into core templates. Mature, ubiquitous, but couple the theme to core template internals.
- **Blocks API** (`api.renderBlocks`) — a declarative layout frame. Blocks are self-contained Glimmer components registered with `@block("theme:espublico:<name>", {...})` and placed into core outlets (`hero-blocks`, `homepage-blocks`, `main-outlet-blocks`, `sidebar-blocks`, `sidebar-discovery`) with declarative `conditions` instead of imperative `if` logic. Discourse runs it in production on Meta and it is where customization is heading, but it is **still marked experimental** — pin `minimum_discourse_version` when relying on it.

**Agreed scope for this theme (hybrid):** Blocks are used for the custom homepage only. Every other surface — topic list, topic view, categories, sidebar, header — is styled with SCSS and adjusted with transformers on top of native layouts. This keeps the experimental surface area contained to one page that can be swapped for a stock homepage if the API shifts. Do not introduce Blocks outside `homepage-blocks` without agreeing it first.

Themes **cannot** register new block outlets — only plugins can.

```
javascripts/discourse/
├── api-initializers/     one file per outlet, named after it (homepage-blocks.gjs)
├── blocks/               block-*.gjs, one component per file
├── components/           Glimmer components rendered into outlets
├── lib/                  shared helpers with no framework dependencies
└── services/             state whose lifetime is the application instance
```

**One outlet per initializer file.** Never call `api.renderBlocks()` for two outlets in the same file.

For cross-cutting behavior that isn't layout, use **transformers** (`api.registerValueTransformer` / `registerBehaviorTransformer`) rather than DOM patching — see `transformers.md`.

### Settings vs. locales — the split that gets violated

`settings.yml` holds **functional configuration only**: URLs, counts, tags, category IDs, filters, feature toggles. Every user-visible **display string** belongs in `locales/en.yml` (+ `es.yml`) and is referenced by i18n key.

In a block initializer this means the string arg is a hardcoded i18n *key*, resolved in the template:

```javascript
// api-initializer
args: { title: "homepage.featured.title", count: settings.featured_count }
```
```handlebars
{{! template }}
{{i18n (themePrefix @title)}}
```

`themePrefix` and the global `settings` object are auto-injected into theme `.gjs` files — no import needed. Core strings skip `themePrefix`: `{{i18n "topic.create"}}`.

Every setting needs a description under `theme_metadata.settings.<name>` in `locales/en.yml` or the admin UI shows a raw key.

### Versioning and compatibility

Bump `theme_version` in `about.json` on user-visible change. `.discourse-compatibility` maps core versions to theme commits so old Discourse versions keep resolving a working commit — needed once the theme depends on APIs newer than the oldest supported core.

## Reference corpus

`.reference/` (gitignored) holds ~19 shallow clones of upstream Discourse themes for grepping real implementations. Regenerate with `./bin/sync-reference`.

Highest-signal ones:

| Theme | Why |
|---|---|
| `discourse-theme-skills` | Official Blocks showcase — the pattern to copy |
| `discourse-central-theme` | Largest modern `.gjs` surface (26 components), block-based sidebar |
| `discourse-air` | Discourse's flagship theme; SCSS-only, color-scheme and bundled-component patterns |
| `discourse-discover-theme` | Custom homepage via `custom_homepage` modifier |
| `discourse-right-sidebar-blocks` | Sidebar block composition |
| `discourse-topic-cards`, `discourse-versatile-banner` | Settings-driven components with `objects` schemas |

The full upstream index (475 themes) lives at `discourse/all-the-themes` — `official.txt` and `third-party.txt` are just lists of repo slugs; clone individually as needed.

## Conventions

- Theme block namespace is `theme:espublico:*`. Changing the theme name means changing every block name.
- Commits, code, comments and identifiers in English; conversation with the maintainer in Spanish.
- Git identity for this repo is set locally to `gestionatools-org` / `desarrollodemedios@espublico.com`; remote is SSH.
- Since `main` is what the production instance pulls, land work through PRs and let CI go green before merging. Since 2026-08-16 this is enforced, not just agreed: `main` requires `ci / linting`, `ci / backend_tests`, `ci / frontend_tests` and `ci / system_tests`, and blocks force pushes and deletion. Two settings are deliberately *off* — no required reviews, because the sole maintainer cannot approve their own PR and requiring one would block every PR; and `enforce_admins: false`, to keep an escape hatch for when Discourse's shared CI workflow breaks, which this repo does not control.
- **A required check that never reports blocks every PR forever.** The CI matrix is built dynamically by `check_for_tests` from `Dir.glob`, so deleting `test/**/*.{js,gjs}` or `spec/system/**/*.rb` would stop `frontend_tests` or `system_tests` from ever reporting. The fix in that case is to drop the context from the branch protection — never to delete the tests to unblock a merge.
- `allow_auto_merge` is on, so `gh pr merge --auto` genuinely waits for the required checks. It did not before the branch was protected: with no required checks GitHub treated every PR as immediately mergeable and `--auto` merged on the spot.

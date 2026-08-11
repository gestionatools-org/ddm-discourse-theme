# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **full Discourse theme** (`"component": false` in `about.json`) for an es|public Discourse **Cloud** instance. It is a *remote theme*: the Discourse instance pulls it from `git@github.com:gestionatools-org/discourse-theme.git`, so `main` is effectively production. There is no build step — Discourse compiles the SCSS/JS itself at install time.

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

`discourse_theme` (Ruby gem) syncs the working tree to a live site on every save. It needs the Homebrew Ruby, not macOS system Ruby 2.6:

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
discourse_theme watch .          # first run prompts for site URL + Global-scope API key
discourse_theme watch . --reset  # change site URL or API key
```

Credentials land in `.discourse-site` (gitignored). Never commit them. Prefer a staging site or theme-creator.io over production for iteration.

### Tests

`spec/system/core_features_spec.rb` runs Discourse core's shared "core features" examples against the theme. It **only runs inside a Discourse development checkout** (Rails + RSpec + Capybara), not here — CI executes it. When the theme intentionally breaks a core flow (e.g. a custom homepage removes the Create Topic button), narrow it rather than deleting the spec:

```ruby
it_behaves_like "having working core features", skip_examples: %i[topics:create]
```

Valid keys: `login`, `likes`, `profile`, `topics`, `topics:read`, `topics:reply`, `topics:create`, `search`, `search:quick_search`, `search:full_page`.

### CI

`.github/workflows/discourse-theme.yml` calls Discourse's shared reusable workflow (lint + system specs against core). `d-compat-branch.yml` runs nightly and cuts compatibility branches automatically — do not hand-edit those branches.

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
- BEM with standalone `--modifier` classes (`.topic-card__title.--highlighted`, not `.topic-card__title--highlighted`) and `is-`/`has-` state prefixes. One BEM block per Ember component.
- Prefer overriding core CSS custom properties over redeclaring rules. Use `light-dark()` for brand tokens so one token serves both palettes.

### JavaScript: prefer Blocks over plugin outlets

Two composition systems coexist:

- **Plugin outlets** (`api.renderInOutlet`) — insertion points that splice into core templates. Mature, ubiquitous, but couple the theme to core template internals.
- **Blocks API** (`api.renderBlocks`) — a declarative layout frame. Blocks are self-contained Glimmer components registered with `@block("theme:espublico:<name>", {...})` and placed into core outlets (`hero-blocks`, `homepage-blocks`, `main-outlet-blocks`, `sidebar-blocks`, `sidebar-discovery`) with declarative `conditions` instead of imperative `if` logic. Discourse runs it in production on Meta and it is where customization is heading, but it is **still marked experimental** — pin `minimum_discourse_version` when relying on it.

Default to Blocks for anything layout-shaped; fall back to outlets when no block outlet reaches the target. Themes **cannot** register new block outlets — only plugins can.

```
javascripts/discourse/
├── api-initializers/     one file per outlet, named after it (homepage-blocks.gjs)
└── blocks/               block-*.gjs, one component per file
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
- Since `main` is what the production instance pulls, land work through PRs and let CI go green before merging.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **full Discourse theme** (`"component": false` in `about.json`) for an es|public Discourse **Cloud** instance. It is a *remote theme*: the Discourse instance pulls it from `git@github.com:gestionatools-org/ddm-discourse-theme.git`. There is no build step — Discourse compiles the SCSS/JS itself at install time.

**Which branch an instance tracks can change overnight, without anyone touching anything.** On 2026-08-26 the first `d-compat/2026.8` branch was cut at 01:08 UTC and PRE moved onto it by itself, freezing at `0.17.0` while six PRs landed on `main`. Before concluding that anything merged is live on an instance, check which branch it actually follows — the theme admin page names it — and read that branch's tip. See *Compatibility branches freeze* under **CI**.

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

`.github/workflows/discourse-theme.yml` calls Discourse's shared reusable workflow (lint + system specs against core). `d-compat-branch.yml` runs nightly and cuts compatibility branches automatically — do not hand-edit those branches.

### Compatibility branches freeze, and an instance can get stuck on one

`d-compat-branch.yml` **creates** a `d-compat/<core-version>` branch and never advances it. The shared workflow's own source is explicit — `Branch #{branch} already exists on origin. Skipping.` — so every later run is a no-op and the branch is a frozen snapshot. That is its purpose.

**The trap is the day it first appears.** Until core rolls a version there is no compat branch, every instance follows `main`, and everything merged reaches them. Then one nightly run cuts the branch, the instance switches to it on its next update check, and from that moment it receives nothing — while its admin keeps reporting "up-to-date", because with respect to that branch it is. Nothing in the repo announces this. The belief "`main` is what the instances run" is true right up until it silently is not.

Measured here on 2026-08-26. The 01:08 UTC run logged `New branch name: d-compat/2026.8` and `Cutting d-compat/2026.8 from 760df745 (2026-08-25T10:52:10Z)` — the first compat branch this repo has ever had. Note the base: `main` was already a commit further along (#30 merged 21:15 the evening before), so **the branch was born behind and stayed there**. PRE picked it up that morning and missed six PRs in nine hours.

This is invisible from the repo. `main` going green and merging says nothing about what any instance is running. The symptom is a feature that is demonstrably on `main` and demonstrably absent from the site, with no error anywhere: a whole homepage lane failed to appear this way, and the missing icon it was hunted through was a red herring — neither the lane nor its `svg_icons` entry existed in the compiled theme.

Diagnose by reading the branch tip rather than trusting the admin:

```bash
git log origin/d-compat/2026.8 --oneline -1
git log origin/d-compat/2026.8..origin/main --oneline   # what the instance is missing
```

Two fixes, and one non-fix:

- **Point the instance at `main`.** Immediate. If the admin will not change the branch in place, the remote has to be reinstalled — record the instance's theme settings first, since reinstalling can drop them.
- **Bring the instance's core up to date.** Structural: the branch only captures an instance whose core is a version behind. A development target that lags production cannot do its job.
- **Do not delete the branch.** It is recreated by the next nightly run — the condition is "already exists", not "ever existed" — so deleting buys one day and loses the audit trail. This is why the rule above says never to hand-edit these branches.

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

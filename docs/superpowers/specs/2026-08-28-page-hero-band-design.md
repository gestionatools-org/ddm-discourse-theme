# Page hero — a heading band above every listing

**Date:** 2026-08-28
**Status:** agreed 2026-08-28. Not implemented.
**Ships as:** `theme_version` 0.25.0
**Reference:** `community.hubspot.com`, the same site `layout.scss` already models the
application shell on.

A band at the top of every listing page carrying a title, a subtitle and one action —
*Hacer una pregunta* — which opens the composer. On the homepage it carries fixed
community copy; on a category page it carries that category's own name and description;
on a generic listing it falls back to the homepage copy.

## Scope

**In:** the custom homepage, all 17 category pages, `/latest`, `/top`, `/unread`, and tag
listings.

**Out:** topic pages, and the full-page search results. Search was raised during design
and deliberately excluded: that page already renders its own heading with the search
field, and a 200px band above it pushes the results down at the exact moment the user's
intent is most specific. The maintainer was told and did not object.

## Why this is not a homepage block

The first framing of this work was a hero for the homepage alone, which would have been a
seventh lane in `homepage-blocks`. The maintainer corrected it: the band belongs to the top
of *pages*, and every category needs one too.

That correction is what makes this architectural rather than bounded. It moves the feature
across the line drawn on 2026-08-11 and recorded in `CLAUDE.md` — **Blocks stay confined to
the custom homepage; every other surface is a plugin outlet plus SCSS.** This design honours
that line rather than crossing it: the listings are served by a plugin outlet, and the only
Block involved is the one that reaches the homepage, which has no other way in.

## Why the homepage needs a second mounting point at all

`custom_homepage: true` means the homepage is its own route and does not render the
discovery outlets. There is no single outlet that reaches both it and the category pages,
so one component is mounted twice. The alternative — mounting once, somewhere high, and
filtering by route name — was considered and rejected under *Approaches* below.

## Approaches considered

**A. One component, two mounting points.** *Chosen.* A single `PageHero` mounted into the
discovery outlet for listings and wrapped in a Block for the homepage. Content is derived
from route state by a pure function both mounts share, so the two surfaces cannot drift
apart. The discovery mount receives the category as an outlet argument rather than looking
it up.

**B. One high mount, filtered by route.** Rejected. It trades declarative data for
imperative logic: route names enumerated by hand, and the category read from a service
instead of received. Its failure mode is the decisive objection — if core renames a route,
the band disappears from that page **with no error anywhere**. That is the exact shape of
failure this repo has already paid for twice, in the `d-compat/2026.8` branch that froze PRE
for nine hours and in the showcase lane that filtered on a renamed tag and rendered empty.

**C. Re-enable core's welcome banner and style it.** Rejected: it does not meet the
requirement. It is a front-page banner whose copy is managed through translation overrides,
not per category. This was **not verified against core** — `context7` confirms only that
`enable_welcome_banner` is a themeable site setting — but even the most favourable reading
gives no per-category text, which is the whole point of the feature.

## Components

Four pieces, each with one responsibility and testable on its own.

| File | Responsibility |
|---|---|
| `javascripts/discourse/lib/hero-content.js` | Pure function `heroContentFor({ category, tag, routeName })` → `{ title, subtitle, category }`. Decides *what it says*. No framework, no DOM — the same shape as the existing `lib/category-topics.js`. |
| `javascripts/discourse/components/page-hero.gjs` | Presentational. Takes `title`, `subtitle` and an optional `category`; renders the band and the button. Injects the `composer` service. Does not know which page it is on. |
| `javascripts/discourse/api-initializers/<outlet>.gjs` | Mounts the component into the discovery outlet, passing `@outletArgs.category` and `@outletArgs.tag`. Named after the outlet, like the two initializers already in the repo. |
| `javascripts/discourse/blocks/block-hero.gjs` | Thin wrapper over `PageHero` carrying the homepage copy. First entry of `homepage-blocks`. |

The split that matters: **`lib` decides what it says, the component decides how it looks,
and the two mounts only decide where it appears.** If the homepage ever stops being custom,
the Block is deleted and nothing else is touched.

### The one open question

**The exact name of the discovery outlet is not yet known.** `discovery-list-container-top`
is documented and does receive the category, but it sits *inside* the list container, and
the band has to span the content column. There is no usage of any such outlet across the 19
themes in `.reference/`, and `context7` does not enumerate the outlets above the list.

Resolve it with Discourse's developer toolbar on PRE, which paints the available outlets
over the page and shows each one's arguments. **This does not change the design** — the
component is identical wherever it hangs; only the initializer's filename and its one
`renderInOutlet` argument depend on the answer.

## Content resolution

| Context | Title | Subtitle | Button category |
|---|---|---|---|
| Homepage | `hero.home.title` | `hero.home.subtitle` | none |
| Category | `category.name` | `category.description_text` | **that category** |
| Tag | `hero.tag.title` interpolated with the tag | `hero.tag.subtitle` | none |
| `/latest`, `/top`, `/unread` | `hero.home.title` | `hero.home.subtitle` | none |

The homepage copy, given by the maintainer verbatim:

- **Title:** *Seguimos aprendiendo juntos*
- **Subtitle:** *Comparte tus ideas o recibe consejos de otros usuarios certificados*
- **Button:** *Hacer una pregunta*

English translations go in `en.yml` alongside them, as every string in this theme does.

### Four decisions inside that table

**`description_text`, not `description`.** The latter is HTML cooked from the category's
definition post; the former is plain text. Using the plain field keeps foreign markup out of
the band.

A known consequence: that field can carry `:emoji:` shortcodes, the problem that made
`block-news` print `:automobile:` as words.

**The right helper here is `dReplaceEmoji`, not the `emojiUnescape` that fixed the news
lane** — corrected 2026-08-28, while writing the implementation plan. The two are not
interchangeable and the discriminator is what the field already contains. An `excerpt` is
HTML-encoded text, so escaping it again double-encodes and prints `&rsquo;` verbatim, which
is why the news lane needs `emojiUnescape`. `description_text` is **plain** text, so it must
be escaped before substitution — exactly what `dReplaceEmoji` does. `block-library.gjs:65`
already applies it to `category.name` for the same reason.

**No description means no subtitle.** The band never invents filler and never repeats the
name as its own subtitle.

**Clamping is CSS, never data.** `line-clamp: 2` on the subtitle. Category 85 *Comparte*
carries 414 characters and renders correctly with nobody rewriting anything in admin, while
the full description goes on serving the native categories page.

**Generic listings share the homepage copy.** `/latest` is not a category and has no
identity of its own; inventing one would be filler.

### Measured: 5 of 17 categories have no description at all

Read from PRE over the API on 2026-08-28. This is why the content question was not answered
"read it from the category" without qualification — the empty ones are the highest-traffic
categories on the site.

| Empty (0 chars) | With a description |
|---|---|
| 3 Administradores, 4 Noticias, 5 Foro del Certificado, 14 Aula de formación, 59 Eventos | 18 (235), 73 (215), 75 (51 — near-empty), 78 (251), 79 (134), 80 (146), 81 (116), 82 (139), 83 (176), 84 (117), 85 (414), 88 (138) |

**Admin task, and it is the maintainer's, not the theme's:** write descriptions for
categories 4, 5, 14 and 59. Category 3 is staff-only and category 75 already has a short
one. Until then those bands render title-only, which is correct behaviour, not a bug. The
text also improves the native categories page, so it is worth doing regardless of this band.

## Edge cases

**Creation permission — the one that matters.** The button renders only when the user can
create a topic in the current context: the global check (`currentUser.can_create_topic`) and,
where there is a category, that its permission allows writing.

**This cannot be measured with the API keys we hold.** `/categories.json` returns the
permission *of the key's user*, who is an admin and sees write access everywhere. What a
normal member sees can only be read in admin — the same gap `CLAUDE.local.md` already
records for category permissions and the tag vocabulary. So the code performs the right
check, but **which categories actually fall on the "no button" side has to be confirmed on
PRE with a non-admin account**. Expected: category 3, and plausibly the documentary
*Recursos Analítica* tree.

**Anonymous users.** The instance is `login_required`, so in practice this does not arise,
but the component must not throw on a null `currentUser`. The guard is cheap and the cost of
omitting it is an exception on the only page a signed-out visitor reaches.

**Navigation without a reload.** Moving between categories does not remount the component.
Receiving the category through `@outletArgs` lets autotracking update it — which is a
concrete reason approach B was worse, since reading from a service would mean subscribing by
hand.

**Two bands on the homepage.** With `custom_homepage: true` the homepage does not go through
discovery, so the Block and the outlet should never both fire. *Should* is not *checked*:
this is the first thing to verify on PRE, because the symptom would be visible and absurd.

**Subcategories** show their own name and description, not the parent's. The seven children
of 73 all have descriptions, so they render complete.

**Tags.** A raw tag name is a slug and reads badly as a headline — `poster-evf`. The title
goes through a locale string with interpolation instead: *"Temas etiquetados %{tag}"*.

## Visual

Edge to edge of the **content column**, not of the window. That keeps the band clear of the
measure cap and avoids a cascade fight. If full-bleed is ever wanted, the rule must be tested
by inserting it into the theme's own compiled sheet — a `<style>` appended to `<head>` from
the console is not a faithful preview and has already produced a confident, wrong conclusion
that reached a commit message (`0959c2c`).

Every colour comes from the brand ramps in `stylesheets/brand/colors.scss`; none is invented.

| Element | Token | Contrast |
|---|---|---|
| Background | `--ga-petrol-800` → `--ga-petrol-700` gradient; `--ga-petrol-950` → `--ga-petrol-900` in dark, via `light-dark()` | — |
| Title | `--ga-neutral-0`, Roboto Slab | 5.94:1 |
| Subtitle | `--ga-petrol-100` | 5.00:1 |
| Button | fill `--ga-mark`, ink `--ga-petrol-950` | 6.81:1 |

The cyan is a fill here, not text on a light surface, so it does not violate the constraint
in `colors.scss` that brand cyan scores 2.48:1 on white. *"La marca no se diluye en oscuro:
se enciende."*

**The three ratios were computed against the ramp values during design and must be
re-validated during implementation before the PR.** They are stated to be checked, not
trusted.

Radius 20, the system's large step. `stylesheets/blocks/page-hero.scss` plus its line in
`_index.scss`. BEM with standalone modifiers. Mobile via `viewport.until(sm)` for padding
and type size — no raw media queries.

## Testing

**Unit, on `hero-content.js`** — the bulk of it, and it needs no DOM: category with a
description, category without one, tag, homepage, generic listing.

**Integration, on `page-hero.gjs`** — renders title and subtitle; **hides the button without
permission**; clicking it calls `openNewTopic` with the right category.

Two cautions this repo has already paid for, respected from the start rather than
rediscovered: declare any new Block arg *inert* before honouring it, and export a stub before
importing it. An undeclared arg aborts the whole QUnit run with an uncaught `BlockError`, and
a missing export hard-fails the Rollup bundle — in both cases the red step reports nothing at
all. Since QUnit only runs in CI (~4 minutes a cycle), the red step goes in one push rather
than test by test.

**Manual verification on PRE**, which is where the three risks no test covers actually live:

1. No double band on the homepage.
2. The button genuinely absent in a read-only category, **checked with a non-admin account**.
3. Appearance at 390px.

Category listings are unguarded by CI — `skip_examples` takes `topics:read`, which removes
"lists topics for a category" — so item 1 and item 3 have no net but the maintainer's eyes.

## Delivery

`npx pnpm@10.28.0 lint` locally, `theme_version` to 0.25.0, branch and PR, CI green before
merge. `main` is what PRE pulls and the theme is the only one installed there, so every merge
lands on every user.

## API note

`this.composer.openNewTopic({ title, body, category, tags })` is the current API, confirmed
against core: the older `createNewTopicViaParams` on the application route is deprecated and
delegates to it.

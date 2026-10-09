# Poster carousel in Comparte — design

**Date:** 2026-10-09 · **Status:** approved in conversation, spec pending review
**Scope:** theme only (component, lib, SCSS, settings, locales, tests). Backfilling images
for PDF-only posters is a **separate task** with its own plan — see *Out of scope*.

## Why

Every newly certified user's poster is published as a topic tagged `poster-evf` inside
the subcategories of **Comparte**. Today they are rows in a topic list: the poster itself,
the one visual object each topic exists for, is never seen until the topic is opened.

## Decisions, each taken in conversation

1. **Approach 1 of three:** an own Glimmer component with a native CSS `scroll-snap`
   track and core's lightbox. Rejected: a CDN carousel library (Swiper/Glide — runtime
   dependency in a repo with no build step) and Topic List Thumbnails in `grid` mode
   (a grid that replaces the list, no lightbox).
2. **Where:** on Comparte (`/c/85`) with every poster of its subtree, **and** on each
   subcategory (`/c/94`, `/c/83`, `/c/93`) with only its own.
3. **Order:** by topic creation date, newest first (`order=created`), not by last activity.
4. **Click:** the image opens a full-screen lightbox; the title below it links to the topic.
5. **12 posters at most, no autoplay.**
6. **PDF-only posters are not shown.** Only topics with an `image_url` qualify; from now on
   posters are to be uploaded as images too (editorial rule, outside the theme).

## Measured on PROD, 2026-10-09 (read-only)

- Comparte = category **85**; children **94** Administración Avanzada, **83** Analítica de
  datos, **93** Gestiona for developers. PRE ids differ — never assume parity.
- `poster-evf`: 188 topics site-wide, 176 inside Comparte's children, 12 in category 88.
- **Only 39 of Comparte's 176 have an `image_url`** — the rest attach the poster as a PDF,
  which Discourse does not thumbnail.
- `/c/<id>/l/latest.json?order=created&tags[]=poster-evf` works: every topic returned
  carries the tag, the list is sorted by `created_at` descending, and every topic with an
  `image_url` also carries `thumbnails`. A parent's listing includes its children's topics.

| Category | `poster-evf` seen in 5 pages | with image | with image on page 1 |
|---|---|---|---|
| 85 | 150 | 38 | 13 |
| 94 | 143 | 24 | 12 |
| 83 | 20 | 12 | 12 |
| 93 | 15 | 3 | 3 |

- Core's lightbox (`discourse/lib/lightbox`, PhotoSwipe) takes a container element and
  binds every `.lightbox` anchor inside it (`SELECTORS.DEFAULT_ITEM_SELECTOR`), so the
  carousel only has to render `<a class="lightbox" href=…>`.

## Architecture

| Unit | Responsibility |
|---|---|
| `javascripts/discourse/lib/posters.js` | Pure functions, no Ember. `pickPosters(topics, { limit, excludeIds })` keeps topics with `image_url`, drops category definition topics, caps at `limit`. `posterImage(topic)` returns the carousel source: the narrowest `thumbnails` entry at least 360px wide (a ~180px slide at 2× density; on PROD that is the 424×600 rendition), else `image_url`. `loadPosters(store, categoryId, options)` pages the listing. |
| `javascripts/discourse/components/poster-carousel.gjs` | Takes `@category`. Decides whether to render, loads, renders the strip, binds the lightbox, drives the prev/next buttons. |
| `javascripts/discourse/api-initializers/discovery-list-controls-above.gjs` | Renders `<PosterCarousel @category={{@outletArgs.category}} />` after the existing `DiscoveryHero`. Same outlet, same file — one outlet per initializer holds. |
| `settings.yml` | `poster_carousel_category_ids` (list, default `85\|94\|83\|93`), `poster_carousel_tag` (string, `poster-evf`), `poster_carousel_count` (integer, 12), `poster_carousel_min` (integer, 3). Ids are settings because PRE and PROD ids differ. |
| `locales/en.yml`, `locales/es.yml` | Heading ("Nuevos usuarios certificados"), prev/next aria labels, a description for each setting under `theme_metadata.settings`. |
| `stylesheets/app/poster-carousel.scss` | BEM block `poster-carousel`: `__header`, `__title`, `__track`, `__item`, `__media`, `__caption`, `__nav`. Imported from `stylesheets/app/_index.scss` (the component is not a Block, so it does not belong in `blocks/`). |

`parseCategoryIds` (`lib/category-topics.js`) parses the list setting; `definitionTopicIds`
from the same file supplies `excludeIds`. No new helper duplicates either.

## Data flow

1. **Origin.** The outlet passes `category`. If its id is not in
   `poster_carousel_category_ids`, the component renders nothing and makes no request.
2. **Transport.** `store.findFiltered("topicList", { filter: "c/<id>/l/latest", params: {
   order: "created", tags: [poster_carousel_tag] } })`. If the page yields fewer than
   `poster_carousel_count` posters and the list has more pages, load the next one, up to a
   hard cap of **5 pages** (~150 topics). On PROD today this is one request for 85, 94 and
   83.
3. **State.** A `@cached` getter returning the load's promise, handed to core's
   `<DAsyncContent>`; no service. The getter reads the category id, so moving between
   categories yields a new promise, and `DAsyncContent` renders only the current one —
   a response for a category that is no longer current is never shown. (`@context` is
   not used: the pinned `@discourse/types` predate it and PRE runs 2026.8.)
4. **Consumption.** Each slide shows `posterImage(topic)`; its lightbox anchor points at
   `image_url` (the optimised ~723×1024 rendition), with the topic title as caption.

## Interface

- A horizontal strip below the hero band, above the category's nav tabs, headed
  "Nuevos usuarios certificados".
- Slides keep the poster's portrait ratio (`aspect-ratio: 723 / 1024`, `object-fit: cover`),
  title clamped to two lines below, linking to the topic.
- Visible at once: ~2.3 under `md`, 4 from `md`, 6 from `xl` — via `viewport.from()`,
  never a raw media query. The partial slide signals that the strip scrolls.
- `overflow-x: auto` + `scroll-snap-type: x mandatory`: touch and trackpad work natively.
  Desktop gets ‹ › `DButton`s that `scrollBy` one viewport width; each is disabled at its end
  (state from the track's `scroll` event).
- Only the image opens the lightbox; the lightbox gallery walks the carousel's posters.
- Theme tokens only (`--ga-border`, `--ga-shadow-lane`, radii), `light-dark()` where a
  colour is new, so it serves both palettes.

## Accessibility

- `<section aria-labelledby>` around a `<ul>` of `<li>`. No live region — nothing moves on
  its own.
- Each image's `alt` is the topic title. The buttons carry translated `ariaLabel`s.
- Tab order is the natural link order; the track scrolls the focused slide into view.
- `prefers-reduced-motion: reduce` drops smooth scrolling.

## Edge cases

| Situation | Behaviour |
|---|---|
| Category not listed | Renders nothing, no request. |
| Fewer than `poster_carousel_min` posters (93 today has exactly 3) | Renders nothing. |
| Network error / 403 | Renders nothing; the topic list below is unaffected. |
| Fast navigation between categories | Stale responses discarded. |
| Topic without `thumbnails` | Falls back to `image_url`. |
| Protected topic /t/2683 | Unaffected: the carousel only reads. |

## Testing

- `test/unit/posters-test.js`: `pickPosters` drops topics without an image, excludes
  definition topics, respects `limit`; `posterImage` prefers the narrowest thumbnail ≥360px and falls
  back to `image_url`.
- `test/integration/poster-carousel-test.gjs` with pretender-stubbed listings: unlisted
  category renders nothing and requests nothing; below the minimum renders nothing; 12
  posters render with lightbox anchors and topic links; pagination stops at the count or
  at 5 pages; a stale response after a category change is ignored.
- `npx pnpm@10.28.0 lint` green; CI's four required checks green before merging.
- Browser verification on PRE after reconciliation (below).

## Prerequisite: reconcile PRE to PROD first

Per `CLAUDE.md`, the first task of the plan diffs PROD against PRE
(`docs/operations/environment-reconciliation.md`) and reconciles PRE. Known gaps:

- The **Topic List Thumbnails** component (PROD theme 15, child of 14, `default_thumbnail_mode
  = grid`) is not installed on PRE. Note that **PROD 15 is that component while PRE 15 is
  our theme** — record this in `docs/operations/current-state.md`.
- PRE's categories 93/94 are not PROD's; PRE's `poster_carousel_category_ids` must be set
  to PRE's own Comparte ids.
- PRE needs `poster-evf` topics with images under those categories to verify against.

## Versioning

`theme_version` 1.5.0 → **1.6.0** (user-visible minor).

## Out of scope

- **Backfilling images for the ~137 PDF-only posters** — a bulk write on PROD (convert each
  PDF's first page to JPG, append it to the first post). Separate plan, with prior-state
  capture, a wiki/bump check per topic and Ricardo's explicit approval of the batch.
- Topic List Thumbnails' site-wide `grid` default — a separate decision.
- Any surface outside Comparte; autoplay; infinite loop.

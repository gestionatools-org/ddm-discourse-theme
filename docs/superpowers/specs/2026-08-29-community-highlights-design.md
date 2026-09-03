# Community highlights — a fourth homepage section

**Date:** 2026-08-29
**Status:** agreed 2026-08-29. Not implemented.
**Ships as:** `theme_version` 0.36.0
**Reference:** `community.hubspot.com`, the same site the homepage's section layout already models.

A bento section below section 1 (latest · agenda · ideas) carrying four cards:

| Card | Source | Shape |
|---|---|---|
| **Podcast** | latest topic tagged `podcast` | 16:9 YouTube thumbnail; a play button swaps it for an embedded `<iframe>` that plays in place |
| **Newsletter** | latest topic tagged `newsletter` | tall portrait card: cover image (or branded placeholder) + title + 2-line excerpt + CTA |
| **Novedad de Gestiona** | latest topic tagged `nueva-version-gestiona` | small card: label + title + CTA, no image |
| **Miembro del mes** | `/directory_items.json?period=monthly` re-ranked client-side | small card: avatar + name + "Member of the month" badge + raw figures |

The layout (option A of three mocked in the visual companion, 2026-08-29):

```
> 56rem container                        base / < 40rem
┌─────────┬───────────────────┐          ┌───────────────────┐
│         │ PODCAST (16:9)     │          │ NEWSLETTER (tall) │
│ NEWS-   ├─────────┬─────────┤          ├───────────────────┤
│ LETTER  │ NOVEDAD │ MIEMBRO │          │ PODCAST (16:9)    │
│ (tall)  │         │         │          ├───────────────────┤
└─────────┴─────────┴─────────┘          │ NOVEDAD           │
                                          ├───────────────────┤
grid-template-areas:                      │ MIEMBRO           │
  "news podcast podcast"                  └───────────────────┘
  "news novedad miembro"
```

## Scope

**In:** the custom homepage only. One new Block registration (`theme:espublico:highlights`),
placed in `homepage-blocks` after the `home-latest` group.

**Out:** every other surface. This stays inside the line drawn on 2026-08-11 — Blocks are for
the custom homepage and nothing else. Nothing here touches a category page, the sidebar, or
the header.

**Not this feature's job:** tag hygiene on the instance, cover images on the source topics,
and creating the `nueva-version-gestiona` tag. Those are admin tasks, listed at the end.

## Why approach 3 — a thin container block over pure helpers

Three approaches were weighed:

**1. One monolithic `BlockHighlights`.** The block owns the grid *and* runs all five fetches,
with card bodies as local `<template>` consts. Rejected: a ~300-line file running five
different fetches, and the two genuinely tricky pieces — YouTube video-ID extraction and the
composite member ranking — buried where no test can reach them without a DOM.

**2. A `BlockGroup` of four independent registered blocks**, like the panel (events + ideas).
Rejected: four block registrations plus four SCSS files, and the three content cards share
~80% of their logic — so it is either three near-identical blocks (a DRY violation) or a
shared component extracted anyway. The asymmetric bento is also awkward to express over
`BlockGroup` children.

**3. A thin container block + presentational components + a pure lib.** *Chosen.* One new
Block registration. The block renders the section frame and the bento grid; each cell is its
own `<DAsyncContent>` so the five fetches load and fail independently. The two hard pieces
live in `lib/highlights.js` as framework-free functions with unit tests — the same split
`lib/hero-content.js` and `lib/category-topics.js` already use, and the one the page-hero
design named explicitly: *the lib decides what it says, the component decides how it looks.*

## Architecture

### The one initializer change

`javascripts/discourse/api-initializers/homepage-blocks.gjs` gains a third top-level entry
after the `home-latest` group:

```js
{
  block: BlockHighlights,
  id: "home-highlights",
  args: {
    title: "homepage.highlights.title",
    podcastTag: settings.highlights_podcast_tag,
    newsletterTag: settings.highlights_newsletter_tag,
    newsTag: settings.highlights_news_tag,
    memberPeriod: settings.highlights_member_period,
  },
}
```

No `homepage.scss` change. The section is one more flex child of `.homepage-blocks__layout`,
which already separates sections with `gap: var(--space-12)`; `&__block, &__block-container`
already carries the `min-width: 0` a grid child needs. The bento grid lives entirely in
`stylesheets/blocks/block-highlights.scss`, targeting `.block-highlights__grid`.

### Files

| File | Responsibility |
|---|---|
| `javascripts/discourse/blocks/block-highlights.gjs` | The block. The section heading and the bento grid with four cells, each cell its own `<DAsyncContent>`. Holds a local `<template>` const `ContentCard` for the newsletter and novedad cards. ~150 lines. (The section is a full-bleed band, not a framed lane — see **Layout**, revised 2026-09-03.) |
| `javascripts/discourse/components/highlight-podcast-card.gjs` | The 16:9 card. `@tracked playing`. Not playing: `<img>` YouTube thumbnail + a play `<button>`. Playing: `<iframe>` `youtube-nocookie.com/embed/<id>?autoplay=1`. No `videoId`: the thumbnail is an `<a>` to the topic, no button. |
| `javascripts/discourse/components/highlight-member-card.gjs` | Avatar (core's `avatar` helper) + name + `star` badge + a line of raw figures. Links to `/u/<username>/summary`. Also renders the "post to show up here" CTA when handed no eligible member. |
| `javascripts/discourse/lib/highlights.js` | Framework-free: `loadLatestTaggedTopic`, `extractVideoId`, `youtubeThumbnail`, `rankTopMember`, `memberHasActivity`, plus the `WEIGHTS` const. |
| `stylesheets/blocks/block-highlights.scss` | The bento grid, its two breakpoints, and the four card treatments. One line added to `stylesheets/blocks/_index.scss`. |
| `test/unit/highlights-test.js` | The pure functions. |
| `test/integration/homepage-highlights-test.gjs` | The block, through `<BlockOutlet>`. |

## Layout

`stylesheets/blocks/block-highlights.scss`. **Revised 2026-09-03** after visual review:
the section does NOT wear `lane-frame`. It is a full-bleed band — the same treatment
`app/page-hero.scss` gives the heading band and every category header — so that section 2
reads as a distinct zone rather than a fourth framed lane.

- **The band.** `background` + a `box-shadow: 0 0 0 100vmax` spread + `clip-path: inset(0
  -100vmax)`, lifted verbatim from `.page-hero`: the paint bleeds edge-to-edge, it answers to
  the box rather than the window so it is exact at every width, and it creates no scrollable
  overflow (`container-type: inline-size` on `.homepage-blocks` was already checked not to
  clip the identical hero bleed). Surface: `--ga-muted` — the same fill `app/page-hero.scss`
  gives the hero band and every category header. (A `--ga-accent-surface` cyan tint shipped
  briefly in #79 and was reverted the same day, 2026-09-03: the maintainer wanted the band
  to match the hero exactly, not carry its own colour.)
- **The heading.** No `lane-header`, no `lane-title` — no filo edge, no hairline, no icon,
  because a category header carries none. `.block-highlights__title` takes the
  `.page-hero__title` treatment instead: Roboto Slab (`--ga-font-slab`), `--font-up-4`,
  `--primary` ink; `--font-up-2` below 40rem. The `{{dIcon "star"}}` is removed from the
  block template.
- **Even air.** A single `--highlights-air` custom property drives the band's `padding-block`
  *and* the header's `margin-bottom`, so the gap above the title, the gap between the title
  and the cards, and the gap below the cards are provably equal — `--space-12` on desktop,
  `--space-8` below 40rem, both symmetric.
- **The grid is unchanged** from the original design: `--count-4` bento at `> 56rem`, 2×2 at
  `> 40rem`, a single stacked column below (`grid-template-columns: repeat(auto-fit,
  minmax(min(100%, 16rem), 1fr))`). `news` spans two rows at the widest step (the tall
  newsletter image), `podcast` spans two columns (the 16:9 video), `novedad` and `miembro`
  are the twin small cards. **The `grid-area` assignments live inside the `> 40rem` /
  `> 56rem` container queries** — a fix from 2026-09-03: unconditional `grid-area` values
  naming areas that only exist inside those queries minted implicit grid lines that stacked
  all four cards into one overlapping pile below 40rem.
- **The cards themselves are untouched** — white `--ga-card` surfaces with a border, sitting
  on the band. "Los 4 bloques integrados en el fondo con los contenedores tal como están."

## Data flow

Four cells, each its own `<DAsyncContent>`, all fired in parallel — five requests in total,
since the podcast cell makes two in sequence. No memoisation service: the homepage renders
once and `<DAsyncContent>` does not refetch on re-render. (The `site-stats` service exists
only because the topbar renders on every listing.)

### Newsletter and Novedad — identical

```js
loadLatestTaggedTopic(store, tag)
  → store.findFiltered("topicList", { filter: `tag/${tag}/l/latest` })
  → drop category definition topics (definitionTopicIds())
  → topics[0] ?? null
```

Fields read: `fancy_title`, `excerpt` (available — `serialize_topic_excerpts` is on),
`image_url` (often `null` → branded placeholder), `created_at`, `id` + `slug` → `/t/<slug>/<id>`.

**To confirm in implementation:** that the store's `topicList` adapter accepts a
`tag/<slug>/l/latest` filter and builds `/tag/<slug>/l/latest.json`. If it does not, the
drop-in fallback is `ajax("/tag/<slug>/l/latest.json")` reading `.topic_list.topics` —
already verified live against PRE (`podcast` → 6, `newsletter` → 29).

### Podcast — two steps in one async

```js
1. const topic = await loadLatestTaggedTopic(store, podcastTag);
2. const { cooked } = (await ajax(`/t/${topic.id}.json`)).post_stream.posts[0];
3. return { topic, videoId: extractVideoId(cooked) };   // videoId may be null
```

Thumbnail: `youtubeThumbnail(videoId)` = `https://i.ytimg.com/vi/<id>/hqdefault.jpg`.
No `videoId`: `topic.image_url` or the placeholder, and the card links to the topic with no
play button.

### Member

```js
const { directory_items } = await ajax(
  `/directory_items.json?period=${memberPeriod}&order=likes_received&limit=50`
);
const top = rankTopMember(directory_items, WEIGHTS);
return memberHasActivity(top) ? top : null;   // null → the card renders the CTA
```

`limit=50` is honoured on this instance (verified live); `?page=0` is the documented
fallback. The `order` is immaterial — `rankTopMember` re-ranks — so `likes_received`, the
directory's own default, is fine. Fifty rows is ample headroom for a community this size to
contain every plausible top-composite candidate.

Verified live against PRE: `/directory_items.json` returns items shaped
`{ id, topic_count, post_count, likes_received, likes_given, days_visited, user{...} }`.
**`time_read` is not in this Discourse version's serializer** — the third ranking factor is
`days_visited` (constancy), not reading time.

## The pure functions — `lib/highlights.js`

### `loadLatestTaggedTopic(store, tag)`

Returns the most recent non-definition topic carrying `tag`, or `null`. Empty `tag` returns
`null` without touching the network (the guard that keeps an unset setting from becoming
`tag/""/l/latest`). Reuses `definitionTopicIds()` from `lib/category-topics.js`.

### `extractVideoId(cooked)`

Pure. Tries these patterns in order, returns the first 11-character match or `null`:

```
data-video-id="([\w-]{11})"              ← Discourse's lazy-video container (the reliable one)
youtube(?:-nocookie)?\.com/embed/([\w-]{11})
youtu\.be/([\w-]{11})
[?&]v=([\w-]{11})
```

Grounded: PRE topic 2597's first post cooks its `youtu.be/1qH2Ye8IJrE` link into
`<div ... data-video-id="1qH2Ye8IJrE">`. Topic 2592, tagged `podcast` but with no video,
yields `null` — which is exactly the case the no-`videoId` branch handles.

### `youtubeThumbnail(id)`

`` `https://i.ytimg.com/vi/${id}/hqdefault.jpg` ``. `hqdefault` (480×360) always exists;
`maxresdefault` does not for every video, so it is not used.

### `rankTopMember(items, weights)`

Pure. For each of `post_count`, `likes_received`, `days_visited`, normalise to `[0, 1]` by
dividing by the maximum in the set (max 0 → contributes 0). Score each item:

```
score(i) = weights.posts · n(post_count)
         + weights.likes · n(likes_received)
         + weights.days  · n(days_visited)
```

Return the highest-scoring item, or `null` for an empty list.

```js
// Only decides WHO wins — the card shows raw figures, never this score. A
// one-line edit here changes the emphasis; deliberately not four theme settings.
export const WEIGHTS = { posts: 0.5, likes: 0.35, days: 0.15 };
```

### `memberHasActivity(item)`

`Boolean(item && (item.post_count > 0 || item.likes_received > 0))`. The guard for a quiet
instance: PRE's 30-day directory is currently all zeros (August, a development target), so
without this the card would crown someone with no posts and no likes.

## Card content

Per-card icons: newsletter `envelope`, novedad `rocket`, podcast label `podcast`, member
badge `star`, play button `play`.

### `ContentCard` — newsletter, novedad (local `<template>`, props `label`, `icon`, `topic`, `cta`, `variant`)

- Image area: `topic.image_url` → `<img>` with `object-fit: cover`; `null` → branded
  placeholder (petrol gradient + large faded `icon`).
- Label (uppercase, `--ga-mark` icon, petrol text) · `fancy_title` via `trustHTML` (already
  cooked HTML, the same pattern as `block-events` / `block-forum`) · `excerpt` clamped with
  `-webkit-line-clamp: 2` (`variant: tall`) or hidden (`variant: compact`, used by novedad) ·
  CTA `DButton` `@href` `/t/<slug>/<id>` with `@translatedLabel`.

### `HighlightPodcastCard`

- 16:9 area. Not playing: `<img>` YouTube thumbnail + `<button class="--play">` (icon `play`,
  `aria-label` "Reproducir el episodio"). Playing: `<iframe>` with `title`,
  `allow="autoplay; encrypted-media; picture-in-picture"`, `allowfullscreen`.
- No `videoId`: the thumbnail is wrapped in `<a href={{topic.url}}>`, no button.
- Label "Podcast" · `fancy_title` · CTA "Ver el episodio" → topic.

### `HighlightMemberCard`

- `{{avatar item.user imageSize="large"}}` inside `<a href="/u/{{username}}/summary">`.
- Name `item.user.name || item.user.username` · badge: `star` icon + "Miembro del mes".
- Figures line: `"40 publicaciones · 96 me gusta · 12 días activo"` (this month), each half a
  pluralised i18n string.
- CTA ghost "Ver perfil" → `/u/<username>/summary`.
- **Empty variant** (handed `null`): `star` icon + "Publica y participa este mes para
  aparecer aquí" + a `DButton` to `/new-topic`. This is also what fills the cell.

### Placeholder — a content card whose tag is set but currently has no topic

Faded icon + "Próximamente". (A card whose *setting* is empty is removed from the grid
instead — see *Reduced layouts*.)

## Strings — `locales/en.yml` + `locales/es.yml`, under `homepage.highlights`

```yaml
highlights:
  title:            # EN "Community highlights"        · ES "Destacado de la comunidad"
  soon:             # EN "Coming soon"                  · ES "Próximamente"
  podcast:
    label:  "Podcast"
    cta:            # EN "Watch the episode"            · ES "Ver el episodio"
    play:           # EN "Play the episode"             · ES "Reproducir el episodio"
  newsletter:
    label:  "Newsletter"
    cta:            # EN "Read the newsletter"          · ES "Leer la newsletter"
  news:
    label:          # EN "What's new in Gestiona"       · ES "Novedad de Gestiona"
    cta:            # EN "See what's new"               · ES "Ver la novedad"
  member:
    badge:          # EN "Member of the month"          · ES "Miembro del mes"
    posts:  { one: "%{count} publicación",  other: "%{count} publicaciones" }
    likes:  { one: "%{count} me gusta",     other: "%{count} me gusta" }   # invariable in ES, as topbar
    days:   { one: "%{count} día activo",   other: "%{count} días activos" }
    profile:        # EN "View profile"                 · ES "Ver perfil"
    cta_empty:      # EN "Post and take part this month to show up here"
                    # ES "Publica y participa este mes para aparecer aquí"
```

Every setting also needs a description under `theme_metadata.settings.<name>` in both files or
admin shows a raw key.

## Configuration

### `settings.yml` — a "Section 2: community highlights" block

| Setting | Type | Default |
|---|---|---|
| `highlights_podcast_tag` | string | `podcast` |
| `highlights_newsletter_tag` | string | `newsletter` |
| `highlights_news_tag` | string | `nueva-version-gestiona` |
| `highlights_member_period` | enum | `monthly` — choices `monthly` / `quarterly` / `yearly` / `all` |

Tags are matched by **slug**, exactly as in `/tag/<slug>`. A renamed tag empties its card in
silence — the same failure mode the category-ID settings already carry, and the comment block
says so.

**No boolean toggle.** The section renders *iff at least one of the three tags is non-empty*.
The member card is never the sole reason to show the section. Emptying all three kills it —
the same idiom as `events_category_id: 0`.

### `about.json`

- `svg_icons`: `["newspaper", "lightbulb", "podcast"]` — `podcast` is added; `envelope`,
  `star`, `play` and `rocket` are already in core's default FontAwesome subset. `dIcon` writes
  the class whether or not the sprite carries the symbol, so a missing entry renders an empty
  box and every test still passes — hence this list is maintained by hand.
- `serialize_topic_excerpts: true` — stays, and **is used again**: the content cards read
  `excerpt`. The comment in `block-latest.gjs` calling it "dead weight" is now wrong and gets
  updated in this branch.
- `topic_thumbnail_sizes: ["400x300"]` — stays, and feeds `image_url` again. It is landscape;
  the tall newsletter card uses `object-fit: cover`. A portrait size is a later refinement if
  quality suffers — most source topics have no image today, so the placeholder path
  dominates.
- `theme_version`: `0.35.0` → `0.36.0`.

## Edge cases and error handling

| Case | Behaviour |
|---|---|
| A tag setting is empty | That card is removed; the grid falls back to a two-column layout over the remaining cards. |
| Tag set, no topics | "Próximamente" placeholder in that cell; the bento holds. |
| Podcast topic has no recognisable video | Thumbnail (topic image or placeholder) links to the topic; no play button. |
| Podcast `videoId` resolves but the video is private/removed | The `<iframe>` shows YouTube's own error. `hqdefault.jpg` is still served for removed videos, so the thumbnail rarely 404s; an `<img onerror>` → placeholder swap was specced but **not built** (deferred in the whole-branch fix wave, 2026-08-29 — it flaked the rendering test), so a genuine thumbnail 404 shows a broken-image icon until it is added. |
| Newsletter and podcast resolve to the **same topic** | Both cards show it. This happens on PRE today (topic 2597 carries both tags). Documented, not coded around — cross-card de-dup between independent `<DAsyncContent>` blocks is not worth its complexity. The fix is tag hygiene (admin task). |
| `enable_user_directory` off, or the directory request fails | Treated as "no eligible member" → the member cell renders the CTA. |
| Directory returns only zero-activity users | `memberHasActivity` is false → CTA. |
| Anonymous user | The homepage is `login_required` and unreachable anonymously, but no code path dereferences `currentUser`; the `/new-topic` link is harmless. |
| A topic write cleared `image_url` (the known fragility) | Placeholder path — expected, not a regression. |

## Testing

QUnit runs **only in CI** (~4 minutes a cycle, no Discourse checkout on this machine), so the
red step of any TDD cycle goes in one push, not test by test. `npx pnpm@10.28.0 lint` is the
only local gate.

**Two Blocks traps, respected from the start** (both have cost this repo a CI run): declare
any new Block arg *inert* before honouring it — an undeclared arg aborts the whole QUnit run
with an uncaught `BlockError` — and export every `lib/highlights.js` symbol as a stub before
importing it, or Rollup hard-fails the bundle and every test dies as one global error.

### Unit — `test/unit/highlights-test.js`

- `extractVideoId`: `data-video-id`, `youtu.be`, `watch?v=`, `/embed/`, `youtube-nocookie`,
  no match, malformed id.
- `rankTopMember`: picks the highest composite; normalisation is per-field; a single item;
  an empty list → `null`; an all-zeros set still returns an item (the activity guard is
  separate).
- `memberHasActivity`: posts only, likes only, both zero, `null`.
- `youtubeThumbnail`: id → the `i.ytimg.com` URL.

### Integration — `test/integration/homepage-highlights-test.gjs`

Through `<BlockOutlet>`, the harness `test/integration/homepage-lanes-test.gjs` establishes
(`visit("/")` does not render blocks in the JS test env; the store is stubbed outright;
fixture ids sit in the 900000+ range to dodge core's definition-topic ids).

- Renders the section heading and four cells.
- Content card: title entities decoded (via `trustHTML`), excerpt shown, CTA `href` correct.
- Content card, no topic → "Próximamente" placeholder.
- Content card, no `image_url` → placeholder block, no broken `<img>`.
- Podcast with `videoId` → play button present; clicking it renders an `<iframe>` whose
  `src` carries the id.
- Podcast without `videoId` → thumbnail is a link to the topic, no play button.
- Member card → figures line + "Miembro del mes" badge + profile link.
- Member card, winner has zero activity → the CTA renders instead.
- Member card, directory request rejects → the CTA renders instead.
- Section does not render when all three tags are empty.

### Manual on PRE — the parts no test covers

1. The bento at three widths: base, the 40–56rem tablet band, and > 56rem.
2. Podcast playback end to end — thumbnail → click → embedded playback.
3. Placeholder rendering, since most source topics have no cover image today.

**The member card cannot be validated with live data on PRE** — its 30-day directory is all
zeros. Check it on PROD, or revisit once PRE activity picks up. Category listings and the
homepage are unguarded by CI (`skip_examples` covers `topics:read`), so items 1–3 have no net
but the maintainer's eyes.

## Delivery

- `npx pnpm@10.28.0 lint` locally — exactly what CI runs.
- Branch `feat/homepage-highlights-section`, PR, CI green before merge.
- `theme_version` 0.36.0.
- `main` is what PRE pulls and the theme is the only one installed there, so the merge lands
  on every PRE user.

## Admin tasks — the maintainer's, not the theme's

1. **Create the `nueva-version-gestiona` tag** and apply it to the release-announcement
   topics. Until then that card does not render (its setting resolves to a tag with no
   topics → "Próximamente", or set the setting empty to drop the card).
2. **Podcast / newsletter tag hygiene.** Keep the two tags disjoint where a topic is really
   one or the other, so the two cards do not show the same topic. And the freshest `podcast`
   topic must carry a YouTube link in its first post for the embed to resolve — otherwise the
   card degrades to a plain link.
3. **Cover images.** Give the latest newsletter / podcast / release topics a cover image
   (portrait-ish for the newsletter) so the cards are not all placeholder. Optional — the
   placeholder is a designed state, not a failure.
4. **`enable_user_directory` must stay on** for the member card.

## Decisions settled at spec review (2026-08-29)

- **Rolling 30 days, not calendar month, for the member card.** Discourse's directory has no
  calendar-month period; `monthly` is the last 30 days, the same window the topbar already
  labels "Este mes:". Confirmed by the maintainer.
- **Tag-overlap is not coded around.** Newsletter and podcast can resolve to the same topic
  (PRE topic 2597 carries both tags today); the maintainer fixes this by tag hygiene in
  admin. The rejected alternative — a combined fetch phase that de-dups before render —
  reintroduces the "one slow fetch blocks all" problem the independent `<DAsyncContent>`
  design avoids.

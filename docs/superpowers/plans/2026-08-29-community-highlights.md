# Community Highlights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fourth homepage section — a bento of four cards (latest podcast with an embedded YouTube player, latest newsletter, latest Gestiona release, and the month's most active member) — below the existing latest/agenda/ideas section.

**Architecture:** One new Block (`theme:espublico:highlights`) registered in `homepage-blocks` after the `home-latest` group. The block renders a framed section with an asymmetric CSS grid; each of the four cells is its own `<DAsyncContent>` so the fetches load and fail independently. Two genuinely tricky pieces — YouTube video-id extraction and the weighted member ranking — live in `javascripts/discourse/lib/highlights.js` as framework-free functions with unit tests. The podcast and member cards are presentational Glimmer components; the newsletter and novedad cards are a local `<template>` const in the block.

**Tech Stack:** Discourse theme (no build step — Discourse compiles it). Glimmer components in `.gjs`, the experimental Blocks API, SCSS with the theme's `lane-*` mixins and `--ga-*` brand tokens. QUnit for tests, run **only in CI**. `npx pnpm@10.28.0 lint` is the only local gate.

**Spec:** `docs/superpowers/specs/2026-08-29-community-highlights-design.md` — read it alongside this plan.

## Global Constraints

- **`theme_version`** in `about.json`: bump `0.35.0` → `0.36.0` (Task 7, once).
- **`minimum_discourse_version`** stays `2026.7.0`. The Blocks API is experimental; do not rely on anything newer.
- **Settings hold configuration, locales hold every visible string.** A block arg that is a string shown to the user is a hardcoded i18n **key**, resolved in the template with `{{i18n (themePrefix @key)}}`. `themePrefix` and the global `settings` object are auto-injected into `.gjs` theme files — no import.
- **Every new `settings.yml` entry needs a description** under `theme_metadata.settings.<name>` in **both** `locales/en.yml` and `locales/es.yml`, or admin shows a raw key.
- **SCSS rules enforced by review:** no raw media queries — use `viewport.from(lg)` / `@container` as the existing homepage SCSS does. BEM with standalone `--modifier` classes (`.highlight-content.--tall`, never `.highlight-content--tall`). Prefer overriding core CSS custom properties over redeclaring rules. `stylesheets/blocks/_index.scss` imports files; adding a block SCSS file touches exactly that one `_index.scss`.
- **`fancy_title` is already cooked HTML** — render it with `{{trustHTML topic.fancy_title}}`, the same as `block-events.gjs` and `block-forum.gjs`. Never pass it through `dReplaceEmoji` (double-encodes).
- **QUnit runs only in CI** (~4 min/cycle, no Discourse checkout on this machine). Within a task, write the test step and the implementation step, run `npx pnpm@10.28.0 lint` locally, and commit. Push once per task (or batch a red push first if you want to see CI red). Two Blocks traps that make the red step report *nothing*: an **undeclared block arg** aborts the whole QUnit run with an uncaught `BlockError`, and a **missing export** hard-fails the Rollup bundle. This plan avoids both by building each unit complete before anything imports it — do not partially wire.
- **Test fixture topic ids sit in the 900000+ range.** `definitionTopicIds()` filters any topic whose id is a category definition topic, and core's site fixture puts those at 2, 11, 24, 25, 28, 389, 1026. A colliding fixture id is silently filtered and the assertion then fails on a missing element.
- **Branch:** `feat/homepage-highlights-section` (already created, spec already committed on it). PR when all tasks are done; CI green before merge. Every merge to `main` lands on every PRE user.
- **Git identity** for this repo is already set locally (`gestionatools-org`). Commit messages in English; end each with the two trailers used across this repo:
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_017RihJJnZkywjNM1UeMkZQo
  ```

---

## File Structure

| File | Created / Modified | Responsibility |
|---|---|---|
| `javascripts/discourse/lib/highlights.js` | Create | Framework-free helpers: `loadLatestTaggedTopic`, `extractVideoId`, `youtubeThumbnail`, `rankTopMember`, `memberHasActivity`, and the `WEIGHTS` const. |
| `test/unit/highlights-test.js` | Create | Unit tests for the pure functions. |
| `javascripts/discourse/components/highlight-podcast-card.gjs` | Create | Presentational 16:9 card. `@tracked playing`; thumbnail → embedded `<iframe>` in place; no `videoId` → thumbnail links to the topic. |
| `javascripts/discourse/components/highlight-member-card.gjs` | Create | Presentational card. With `@member`: avatar + figures + "member of the month" badge. Without: the "take part" CTA. |
| `javascripts/discourse/blocks/block-highlights.gjs` | Create | The Block. Section frame + bento grid + four `<DAsyncContent>` cells. Holds local `<template>` consts `ContentCard` and `Placeholder`. |
| `stylesheets/blocks/block-highlights.scss` | Create | Bento grid, its breakpoints, and the four card treatments. |
| `stylesheets/blocks/_index.scss` | Modify | One `@import "block-highlights";` line. |
| `javascripts/discourse/api-initializers/homepage-blocks.gjs` | Modify | Add the `BlockHighlights` entry after the `home-latest` group. |
| `settings.yml` | Modify | Four new settings under a "Section 2" block. |
| `locales/en.yml` | Modify | `homepage.highlights.*` strings + four `theme_metadata.settings.*` descriptions. |
| `locales/es.yml` | Modify | Same, Spanish. |
| `about.json` | Modify | `svg_icons` gains `"podcast"`; `theme_version` → `0.36.0`. |
| `javascripts/discourse/blocks/block-latest.gjs` | Modify | Fix the comment that calls `serialize_topic_excerpts` "dead weight" — the highlights content cards read `excerpt`. |
| `test/integration/homepage-highlights-test.gjs` | Create | The block, through `<BlockOutlet>`. |
| `traceability.md` | Modify | One concise session entry (Task 7). |

---

## Task 1: `lib/highlights.js` — the pure helpers

**Files:**
- Create: `javascripts/discourse/lib/highlights.js`
- Test: `test/unit/highlights-test.js`

**Interfaces:**
- Consumes: `definitionTopicIds` from `javascripts/discourse/lib/category-topics.js` (existing); `ajax` from `discourse/lib/ajax` is **not** used here.
- Produces:
  - `WEIGHTS: { posts: number, likes: number, days: number }`
  - `loadLatestTaggedTopic(store, tag: string) => Promise<object|null>`
  - `extractVideoId(cooked: string) => string|null`
  - `youtubeThumbnail(id: string) => string`
  - `rankTopMember(items: object[], weights) => object|null`
  - `memberHasActivity(item: object|null) => boolean`

- [ ] **Step 1: Write the failing unit tests**

Create `test/unit/highlights-test.js`. The pure functions (`extractVideoId`, `youtubeThumbnail`, `rankTopMember`, `memberHasActivity`) take plain `module` + `test` from `qunit`. `loadLatestTaggedTopic` calls `definitionTopicIds()` → `Category.list()`, which needs a booted app, so put that one in its own `acceptance(...)` module with `needs.user()` — the same reason `test/acceptance/category-topics-test.js` uses `acceptance` for functions that read the preloaded category list.

```js
import { module, test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  extractVideoId,
  loadLatestTaggedTopic,
  memberHasActivity,
  rankTopMember,
  WEIGHTS,
  youtubeThumbnail,
} from "../../discourse/lib/highlights";

module("Espublico Theme | Unit | highlights | extractVideoId", function () {
  test("reads Discourse's lazy-video container", function (assert) {
    const cooked = `<p>x</p><div class="lazy-video-container" data-video-id="1qH2Ye8IJrE" data-provider="youtube"></div>`;
    assert.strictEqual(extractVideoId(cooked), "1qH2Ye8IJrE");
  });

  test("falls back to a bare youtu.be link", function (assert) {
    assert.strictEqual(
      extractVideoId(`<a href="https://youtu.be/dZJpHhWGyzQ">watch</a>`),
      "dZJpHhWGyzQ"
    );
  });

  test("falls back to a watch?v= link", function (assert) {
    assert.strictEqual(
      extractVideoId(`<a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=1">x</a>`),
      "dQw4w9WgXcQ"
    );
  });

  test("falls back to an /embed/ url", function (assert) {
    assert.strictEqual(
      extractVideoId(`<iframe src="https://www.youtube-nocookie.com/embed/abcdefghijk"></iframe>`),
      "abcdefghijk"
    );
  });

  test("prefers the lazy-video id when several are present", function (assert) {
    const cooked = `<a href="https://youtu.be/AAAAAAAAAAA">teaser</a><div data-video-id="BBBBBBBBBBB"></div>`;
    assert.strictEqual(extractVideoId(cooked), "BBBBBBBBBBB");
  });

  test("returns null when there is no video", function (assert) {
    assert.strictEqual(extractVideoId(`<p>Just text.</p>`), null);
    assert.strictEqual(extractVideoId(""), null);
    assert.strictEqual(extractVideoId(null), null);
  });
});

module("Espublico Theme | Unit | highlights | youtubeThumbnail", function () {
  test("builds the hqdefault url", function (assert) {
    assert.strictEqual(
      youtubeThumbnail("1qH2Ye8IJrE"),
      "https://i.ytimg.com/vi/1qH2Ye8IJrE/hqdefault.jpg"
    );
  });
});

module("Espublico Theme | Unit | highlights | rankTopMember", function () {
  test("returns null for an empty list", function (assert) {
    assert.strictEqual(rankTopMember([], WEIGHTS), null);
    assert.strictEqual(rankTopMember(undefined, WEIGHTS), null);
  });

  test("returns the only item when there is one", function (assert) {
    const only = { post_count: 0, likes_received: 0, days_visited: 3 };
    assert.strictEqual(rankTopMember([only], WEIGHTS), only);
  });

  test("picks the highest weighted composite, not the highest single field", function (assert) {
    // A: leads on posts. B: leads on likes and days. With the default weights
    // A's post lead (0.5) beats B's likes+days (0.35 + 0.15 of a smaller gap).
    const a = { post_count: 10, likes_received: 1, days_visited: 1 };
    const b = { post_count: 1, likes_received: 10, days_visited: 10 };
    // a.score = .5*1 + .35*.1 + .15*.1 = .55 ; b.score = .5*.1 + .35*1 + .15*1 = .55
    // tie-break: reduce keeps the first, which is `a`
    assert.strictEqual(rankTopMember([a, b], WEIGHTS), a);

    const c = { post_count: 3, likes_received: 10, days_visited: 10 };
    // c.score = .5*.3 + .35 + .15 = .65 > a.score .55 -> c wins over a
    assert.strictEqual(rankTopMember([a, c], WEIGHTS), c);
  });

  test("treats a field whose max is zero as contributing nothing", function (assert) {
    const x = { post_count: 0, likes_received: 5, days_visited: 0 };
    const y = { post_count: 0, likes_received: 2, days_visited: 0 };
    assert.strictEqual(rankTopMember([x, y], WEIGHTS), x);
  });
});

module("Espublico Theme | Unit | highlights | memberHasActivity", function () {
  test("true when there are posts or likes", function (assert) {
    assert.true(memberHasActivity({ post_count: 1, likes_received: 0 }));
    assert.true(memberHasActivity({ post_count: 0, likes_received: 4 }));
  });

  test("false for a zero-activity item or nothing", function (assert) {
    assert.false(memberHasActivity({ post_count: 0, likes_received: 0, days_visited: 20 }));
    assert.false(memberHasActivity(null));
    assert.false(memberHasActivity(undefined));
  });
});

acceptance("Espublico Theme | Unit | highlights | loadLatestTaggedTopic", function (needs) {
  needs.user();

  test("returns null for an empty tag without a request", async function (assert) {
    const store = { findFiltered: () => assert.step("should not be called") };
    const result = await loadLatestTaggedTopic(store, "");
    assert.strictEqual(result, null);
    assert.verifySteps([]);
  });

  test("returns the first non-definition topic", async function (assert) {
    const store = {
      findFiltered: async () => ({
        topics: [{ id: 900001, fancy_title: "First" }, { id: 900002 }],
      }),
    };
    const topic = await loadLatestTaggedTopic(store, "podcast");
    assert.strictEqual(topic.id, 900001);
  });

  test("returns null when the tag has no topics", async function (assert) {
    const store = { findFiltered: async () => ({ topics: [] }) };
    assert.strictEqual(await loadLatestTaggedTopic(store, "podcast"), null);
  });
});
```

- [ ] **Step 2: Verify the tests fail**

Run: `npx pnpm@10.28.0 lint` (must pass — lint is local). Then push the branch; the `frontend_tests` CI job is the QUnit runner.
Expected: `frontend_tests` RED — `highlights.js` does not exist, module resolution fails.
(You may skip the red push and go straight to Step 3 if batching; the green run at Step 4 is the real gate.)

- [ ] **Step 3: Write `javascripts/discourse/lib/highlights.js`**

```js
import { definitionTopicIds } from "./category-topics";

// Only decides WHO wins the member card — the card shows raw figures, never
// this score. A one-line edit changes the emphasis; deliberately not four
// theme settings. `days_visited` stands in for "time on the platform" because
// this Discourse version's directory serializer omits `time_read`.
export const WEIGHTS = { posts: 0.5, likes: 0.35, days: 0.15 };

/**
 * The most recent non-definition topic carrying `tag`, or null.
 *
 * An empty `tag` returns null without touching the network — the guard that
 * stops an unset setting becoming the filter `tag//l/latest`. Definition topics
 * are dropped for the same reason `loadCategoryTopics` drops them: they are
 * pinned "Acerca de la categoría …" boilerplate.
 *
 * @param {Object} store - the injected store service
 * @param {String} tag - tag slug, exactly as in /tag/<slug>
 * @returns {Promise<Object|null>}
 */
export async function loadLatestTaggedTopic(store, tag) {
  if (!tag) {
    return null;
  }

  const topicList = await store.findFiltered("topicList", {
    filter: `tag/${tag}/l/latest`,
  });

  const definitions = definitionTopicIds();
  const topic = topicList?.topics?.find((t) => !definitions.has(t.id));

  return topic ?? null;
}

/**
 * The first YouTube video id in a cooked post, or null.
 *
 * `data-video-id` is Discourse's own lazy-video container and the reliable
 * signal; the bare-URL patterns are fallbacks for a link core did not onebox.
 * A YouTube id is always exactly 11 characters of [A-Za-z0-9_-].
 *
 * @param {String} cooked - post HTML
 * @returns {String|null}
 */
export function extractVideoId(cooked) {
  if (!cooked) {
    return null;
  }

  const patterns = [
    /data-video-id="([\w-]{11})"/,
    /youtube(?:-nocookie)?\.com\/embed\/([\w-]{11})/,
    /youtu\.be\/([\w-]{11})/,
    /[?&]v=([\w-]{11})/,
  ];

  for (const pattern of patterns) {
    const match = cooked.match(pattern);
    if (match) {
      return match[1];
    }
  }

  return null;
}

/**
 * The hqdefault thumbnail URL for a YouTube id. hqdefault (480×360) always
 * exists; maxresdefault does not for every video, so it is not used.
 *
 * @param {String} id
 * @returns {String}
 */
export function youtubeThumbnail(id) {
  return `https://i.ytimg.com/vi/${id}/hqdefault.jpg`;
}

/**
 * The directory item with the highest weighted-composite activity, or null for
 * an empty list.
 *
 * Each of post_count, likes_received and days_visited is normalised against the
 * maximum in `items` (a field whose max is 0 contributes 0), then combined by
 * `weights`. Ties keep the earlier item.
 *
 * @param {Array<Object>} items - directory_items entries
 * @param {{posts:Number,likes:Number,days:Number}} weights
 * @returns {Object|null}
 */
export function rankTopMember(items, weights) {
  if (!items?.length) {
    return null;
  }

  const ceiling = (key) => Math.max(0, ...items.map((it) => it[key] || 0));
  const maxPosts = ceiling("post_count");
  const maxLikes = ceiling("likes_received");
  const maxDays = ceiling("days_visited");

  const norm = (value, max) => (max > 0 ? (value || 0) / max : 0);

  const score = (it) =>
    weights.posts * norm(it.post_count, maxPosts) +
    weights.likes * norm(it.likes_received, maxLikes) +
    weights.days * norm(it.days_visited, maxDays);

  return items.reduce((best, it) => (score(it) > score(best) ? it : best));
}

/**
 * Whether a directory item represents real participation this period. The
 * guard for a quiet instance, where the ranking would otherwise crown someone
 * with no posts and no likes (PRE's 30-day directory is all zeros today).
 *
 * @param {Object|null} item
 * @returns {Boolean}
 */
export function memberHasActivity(item) {
  return Boolean(item && (item.post_count > 0 || item.likes_received > 0));
}
```

- [ ] **Step 4: Verify the tests pass**

Run: `npx pnpm@10.28.0 lint` locally (must be clean). Push; wait for `frontend_tests`.
Expected: `frontend_tests` GREEN, all new `highlights` unit tests passing.

- [ ] **Step 5: Commit**

```bash
git add javascripts/discourse/lib/highlights.js test/unit/highlights-test.js
git commit -m "$(cat <<'EOF'
feat: pure helpers for the community-highlights section

extractVideoId (Discourse lazy-video + bare-URL fallbacks), rankTopMember
(weighted composite over post_count/likes_received/days_visited),
memberHasActivity (quiet-instance guard), loadLatestTaggedTopic,
youtubeThumbnail.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017RihJJnZkywjNM1UeMkZQo
EOF
)"
```

---

## Task 2: settings, strings, and the icon manifest

**Files:**
- Modify: `settings.yml`
- Modify: `locales/en.yml`
- Modify: `locales/es.yml`
- Modify: `about.json` (`svg_icons` only — the `theme_version` bump is Task 7)

**Interfaces:**
- Produces: settings `highlights_podcast_tag`, `highlights_newsletter_tag`, `highlights_news_tag`, `highlights_member_period`; i18n keys under `homepage.highlights.*`.
- Consumes: nothing.

- [ ] **Step 1: Add the settings**

Append to `settings.yml` (after the `first_steps_url` block):

```yaml
# --- Section 2: community highlights ---------------------------------------
# Four cards below section 1: latest podcast, latest newsletter, latest Gestiona
# release, and the month's most active member. The three tag settings are matched
# by slug, exactly as in /tag/<slug>. Each hides its card when empty; a card
# whose tag is set but currently has no topic shows a "coming soon" placeholder.
#
# The section renders only when at least one of the three tags is non-empty —
# the member card is a companion, never the sole reason to show the section.
# Emptying all three hides it, the same idiom as events_category_id: 0.
#
# A renamed tag empties its card in silence, the same failure mode the category
# IDs above carry. Re-check the three slugs after any tag reorganisation.
highlights_podcast_tag:
  type: string
  default: "podcast"

highlights_newsletter_tag:
  type: string
  default: "newsletter"

# Ricardo is creating this tag in admin; until it exists and carries topics the
# card shows "coming soon". Set empty to drop the card entirely.
highlights_news_tag:
  type: string
  default: "nueva-version-gestiona"

# Rolling window for the "most active member" ranking. Discourse's directory has
# no calendar-month period — "monthly" is the last 30 days, the same window the
# topbar figures use ("Este mes:").
highlights_member_period:
  type: enum
  default: monthly
  choices:
    - monthly
    - quarterly
    - yearly
    - all
```

- [ ] **Step 2: Add the English strings**

In `locales/en.yml`, under `theme_metadata.settings:` add:

```yaml
      highlights_podcast_tag: "Tag whose most recent topic fills the podcast card. Matched by slug. Empty hides the card."
      highlights_newsletter_tag: "Tag whose most recent topic fills the newsletter card. Matched by slug. Empty hides the card."
      highlights_news_tag: "Tag whose most recent topic fills the 'What's new in Gestiona' card. Matched by slug. Empty hides the card."
      highlights_member_period: "Window for the most-active-member ranking. 'monthly' is the last 30 days — Discourse has no calendar-month option."
```

And under `homepage:` (after the `forum:` block) add:

```yaml
    highlights:
      title: "Community highlights"
      soon: "Coming soon"
      podcast:
        label: "Podcast"
        cta: "Watch the episode"
        play: "Play the episode"
      newsletter:
        label: "Newsletter"
        cta: "Read the newsletter"
      news:
        label: "What's new in Gestiona"
        cta: "See what's new"
      member:
        badge: "Member of the month"
        posts:
          one: "%{count} post"
          other: "%{count} posts"
        likes:
          one: "%{count} like"
          other: "%{count} likes"
        days:
          one: "%{count} active day"
          other: "%{count} active days"
        profile: "View profile"
        cta_empty: "Post and take part this month to show up here"
        cta_empty_button: "Write a post"
```

- [ ] **Step 3: Add the Spanish strings**

In `locales/es.yml`, under `theme_metadata.settings:` add:

```yaml
      highlights_podcast_tag: "Etiqueta cuyo tema más reciente ocupa la tarjeta de podcast. Se compara por slug. Vacío oculta la tarjeta."
      highlights_newsletter_tag: "Etiqueta cuyo tema más reciente ocupa la tarjeta de newsletter. Se compara por slug. Vacío oculta la tarjeta."
      highlights_news_tag: "Etiqueta cuyo tema más reciente ocupa la tarjeta «Novedad de Gestiona». Se compara por slug. Vacío oculta la tarjeta."
      highlights_member_period: "Ventana para el ranking del miembro más activo. «monthly» son los últimos 30 días — Discourse no ofrece mes natural."
```

And under `homepage:` add:

```yaml
    highlights:
      title: "Destacado de la comunidad"
      soon: "Próximamente"
      podcast:
        label: "Podcast"
        cta: "Ver el episodio"
        play: "Reproducir el episodio"
      newsletter:
        label: "Newsletter"
        cta: "Leer la newsletter"
      news:
        label: "Novedad de Gestiona"
        cta: "Ver la novedad"
      member:
        badge: "Miembro del mes"
        posts:
          one: "%{count} publicación"
          other: "%{count} publicaciones"
        likes:
          one: "%{count} me gusta"
          other: "%{count} me gusta"
        days:
          one: "%{count} día activo"
          other: "%{count} días activos"
        profile: "Ver perfil"
        cta_empty: "Publica y participa este mes para aparecer aquí"
        cta_empty_button: "Escribir una publicación"
```

Note: `likes.one` and `likes.other` are identical on purpose — "me gusta" is invariable as a noun in Spanish, matching the existing `topbar.stats.likes` entry.

- [ ] **Step 4: Add `podcast` to the icon manifest**

In `about.json`, change:

```json
    "svg_icons": ["newspaper", "lightbulb"]
```

to:

```json
    "svg_icons": ["newspaper", "lightbulb", "podcast"]
```

`envelope`, `star`, `play` and `rocket` are already in core's default FontAwesome subset (verified against `.claude/skills/discourse-theme-authoring/icons.md`); only `podcast` needs the entry.

- [ ] **Step 5: Verify**

Run: `npx pnpm@10.28.0 lint`
Expected: PASS (YAML + JSON well-formed, prettier clean).

- [ ] **Step 6: Commit**

```bash
git add settings.yml locales/en.yml locales/es.yml about.json
git commit -m "$(cat <<'EOF'
feat: settings, strings and icon for the community-highlights section

Four settings (three tag slugs + member-ranking window), the
homepage.highlights.* string tree in both locales, and "podcast" added
to svg_icons.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017RihJJnZkywjNM1UeMkZQo
EOF
)"
```

---

## Task 3: `HighlightPodcastCard` component

**Files:**
- Create: `javascripts/discourse/components/highlight-podcast-card.gjs`
- Test: `test/integration/homepage-highlights-test.gjs` (create the file here; Task 5/6 add to it)

**Interfaces:**
- Consumes: `youtubeThumbnail` from `lib/highlights.js`.
- Produces: default export `HighlightPodcastCard`, a Glimmer component taking `@topic` (object with `url`, `fancy_title`, `image_url`) and `@videoId` (string or null).

- [ ] **Step 1: Write the failing rendering tests**

Create `test/integration/homepage-highlights-test.gjs`:

```js
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import HighlightMemberCard from "../../discourse/components/highlight-member-card";
import HighlightPodcastCard from "../../discourse/components/highlight-podcast-card";

// Components render directly — they are plain Glimmer components, not Blocks, so
// they do not need the `<BlockOutlet>` dance the block tests below use. Data
// arrives as args; the block owns the fetching.

module("Espublico Theme | Integration | highlights | podcast card", function (hooks) {
  setupRenderingTest(hooks);

  const topic = {
    url: "/t/episodio-7/2597",
    fancy_title: "Episodio 7 &mdash; Contrataci&oacute;n con IA",
    image_url: null,
  };

  test("shows a play button that swaps the thumbnail for an embedded player", async function (assert) {
    await render(
      <template>
        <HighlightPodcastCard @topic={{topic}} @videoId="1qH2Ye8IJrE" />
      </template>
    );

    assert.dom(".highlight-podcast__play").exists("a play button before pressing");
    assert.dom(".highlight-podcast__player").doesNotExist("no iframe yet");
    assert
      .dom(".highlight-podcast__play img")
      .hasAttribute("src", "https://i.ytimg.com/vi/1qH2Ye8IJrE/hqdefault.jpg");

    await click(".highlight-podcast__play");

    assert.dom(".highlight-podcast__player").exists("the iframe after pressing");
    assert
      .dom(".highlight-podcast__player")
      .hasAttribute("src", /\/embed\/1qH2Ye8IJrE/, "embeds the right video");
    assert.dom(".highlight-podcast__play").doesNotExist("play button is gone");
  });

  test("with no video, the thumbnail is a link to the topic and there is no play button", async function (assert) {
    await render(
      <template>
        <HighlightPodcastCard @topic={{topic}} @videoId={{null}} />
      </template>
    );

    assert.dom(".highlight-podcast__play").doesNotExist();
    assert.dom(".highlight-podcast__link").hasAttribute("href", "/t/episodio-7/2597");
  });

  test("renders the title entities as characters, not markup", async function (assert) {
    await render(
      <template>
        <HighlightPodcastCard @topic={{topic}} @videoId="1qH2Ye8IJrE" />
      </template>
    );
    assert.dom(".highlight-card__title").includesText("Episodio 7 — Contratación con IA");
  });
});
```

- [ ] **Step 2: Verify the tests fail**

`npx pnpm@10.28.0 lint`, then push. Expected: `frontend_tests` RED — `highlight-podcast-card` does not exist. (Batching: fine to continue.)

- [ ] **Step 3: Write the component**

`javascripts/discourse/components/highlight-podcast-card.gjs`:

```gjs
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { youtubeThumbnail } from "../lib/highlights";

// The 16:9 card. Presentational: the block resolves the topic and the video id
// and hands them down; the only state here is whether the viewer has pressed
// play. With a video id the thumbnail swaps for an embedded player that plays in
// place — on www.youtube.com/embed, the host Discourse's own lazy-video uses, so
// it clears the frame-src allowlist. Without a video id the thumbnail is just a
// link to the topic.
export default class HighlightPodcastCard extends Component {
  @tracked playing = false;

  get thumbnail() {
    return this.args.videoId
      ? youtubeThumbnail(this.args.videoId)
      : this.args.topic.image_url;
  }

  get embedUrl() {
    return `https://www.youtube.com/embed/${this.args.videoId}?autoplay=1`;
  }

  @action
  play() {
    this.playing = true;
  }

  <template>
    <article class="highlight-card highlight-podcast">
      <div class="highlight-podcast__frame">
        {{#if this.playing}}
          <iframe
            class="highlight-podcast__player"
            src={{this.embedUrl}}
            title={{i18n (themePrefix "homepage.highlights.podcast.label")}}
            allow="autoplay; encrypted-media; picture-in-picture"
            allowfullscreen
          ></iframe>
        {{else if @videoId}}
          <button
            type="button"
            class="highlight-podcast__play"
            aria-label={{i18n (themePrefix "homepage.highlights.podcast.play")}}
            {{on "click" this.play}}
          >
            {{#if this.thumbnail}}
              <img src={{this.thumbnail}} alt="" loading="lazy" />
            {{/if}}
            <span class="highlight-podcast__play-icon">{{dIcon "play"}}</span>
          </button>
        {{else}}
          <a href={{@topic.url}} class="highlight-podcast__link">
            {{#if this.thumbnail}}
              <img src={{this.thumbnail}} alt="" loading="lazy" />
            {{else}}
              <span class="highlight-card__placeholder">{{dIcon "podcast"}}</span>
            {{/if}}
          </a>
        {{/if}}
      </div>

      <div class="highlight-card__body">
        <div class="highlight-card__label">
          {{dIcon "podcast"}}
          {{i18n (themePrefix "homepage.highlights.podcast.label")}}
        </div>
        <h3 class="highlight-card__title">
          <a href={{@topic.url}}>{{trustHTML @topic.fancy_title}}</a>
        </h3>
        <DButton
          class="btn-flat highlight-card__cta"
          @href={{@topic.url}}
          @translatedLabel={{i18n (themePrefix "homepage.highlights.podcast.cta")}}
        />
      </div>
    </article>
  </template>
}
```

- [ ] **Step 4: Verify the tests pass**

`npx pnpm@10.28.0 lint`, then push. Expected: `frontend_tests` GREEN for the podcast-card module.

- [ ] **Step 5: Commit**

```bash
git add javascripts/discourse/components/highlight-podcast-card.gjs test/integration/homepage-highlights-test.gjs
git commit -m "$(cat <<'EOF'
feat: HighlightPodcastCard — thumbnail that plays in place

Play button swaps the YouTube thumbnail for an embedded www.youtube.com
player. No video id -> thumbnail links to the topic, no button.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017RihJJnZkywjNM1UeMkZQo
EOF
)"
```

---

## Task 4: `HighlightMemberCard` component

**Files:**
- Create: `javascripts/discourse/components/highlight-member-card.gjs`
- Test: `test/integration/homepage-highlights-test.gjs` (add a module)

**Interfaces:**
- Consumes: `avatar` from `discourse/helpers/avatar`.
- Produces: default export `HighlightMemberCard`, taking `@member` — either `null`/`undefined`, or a directory item `{ post_count, likes_received, days_visited, user: { username, name, avatar_template } }`.

- [ ] **Step 1: Write the failing rendering tests**

Add to `test/integration/homepage-highlights-test.gjs`:

```js
module("Espublico Theme | Integration | highlights | member card", function (hooks) {
  setupRenderingTest(hooks);

  const member = {
    post_count: 40,
    likes_received: 96,
    days_visited: 12,
    user: { username: "msanz", name: "María Sanz", avatar_template: "/letter_avatar/msanz/{size}/1.png" },
  };

  test("shows the badge, the figures and a profile link", async function (assert) {
    await render(<template><HighlightMemberCard @member={{member}} /></template>);

    assert.dom(".highlight-member").includesText("Member of the month");
    assert.dom(".highlight-member__figures").includesText("40 posts");
    assert.dom(".highlight-member__figures").includesText("96 likes");
    assert.dom(".highlight-member__figures").includesText("12 active days");
    assert.dom(".highlight-card__cta").hasAttribute("href", "/u/msanz/summary");
    assert.dom(".highlight-member__avatar").hasAttribute("href", "/u/msanz/summary");
  });

  test("falls back to the username when the member has no display name", async function (assert) {
    const noName = { ...member, user: { ...member.user, name: null } };
    await render(<template><HighlightMemberCard @member={{noName}} /></template>);
    assert.dom(".highlight-card__title").hasText("msanz");
  });

  test("with no member, renders the take-part CTA instead", async function (assert) {
    await render(<template><HighlightMemberCard @member={{null}} /></template>);

    assert.dom(".highlight-member__empty").exists();
    assert.dom(".highlight-member__empty").includesText("Post and take part this month");
    assert.dom(".highlight-card__cta").hasAttribute("href", "/new-topic");
    assert.dom(".highlight-member__figures").doesNotExist();
  });
});
```

- [ ] **Step 2: Verify the tests fail**

`npx pnpm@10.28.0 lint`, then push. Expected: `frontend_tests` RED — component missing.

- [ ] **Step 3: Write the component**

`javascripts/discourse/components/highlight-member-card.gjs`:

```gjs
import Component from "@glimmer/component";
import avatar from "discourse/helpers/avatar";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// The bottom-right twin card. Presentational: the block hands down the ranked
// directory item, or nothing. With a member it is an avatar, the raw figures
// that earned the spot, and a "member of the month" badge. With nobody eligible
// — a quiet month, or the directory switched off — it is a nudge to take part,
// which also stops the bento grid growing a hole.
export default class HighlightMemberCard extends Component {
  get user() {
    return this.args.member?.user;
  }

  get displayName() {
    return this.user.name || this.user.username;
  }

  get profileUrl() {
    return `/u/${this.user.username}/summary`;
  }

  <template>
    <article class="highlight-card highlight-member">
      {{#if @member}}
        <a href={{this.profileUrl}} class="highlight-member__avatar">
          {{avatar this.user imageSize="large"}}
        </a>
        <div class="highlight-card__body">
          <div class="highlight-card__label">
            {{dIcon "star"}}
            {{i18n (themePrefix "homepage.highlights.member.badge")}}
          </div>
          <h3 class="highlight-card__title">
            <a href={{this.profileUrl}}>{{this.displayName}}</a>
          </h3>
          <p class="highlight-member__figures">
            <span>{{i18n
                (themePrefix "homepage.highlights.member.posts")
                count=@member.post_count
              }}</span>
            <span>{{i18n
                (themePrefix "homepage.highlights.member.likes")
                count=@member.likes_received
              }}</span>
            <span>{{i18n
                (themePrefix "homepage.highlights.member.days")
                count=@member.days_visited
              }}</span>
          </p>
          <DButton
            class="btn-flat highlight-card__cta"
            @href={{this.profileUrl}}
            @translatedLabel={{i18n (themePrefix "homepage.highlights.member.profile")}}
          />
        </div>
      {{else}}
        <div class="highlight-card__body highlight-member__empty">
          <span class="highlight-card__placeholder">{{dIcon "star"}}</span>
          <p>{{i18n (themePrefix "homepage.highlights.member.cta_empty")}}</p>
          <DButton
            class="btn-flat highlight-card__cta"
            @href="/new-topic"
            @translatedLabel={{i18n
              (themePrefix "homepage.highlights.member.cta_empty_button")
            }}
          />
        </div>
      {{/if}}
    </article>
  </template>
}
```

- [ ] **Step 4: Verify the tests pass**

`npx pnpm@10.28.0 lint`, then push. Expected: `frontend_tests` GREEN for the member-card module.

- [ ] **Step 5: Commit**

```bash
git add javascripts/discourse/components/highlight-member-card.gjs test/integration/homepage-highlights-test.gjs
git commit -m "$(cat <<'EOF'
feat: HighlightMemberCard — the month's most active member, or a nudge

Avatar, the raw figures that earned the spot, a "member of the month"
badge. Handed no member, it renders the take-part CTA that also keeps the
bento grid whole.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017RihJJnZkywjNM1UeMkZQo
EOF
)"
```

---

## Task 5: `block-highlights.gjs` — frame, grid, content cells

**Files:**
- Create: `javascripts/discourse/blocks/block-highlights.gjs`
- Create: `stylesheets/blocks/block-highlights.scss`
- Modify: `stylesheets/blocks/_index.scss`
- Test: `test/integration/homepage-highlights-test.gjs` (add a module)

**Interfaces:**
- Consumes: `loadLatestTaggedTopic` from `lib/highlights.js`. `HighlightPodcastCard` / `HighlightMemberCard` are **not** imported here — Task 6 adds those imports when it wires their cells. (Importing a component that already exists is harmless, but leaving it unused would trip lint; there is no bundle-trap reason to import early — that trap is about `lib/` exports, not components.)
- Produces: default export `BlockHighlights`, registered as `theme:espublico:highlights` with args `title`, `podcastTag`, `newsletterTag`, `newsTag`, `memberPeriod` — **all five declared from this commit**, so no later task adds an arg (an undeclared arg aborts the whole QUnit run).

- [ ] **Step 1: Write the failing tests**

Add to `test/integration/homepage-highlights-test.gjs`. This module uses the `<BlockOutlet>` pattern from `test/integration/homepage-lanes-test.gjs` — read that file's header comment first (why `main-outlet-blocks` and not `homepage-blocks`, why the store is replaced outright, the 900000+ id range).

```js
import { render } from "@ember/test-helpers";
import BlockOutlet from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
import BlockHighlights from "../../discourse/blocks/block-highlights";

function stubStore(owner, byFilter) {
  // byFilter: { "tag/podcast/l/latest": [topic, …], … }. A filter with no entry
  // resolves to an empty list.
  owner.unregister("service:store");
  owner.register(
    "service:store",
    {
      findFiltered: async (_type, { filter }) => ({ topics: byFilter[filter] || [] }),
    },
    { instantiate: false }
  );
}

function renderHighlights(args) {
  withPluginApi((api) =>
    api.renderBlocks("main-outlet-blocks", [{ block: BlockHighlights, args }])
  );
  return render(<template><BlockOutlet @name="main-outlet-blocks" /></template>);
}

const DEFAULT_ARGS = {
  title: "homepage.highlights.title",
  podcastTag: "podcast",
  newsletterTag: "newsletter",
  newsTag: "nueva-version-gestiona",
  memberPeriod: "monthly",
};

module("Espublico Theme | Integration | highlights | section", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the heading and the newsletter and novedad cards", async function (assert) {
    stubStore(this.owner, {
      "tag/newsletter/l/latest": [
        { id: 900101, fancy_title: "Newsletter 14", url: "/t/nl-14/900101", excerpt: "Resumen de julio.", image_url: null },
      ],
      "tag/nueva-version-gestiona/l/latest": [
        { id: 900102, fancy_title: "Gestiona V9.3", url: "/t/v93/900102", excerpt: "Firma en lote.", image_url: null },
      ],
    });

    await renderHighlights(DEFAULT_ARGS);

    assert.dom(".block-highlights__title").hasText("Community highlights");
    assert.dom(".block-highlights__cell.--news .highlight-card__title").includesText("Newsletter 14");
    assert.dom(".block-highlights__cell.--news .highlight-card__excerpt").hasText("Resumen de julio.");
    assert.dom(".block-highlights__cell.--novedad .highlight-card__title").includesText("Gestiona V9.3");
    // novedad is the compact variant — no excerpt
    assert.dom(".block-highlights__cell.--novedad .highlight-card__excerpt").doesNotExist();
  });

  test("a content card with no topic shows the coming-soon placeholder", async function (assert) {
    stubStore(this.owner, {}); // every filter empty

    await renderHighlights(DEFAULT_ARGS);

    assert.dom(".block-highlights__cell.--news .highlight-card.--empty").exists();
    assert.dom(".block-highlights__cell.--news").includesText("Coming soon");
  });

  test("a content card with a topic but no image shows the placeholder icon, not a broken img", async function (assert) {
    stubStore(this.owner, {
      "tag/newsletter/l/latest": [
        { id: 900103, fancy_title: "Sin imagen", url: "/t/x/900103", excerpt: "x", image_url: null },
      ],
    });

    await renderHighlights(DEFAULT_ARGS);

    assert.dom(".block-highlights__cell.--news .highlight-card__media img").doesNotExist();
    assert.dom(".block-highlights__cell.--news .highlight-card__placeholder").exists();
  });

  test("the section does not render when all three tags are empty", async function (assert) {
    stubStore(this.owner, {});

    await renderHighlights({ ...DEFAULT_ARGS, podcastTag: "", newsletterTag: "", newsTag: "" });

    assert.dom(".block-highlights").doesNotExist();
  });

  // Two separate tests, not one: a second `renderBlocks("main-outlet-blocks", …)`
  // inside one test body raises "already has a layout registered" — the reset is
  // between rendering tests, not within (see homepage-lanes-test.gjs).
  test("the grid modifier is --count-4 with all three tags set", async function (assert) {
    stubStore(this.owner, {});
    await renderHighlights(DEFAULT_ARGS);
    assert.dom(".block-highlights__grid.--count-4").exists("podcast + newsletter + novedad + member");
  });

  test("the grid modifier drops to --count-3 when a content tag is empty", async function (assert) {
    stubStore(this.owner, {});
    await renderHighlights({ ...DEFAULT_ARGS, newsTag: "" });
    assert.dom(".block-highlights__grid.--count-3").exists();
    assert.dom(".block-highlights__cell.--novedad").doesNotExist("no novedad cell");
  });
});
```

- [ ] **Step 2: Verify the tests fail**

`npx pnpm@10.28.0 lint`, then push. Expected: `frontend_tests` RED — `block-highlights` missing.

- [ ] **Step 3: Write the block**

`javascripts/discourse/blocks/block-highlights.gjs`:

```gjs
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import { eq } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { loadLatestTaggedTopic } from "../lib/highlights";

// A content card for the newsletter and novedad cells: an optional cover image
// (or a branded placeholder), a label, the topic title and a CTA. `fancy_title`
// is already cooked HTML — `trustHTML`, as everywhere else in these blocks. The
// excerpt shows only on the tall variant; `serialize_topic_excerpts` (about.json)
// is what serialises it.
const ContentCard = <template>
  <article class="highlight-card highlight-content --{{@variant}}">
    <div class="highlight-card__media">
      {{#if @topic.image_url}}
        <img src={{@topic.image_url}} alt="" loading="lazy" />
      {{else}}
        <span class="highlight-card__placeholder">{{dIcon @icon}}</span>
      {{/if}}
    </div>
    <div class="highlight-card__body">
      <div class="highlight-card__label">
        {{dIcon @icon}}
        {{i18n (themePrefix @label)}}
      </div>
      <h3 class="highlight-card__title">
        <a href={{@topic.url}}>{{trustHTML @topic.fancy_title}}</a>
      </h3>
      {{#if (eq @variant "tall")}}
        <p class="highlight-card__excerpt">{{@topic.excerpt}}</p>
      {{/if}}
      <DButton
        class="btn-flat highlight-card__cta"
        @href={{@topic.url}}
        @translatedLabel={{i18n (themePrefix @cta)}}
      />
    </div>
  </article>
</template>;

// Shown in a content cell whose tag is set but currently has no topic.
const Placeholder = <template>
  <article class="highlight-card highlight-content --{{@variant}} --empty">
    <div class="highlight-card__body">
      <span class="highlight-card__placeholder">{{dIcon @icon}}</span>
      <p>{{i18n (themePrefix "homepage.highlights.soon")}}</p>
    </div>
  </article>
</template>;

// Section 2 of the homepage: a bento of four cards. Each cell has its own
// `<DAsyncContent>` so the fetches load and fail independently — there is no
// combined fetch phase, which is why newsletter and podcast can (today) resolve
// to the same topic and the fix for that is tag hygiene, not code.
//
// The section renders only when at least one content tag is set. The member card
// is a companion — it never keeps the section alive on its own.
@block("theme:espublico:highlights", {
  description:
    "A bento of the community's podcast, newsletter, latest release and top member",
  args: {
    title: { type: "string" },
    podcastTag: { type: "string", default: "" },
    newsletterTag: { type: "string", default: "" },
    newsTag: { type: "string", default: "" },
    memberPeriod: { type: "string", default: "monthly" },
  },
})
export default class BlockHighlights extends Component {
  @service store;

  get active() {
    return Boolean(
      this.args.podcastTag || this.args.newsletterTag || this.args.newsTag
    );
  }

  // Podcast + newsletter + novedad, whichever have a tag set, plus the member
  // card, which is always present (it renders a CTA when nobody qualifies).
  get cellCount() {
    return (
      1 +
      (this.args.podcastTag ? 1 : 0) +
      (this.args.newsletterTag ? 1 : 0) +
      (this.args.newsTag ? 1 : 0)
    );
  }

  @bind
  fetchNewsletter() {
    return loadLatestTaggedTopic(this.store, this.args.newsletterTag);
  }

  @bind
  fetchNews() {
    return loadLatestTaggedTopic(this.store, this.args.newsTag);
  }

  <template>
    {{#if this.active}}
      <section class="block-highlights">
        <header class="block-highlights__header">
          <h2 class="block-highlights__title">
            {{dIcon "star"}}
            {{i18n (themePrefix @title)}}
          </h2>
        </header>

        <div class="block-highlights__grid --count-{{this.cellCount}}">
          {{#if @newsletterTag}}
            <div class="block-highlights__cell --news">
              <DAsyncContent @asyncData={{this.fetchNewsletter}}>
                <:content as |topic|>
                  <ContentCard
                    @topic={{topic}}
                    @variant="tall"
                    @icon="envelope"
                    @label="homepage.highlights.newsletter.label"
                    @cta="homepage.highlights.newsletter.cta"
                  />
                </:content>
                <:empty>
                  <Placeholder @variant="tall" @icon="envelope" />
                </:empty>
              </DAsyncContent>
            </div>
          {{/if}}

          {{#if @newsTag}}
            <div class="block-highlights__cell --novedad">
              <DAsyncContent @asyncData={{this.fetchNews}}>
                <:content as |topic|>
                  <ContentCard
                    @topic={{topic}}
                    @variant="compact"
                    @icon="rocket"
                    @label="homepage.highlights.news.label"
                    @cta="homepage.highlights.news.cta"
                  />
                </:content>
                <:empty>
                  <Placeholder @variant="compact" @icon="rocket" />
                </:empty>
              </DAsyncContent>
            </div>
          {{/if}}

          {{! podcast cell and the always-present member cell are wired in Task 6,
              between the newsletter cell and the novedad cell / after novedad }}
        </div>
      </section>
    {{/if}}
  </template>
}
```

At this stage only the newsletter and novedad cells render. `--count-4` still means "four cells will be active once Task 6 lands" — `cellCount` counts tags + the (not-yet-rendered) member, so the grid modifier is already correct; the tuned bento areas just reference `podcast`/`miembro` grid-areas that have no item yet. That is a one-commit intermediate state; do not ship it without Task 6.

- [ ] **Step 4: Write the SCSS**

`stylesheets/blocks/block-highlights.scss`:

```scss
// The community-highlights section: a bento of four cards below section 1.
// Frame and header come from the shared lane mixins; the asymmetric grid and
// the card treatments are this section's own. Tokens: `--ga-*` from
// stylesheets/brand/colors.scss, all verified present.
.block-highlights {
  @include lane-frame;

  &__header {
    @include lane-header;
  }

  &__title {
    @include lane-title;
  }

  &__grid {
    display: grid;
    gap: var(--space-4);
    // The safe default for any card count: a responsive row that wraps. The
    // tuned bento only replaces this at --count-4 on a wide container.
    grid-template-columns: repeat(auto-fit, minmax(min(100%, 16rem), 1fr));
  }

  // The tuned arrangement. 56rem is the panel's own threshold, measured against
  // the container (the content column narrows when the sidebar opens); the
  // 40rem step keeps the newsletter card from becoming a tower on a tablet.
  &__grid.--count-4 {
    @container homepage-blocks (width > 40rem) {
      grid-template-columns: 1fr 1fr;
      grid-template-areas:
        "news    podcast"
        "novedad miembro";
    }

    @container homepage-blocks (width > 56rem) {
      grid-template-columns: 0.95fr 1.35fr 1fr;
      grid-template-areas:
        "news podcast podcast"
        "news novedad miembro";
    }
  }

  &__cell {
    display: flex; // the card fills the cell — matters where `news` spans two rows
    min-width: 0;

    &.--news {
      grid-area: news;
    }

    &.--podcast {
      grid-area: podcast;
    }

    &.--novedad {
      grid-area: novedad;
    }

    &.--miembro {
      grid-area: miembro;
    }
  }
}

// One card. Flat bordered surface — "bordes antes que sombras"; only the section
// frame carries a shadow.
.highlight-card {
  display: flex;
  flex: 1;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid var(--ga-border);
  border-radius: var(--d-border-radius-large);
  background: var(--ga-card);

  &__media {
    position: relative;
    aspect-ratio: 16 / 10;
    background: var(--ga-muted);

    img {
      display: block;
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  &__placeholder {
    display: grid;
    place-items: center;
    min-height: 6rem;
    color: var(--ga-mark);
    font-size: var(--font-up-3);
  }

  &__body {
    display: flex;
    flex: 1;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3);
  }

  &__label {
    display: flex;
    align-items: center;
    gap: var(--space-half);
    color: var(--tertiary);
    font-size: var(--font-down-2);
    font-weight: 700;
    letter-spacing: 0.04em;
    text-transform: uppercase;

    .d-icon {
      color: var(--ga-mark);
    }
  }

  &__title {
    margin: 0;
    font-size: var(--font-0);
    font-weight: 700;
    line-height: var(--line-height-medium);

    a {
      color: inherit;
    }

    a:hover,
    a:focus-visible {
      color: var(--tertiary);
    }
  }

  &__excerpt {
    display: -webkit-box;
    overflow: hidden;
    margin: 0;
    color: var(--ga-muted-fg);
    font-size: var(--font-down-1);
    line-height: var(--line-height-medium);
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  &__cta {
    align-self: flex-start;
    margin-top: auto;
  }
}

// The newsletter card leads with a tall portrait image; the compact novedad card
// has no image at all.
.highlight-content.--tall .highlight-card__media {
  aspect-ratio: 3 / 4;
}

.highlight-content.--compact .highlight-card__media {
  display: none;
}

.highlight-content.--empty .highlight-card__body {
  align-items: center;
  color: var(--ga-muted-fg);
  text-align: center;
}

// The podcast card: a 16:9 frame that swaps thumbnail for player in place.
.highlight-podcast {
  &__frame {
    position: relative;
    aspect-ratio: 16 / 9;
    background: var(--ga-muted);
  }

  &__player,
  &__play img,
  &__link img {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    border: 0;
    object-fit: cover;
  }

  &__play {
    position: absolute;
    inset: 0;
    display: grid;
    place-items: center;
    padding: 0;
    border: 0;
    background: transparent;
    cursor: pointer;
  }

  &__play-icon {
    position: relative;
    display: grid;
    place-items: center;
    width: 3.5rem;
    height: 3.5rem;
    border-radius: 50%;
    background: var(--ga-mark);
    color: var(--ga-petrol-950);
    font-size: var(--font-up-2);
    box-shadow: 0 4px 16px rgb(0 0 0 / 30%);
  }
}

// The member card: avatar, then the figures that earned the spot.
.highlight-member {
  &__avatar {
    display: block;
    padding: var(--space-3) var(--space-3) 0;

    img {
      border-radius: 50%;
    }
  }

  &__figures {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-half) var(--space-2);
    margin: 0;
    color: var(--ga-muted-fg);
    font-size: var(--font-down-1);
    font-variant-numeric: tabular-nums;
  }

  &__empty {
    align-items: flex-start;
    color: var(--ga-muted-fg);
    text-align: left;
  }
}
```

- [ ] **Step 5: Register the SCSS file**

In `stylesheets/blocks/_index.scss`, add the import (keep the existing order — latest, events, forum, then this):

```scss
@import "block-latest";
@import "block-events";
@import "block-forum";
@import "block-highlights";
```

- [ ] **Step 6: Verify**

`npx pnpm@10.28.0 lint` (stylelint will check the SCSS — no raw media queries, BEM modifiers, property order). Then push.
Expected: `frontend_tests` GREEN for the `section` module; lint clean.

- [ ] **Step 7: Commit**

```bash
git add javascripts/discourse/blocks/block-highlights.gjs stylesheets/blocks/block-highlights.scss stylesheets/blocks/_index.scss test/integration/homepage-highlights-test.gjs
git commit -m "$(cat <<'EOF'
feat: BlockHighlights — section frame, bento grid, content cards

The section, its asymmetric grid (tuned only at --count-4 on a wide
container, responsive-wrap otherwise), and the newsletter/novedad content
cards with their coming-soon placeholder. Podcast and member cells are
stubbed until the next commit. Renders only when a content tag is set.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017RihJJnZkywjNM1UeMkZQo
EOF
)"
```

---

## Task 6: wire the podcast and member cells

**Files:**
- Modify: `javascripts/discourse/blocks/block-highlights.gjs`
- Test: `test/integration/homepage-highlights-test.gjs` (extend the `section` module)

**Interfaces:**
- Consumes: `HighlightPodcastCard`, `HighlightMemberCard` (already imported); `extractVideoId`, `rankTopMember`, `memberHasActivity`, `WEIGHTS` from `lib/highlights.js`; `ajax` from `discourse/lib/ajax`.
- Produces: no new exports or args.

- [ ] **Step 1: Write the failing tests**

The two cells make raw `ajax` calls (`/t/<id>.json` for the podcast video, `/directory_items.json` for the member). `setupRenderingTest` installs the global pretender; add routes to it. Import at the top of the test file:

```js
import pretender, { response } from "discourse/tests/helpers/create-pretender";
```

**If that import path fails to resolve in CI**, the fallback is to move these two tests into an `acceptance(...)` module (pattern: `test/acceptance/topbar-test.js`) that does `needs.pretender(...)`, `needs.user()`, renders the block into `main-outlet-blocks` in a `needs.hooks.beforeEach`, and `visit("/latest")`. Do not spend a second CI cycle guessing — check the import once, then commit to one path.

Add to the `section` module in `test/integration/homepage-highlights-test.gjs`:

```js
test("the podcast cell embeds the video from the topic's first post", async function (assert) {
  stubStore(this.owner, {
    "tag/podcast/l/latest": [
      { id: 2597, fancy_title: "Episodio 7", url: "/t/ep-7/2597", image_url: null },
    ],
  });
  pretender.get("/t/2597.json", () =>
    response({
      post_stream: {
        posts: [
          { cooked: `<div class="lazy-video-container" data-video-id="1qH2Ye8IJrE"></div>` },
        ],
      },
    })
  );
  pretender.get("/directory_items.json", () => response({ directory_items: [] }));

  await renderHighlights({ ...DEFAULT_ARGS, newsletterTag: "", newsTag: "" });

  assert.dom(".block-highlights__cell.--podcast .highlight-podcast__play").exists();
});

test("the podcast cell degrades to a topic link when the first post has no video", async function (assert) {
  stubStore(this.owner, {
    "tag/podcast/l/latest": [
      { id: 2592, fancy_title: "Newsletter 14", url: "/t/nl-14/2592", image_url: null },
    ],
  });
  pretender.get("/t/2592.json", () =>
    response({ post_stream: { posts: [{ cooked: `<p>No video here.</p>` }] } })
  );
  pretender.get("/directory_items.json", () => response({ directory_items: [] }));

  await renderHighlights({ ...DEFAULT_ARGS, newsletterTag: "", newsTag: "" });

  assert.dom(".block-highlights__cell.--podcast .highlight-podcast__play").doesNotExist();
  assert.dom(".block-highlights__cell.--podcast .highlight-podcast__link").exists();
});

test("the member cell crowns the highest composite and shows the figures", async function (assert) {
  stubStore(this.owner, {});
  pretender.get("/directory_items.json", () =>
    response({
      directory_items: [
        { post_count: 2, likes_received: 1, days_visited: 3, user: { username: "a", name: "A", avatar_template: "/a/{size}.png" } },
        { post_count: 40, likes_received: 96, days_visited: 12, user: { username: "msanz", name: "María Sanz", avatar_template: "/m/{size}.png" } },
      ],
    })
  );

  await renderHighlights({ ...DEFAULT_ARGS, podcastTag: "", newsletterTag: "", newsTag: "nueva-version-gestiona" });
  // (newsTag kept non-empty only so the section renders; its cell is a placeholder)

  assert.dom(".block-highlights__cell.--miembro .highlight-card__title").hasText("María Sanz");
  assert.dom(".block-highlights__cell.--miembro .highlight-member__figures").includesText("40 posts");
});

test("the member cell falls to the CTA when the directory is all zeros", async function (assert) {
  stubStore(this.owner, {});
  pretender.get("/directory_items.json", () =>
    response({
      directory_items: [
        { post_count: 0, likes_received: 0, days_visited: 9, user: { username: "z", name: "Z", avatar_template: "/z/{size}.png" } },
      ],
    })
  );

  await renderHighlights({ ...DEFAULT_ARGS, podcastTag: "", newsletterTag: "" });

  assert.dom(".block-highlights__cell.--miembro .highlight-member__empty").exists();
});

test("the member cell falls to the CTA when the directory request fails", async function (assert) {
  stubStore(this.owner, {});
  pretender.get("/directory_items.json", () => response(403, { errors: ["forbidden"] }));

  await renderHighlights({ ...DEFAULT_ARGS, podcastTag: "", newsletterTag: "" });

  assert.dom(".block-highlights__cell.--miembro .highlight-member__empty").exists();
});
```

- [ ] **Step 2: Verify the tests fail**

`npx pnpm@10.28.0 lint`, then push. Expected: RED — the `.--podcast` and `.--miembro` cells are not rendered yet (`{{#if false}}`).

- [ ] **Step 3: Wire the cells**

In `block-highlights.gjs`:

1. Add imports:

```gjs
import { ajax } from "discourse/lib/ajax";
```

and extend the `lib/highlights` import:

```gjs
import {
  extractVideoId,
  loadLatestTaggedTopic,
  memberHasActivity,
  rankTopMember,
  WEIGHTS,
} from "../lib/highlights";
```

2. Add two `@bind` fetch methods to the class:

```gjs
  @bind
  async fetchPodcast() {
    const topic = await loadLatestTaggedTopic(this.store, this.args.podcastTag);
    if (!topic) {
      return null;
    }
    // Cheap second hop: the topic list carries no post bodies, and the video id
    // lives in the first post's cooked HTML. A removed or access-controlled
    // topic just means no inline player.
    let videoId = null;
    try {
      const full = await ajax(`/t/${topic.id}.json`);
      videoId = extractVideoId(full?.post_stream?.posts?.[0]?.cooked);
    } catch {
      videoId = null;
    }
    return { topic, videoId };
  }

  @bind
  async fetchMember() {
    // A directory that is switched off or unreachable is the same as nobody
    // qualifying: the card falls to its take-part nudge. Any `order` works —
    // rankTopMember re-ranks — so the directory's own default is fine.
    let member = null;
    try {
      const { directory_items } = await ajax(
        `/directory_items.json?period=${this.args.memberPeriod}&order=likes_received&limit=50`
      );
      const top = rankTopMember(directory_items, WEIGHTS);
      member = memberHasActivity(top) ? top : null;
    } catch {
      member = null;
    }
    return { member };
  }
```

3. Replace the `{{#if false}}` block with the real cells (placed **between** the newsletter cell and the novedad cell so the source order matches the visual order news → podcast → novedad → miembro):

```gjs
          {{#if @podcastTag}}
            <div class="block-highlights__cell --podcast">
              <DAsyncContent @asyncData={{this.fetchPodcast}}>
                <:content as |data|>
                  <HighlightPodcastCard
                    @topic={{data.topic}}
                    @videoId={{data.videoId}}
                  />
                </:content>
                <:empty>
                  <Placeholder @variant="wide" @icon="podcast" />
                </:empty>
              </DAsyncContent>
            </div>
          {{/if}}
```

and after the novedad cell, the always-present member cell:

```gjs
          <div class="block-highlights__cell --miembro">
            <DAsyncContent @asyncData={{this.fetchMember}}>
              <:content as |data|>
                <HighlightMemberCard @member={{data.member}} />
              </:content>
            </DAsyncContent>
          </div>
```

`fetchMember` always resolves to a `{ member }` object (never null/empty), so the member cell needs no `<:empty>` slot — `HighlightMemberCard` renders its own CTA when `@member` is falsy.

- [ ] **Step 4: Verify the tests pass**

`npx pnpm@10.28.0 lint`, then push. Expected: `frontend_tests` GREEN across the whole `homepage-highlights` file.

- [ ] **Step 5: Commit**

```bash
git add javascripts/discourse/blocks/block-highlights.gjs test/integration/homepage-highlights-test.gjs
git commit -m "$(cat <<'EOF'
feat: wire the podcast and member cells into BlockHighlights

Podcast: a second hop to /t/<id>.json, extractVideoId on the first post's
cooked HTML, degrade to a topic link when there is none. Member:
directory_items re-ranked by the weighted composite, falling to the
take-part CTA on a quiet month or a failed request.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017RihJJnZkywjNM1UeMkZQo
EOF
)"
```

---

## Task 7: mount the block, bump the version, tidy the comments

**Files:**
- Modify: `javascripts/discourse/api-initializers/homepage-blocks.gjs`
- Modify: `about.json` (`theme_version`)
- Modify: `javascripts/discourse/blocks/block-latest.gjs` (comment only)
- Modify: `traceability.md`

**Interfaces:**
- Consumes: `BlockHighlights` from `../blocks/block-highlights`.
- Produces: the live section on the homepage.

- [ ] **Step 1: Add the block to the homepage**

In `javascripts/discourse/api-initializers/homepage-blocks.gjs`:

1. Import it near the other block imports:

```js
import BlockHighlights from "../blocks/block-highlights";
```

2. Add a third top-level entry to the `api.renderBlocks("homepage-blocks", [...])` array, **after** the `home-latest` group's closing `},` and before the array's closing `]`:

```js
    // Section 2. The community highlights bento — see
    // docs/superpowers/specs/2026-08-29-community-highlights-design.md. Its own
    // SCSS carries the grid; here it is just one more section of the stack.
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
    },
```

- [ ] **Step 2: Bump `theme_version`**

In `about.json`: `"theme_version": "0.35.0"` → `"theme_version": "0.36.0"`.

- [ ] **Step 3: Fix the stale comment in `block-latest.gjs`**

The block comment currently says `serialize_topic_excerpts` is "now dead weight — left in place for a separate about.json pass". Replace that sentence (around the "What is given up is the excerpt" paragraph) with:

```
// What is given up here is the excerpt: the native list has no room for one.
// `serialize_topic_excerpts` (about.json) is still earned, though — the
// community-highlights content cards read `topic.excerpt`.
```

Keep the rest of the comment. Do not touch `about.json`'s `serialize_topic_excerpts` or `topic_thumbnail_sizes` — both are now used again (see the spec's `about.json` section).

- [ ] **Step 4: Add the traceability entry**

Append a concise entry to `traceability.md` in the same style as the existing ones (date, what shipped, the two or three non-obvious facts). Cover: the section ships as 0.36.0; `directory_items` on this Discourse version has no `time_read` (composite uses `days_visited`); the podcast video id comes from the first post's `data-video-id` lazy-video container; the member card cannot be validated on PRE (30-day directory all zeros) and needs a PROD check or a wait.

- [ ] **Step 5: Verify**

Run: `npx pnpm@10.28.0 lint`
Expected: PASS.

Push and wait for the **full** CI suite (`linting`, `frontend_tests`, `backend_tests`, `system_tests`).
Expected: all GREEN. `system_tests` runs core's shared "core features" examples against the theme; this section adds no server-side behaviour and removes no core flow, so nothing there should move.

- [ ] **Step 6: Commit**

```bash
git add javascripts/discourse/api-initializers/homepage-blocks.gjs about.json javascripts/discourse/blocks/block-latest.gjs traceability.md
git commit -m "$(cat <<'EOF'
feat: mount the community-highlights section on the homepage (0.36.0)

Third top-level entry in homepage-blocks, after the latest section. Bumps
theme_version to 0.36.0 and corrects the block-latest comment that called
serialize_topic_excerpts dead weight — the new content cards read it.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017RihJJnZkywjNM1UeMkZQo
EOF
)"
```

- [ ] **Step 7: Open the PR**

```bash
git push -u origin feat/homepage-highlights-section
gh pr create --fill --base main
```

PR body should list: what ships (the four-card section), the spec path, the admin follow-ups from the spec (create `nueva-version-gestiona`, tag hygiene, cover images, keep `enable_user_directory` on), and the manual-PRE checklist below. End the body with:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_017RihJJnZkywjNM1UeMkZQo
```

---

## Manual verification on PRE (after merge, or on a theme-creator preview)

Nothing below is covered by CI — category listings and the homepage are unguarded (`skip_examples` takes `topics:read`).

1. **The bento at three widths:** narrow (< 40rem, single column), tablet (40–56rem, 2×2), wide (> 56rem, the full bento with the newsletter tower). Resize the window *and* toggle the sidebar — the threshold is the container, not the viewport.
2. **Podcast playback end to end:** thumbnail loads → click → the video plays inside the card. If the embed is blank, check the browser console for a CSP `frame-src` violation and confirm `www.youtube.com` is allowed (it is what core's lazy-video uses).
3. **Placeholders:** with today's content most source topics have no cover image, so the newsletter and novedad cards should show the branded icon block, not a broken image.
4. **The member card cannot be checked with live PRE data** — its 30-day directory is all zeros. Either check on PROD once the theme is there, or revisit when PRE activity picks up. Until then it correctly shows the take-part CTA.
5. **Read the instance's `remote_theme` record** before concluding the section is or isn't live — `commits_behind: 0` with a stale `updated_at` is not proof (see `CLAUDE.md`). Force a pull with `PUT /admin/themes/15.json {"theme":{"remote_update":true}}`.

---

## Self-Review

**1. Spec coverage**

| Spec section | Task |
|---|---|
| Scope — one Block in `homepage-blocks` | Task 5 (block), Task 7 (mount) |
| Approach 3 — thin block + components + pure lib | Tasks 1, 3, 4, 5, 6 |
| Architecture — initializer entry | Task 7 |
| Architecture — file table | all tasks (see File Structure) |
| Layout — `lane-frame` + bento grid + two breakpoints + reduced layouts | Task 5 (SCSS) |
| Data flow — newsletter/novedad via `loadLatestTaggedTopic` | Tasks 1, 5 |
| Data flow — podcast two-step | Task 6 |
| Data flow — member via `/directory_items.json` + re-rank | Task 6 |
| Pure functions — all five + WEIGHTS | Task 1 |
| Card content — ContentCard, PodcastCard, MemberCard, CTA, Placeholder | Tasks 3, 4, 5 |
| Strings — `homepage.highlights.*` both locales | Task 2 |
| Settings — four + descriptions | Task 2 |
| `about.json` — svg_icons, version, the two modifiers stay | Tasks 2, 7 |
| `block-latest.gjs` comment fix | Task 7 |
| Edge cases — empty tag, no topic, no video, quiet directory, directory error, tag overlap | Tasks 5, 6 (tests); tag overlap is documented-not-coded per spec |
| Testing — unit + integration + manual PRE list | Tasks 1, 3, 4, 5, 6 + Manual section |
| Delivery — lint, branch, PR, 0.36.0 | Task 7 |

No spec requirement is left without a task.

**2. Placeholder scan**

No "TBD"/"TODO"/"handle edge cases"/"similar to Task N" in any step. Every code step carries the actual code. The one conditional instruction — the pretender import fallback in Task 6 Step 1 — names the exact alternative pattern and file rather than deferring the decision.

**3. Type consistency**

- `loadLatestTaggedTopic(store, tag)` — same signature in Task 1 (definition, tests) and Tasks 5/6 (`this.fetchNewsletter`, `this.fetchNews`, `fetchPodcast`).
- `rankTopMember(items, weights)` and `WEIGHTS` — defined Task 1, consumed Task 6 with the same shape `{ posts, likes, days }`.
- `extractVideoId(cooked)` → `string|null` — Task 1, consumed Task 6 as `videoId`, passed to `HighlightPodcastCard @videoId` (Task 3 contract: `string | null`).
- `HighlightPodcastCard` args `@topic`, `@videoId` — identical in Task 3 (definition + tests) and Task 6 (call site).
- `HighlightMemberCard` arg `@member` — nullable directory item in Task 4 and Task 6; `fetchMember` returns `{ member }`, cell reads `data.member`. Consistent.
- CSS class names: `.block-highlights`, `.block-highlights__grid.--count-N`, `.block-highlights__cell.--news/--podcast/--novedad/--miembro`, `.highlight-card__*`, `.highlight-podcast__play/__player/__link/__frame/__play-icon`, `.highlight-member__avatar/__figures/__empty` — every class asserted in a test (Tasks 3–6) is emitted by a template or the SCSS in the same or an earlier task.
- i18n keys: every `homepage.highlights.*` key used in a template (Tasks 3–6) is defined in Task 2, both locales. Checked key by key: `title`, `soon`, `podcast.{label,cta,play}`, `newsletter.{label,cta}`, `news.{label,cta}`, `member.{badge,posts,likes,days,profile,cta_empty,cta_empty_button}`.

No inconsistencies found.

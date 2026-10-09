# Poster Carousel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A horizontal carousel of certified users' posters (`poster-evf` topics with an image) above the topic list on Comparte and each of its subcategories, newest first, image → lightbox, title → topic.

**Architecture:** A plain Glimmer component mounted in the existing `discovery-list-controls-above` initializer, next to `DiscoveryHero`. Pure helpers in `lib/posters.js` select and page the data; the component hands a `@cached` promise to core's `<DAsyncContent>` and binds core's lightbox to the rendered anchors. Native CSS `scroll-snap`, no dependency.

**Tech Stack:** Discourse theme (Glimmer `.gjs`, SCSS, `settings.yml`, locales), QUnit via core's test helpers, `ember-modifier`, `discourse/lib/lightbox`.

**Spec:** `docs/superpowers/specs/2026-10-09-poster-carousel-design.md`

## Global Constraints

- Blocks API stays confined to the homepage: this is a plugin-outlet component, not a Block.
- One outlet per initializer file: extend `discovery-list-controls-above.gjs`, do not create a second file for the same outlet.
- `settings.yml` holds configuration only; every visible string goes in `locales/en.yml` **and** `locales/es.yml`, each setting gets a `theme_metadata.settings.<name>` description in both.
- SCSS: BEM with standalone `--modifier`, `viewport.from()/until()` only — never a raw media query; file imported from `stylesheets/app/_index.scss`.
- No `any`, no new npm or CDN dependency.
- pnpm only via `npx pnpm@10.28.0`.
- Code, comments, commits in English. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- PROD is read-only throughout. PRE writes only after Ricardo approves the reconciliation list (Task 1). Never touch `/t/2683`.
- Never read or print `~/.discourse_theme`; credentials come from `.env.local` (`PROD_DISCOURSE_API_KEY`, `PRE_DISCOURSE_GLOBAL_API_KEY`), piped to consumers, never echoed. Strip a trailing `/` from `*_DISCOURSE_URL`.
- `theme_version` 1.5.0 → 1.6.0.
- Merge only after the four required checks are green; `gh pr merge --auto` does not wait for them from this account.

## Review Focus

1. **`more_topics_url` absent on the TopicList model** — if the store does not copy it, paging stops after page 1. Expected: on PROD 85/94/83 page 1 already holds 12, so the visible result is unchanged; the PRE browser check in Task 6 confirms the property exists. Pinned by the `loadPosters` stop-at-last-page test (Task 2).
2. **Same topic on two pages** (a poster created between two page requests shifts the list) — expected: shown once. Pinned by the dedupe test (Task 2).
3. **A category id that arrives as a string or a list setting with blanks** (`"85|94|"`) — expected: carousel still shows on the listed ids. Pinned by reusing `parseCategoryIds` and the integration test with a trailing separator (Task 4).
4. **Request fails (403 for a member without access to a child, network error)** — expected: nothing rendered, topic list intact, no flash error. Pinned by the rejection test (Task 4).
5. **Moving between two listed categories** — expected: the second category's posters, never the first's. Pinned by the rerender test (Task 4).

---

### Task 1: Reconcile PRE to PROD (read-only diff, then PRE writes after approval)

**Files:**
- Read: `docs/operations/environment-reconciliation.md`, `docs/operations/current-state.md`
- Modify (after approval): `docs/operations/current-state.md`, `traceability.md`
- Scratchpad only: every captured JSON (never the repo)

- [ ] **Step 1: Diff the surfaces the carousel depends on, read-only on both instances**

```bash
cd /Users/ricardoespublico/Documents/proyectos-espublico/theme-discourse
S="$CLAUDE_SCRATCHPAD"   # the session scratchpad path
set -a; . ./.env.local; set +a
P="${PROD_DISCOURSE_URL%/}"; R="${PRE_DISCOURSE_URL%/}"
PH=(-H "Api-Key: $PROD_DISCOURSE_API_KEY" -H "Api-Username: $PROD_DISCOURSE_API_USERNAME")
RH=(-H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PRE_DISCOURSE_API_USERNAME")
# themes + components
for x in P R; do U=${!x}; [ $x = P ] && H=("${PH[@]}") || H=("${RH[@]}")
  curl -s "$U/admin/themes.json" "${H[@]}" > "$S/themes-$x.json"
  jq -c '.themes[]|{id,name,component,parent:[.parent_themes[]?.id],remote:.remote_theme.remote_url,ver:.remote_theme.remote_version}' "$S/themes-$x.json"
done
# Comparte subtree by name
for x in P R; do U=${!x}; [ $x = P ] && H=("${PH[@]}") || H=("${RH[@]}")
  curl -s "$U/categories.json?include_subcategories=true" "${H[@]}" \
   | jq -c --arg x $x '.category_list.categories[]|select(.name=="Comparte")|{x:$x,id,children:[.subcategory_list[]|{id,name}]}'
done
# poster-evf on PRE under its own Comparte ids (fill ids from the line above)
curl -sL "$R/tag/poster-evf/l/latest.json" "${RH[@]}" | jq -c '[.topic_list.topics[]|{c:.category_id,img:(.image_url!=null)}]|group_by(.c)|map({c:.[0].c,n:length,img:(map(select(.img))|length)})'
# core versions
for U in "$P" "$R"; do curl -s "$U/login" | grep -o '<meta name="generator"[^>]*>'; done
```

Expected: PROD lists component 15 "Topic List Thumbnails" (child of 14); PRE does not. Record PRE's Comparte id and its children's ids, and how many `poster-evf` topics with images PRE has under them.

- [ ] **Step 2: Diff the full site settings and our theme's settings (the standard reconciliation)**

```bash
for x in P R; do U=${!x}; [ $x = P ] && H=("${PH[@]}") || H=("${RH[@]}")
  curl -s "$U/admin/site_settings.json" "${H[@]}" | jq -S '[.site_settings[]|{(.setting):.value}]|add' > "$S/ss-$x.json"
done
diff "$S/ss-P.json" "$S/ss-R.json" | head -80
jq -S '.themes[]|select(.id==14)|[.settings[]|{(.setting):.value}]|add' "$S/themes-P.json" > "$S/ts-P.json"
jq -S '.themes[]|select(.id==15)|[.settings[]|{(.setting):.value}]|add' "$S/themes-R.json" > "$S/ts-R.json"
diff "$S/ts-P.json" "$S/ts-R.json"
```

Expected: a list of differences. `header_room_category_ids` and `automatically_clean_unused_tags` differ by design (see the reconciliation doc).

- [ ] **Step 3: STOP — show Ricardo the difference list and the proposed PRE writes**

Proposed writes to put to him (nothing is written before his yes):
1. Install `https://github.com/discourse/discourse-topic-thumbnails.git` on PRE as a component of PRE theme 15, with PROD's settings (all defaults: `default_thumbnail_mode = grid`). Request: `POST /admin/themes/import.json` with `remote=<url>`, then `PUT /admin/themes/15.json` with `theme[child_theme_ids][]=<new id>`.
2. Each site-setting / theme-setting difference that is not by design.
3. If PRE has fewer than 3 `poster-evf` topics with images under one of its Comparte children, say so — the browser check in Task 6 then covers that child's "hidden below minimum" case instead of a full carousel. No content is copied without asking.

- [ ] **Step 4: Apply the approved writes to PRE, capturing prior state first, then re-read**

Prior state is already in `$S/themes-R.json`, `$S/ss-R.json`. After each write, re-read the same endpoint and confirm the value matches PROD.

- [ ] **Step 5: Record the ID clash and the reconciliation**

In `docs/operations/current-state.md`, replace the theme-id line with the dated fact: *2026-10-09 — PROD theme 15 is the Topic List Thumbnails component (child of 14); PRE theme 15 is our theme. Map themes by name, never by id.* Plus PRE's component id if installed. In `traceability.md`, one concise entry for the reconciliation. `current-state.md` is untracked (`git check-ignore -v docs/operations/current-state.md` — if it is tracked, keep the line free of member data).

```bash
git add traceability.md
git commit -m "docs: reconcile PRE with PROD before the poster carousel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `lib/posters.js` — selection, image choice, paging

**Files:**
- Create: `javascripts/discourse/lib/posters.js`
- Test: `test/unit/posters-test.js`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `POSTER_THUMBNAIL_MIN_WIDTH: number` (360), `POSTER_MAX_PAGES: number` (5)
  - `posterImage(topic: {image_url?: string|null, thumbnails?: Array<{url?: string, width: number}>}|null, minWidth?: number): string|null`
  - `pickPosters(topics: Array|null|undefined, { limit: number, excludeIds?: Set<number> }): Array`
  - `loadPosters(store: {findFiltered: Function}, categoryId: number|null, { tag: string, count: number, excludeIds?: Set<number>, maxPages?: number }): Promise<Array>`

- [ ] **Step 1: Write the failing tests**

```javascript
// test/unit/posters-test.js
import { module, test } from "qunit";
import {
  loadPosters,
  pickPosters,
  POSTER_MAX_PAGES,
  posterImage,
} from "../../discourse/lib/posters";

// Pure functions plus one loader that only talks to the store it is handed, so
// a fake store replaces the app. The component's rendering is covered in
// `test/integration/poster-carousel-test.gjs`.

const withImage = (id) => ({ id, image_url: `/img/${id}.jpg` });
const withoutImage = (id) => ({ id, image_url: null });

// Shaped like PROD's thumbnails for a 1587×2245 poster, measured 2026-10-09.
const THUMBNAILS = [
  { url: "/o.jpg", width: 1587 },
  { url: "/1024.jpg", width: 723 },
  { url: "/800.jpg", width: 565 },
  { url: "/600.jpg", width: 424 },
  { url: "/400.jpg", width: 282 },
  { url: "/400x300.jpg", width: 212 },
  { url: "/200.jpg", width: 141 },
];

module("Espublico Theme | Unit | posters | posterImage", function () {
  test("takes the narrowest thumbnail at least 360px wide", function (assert) {
    assert.strictEqual(
      posterImage({ image_url: "/full.jpg", thumbnails: THUMBNAILS }),
      "/600.jpg"
    );
  });

  test("falls back to image_url with no thumbnails", function (assert) {
    assert.strictEqual(posterImage({ image_url: "/full.jpg" }), "/full.jpg");
    assert.strictEqual(
      posterImage({ image_url: "/full.jpg", thumbnails: [] }),
      "/full.jpg"
    );
  });

  test("falls back to image_url when every thumbnail is too narrow", function (assert) {
    assert.strictEqual(
      posterImage({
        image_url: "/full.jpg",
        thumbnails: [{ url: "/200.jpg", width: 141 }],
      }),
      "/full.jpg"
    );
  });

  test("skips a thumbnail entry with no url", function (assert) {
    // Core lists sizes it has not generated yet with a null url.
    assert.strictEqual(
      posterImage({
        image_url: "/full.jpg",
        thumbnails: [
          { url: null, width: 424 },
          { url: "/800.jpg", width: 565 },
        ],
      }),
      "/800.jpg"
    );
  });

  test("returns null for a topic with no image at all", function (assert) {
    assert.strictEqual(posterImage({ image_url: null }), null);
    assert.strictEqual(posterImage(null), null);
  });
});

module("Espublico Theme | Unit | posters | pickPosters", function () {
  test("keeps only topics with an image, in order", function (assert) {
    const picked = pickPosters(
      [withImage(1), withoutImage(2), withImage(3)],
      { limit: 12 }
    );
    assert.deepEqual(
      picked.map((t) => t.id),
      [1, 3]
    );
  });

  test("drops excluded ids (category definition topics)", function (assert) {
    const picked = pickPosters([withImage(1), withImage(2)], {
      limit: 12,
      excludeIds: new Set([1]),
    });
    assert.deepEqual(
      picked.map((t) => t.id),
      [2]
    );
  });

  test("caps at the limit after filtering", function (assert) {
    const topics = [withoutImage(1), withImage(2), withImage(3), withImage(4)];
    assert.deepEqual(
      pickPosters(topics, { limit: 2 }).map((t) => t.id),
      [2, 3]
    );
  });

  test("tolerates a missing list", function (assert) {
    assert.deepEqual(pickPosters(undefined, { limit: 12 }), []);
    assert.deepEqual(pickPosters(null, { limit: 12 }), []);
  });
});

function fakeStore(pages) {
  const calls = [];
  return {
    calls,
    async findFiltered(type, options) {
      calls.push({ type, ...options });
      const page = options.params.page ?? 0;
      const topics = pages[page] ?? [];
      return {
        topics,
        more_topics_url: page < pages.length - 1 ? `/next?page=${page + 1}` : null,
      };
    },
  };
}

module("Espublico Theme | Unit | posters | loadPosters", function () {
  test("asks the category listing for the tag, newest first", async function (assert) {
    const store = fakeStore([[withImage(1)]]);
    await loadPosters(store, 85, { tag: "poster-evf", count: 12 });

    assert.deepEqual(store.calls[0], {
      type: "topicList",
      filter: "c/85/l/latest",
      params: { order: "created", tags: ["poster-evf"] },
    });
  });

  test("stops after one page when it already holds enough", async function (assert) {
    const store = fakeStore([
      [withImage(1), withImage(2)],
      [withImage(3)],
    ]);
    const posters = await loadPosters(store, 85, { tag: "t", count: 2 });

    assert.deepEqual(
      posters.map((t) => t.id),
      [1, 2]
    );
    assert.strictEqual(store.calls.length, 1);
  });

  test("pages on until it has enough", async function (assert) {
    const store = fakeStore([
      [withImage(1), withoutImage(2)],
      [withoutImage(3), withImage(4)],
      [withImage(5)],
    ]);
    const posters = await loadPosters(store, 85, { tag: "t", count: 3 });

    assert.deepEqual(
      posters.map((t) => t.id),
      [1, 4, 5]
    );
    assert.deepEqual(
      store.calls.map((c) => c.params.page),
      [undefined, 1, 2]
    );
  });

  test("stops at the last page", async function (assert) {
    const store = fakeStore([[withImage(1)], [withImage(2)]]);
    const posters = await loadPosters(store, 85, { tag: "t", count: 12 });

    assert.deepEqual(
      posters.map((t) => t.id),
      [1, 2]
    );
    assert.strictEqual(store.calls.length, 2);
  });

  test("stops at the page cap", async function (assert) {
    const pages = Array.from({ length: 10 }, (_, i) => [withoutImage(i)]);
    const store = fakeStore(pages);
    await loadPosters(store, 85, { tag: "t", count: 12 });

    assert.strictEqual(store.calls.length, POSTER_MAX_PAGES);
  });

  test("shows a topic once even if it shifts onto the next page", async function (assert) {
    // A poster created between two requests pushes the last topic of page 0
    // onto page 1.
    const store = fakeStore([
      [withImage(1), withImage(2)],
      [withImage(2), withImage(3)],
    ]);
    const posters = await loadPosters(store, 85, { tag: "t", count: 3 });

    assert.deepEqual(
      posters.map((t) => t.id),
      [1, 2, 3]
    );
  });

  test("drops excluded ids across pages", async function (assert) {
    const store = fakeStore([[withImage(1), withImage(2)]]);
    const posters = await loadPosters(store, 85, {
      tag: "t",
      count: 12,
      excludeIds: new Set([1]),
    });

    assert.deepEqual(
      posters.map((t) => t.id),
      [2]
    );
  });

  test("makes no request without a category, a tag or a count", async function (assert) {
    const store = fakeStore([[withImage(1)]]);

    assert.deepEqual(await loadPosters(store, null, { tag: "t", count: 12 }), []);
    assert.deepEqual(await loadPosters(store, 85, { tag: "", count: 12 }), []);
    assert.deepEqual(await loadPosters(store, 85, { tag: "t", count: 0 }), []);
    assert.strictEqual(store.calls.length, 0);
  });
});
```

- [ ] **Step 2: Run lint to verify the test file fails to resolve its import**

Run: `npx pnpm@10.28.0 lint:js`
Expected: FAIL — `import/no-unresolved` (or equivalent) for `../../discourse/lib/posters`. QUnit itself only runs in CI (it needs a Discourse checkout); lint is the local red signal.

- [ ] **Step 3: Write the implementation**

```javascript
// javascripts/discourse/lib/posters.js

// The carousel's slide is ~180px wide at its narrowest column count, so 360px
// covers a 2× display. On PROD (2026-10-09) that picks the 424×600 rendition of
// a portrait poster rather than the 723×1024 one `image_url` points at.
export const POSTER_THUMBNAIL_MIN_WIDTH = 360;

// 5 × 30 topics. On PROD 2026-10-09 the first page already held 12 posters with
// an image in categories 85, 94 and 83; the cap only matters where images are
// scarce, and bounds the requests a sparse category can cost.
export const POSTER_MAX_PAGES = 5;

/**
 * The image a carousel slide shows: the narrowest generated thumbnail that is
 * still sharp at the slide's size, else the topic's own image.
 *
 * @param {Object|null} topic
 * @param {Number} [minWidth]
 * @returns {String|null}
 */
export function posterImage(topic, minWidth = POSTER_THUMBNAIL_MIN_WIDTH) {
  const fit = (topic?.thumbnails ?? [])
    .filter((thumbnail) => thumbnail.url && thumbnail.width >= minWidth)
    .sort((a, b) => a.width - b.width)[0];

  return fit?.url ?? topic?.image_url ?? null;
}

/**
 * Topics that can be shown as a poster: they carry an image and are not
 * excluded (category definition topics). Order is preserved.
 *
 * Only 39 of Comparte's 176 `poster-evf` topics had an `image_url` on PROD on
 * 2026-10-09 — the rest attach the poster as a PDF, which Discourse does not
 * thumbnail — so this filter is what the carousel is mostly doing.
 *
 * @param {Array|null|undefined} topics
 * @param {Object} options
 * @param {Number} options.limit
 * @param {Set<Number>} [options.excludeIds]
 * @returns {Array}
 */
export function pickPosters(topics, { limit, excludeIds = new Set() }) {
  return (topics ?? [])
    .filter((topic) => topic.image_url && !excludeIds.has(topic.id))
    .slice(0, limit);
}

/**
 * Load up to `count` posters from a category's listing (subcategories
 * included), newest first, paging until there are enough, the listing ends, or
 * the page cap is reached.
 *
 * `order: "created"` sorts by when the topic was written, not by last activity
 * — a reply to an old poster must not move it to the front. Verified on PROD
 * 2026-10-09: `c/<id>/l/latest.json?order=created&tags[]=poster-evf` returns
 * only tagged topics, sorted by `created_at` descending.
 *
 * @param {Object} store - the injected `store` service
 * @param {Number|null} categoryId
 * @param {Object} options
 * @param {String} options.tag
 * @param {Number} options.count
 * @param {Set<Number>} [options.excludeIds]
 * @param {Number} [options.maxPages]
 * @returns {Promise<Array>}
 */
export async function loadPosters(
  store,
  categoryId,
  { tag, count, excludeIds = new Set(), maxPages = POSTER_MAX_PAGES }
) {
  if (!categoryId || !tag || !(count > 0)) {
    return [];
  }

  const posters = [];
  const seen = new Set(excludeIds);

  for (let page = 0; page < maxPages && posters.length < count; page++) {
    const params = { order: "created", tags: [tag] };
    if (page > 0) {
      params.page = page;
    }

    const list = await store.findFiltered("topicList", {
      filter: `c/${categoryId}/l/latest`,
      params,
    });

    // `seen` doubles as the exclusion set, so a topic that slid onto the next
    // page between two requests is not shown twice.
    for (const topic of pickPosters(list?.topics, {
      limit: count - posters.length,
      excludeIds: seen,
    })) {
      seen.add(topic.id);
      posters.push(topic);
    }

    if (!list?.more_topics_url) {
      break;
    }
  }

  return posters;
}
```

Note: `pickPosters` slices before the loop dedupes, but `seen` already holds every id pushed so far, so a duplicate is filtered *inside* `pickPosters` — the slice never counts it.

- [ ] **Step 4: Run lint to verify it passes**

Run: `npx pnpm@10.28.0 lint:js && npx pnpm@10.28.0 lint:prettier && npx pnpm@10.28.0 lint:types`
Expected: PASS. If prettier complains, `npx pnpm@10.28.0 lint:prettier:fix` and re-run.

- [ ] **Step 5: Commit**

```bash
git add javascripts/discourse/lib/posters.js test/unit/posters-test.js
git commit -m "feat: poster selection and paging helpers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Settings and locales

**Files:**
- Modify: `settings.yml` (append)
- Modify: `locales/en.yml`, `locales/es.yml` (`theme_metadata.settings` + new top-level `poster_carousel:` key)

**Interfaces:**
- Produces: `settings.poster_carousel_category_ids` (pipe string), `settings.poster_carousel_tag` (string), `settings.poster_carousel_count` (integer), `settings.poster_carousel_min` (integer); locale keys `poster_carousel.title`, `poster_carousel.previous`, `poster_carousel.next`.

- [ ] **Step 1: Append to `settings.yml`**

```yaml
# The poster carousel above the topic list, by category id. Each listed
# category shows the posters of its whole subtree, so the parent shows all of
# them and each child only its own. Ids rather than names because they are
# per-instance: PROD's Comparte is 85 with children 94, 83 and 93; PRE's are
# different. Empty hides the carousel everywhere.
poster_carousel_category_ids:
  type: list
  list_type: category
  default: "85|94|83|93"

# Only topics carrying this tag become posters. Matched server-side.
poster_carousel_tag:
  type: string
  default: "poster-evf"

poster_carousel_count:
  type: integer
  default: 12
  min: 1
  max: 30

# Below this many posters with an image the carousel is not shown: a strip of
# one or two reads as broken rather than as a gallery.
poster_carousel_min:
  type: integer
  default: 3
  min: 1
```

- [ ] **Step 2: Add the setting descriptions under `theme_metadata.settings` in `locales/en.yml`** (after `certification_url`)

```yaml
      poster_carousel_category_ids: "Categories that show the poster carousel above their topic list. A category shows the posters of its subcategories too. Empty hides the carousel."
      poster_carousel_tag: "Only topics carrying this tag become posters, newest first. Topics without an image are skipped."
      poster_carousel_count: "Maximum number of posters in the carousel."
      poster_carousel_min: "Below this many posters with an image the carousel is hidden."
```

and in `locales/es.yml`:

```yaml
      poster_carousel_category_ids: "Categorías que muestran el carrusel de pósteres encima de su lista de temas. Una categoría muestra también los pósteres de sus subcategorías. Vacío oculta el carrusel."
      poster_carousel_tag: "Solo los temas con esta etiqueta se muestran como póster, del más reciente al más antiguo. Los temas sin imagen se omiten."
      poster_carousel_count: "Número máximo de pósteres en el carrusel."
      poster_carousel_min: "Con menos pósteres con imagen que este número, el carrusel se oculta."
```

- [ ] **Step 3: Add the display strings as a new top-level key at the end of each file**

`locales/en.yml`:

```yaml
  poster_carousel:
    title: "Newly certified users"
    previous: "Previous posters"
    next: "Next posters"
```

`locales/es.yml`:

```yaml
  poster_carousel:
    title: "Nuevos usuarios certificados"
    previous: "Pósteres anteriores"
    next: "Pósteres siguientes"
```

- [ ] **Step 4: Validate YAML**

Run: `ruby -ryaml -e '%w[settings.yml locales/en.yml locales/es.yml].each { |f| YAML.load_file(f); puts "ok #{f}" }'` (Homebrew Ruby: prefix `PATH="/opt/homebrew/opt/ruby/bin:$PATH"`)
Expected: three `ok` lines.

- [ ] **Step 5: Commit**

```bash
git add settings.yml locales/en.yml locales/es.yml
git commit -m "feat: settings and strings for the poster carousel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `PosterCarousel` component

**Files:**
- Create: `javascripts/discourse/components/poster-carousel.gjs`
- Test: `test/integration/poster-carousel-test.gjs`

**Interfaces:**
- Consumes: `loadPosters`, `posterImage` (Task 2); `parseCategoryIds`, `definitionTopicIds` from `lib/category-topics.js`; settings and locale keys (Task 3).
- Produces: `<PosterCarousel @category={{category}} />` — `@category` is a Category model or `{ id }`, may be undefined.

- [ ] **Step 1: Write the failing integration tests**

```javascript
// test/integration/poster-carousel-test.gjs
import { render, settled } from "@ember/test-helpers";
import { tracked } from "@glimmer/tracking";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PosterCarousel from "../../discourse/components/poster-carousel";

// The store is stubbed rather than pretender: the component only ever calls
// `findFiltered`, and the request shape is pinned in the unit tests.
function stubStore(owner, byCategory, { reject = false } = {}) {
  const calls = [];
  owner.unregister("service:store");
  owner.register(
    "service:store",
    {
      findFiltered: async (_type, { filter, params }) => {
        calls.push({ filter, params });
        if (reject) {
          throw new Error("403");
        }
        const id = Number(filter.split("/")[1]);
        return { topics: byCategory[id] ?? [], more_topics_url: null };
      },
    },
    { instantiate: false }
  );
  return calls;
}

const poster = (id) => ({
  id,
  title: `Poster ${id}`,
  fancy_title: `Poster ${id} &amp; co`,
  url: `/t/poster-${id}/${id}`,
  image_url: `/img/${id}.jpg`,
  thumbnails: [{ url: `/img/${id}-600.jpg`, width: 424 }],
});
const posters = (from, n) =>
  Array.from({ length: n }, (_, i) => poster(from + i));

module("Espublico Theme | Integration | poster carousel", function (hooks) {
  setupRenderingTest(hooks);

  // `settings` is shared across the whole QUnit run: state every value.
  hooks.beforeEach(function () {
    settings.poster_carousel_category_ids = "85|94|";
    settings.poster_carousel_tag = "poster-evf";
    settings.poster_carousel_count = 12;
    settings.poster_carousel_min = 3;
  });

  test("renders nothing and requests nothing for an unlisted category", async function (assert) {
    const calls = stubStore(this.owner, { 4: posters(1, 5) });
    const category = { id: 4 };
    await render(<template><PosterCarousel @category={{category}} /></template>);

    assert.dom(".poster-carousel").doesNotExist();
    assert.strictEqual(calls.length, 0);
  });

  test("renders nothing with no category (tag pages, /latest)", async function (assert) {
    const calls = stubStore(this.owner, {});
    await render(<template><PosterCarousel /></template>);

    assert.dom(".poster-carousel").doesNotExist();
    assert.strictEqual(calls.length, 0);
  });

  test("renders nothing below the minimum", async function (assert) {
    stubStore(this.owner, { 85: posters(1, 2) });
    const category = { id: 85 };
    await render(<template><PosterCarousel @category={{category}} /></template>);

    assert.dom(".poster-carousel").doesNotExist();
  });

  test("renders nothing when the request fails, without a flash error", async function (assert) {
    stubStore(this.owner, {}, { reject: true });
    const category = { id: 85 };
    await render(<template><PosterCarousel @category={{category}} /></template>);

    assert.dom(".poster-carousel").doesNotExist();
    assert.dom(".alert-error").doesNotExist();
  });

  test("renders up to the count, each with a lightbox image and a topic link", async function (assert) {
    stubStore(this.owner, { 85: posters(1, 15) });
    const category = { id: 85 };
    await render(<template><PosterCarousel @category={{category}} /></template>);

    assert.dom(".poster-carousel__item").exists({ count: 12 });
    assert
      .dom(".poster-carousel__item:first-child a.lightbox")
      .hasAttribute("href", "/img/1.jpg", "lightbox opens the full image");
    assert
      .dom(".poster-carousel__item:first-child img")
      .hasAttribute("src", "/img/1-600.jpg", "slide shows the thumbnail")
      .hasAttribute("alt", "Poster 1");
    assert
      .dom(".poster-carousel__item:first-child .poster-carousel__caption")
      .hasAttribute("href", "/t/poster-1/1")
      .hasText("Poster 1 & co", "entities render as characters");
  });

  test("is labelled by its heading and has translated nav buttons", async function (assert) {
    stubStore(this.owner, { 85: posters(1, 4) });
    const category = { id: 85 };
    await render(<template><PosterCarousel @category={{category}} /></template>);

    const heading = document.querySelector(".poster-carousel__title");
    assert
      .dom(".poster-carousel")
      .hasAttribute("aria-labelledby", heading.id);
    assert.dom(".poster-carousel__prev").hasAttribute("aria-label");
    assert.dom(".poster-carousel__next").hasAttribute("aria-label");
    assert
      .dom(".poster-carousel__prev")
      .isDisabled("at the start, previous is disabled");
  });

  test("moving to another listed category shows that category's posters", async function (assert) {
    stubStore(this.owner, { 85: posters(1, 4), 94: posters(100, 3) });
    const state = new (class {
      @tracked category = { id: 85 };
    })();
    await render(
      <template><PosterCarousel @category={{state.category}} /></template>
    );
    assert.dom(".poster-carousel__item").exists({ count: 4 });

    state.category = { id: 94 };
    await settled();

    assert.dom(".poster-carousel__item").exists({ count: 3 });
    assert
      .dom(".poster-carousel__item:first-child img")
      .hasAttribute("alt", "Poster 100");
  });
});
```

- [ ] **Step 2: Run lint to verify the import fails**

Run: `npx pnpm@10.28.0 lint:js`
Expected: FAIL on the unresolved `../../discourse/components/poster-carousel`.

- [ ] **Step 3: Write the component**

```javascript
// javascripts/discourse/components/poster-carousel.gjs
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import lightbox from "discourse/lib/lightbox";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { definitionTopicIds, parseCategoryIds } from "../lib/category-topics";
import { loadPosters, posterImage } from "../lib/posters";

// Certified users' posters above the topic list of Comparte and its
// subcategories. Mounted next to `DiscoveryHero` in
// `discovery-list-controls-above` — a plugin outlet, not a Block: the Blocks
// API stays confined to the homepage.
//
// The image opens core's lightbox (the same PhotoSwipe a post uses, bound to
// every `.lightbox` anchor inside the track); the caption links to the topic.
// A portrait poster is unreadable at slide size, so the lightbox is how it is
// read without leaving the listing.
export default class PosterCarousel extends Component {
  @service store;

  @tracked atStart = true;
  @tracked atEnd = false;

  titleId = `poster-carousel-title-${guidFor(this)}`;
  track = null;

  bindLightbox = modifier((element) => {
    lightbox(element);
  });

  registerTrack = modifier((element) => {
    this.track = element;
    const update = () => this.updateEnds();
    // Not synchronously: these flags were read earlier in this same render,
    // and writing them now would trip Glimmer's backtracking assertion.
    schedule("afterRender", update);
    element.addEventListener("scroll", update, { passive: true });
    return () => {
      element.removeEventListener("scroll", update);
      this.track = null;
    };
  });

  get categoryId() {
    const id = Number(this.args.category?.id);
    const listed = parseCategoryIds(settings.poster_carousel_category_ids);
    return listed.includes(id) ? id : null;
  }

  // A new promise per category. `DAsyncContent` renders only the promise it
  // currently holds, so a response for a category the reader has already left
  // is never shown. `@context` is not used: the pinned `@discourse/types`
  // predate it and PRE runs core 2026.8.
  @cached
  get posters() {
    const categoryId = this.categoryId;
    if (!categoryId) {
      return null;
    }

    return loadPosters(this.store, categoryId, {
      tag: settings.poster_carousel_tag,
      count: settings.poster_carousel_count,
      excludeIds: definitionTopicIds(),
    }).then(
      (topics) => (topics.length >= settings.poster_carousel_min ? topics : null),
      // A member without access to a child gets a 403; the topic list below
      // must not be disturbed by a flash error for a decorative strip.
      () => null
    );
  }

  updateEnds() {
    const track = this.track;
    if (!track) {
      return;
    }
    this.atStart = track.scrollLeft <= 1;
    this.atEnd = track.scrollLeft + track.clientWidth >= track.scrollWidth - 1;
  }

  @action
  scroll(direction) {
    const reduce = window.matchMedia?.(
      "(prefers-reduced-motion: reduce)"
    ).matches;
    this.track?.scrollBy({
      left: direction * this.track.clientWidth,
      behavior: reduce ? "auto" : "smooth",
    });
  }

  <template>
    {{#if this.categoryId}}
      <DAsyncContent @asyncData={{this.posters}}>
        <:loading></:loading>
        <:empty></:empty>
        <:content as |topics|>
          <section class="poster-carousel" aria-labelledby={{this.titleId}}>
            <header class="poster-carousel__header">
              <h2 id={{this.titleId}} class="poster-carousel__title">
                {{i18n (themePrefix "poster_carousel.title")}}
              </h2>
              <div class="poster-carousel__nav">
                <DButton
                  class="btn-flat poster-carousel__prev"
                  @icon="chevron-left"
                  @ariaLabel={{themePrefix "poster_carousel.previous"}}
                  @disabled={{this.atStart}}
                  @action={{fn this.scroll -1}}
                />
                <DButton
                  class="btn-flat poster-carousel__next"
                  @icon="chevron-right"
                  @ariaLabel={{themePrefix "poster_carousel.next"}}
                  @disabled={{this.atEnd}}
                  @action={{fn this.scroll 1}}
                />
              </div>
            </header>
            <ul
              class="poster-carousel__track"
              {{this.registerTrack}}
              {{this.bindLightbox}}
            >
              {{#each topics key="id" as |topic|}}
                <li class="poster-carousel__item">
                  <a
                    class="lightbox poster-carousel__media"
                    href={{topic.image_url}}
                    title={{topic.title}}
                  >
                    <img
                      src={{posterImage topic}}
                      alt={{topic.title}}
                      loading="lazy"
                    />
                  </a>
                  <a class="poster-carousel__caption" href={{topic.url}}>
                    {{trustHTML topic.fancy_title}}
                  </a>
                </li>
              {{/each}}
            </ul>
          </section>
        </:content>
      </DAsyncContent>
    {{/if}}
  </template>
}
```

- [ ] **Step 4: Run lint (all four linters)**

Run: `npx pnpm@10.28.0 lint`
Expected: PASS. Typical fixes: prettier formatting (`lint:fix`); if `ember-tsc` rejects an import path that exists at runtime (e.g. `discourse/ui-kit/d-async-content` is newer than the pinned `@discourse/types`), copy how `block-latest.gjs` imports and uses it — it already passes `lint:types` with the same import.

- [ ] **Step 5: Commit**

```bash
git add javascripts/discourse/components/poster-carousel.gjs test/integration/poster-carousel-test.gjs
git commit -m "feat: poster carousel component

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Styles, mount, version

**Files:**
- Create: `stylesheets/app/poster-carousel.scss`
- Modify: `stylesheets/app/_index.scss` (add `@import "poster-carousel";` after `@import "page-hero";`)
- Modify: `javascripts/discourse/api-initializers/discovery-list-controls-above.gjs`
- Modify: `about.json` (`theme_version` → `"1.6.0"`)

**Interfaces:**
- Consumes: `PosterCarousel` (Task 4); BEM classes `poster-carousel`, `__header`, `__title`, `__nav`, `__prev`, `__next`, `__track`, `__item`, `__media`, `__caption`.

- [ ] **Step 1: Write the stylesheet**

```scss
// stylesheets/app/poster-carousel.scss

// Certified users' posters above Comparte's topic list. A strip, not a grid:
// it scrolls on its own axis with native snap, so touch and trackpad need no
// script; the buttons are a desktop convenience on top.
.poster-carousel {
  // Visible slides at once. A fraction of the next one shows at every width —
  // that partial slide is what says "this scrolls".
  --poster-carousel-columns: 2.3;
  --poster-carousel-gap: 0.75rem;

  margin-block: 1.5rem;

  @include viewport.from(md) {
    --poster-carousel-columns: 4.3;
  }

  @include viewport.from(xl) {
    --poster-carousel-columns: 6.3;
  }

  &__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    margin-block-end: 0.75rem;
  }

  &__title {
    margin: 0;
    font-size: var(--font-up-1);
  }

  // Touch users swipe; the buttons would only take room from the title.
  &__nav {
    display: none;
    gap: 0.25rem;

    @include viewport.from(md) {
      display: flex;
    }
  }

  &__track {
    display: grid;
    grid-auto-columns: calc(
      (
          100% - (var(--poster-carousel-columns) - 1) *
            var(--poster-carousel-gap)
        ) /
        var(--poster-carousel-columns)
    );
    grid-auto-flow: column;
    gap: var(--poster-carousel-gap);
    margin: 0;
    padding: 0 0 0.5rem;
    list-style: none;
    overflow-x: auto;
    overscroll-behavior-x: contain;
    scroll-snap-type: x mandatory;
    scroll-behavior: smooth;

    @media (prefers-reduced-motion: reduce) {
      scroll-behavior: auto;
    }
  }

  &__item {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    min-width: 0;
    scroll-snap-align: start;
  }

  &__media {
    display: block;
    overflow: hidden;
    border: 1px solid var(--ga-border);
    border-radius: var(--d-border-radius);
    background: var(--ga-muted);
    box-shadow: var(--ga-shadow-lane);

    img {
      display: block;
      width: 100%;
      height: auto;
      // PROD's posters are 723×1024 renditions of an A-series sheet.
      aspect-ratio: 723 / 1024;
      object-fit: cover;
    }

    &:focus-visible {
      outline: 2px solid var(--tertiary);
      outline-offset: 2px;
    }
  }

  &__caption {
    display: -webkit-box;
    overflow: hidden;
    color: var(--primary);
    font-size: var(--font-down-1);
    line-height: var(--line-height-medium);
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 2;
  }
}
```

Note the one `@media (prefers-reduced-motion: reduce)`: it is a user-preference query, not a viewport breakpoint, so the "no raw media query" rule (which is about breakpoints) does not cover it. If stylelint flags it, check `stylesheets/app/motion.scss` for how the theme already handles reduced motion and follow that.

- [ ] **Step 2: Import it**

In `stylesheets/app/_index.scss`, after `@import "page-hero";`:

```scss
@import "poster-carousel";
```

- [ ] **Step 3: Mount it next to the hero**

Replace the `api.renderInOutlet(...)` call in `javascripts/discourse/api-initializers/discovery-list-controls-above.gjs` and add the import; append one paragraph to the header comment:

```javascript
import { apiInitializer } from "discourse/lib/api";
import DiscoveryHero from "../components/discovery-hero";
import PosterCarousel from "../components/poster-carousel";

// …existing comment unchanged…
//
// The poster carousel shares the outlet for the same reason the band uses it:
// it needs `category` as an argument and must sit above the nav tabs. It
// decides for itself whether the category is one it shows on.
export default apiInitializer((api) => {
  api.renderInOutlet(
    "discovery-list-controls-above",
    <template>
      <DiscoveryHero
        @category={{@outletArgs.category}}
        @tag={{@outletArgs.tag}}
      />
      <PosterCarousel @category={{@outletArgs.category}} />
    </template>
  );
});
```

- [ ] **Step 4: Bump the version**

In `about.json`: `"theme_version": "1.6.0"`.

- [ ] **Step 5: Full lint**

Run: `npx pnpm@10.28.0 lint`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add stylesheets/app/poster-carousel.scss stylesheets/app/_index.scss javascripts/discourse/api-initializers/discovery-list-controls-above.gjs about.json
git commit -m "feat: show the poster carousel above Comparte's topic lists

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: PR, CI, PRE settings, verification on PRE and PROD

**Files:**
- Modify: `traceability.md`, `docs/history/homepage-sections.md` is **not** touched (this is not the homepage).

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin feat/poster-carousel
gh pr create --title "feat: poster carousel in Comparte" --body "$(cat <<'EOF'
Carousel of certified users' posters (`poster-evf` topics with an image) above the topic list on Comparte and its subcategories. Newest first, 12 max, no autoplay; image opens core's lightbox, title links to the topic.

Spec: docs/superpowers/specs/2026-10-09-poster-carousel-design.md
Plan: docs/superpowers/plans/2026-10-09-poster-carousel.md

**Merging reaches PROD and PRE at once.** PRE needs `poster_carousel_category_ids` set to its own Comparte ids after the merge.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 2: Watch the four required checks until they report**

Run: `gh pr checks --watch`
Expected: `linting`, `backend_tests`, `frontend_tests`, `system_tests` all pass. If `frontend_tests` fails on the new tests, read the failure, fix, push — do not merge red. Two attempts, then stop and ask Ricardo.

- [ ] **Step 3: STOP — ask Ricardo for the merge go-ahead**

Merging reaches PROD's 374 members immediately. State: checks green, and what the carousel will show on PROD per category, re-measured with the Task 1 query just before asking (2026-10-09: 85 → 12, 94 → 12, 83 → 12, 93 → 3, which equals `poster_carousel_min`, so it shows; any other category → nothing).

- [ ] **Step 4: After his yes, merge and force both instances to pull**

```bash
gh pr merge --squash --delete-branch
```

Then for each instance read the `remote_theme` record (`remote_version` must equal the merge commit; `updated_at` after the merge). If not, `PUT /admin/themes/<id>.json` with `theme[remote_update]=true` — on PRE freely, on PROD only with Ricardo's yes (it is a PROD write).

- [ ] **Step 5: Set PRE's category ids (PRE write, approved in Task 1)**

`PUT /admin/themes/15/setting.json` with `name=poster_carousel_category_ids&value=<PRE Comparte id>|<children>` using PRE's ids recorded in Task 1. Re-read and confirm.

- [ ] **Step 6: Verify on PRE in the browser (measure, do not screenshot a login form)**

Log in on PRE by hand or with an existing session; then with Playwright evaluate on `/c/<PRE Comparte id>`:

```javascript
() => ({
  items: document.querySelectorAll(".poster-carousel__item").length,
  firstImg: document.querySelector(".poster-carousel__item img")?.currentSrc,
  trackScrolls:
    document.querySelector(".poster-carousel__track")?.scrollWidth >
    document.querySelector(".poster-carousel__track")?.clientWidth,
  aboveNav:
    document.querySelector(".poster-carousel")?.compareDocumentPosition(
      document.querySelector(".list-controls")
    ) === Node.DOCUMENT_POSITION_FOLLOWING,
  pageOverflow: document.documentElement.scrollWidth > window.innerWidth,
})
```

Expected: `items` between the minimum and 12, `trackScrolls` true when items exceed the visible columns, `aboveNav` true, `pageOverflow` false. Then: click the first image → `.pswp` exists; press Escape; click "next" → track `scrollLeft` > 0 and "previous" enabled; resize to 375px → nav hidden, no page overflow; a non-listed category (`/c/4`) → no `.poster-carousel`; dark mode via `emulateMedia({ colorScheme: "dark" })` → border and caption readable.

- [ ] **Step 7: Verify on PROD (read-only)**

Same evaluation on `/c/85`, `/c/94`, `/c/83`, `/c/93` and `/c/4`. PROD runs a newer core than PRE, so this is not optional. Expected counts today: 12, 12, 12, 3, none.

- [ ] **Step 8: Record and close**

`traceability.md`: one concise entry (what shipped, version 1.6.0, PRE ids set, verification result). Commit through a docs PR like the previous ones (`docs: …`).

---

## Out of scope (separate plans)

- Backfilling images for the ~137 PDF-only posters on PROD (bulk write; prior-state capture, wiki/bump check per topic, Ricardo approves the batch).
- Topic List Thumbnails' site-wide `grid` default on PROD.

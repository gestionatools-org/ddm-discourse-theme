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
    const picked = pickPosters([withImage(1), withoutImage(2), withImage(3)], {
      limit: 12,
    });
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
        more_topics_url:
          page < pages.length - 1 ? `/next?page=${page + 1}` : null,
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
    const store = fakeStore([[withImage(1), withImage(2)], [withImage(3)]]);
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

    assert.deepEqual(
      await loadPosters(store, null, { tag: "t", count: 12 }),
      []
    );
    assert.deepEqual(await loadPosters(store, 85, { tag: "", count: 12 }), []);
    assert.deepEqual(await loadPosters(store, 85, { tag: "t", count: 0 }), []);
    assert.strictEqual(store.calls.length, 0);
  });
});

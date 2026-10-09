import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
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
// Ids far above the test site's fixtures: the component drops category
// definition topics, and a fixture category's definition topic has a low id
// that collided with poster 1–4 (CI 2026-10-09: 3 rendered instead of 4).
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
    const calls = stubStore(this.owner, { 4: posters(9001, 5) });
    const category = { id: 4 };
    await render(
      <template><PosterCarousel @category={{category}} /></template>
    );

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
    stubStore(this.owner, { 85: posters(9001, 2) });
    const category = { id: 85 };
    await render(
      <template><PosterCarousel @category={{category}} /></template>
    );

    assert.dom(".poster-carousel").doesNotExist();
  });

  test("renders nothing when the request fails, without a flash error", async function (assert) {
    stubStore(this.owner, {}, { reject: true });
    const category = { id: 85 };
    await render(
      <template><PosterCarousel @category={{category}} /></template>
    );

    assert.dom(".poster-carousel").doesNotExist();
    assert.dom(".alert-error").doesNotExist();
  });

  test("renders up to the count, each with a lightbox image and a topic link", async function (assert) {
    stubStore(this.owner, { 85: posters(9001, 15) });
    const category = { id: 85 };
    await render(
      <template><PosterCarousel @category={{category}} /></template>
    );

    assert.dom(".poster-carousel__item").exists({ count: 12 });
    assert
      .dom(".poster-carousel__item:first-child a.lightbox")
      .hasAttribute("href", "/img/9001.jpg", "lightbox opens the full image")
      // Without a size core's lightbox preloads every full image on render.
      .hasAttribute("data-target-width", "723")
      .hasAttribute("data-target-height", "1024");
    assert
      .dom(".poster-carousel__item:first-child img")
      .hasAttribute("src", "/img/9001-600.jpg", "slide shows the thumbnail")
      .hasAttribute("alt", "Poster 9001");
    assert
      .dom(".poster-carousel__item:first-child .poster-carousel__caption")
      .hasAttribute("href", "/t/poster-9001/9001")
      .hasText("Poster 9001 & co", "entities render as characters");
  });

  test("is labelled by its heading and has translated nav buttons", async function (assert) {
    stubStore(this.owner, { 85: posters(9001, 4) });
    const category = { id: 85 };
    await render(
      <template><PosterCarousel @category={{category}} /></template>
    );

    const heading = document.querySelector(".poster-carousel__title");
    assert.dom(".poster-carousel").hasAttribute("aria-labelledby", heading.id);
    assert.dom(".poster-carousel__prev").hasAttribute("aria-label");
    assert.dom(".poster-carousel__next").hasAttribute("aria-label");
    assert
      .dom(".poster-carousel__prev")
      .isDisabled("at the start, previous is disabled");
  });

  test("moving to another listed category shows that category's posters", async function (assert) {
    stubStore(this.owner, { 85: posters(9001, 4), 94: posters(9101, 3) });
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
      .hasAttribute("alt", "Poster 9101");
  });
});

import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockEvents from "../../discourse/blocks/block-events";
import BlockForum from "../../discourse/blocks/block-forum";
import BlockNews from "../../discourse/blocks/block-news";
import BlockShowcase from "../../discourse/blocks/block-showcase";

// The three bugs left from the 2026-08-16/17 review live in the templates, not
// in the pipeline `test/acceptance/category-topics-test.js` already covers.
// Reaching them needs the DOM.
//
// Rendered through `<BlockOutlet>` rather than by visiting "/". The theme sets
// `custom_homepage`, but that modifier is applied server-side and does not
// reach the JS test environment: "/" is core's discovery route there, the
// `homepage-blocks` outlet never renders, and every assertion tried that way
// failed on an element that was simply absent. This is core's own pattern,
// taken from `discourse/tests/integration/components/block-outlet-test.gjs`.
//
// `setupRenderingTest` provides a store service but no pretender, so the store
// is replaced outright — the same fake used at the function boundary, and it
// keeps these tests off the network entirely.
//
// The outlet is `main-outlet-blocks`, not the `homepage-blocks` these lanes
// occupy in production. `setupRenderingTest` runs `autoLoadModules`, which
// executes the theme's own `api-initializers/homepage-blocks.gjs`, so that
// outlet already has a layout before any test body runs and a second
// `renderBlocks` for it raises "already has a layout registered". The lanes
// declare no `allowedOutlets`, so which outlet holds them changes nothing
// about what they render. Outlet layouts are reset between rendering tests —
// core reuses one outlet fifteen times in a single file — so all of these can
// share it.

function topic(attrs) {
  return {
    id: 1,
    fancy_title: "A topic",
    url: "/t/a-topic/1",
    reply_count: 0,
    image_url: null,
    excerpt: null,
    created_at: "2026-08-01T10:00:00.000Z",
    ...attrs,
  };
}

function stubStore(owner, topics) {
  owner.unregister("service:store");
  owner.register(
    "service:store",
    { findFiltered: async () => ({ topics }) },
    { instantiate: false }
  );
}

module("Espublico Theme | Integration | homepage lanes", function (hooks) {
  setupRenderingTest(hooks);

  module("news lane", function () {
    test("renders a title's entities as characters, not as markup", async function (assert) {
      // `fancy_title` arrives already cooked. Passing it through dReplaceEmoji
      // escaped the ampersand first, so the page printed the entity verbatim:
      // "La Seu d&rsquo;Urgell".
      stubStore(this.owner, [
        topic({ id: 10, fancy_title: "La Seu d&rsquo;Urgell estrena sede" }),
      ]);

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockNews,
            args: { title: "homepage.news.title", categoryId: 4, count: 4 },
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert
        .dom(".block-news__item-title")
        .hasText("La Seu d’Urgell estrena sede");
    });

    test("resolves emoji shortcodes in an excerpt", async function (assert) {
      // ExcerptParser strips cooked HTML back to text and turns emoji images
      // into their `:shortcode:`, so one news excerpt in four printed
      // ":automobile:" as words.
      stubStore(this.owner, [
        topic({ id: 11, excerpt: "Nuevo :automobile: para el parque móvil" }),
      ]);

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockNews,
            args: { title: "homepage.news.title", categoryId: 4, count: 4 },
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert
        .dom(".block-news__item-excerpt img.emoji")
        .exists({ count: 1 }, "the shortcode became an image");
      assert
        .dom(".block-news__item-excerpt")
        .doesNotIncludeText(":automobile:", "no shortcode survives as text");
    });
  });

  module("forum lane", function () {
    test("promotes the reply count, which is this lane's reason to exist", async function (assert) {
      stubStore(this.owner, [topic({ id: 20, reply_count: 7 })]);

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockForum,
            args: { title: "homepage.forum.title", categoryId: 5, count: 6 },
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".block-forum__item-replies").includesText("7");
    });
  });

  module("showcase lane", function () {
    test("hangs only the topics that carry a cover image", async function (assert) {
      // Half the live grid was grey boxes: a card with no image exhibits
      // nothing, and this lane exists to exhibit work.
      stubStore(this.owner, [
        topic({ id: 30, image_url: null }),
        topic({ id: 31, image_url: "/uploads/poster.png" }),
      ]);

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockShowcase,
            args: {
              title: "homepage.showcase.title",
              categoryId: 78,
              count: 6,
            },
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".block-showcase__card").exists({ count: 1 });
      assert
        .dom(".block-showcase__card-image")
        .hasAttribute("src", "/uploads/poster.png");
    });
  });

  module("events lane", function () {
    // Relative to now, so the split cannot rot into a false pass the way a
    // hardcoded date would.
    const day = 86400000;
    const soon = new Date(Date.now() + day).toISOString();
    const later = new Date(Date.now() + 30 * day).toISOString();
    const gone = new Date(Date.now() - 30 * day).toISOString();

    function renderEvents() {
      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockEvents,
            args: { title: "homepage.events.title", categoryId: 59, count: 4 },
          },
        ])
      );

      return render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );
    }

    test("puts what is still ahead first, soonest first", async function (assert) {
      // The listing arrives bumped_at descending whatever the category's event
      // sort setting says, so the one upcoming event led the lane only by
      // accident of being the most recently bumped topic. Served out of order
      // here on purpose.
      stubStore(this.owner, [
        topic({ id: 40, fancy_title: "Congreso", event_starts_at: later }),
        topic({ id: 41, fancy_title: "Jornada pasada", event_starts_at: gone }),
        topic({ id: 42, fancy_title: "Webinar", event_starts_at: soon }),
      ]);

      await renderEvents();

      const groups = [...document.querySelectorAll(".block-events__group")];
      assert.strictEqual(groups.length, 2, "both halves are labelled");

      const upcoming = [
        ...groups[0].querySelectorAll(".block-events__item-title"),
      ].map((el) => el.textContent.trim());

      assert.deepEqual(
        upcoming,
        ["Webinar", "Congreso"],
        "soonest first, not in the order served"
      );

      const past = [
        ...groups[1].querySelectorAll(".block-events__item-title"),
      ].map((el) => el.textContent.trim());

      assert.deepEqual(past, ["Jornada pasada"]);
    });

    test("marks a real event date apart from a topic date", async function (assert) {
      // Core's relative helpers cannot render a future date — `medium` prints
      // every one of them as "now" — so a scheduled date is absolute and
      // carries its own modifier.
      stubStore(this.owner, [
        topic({ id: 43, fancy_title: "Webinar", event_starts_at: soon }),
        topic({ id: 44, fancy_title: "Sin evento" }),
      ]);

      await renderEvents();

      assert.dom(".block-events__item-date.--scheduled").exists({ count: 1 });
      assert.dom(".block-events__item-date").exists({ count: 2 });
    });

    test("shows the archive alone rather than an empty heading", async function (assert) {
      stubStore(this.owner, [
        topic({ id: 45, fancy_title: "Solo pasado", event_starts_at: gone }),
      ]);

      await renderEvents();

      assert.dom(".block-events__group").exists({ count: 1 });
      assert
        .dom(".block-events__group-title")
        .hasText("Past events", "no 'Coming up' with nothing under it");
    });
  });
});

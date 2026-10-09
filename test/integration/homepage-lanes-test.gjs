import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockCertified from "../../discourse/blocks/block-certified";
import BlockEvents from "../../discourse/blocks/block-events";
import BlockHero from "../../discourse/blocks/block-hero";
import BlockLatest from "../../discourse/blocks/block-latest";

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

// Ids sit in a 900000+ range on purpose. `loadCategoryTopics` drops any topic
// whose id belongs to a category definition topic, and core's site fixture puts
// those at 2, 11, 24, 25, 28, 389, 1026 and upwards — id 11 appears three
// times. A fixture topic that collides is silently filtered out, the lane falls
// through to its empty state, and the assertion then fails on a missing element
// that looks like a rendering bug. That cost several CI runs on the excerpt
// test below, which used id 11 and was never about emoji at all.
function topic(attrs) {
  return {
    id: 900001,
    fancy_title: "A topic",
    url: "/t/a-topic/1",
    reply_count: 0,
    image_url: null,
    excerpt: null,
    created_at: "2026-08-01T10:00:00.000Z",
    // Core's topic list serializer always sends `posters`, and `Topic`'s
    // `featuredUsers` getter reads `this.posters.length` without a null guard
    // (`models/topic.js`) — unlike its `creator` and `lastPoster` siblings. The
    // latest lane renders `<TopicList @showPosters={{true}} />`, so an absent
    // `posters` raises "Cannot read properties of undefined (reading 'length')"
    // as an uncaught global error that fails the run without naming a test. The
    // POJO lanes ignore this key; only the model fixtures need it.
    posters: [],
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

// Core's topic list needs real Topic **models**, not the plain objects the
// other lanes are happy with: `topic-list/item` calls `topic?.get(...)`, so a
// POJO raises "topic?.get is not a function" as an uncaught global error and
// fails the run without naming a test. In production the models arrive for
// free — `store.findFiltered` returns them — so this is a fixture concern only.
//
// The real store is looked up *before* the stub replaces it, and the reference
// stays valid afterwards. `store.createRecord("topic", …)` is core's own idiom,
// from `tests/integration/components/topic-list-test.gjs`.
//
// `url` has to come off the attrs first. On the model it is
// `@computed("id", "slug")` (`models/topic.js`), so handing it over as an
// attribute raises "Cannot override the computed property `url`" — which is
// what took these three tests down once the `.get` error was fixed. The model
// derives the same path from the id, and `fancy_title` stays because it *is* a
// plain attribute: the computed one is `fancyTitle`, which reads it.
function topicModel(store, attrs) {
  const settable = { ...attrs };
  delete settable.url;
  return store.createRecord("topic", settable);
}

function stubStoreWithModels(owner, attrsList) {
  const store = owner.lookup("service:store");
  const topics = attrsList.map((attrs) => topicModel(store, attrs));
  owner.unregister("service:store");
  owner.register(
    "service:store",
    { findFiltered: async () => ({ topics }) },
    { instantiate: false }
  );
  return topics;
}

// Same, but it keeps what it was asked for.
function recordingStoreWithModels(owner, attrsList) {
  const calls = [];
  const store = owner.lookup("service:store");
  const topics = attrsList.map((attrs) => topicModel(store, attrs));
  owner.unregister("service:store");
  owner.register(
    "service:store",
    {
      findFiltered: async (type, options) => {
        calls.push({ type, options });
        return { topics };
      },
    },
    { instantiate: false }
  );
  return calls;
}

module("Espublico Theme | Integration | homepage lanes", function (hooks) {
  setupRenderingTest(hooks);

  module("latest lane", function () {
    test("renders core's own topic list, not a hand-rolled one", async function (assert) {
      // The whole point of this lane's rewrite: the native list carries reply,
      // view and activity columns and inherits the theme's table styling from
      // stylesheets/app/topic-list.scss, so none of it is reimplemented here.
      // Verified against the reference on 2026-08-28 — community.hubspot.com's
      // own "Temas recientes" section is a real `table.topic-list`.
      stubStoreWithModels(this.owner, [
        topic({ id: 900010, fancy_title: "Un tema reciente" }),
        topic({ id: 900011, fancy_title: "Otro tema" }),
      ]);

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockLatest,
            args: { title: "homepage.latest.title", count: 8 },
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".block-latest table.topic-list").exists("the native table");
      assert.dom(".block-latest tr.topic-list-item").exists({ count: 2 });
    });

    test("renders a title's entities as characters, not as markup", async function (assert) {
      // `fancy_title` arrives already cooked, and printing it escaped put
      // "La Seu d&rsquo;Urgell" on the page verbatim. Core's list owns this
      // now; the assertion stays because the regression is ours to notice.
      stubStoreWithModels(this.owner, [
        topic({
          id: 900012,
          fancy_title: "La Seu d&rsquo;Urgell estrena sede",
        }),
      ]);

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockLatest,
            args: { title: "homepage.latest.title", count: 8 },
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      // `includesText`, not `hasText`: core's TopicLink adds an `sr-only` span
      // inside the anchor for the unread case, and this assertion is about the
      // entity being decoded rather than about the anchor's exact contents.
      assert
        .dom(".block-latest .topic-list-item a.title")
        .includesText("La Seu d\u2019Urgell estrena sede");
    });

    test("reads the site-wide latest list, with no category to point at", async function (assert) {
      // The lane stopped being category-keyed: pointing it at category 4 made
      // it 57% arrival announcements, because 4's listing included category
      // 78's 164 topics. Site-wide `latest` is the honest source for "what's
      // new" and it cannot be emptied by a category reorganisation.
      const calls = recordingStoreWithModels(this.owner, [
        topic({ id: 900013 }),
      ]);

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockLatest,
            args: { title: "homepage.latest.title", count: 8 },
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.deepEqual(calls[0].options, {
        filter: "latest",
        params: { order: "created" },
      });
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
        topic({ id: 900040, fancy_title: "Congreso", event_starts_at: later }),
        topic({
          id: 900041,
          fancy_title: "Jornada pasada",
          event_starts_at: gone,
        }),
        topic({ id: 900042, fancy_title: "Webinar", event_starts_at: soon }),
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
        topic({ id: 900043, fancy_title: "Webinar", event_starts_at: soon }),
        topic({ id: 900044, fancy_title: "Sin evento" }),
      ]);

      await renderEvents();

      assert.dom(".block-events__item-date.--scheduled").exists({ count: 1 });
      assert.dom(".block-events__item-date").exists({ count: 2 });
    });

    // The chip is built here, not by core's date helpers: `dFormatDate` has no
    // format that yields the two parts separately, and the future-date trap
    // documented in `block-events.gjs` rules out the relative ones entirely.
    //
    // Both fixtures are built from local components at midday rather than from
    // a UTC string, so the month and day a formatter renders in the runner's
    // timezone cannot drift a day either side of midnight. CI's timezone is
    // not ours to choose.
    test("splits a scheduled date into a month and a day", async function (assert) {
      stubStore(this.owner, [
        topic({
          id: 900046,
          fancy_title: "Congreso",
          event_starts_at: new Date(2026, 10, 5, 12).toISOString(),
        }),
      ]);

      await renderEvents();

      assert.dom(".block-events__item-date-month").hasText("Nov");
      assert.dom(".block-events__item-date-day").hasText("5");
    });

    test("builds the chip from the topic's own date when there is no event", async function (assert) {
      // Every row carries a chip, so the lane keeps one rhythm; only the
      // `--scheduled` modifier separates a date you can still act on from the
      // day a write-up was posted.
      stubStore(this.owner, [
        topic({
          id: 900047,
          fancy_title: "Cronica",
          created_at: new Date(2026, 7, 1, 12).toISOString(),
        }),
      ]);

      await renderEvents();

      assert.dom(".block-events__item-date-month").hasText("Aug");
      assert.dom(".block-events__item-date-day").hasText("1");
      assert.dom(".block-events__item-date.--scheduled").doesNotExist();
    });

    // The grey line under the title. Three shapes, and the multi-day one has
    // never rendered on the instance — category 59 holds exactly one topic
    // with an `[event]` block and it runs for a single day — so these tests
    // are the only thing standing behind that branch.
    test("gives a one-day event its date and its hours", async function (assert) {
      stubStore(this.owner, [
        topic({
          id: 900050,
          fancy_title: "Congreso",
          event_starts_at: new Date(2026, 10, 5, 10).toISOString(),
          event_ends_at: new Date(2026, 10, 5, 18).toISOString(),
        }),
      ]);

      await renderEvents();

      // Asserted by parts rather than against a whole string: the exact
      // separators and the 12/24-hour choice come from the runner's ICU build
      // and its locale, neither of which this repo pins.
      const when = document
        .querySelector(".block-events__item-when")
        .textContent.trim();

      assert.true(when.includes("November"), `month spelled out in "${when}"`);
      assert.true(when.includes("2026"), `year present in "${when}"`);
      assert.true(/10[:.]00/.test(when), `start time in "${when}"`);
      assert.true(
        /6[:.]00|18[:.]00/.test(when),
        `end time in "${when}", in whichever clock the locale uses`
      );
    });

    test("collapses a multi-day event into a range, with no times", async function (assert) {
      stubStore(this.owner, [
        topic({
          id: 900051,
          fancy_title: "Cumbre",
          event_starts_at: new Date(2026, 9, 12, 9).toISOString(),
          event_ends_at: new Date(2026, 9, 15, 17).toISOString(),
        }),
      ]);

      await renderEvents();

      const when = document
        .querySelector(".block-events__item-when")
        .textContent.trim();

      assert.true(when.includes("12"), `first day in "${when}"`);
      assert.true(when.includes("15"), `last day in "${when}"`);
      assert.true(when.includes("October"), `month once, not twice: "${when}"`);
      assert.false(
        /\d{1,2}[:.]\d{2}/.test(when),
        `a range spanning days drops the clock: "${when}"`
      );
    });

    test("falls back to the posting date when there is no event", async function (assert) {
      // 29 of the 30 topics in this category are write-ups with no `[event]`
      // block, so this is the shape almost every row takes.
      stubStore(this.owner, [
        topic({
          id: 900052,
          fancy_title: "Cronica",
          created_at: new Date(2026, 6, 14, 12).toISOString(),
        }),
      ]);

      await renderEvents();

      const when = document
        .querySelector(".block-events__item-when")
        .textContent.trim();

      assert.true(when.includes("July"), `posting month in "${when}"`);
      assert.true(when.includes("14"), `posting day in "${when}"`);
      assert.false(
        /\d{1,2}[:.]\d{2}/.test(when),
        `no invented clock on a topic that has no event: "${when}"`
      );
    });

    test("shows the archive alone rather than an empty heading", async function (assert) {
      stubStore(this.owner, [
        topic({
          id: 900045,
          fancy_title: "Solo pasado",
          event_starts_at: gone,
        }),
      ]);

      await renderEvents();

      assert.dom(".block-events__group").exists({ count: 1 });
      assert
        .dom(".block-events__group-title")
        .hasText("Past events", "no 'Coming up' with nothing under it");
    });
  });

  module("hero band", function () {
    test("renders the community copy at the top of the homepage", async function (assert) {
      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [{ block: BlockHero }])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".page-hero__title").hasText("Connect with the community");
    });
  });

  module("certified-users lane", function () {
    // Core's site fixture, not a theme one: any category whose definition topic
    // is known stands in for Comparte.
    function fixtureCategory() {
      return Category.list().find((category) => category.topic_url);
    }

    function renderLane(args) {
      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockCertified,
            args: {
              title: "homepage.certified.title",
              linkText: "homepage.certified.link_text",
              emptyText: "homepage.certified.empty",
              tag: "poster-evf",
              count: 6,
              ...args,
            },
          },
        ])
      );

      return render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );
    }

    test("lists the newest posters by creation date, filtered server-side by tag", async function (assert) {
      // By creation, not activity: a reply to an old poster must not put it
      // at the head of a lane announcing the latest certifications. And by
      // tag on the server, because 176 posters sit among Comparte's other
      // topics and one fetched page would not hold them.
      const queries = [];
      this.owner.unregister("service:store");
      this.owner.register(
        "service:store",
        {
          findFiltered: async (type, options) => {
            queries.push(options);
            return { topics: [topic({ id: 900060 })] };
          },
        },
        { instantiate: false }
      );

      await renderLane({ categoryId: 85 });

      assert.deepEqual(queries[0], {
        filter: "c/85/l/latest",
        params: { tags: ["poster-evf"], order: "created" },
      });
    });

    test("renders one link per poster, to its topic", async function (assert) {
      // No image filter: most posters are attached as a PDF and carry no
      // `image_url`, and they are certifications all the same.
      stubStore(this.owner, [
        topic({
          id: 900061,
          fancy_title: "Nueva alumna certificada",
          url: "/t/a/900061",
        }),
        topic({
          id: 900062,
          fancy_title: "Nuevo alumno certificado",
          url: "/t/b/900062",
        }),
      ]);

      await renderLane({ categoryId: fixtureCategory().id });

      assert.dom(".block-certified__title").includesText("Shared resources");
      assert.dom(".block-certified__title .d-icon-medal").exists();
      assert
        .dom(".block-certified__item .d-icon")
        .doesNotExist("the medal heads the lane once, not every row");
      assert.dom(".block-certified__item").exists({ count: 2 });
      assert
        .dom(".block-certified__item-link")
        .hasAttribute("href", "/t/a/900061");
      assert
        .dom(".block-certified__item-title")
        .hasText("Nueva alumna certificada");
    });

    test("names the programme and the posting date under each title", async function (assert) {
      // The programme is the poster's subcategory, read off the preloaded
      // category list; the date is creation, matching the lane's order.
      const category = fixtureCategory();
      stubStore(this.owner, [
        topic({
          id: 900064,
          category_id: category.id,
          created_at: "2026-10-08T09:00:00.000Z",
        }),
      ]);

      await renderLane({ categoryId: category.id });

      assert
        .dom(".block-certified__item-meta")
        .includesText(category.name)
        .hasAttribute("datetime", "2026-10-08T09:00:00.000Z");
    });

    test("links to the category's own About topic, not to its listing", async function (assert) {
      // The topic is read off the preloaded category rather than configured,
      // so the link follows the instance the theme is installed on.
      const category = fixtureCategory();
      stubStore(this.owner, [topic({ id: 900063 })]);

      await renderLane({ categoryId: category.id });

      assert
        .dom(".block-certified__footer .block-certified__link")
        .hasAttribute("href", category.topic_url)
        .hasText("See them in Comparte");
    });

    test("says there are no posters when the listing is empty", async function (assert) {
      stubStore(this.owner, []);

      await renderLane({ categoryId: fixtureCategory().id });

      assert
        .dom(".block-certified__empty")
        .hasText("No certification posters yet.");
    });
  });
});

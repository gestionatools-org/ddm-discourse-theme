import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

// The theme sets `custom_homepage`, so "/" is the theme's own five lanes.
// Every lane fetches on render, so each of these modules stubs all four
// category listings even when it only asserts on one — an unstubbed lane
// would fail its request rather than simply render nothing.
//
// These cover what `test/acceptance/category-topics-test.js` cannot: that
// pipeline is tested at the function boundary, this one at the DOM. The three
// remaining bugs from the 2026-08-16/17 review all live here, in the template.

const LANES = { news: 4, forum: 5, events: 59, showcase: 78 };

function topic(attrs) {
  return {
    id: 1,
    title: "A topic",
    fancy_title: "A topic",
    slug: "a-topic",
    posts_count: 1,
    reply_count: 0,
    highest_post_number: 1,
    image_url: null,
    excerpt: null,
    created_at: "2026-08-01T10:00:00.000Z",
    last_posted_at: "2026-08-01T10:00:00.000Z",
    bumped: true,
    bumped_at: "2026-08-01T10:00:00.000Z",
    archetype: "regular",
    unseen: false,
    pinned: false,
    unpinned: null,
    visible: true,
    closed: false,
    archived: false,
    category_id: 4,
    posters: [],
    ...attrs,
  };
}

function topicList(topics) {
  return {
    users: [],
    primary_groups: [],
    flair_groups: [],
    topic_list: { can_create_topic: true, per_page: 30, topics },
  };
}

// Nothing in any lane unless a module overrides it, so a lane under test is
// never crowded by another lane's fixture.
function stubLanes(server, helper, overrides = {}) {
  for (const [name, id] of Object.entries(LANES)) {
    server.get(`/c/${id}/l/latest.json`, () =>
      helper.response(topicList(overrides[name] ?? []))
    );
  }
}

function useLaneSettings() {
  settings.news_category_id = LANES.news;
  settings.news_count = 4;
  settings.forum_category_id = LANES.forum;
  settings.forum_count = 6;
  settings.events_category_id = LANES.events;
  settings.events_count = 4;
  settings.showcase_category_id = LANES.showcase;
  settings.showcase_count = 6;
  settings.library_category_ids = "73|85";
}

const LIBRARY_CATEGORIES = [
  {
    id: 73,
    name: "Recursos Certificación",
    slug: "documentacion-analiza",
    color: "0088CC",
    topic_count: 0,
    topic_url: "/t/acerca-de-la-categoria-documentacion-analiza/2200",
  },
  {
    id: 79,
    name: "Técnicas",
    slug: "tecnicas",
    parent_category_id: 73,
    topic_count: 40,
    topic_url: "/t/acerca-de-la-categoria-tecnicas/2201",
  },
  {
    id: 80,
    name: "Biblioteca",
    slug: "biblioteca",
    parent_category_id: 73,
    topic_count: 26,
    topic_url: "/t/acerca-de-la-categoria-biblioteca/2202",
  },
  {
    id: 85,
    name: "Recursos compartidos",
    slug: "recursos-y-proyectos-compartidos",
    color: "92278F",
    topic_count: 3,
    topic_url: "/t/acerca-de-la-categoria-recursos/2203",
  },
];

acceptance("Espublico Theme | Homepage | news lane", function (needs) {
  needs.user();
  needs.hooks.beforeEach(useLaneSettings);
  needs.pretender((server, helper) =>
    stubLanes(server, helper, {
      news: [
        topic({
          id: 10,
          // Already-cooked HTML, exactly as fancy_title arrives.
          fancy_title: "La Seu d&rsquo;Urgell estrena sede",
          excerpt: "Nuevo :automobile: para el parque móvil",
          slug: "la-seu-durgell",
        }),
      ],
    })
  );

  test("renders a title's entities as characters, not as markup", async function (assert) {
    await visit("/");

    // `fancy_title` is already HTML. Passing it through dReplaceEmoji escaped
    // the ampersand first, so the page printed "La Seu d&rsquo;Urgell".
    assert
      .dom(".block-news__item-title")
      .hasText("La Seu d’Urgell estrena sede");
  });

  test("resolves emoji shortcodes in an excerpt", async function (assert) {
    await visit("/");

    // ExcerptParser strips cooked HTML back to text and turns emoji images
    // into their `:shortcode:`, so one news excerpt in four printed
    // ":automobile:" as words.
    assert
      .dom(".block-news__item-excerpt img.emoji")
      .exists({ count: 1 }, "the shortcode became an image");
    assert
      .dom(".block-news__item-excerpt")
      .doesNotIncludeText(":automobile:", "and no shortcode survives as text");
  });
});

acceptance("Espublico Theme | Homepage | forum lane", function (needs) {
  needs.user();
  needs.hooks.beforeEach(useLaneSettings);
  needs.pretender((server, helper) =>
    stubLanes(server, helper, {
      forum: [
        topic({ id: 20, slug: "una-duda", reply_count: 7, category_id: 5 }),
      ],
    })
  );

  test("promotes the reply count, which is this lane's reason to exist", async function (assert) {
    await visit("/");

    assert.dom(".block-forum__item-replies").hasText("7");
  });
});

acceptance("Espublico Theme | Homepage | showcase lane", function (needs) {
  needs.user();
  needs.hooks.beforeEach(useLaneSettings);
  needs.pretender((server, helper) =>
    stubLanes(server, helper, {
      showcase: [
        topic({ id: 30, slug: "sin-imagen", image_url: null, category_id: 78 }),
        topic({
          id: 31,
          slug: "con-imagen",
          image_url: "/uploads/poster.png",
          category_id: 78,
        }),
      ],
    })
  );

  test("hangs only the topics that carry a cover image", async function (assert) {
    await visit("/");

    // Half the live grid was grey boxes: a card with no image exhibits
    // nothing, and this lane exists to exhibit work.
    assert.dom(".block-showcase__card").exists({ count: 1 });
    assert
      .dom(".block-showcase__card-image")
      .hasAttribute("src", "/uploads/poster.png");
  });
});

acceptance("Espublico Theme | Homepage | events lane", function (needs) {
  needs.user();
  needs.hooks.beforeEach(useLaneSettings);

  // Dates are relative to now so the split cannot rot: two events ahead, one
  // behind, deliberately served in the wrong order.
  const day = 86400000;
  const soon = new Date(Date.now() + day).toISOString();
  const later = new Date(Date.now() + 30 * day).toISOString();
  const gone = new Date(Date.now() - 30 * day).toISOString();

  needs.pretender((server, helper) =>
    stubLanes(server, helper, {
      events: [
        topic({
          id: 40,
          slug: "congreso",
          fancy_title: "Congreso",
          event_starts_at: later,
          category_id: 59,
        }),
        topic({
          id: 41,
          slug: "jornada-pasada",
          fancy_title: "Jornada pasada",
          event_starts_at: gone,
          category_id: 59,
        }),
        topic({
          id: 42,
          slug: "webinar",
          fancy_title: "Webinar",
          event_starts_at: soon,
          category_id: 59,
        }),
      ],
    })
  );

  test("puts what is still ahead first, soonest first", async function (assert) {
    await visit("/");

    // The listing is served bumped_at descending regardless of the category's
    // event sort setting, so an upcoming event led the lane only by accident
    // of being the most recently bumped topic.
    const groups = [...document.querySelectorAll(".block-events__group")];

    assert.strictEqual(groups.length, 2, "both halves are labelled");
    assert
      .dom(groups[0].querySelector(".block-events__group-title"))
      .hasText("Coming up");

    const upcoming = [
      ...groups[0].querySelectorAll(".block-events__item-title"),
    ].map((el) => el.textContent.trim());

    assert.deepEqual(
      upcoming,
      ["Webinar", "Congreso"],
      "soonest first, not in the order served"
    );
  });

  test("keeps the record behind the announcement", async function (assert) {
    await visit("/");

    const groups = [...document.querySelectorAll(".block-events__group")];
    const past = [
      ...groups[1].querySelectorAll(".block-events__item-title"),
    ].map((el) => el.textContent.trim());

    assert
      .dom(groups[1].querySelector(".block-events__group-title"))
      .hasText("Past events");
    assert.deepEqual(past, ["Jornada pasada"]);
  });

  test("marks a real event date apart from a topic date", async function (assert) {
    await visit("/");

    // Core's relative helpers cannot render a future date — `medium` prints
    // every one of them as "now" — so a scheduled date is absolute and
    // carries its own modifier.
    assert.dom(".block-events__item-date.--scheduled").exists({ count: 3 });
  });
});

acceptance(
  "Espublico Theme | Homepage | events lane with nothing ahead",
  function (needs) {
    needs.user();
    needs.hooks.beforeEach(useLaneSettings);
    needs.pretender((server, helper) =>
      stubLanes(server, helper, {
        events: [
          topic({
            id: 43,
            slug: "solo-pasado",
            fancy_title: "Solo pasado",
            event_starts_at: new Date(Date.now() - 86400000).toISOString(),
            category_id: 59,
          }),
        ],
      })
    );

    test("shows the archive alone rather than an empty heading", async function (assert) {
      await visit("/");

      assert.dom(".block-events__group").exists({ count: 1 });
      assert
        .dom(".block-events__group-title")
        .hasText("Past events", "no 'Coming up' with nothing under it");
    });
  }
);

acceptance("Espublico Theme | Homepage | library lane", function (needs) {
  needs.user();
  needs.hooks.beforeEach(useLaneSettings);
  needs.site({ categories: LIBRARY_CATEGORIES });
  needs.pretender(stubLanes);

  test("counts a tree's documents through its sections", async function (assert) {
    await visit("/");

    // The lane that exists to advertise the library announced "0 documentos"
    // for its two largest trees, because topic_count counts direct topics only
    // and subcategory_count arrives null on the preloaded categories.
    const cards = [...document.querySelectorAll(".block-library__card")];

    assert.strictEqual(cards.length, 2, "one card per configured category");
    assert
      .dom(cards[0])
      .includesText("2 sections", "the subtree is counted, not the parent");
    assert.dom(cards[0]).includesText("66 documents");
  });

  test("renders a childless category without a section count", async function (assert) {
    await visit("/");

    const cards = [...document.querySelectorAll(".block-library__card")];

    assert.dom(cards[1]).includesText("3 documents");
    assert
      .dom(cards[1])
      .doesNotIncludeText("section", "no '0 sections' on a flat category");
  });
});

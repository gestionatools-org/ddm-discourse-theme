import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  categoryStats,
  definitionTopicIds,
  loadCategoryTopics,
  loadLatestTopics,
  resolveCategories,
} from "../../discourse/lib/category-topics";

// These functions read the preloaded site category list, so they need an
// application booted around them — `acceptance` is what seeds `needs.site`.
// None of them renders anything, so no test here visits a route: the homepage
// blocks that consume them are exercised separately.
//
// The taxonomy below mirrors the real one in shape, not in size: two-level
// trees whose parents keep few or no direct topics, which is the arrangement
// that made the library lane report "0 documentos" for its two largest trees.
const CATEGORIES = [
  {
    id: 73,
    name: "Recursos Certificación Analítica de datos",
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
    name: "Recursos y proyectos compartidos",
    slug: "recursos-y-proyectos-compartidos",
    color: "92278F",
    topic_count: 0,
    topic_url: "/t/acerca-de-la-categoria-recursos/2203",
  },
  {
    id: 86,
    name: "Proyectos 360 · Hackathon Gestiona",
    slug: "proyectos-360-hackathon-gestiona",
    parent_category_id: 85,
    topic_count: 8,
    topic_url: "/t/acerca-de-la-categoria-proyectos-360/2204",
  },
  {
    id: 78,
    name: "Nuevos usuarios certificados · Pósters",
    slug: "nuevos-usuarios-certificados",
    topic_count: 29,
    topic_url: "/t/acerca-de-la-categoria-posters/2246",
  },
];

// A stand-in for the injected `store` service. `loadCategoryTopics` takes the
// store as an argument rather than reaching for it, so the whole fetch path is
// testable without a network stub.
function fakeStore(topics, calls = []) {
  return {
    calls,
    async findFiltered(type, options) {
      calls.push({ type, options });
      return { topics };
    },
  };
}

function topic(attrs) {
  return { id: 1, fancy_title: "A topic", image_url: null, ...attrs };
}

acceptance("Espublico Theme | category-topics", function (needs) {
  needs.site({ categories: CATEGORIES });

  test("collects every category definition topic on the site", function (assert) {
    const ids = definitionTopicIds();

    assert.true(ids.has(2246), "the showcase category's own definition topic");
    assert.true(
      ids.has(2201),
      "and a subcategory's, since a lane pulls subcategory topics into its parent's listing"
    );
    assert.strictEqual(ids.size, 6, "one per seeded category, none missed");
  });

  test("sums a directory card's counts over the subtree", function (assert) {
    // The bug this guards: `topic_count` counts direct topics only and
    // `subcategory_count` arrives as null on the preloaded categories, so
    // reading either alone reported "0 documentos" for exactly the trees the
    // library lane exists to advertise.
    assert.deepEqual(
      categoryStats(CATEGORIES[0]),
      { sections: 2, documents: 66 },
      "a parent with no direct topics still reports its children's"
    );
  });

  test("counts a parent's own topics alongside its children's", function (assert) {
    assert.deepEqual(categoryStats({ id: 85, topic_count: 3 }), {
      sections: 1,
      documents: 11,
    });
  });

  test("reports a childless category as zero sections", function (assert) {
    assert.deepEqual(categoryStats({ id: 78, topic_count: 29 }), {
      sections: 0,
      documents: 29,
    });
  });

  test("treats a missing topic_count as zero rather than NaN", function (assert) {
    assert.deepEqual(categoryStats({ id: 999 }), {
      sections: 0,
      documents: 0,
    });
  });

  test("resolves configured ids against the site list", function (assert) {
    const resolved = resolveCategories([73, 85]);

    assert.deepEqual(
      resolved.map((category) => category.id),
      [73, 85]
    );
  });

  test("drops an id that no longer resolves instead of rendering a blank", function (assert) {
    // A category deleted in admin should cost one card, not the whole lane.
    const resolved = resolveCategories([73, 4242, 85]);

    assert.deepEqual(
      resolved.map((category) => category.id),
      [73, 85]
    );
  });

  test("resolves nothing from an empty or absent list", function (assert) {
    assert.deepEqual(resolveCategories([]), [], "empty");
    assert.deepEqual(resolveCategories(null), [], "absent");
  });
});

acceptance(
  "Espublico Theme | category-topics | loadCategoryTopics",
  function (needs) {
    needs.site({ categories: CATEGORIES });

    test("asks for the category's latest listing", async function (assert) {
      const store = fakeStore([topic({ id: 10 })]);

      await loadCategoryTopics(store, 78, 4);

      assert.deepEqual(store.calls[0], {
        type: "topicList",
        options: { filter: "c/78/l/latest" },
      });
    });

    test("does not fetch at all when the lane is disabled", async function (assert) {
      // 0 is how an admin turns a lane off, and it must not reach the network.
      const store = fakeStore([topic({ id: 10 })]);

      assert.strictEqual(await loadCategoryTopics(store, 0, 4), null);
      assert.strictEqual(store.calls.length, 0, "no request was made");
    });

    test("drops the category definition topic", async function (assert) {
      // It is auto-generated boilerplate, it is pinned so it sorts first, and it
      // carries no cover image — which put an empty grey card at the head of the
      // showcase grid.
      const store = fakeStore([
        topic({ id: 2246, fancy_title: "Acerca de la categoría …" }),
        topic({ id: 10, fancy_title: "A real topic" }),
      ]);

      const topics = await loadCategoryTopics(store, 78, 4);

      assert.deepEqual(
        topics.map((t) => t.id),
        [10]
      );
    });

    test("keeps a lane at its configured length", async function (assert) {
      const store = fakeStore([
        topic({ id: 10 }),
        topic({ id: 11 }),
        topic({ id: 12 }),
      ]);

      const topics = await loadCategoryTopics(store, 78, 2);

      assert.deepEqual(
        topics.map((t) => t.id),
        [10, 11]
      );
    });

    test("returns null rather than an empty array when nothing qualifies", async function (assert) {
      // AsyncContent routes null to its <:empty> block; an empty array would
      // render an empty list instead.
      assert.strictEqual(
        await loadCategoryTopics(fakeStore([]), 78, 4),
        null,
        "nothing served"
      );
      assert.strictEqual(
        await loadCategoryTopics(fakeStore([topic({ id: 2246 })]), 78, 4),
        null,
        "nothing left after the definition topic goes"
      );
    });

    test("drops imageless topics when the lane requires a cover image", async function (assert) {
      // The showcase exists to exhibit member work; a card with no image
      // exhibits nothing. Three of six live cells were grey boxes before this.
      const store = fakeStore([
        topic({ id: 10, image_url: null }),
        topic({ id: 11, image_url: "https://example.com/a.png" }),
      ]);

      const topics = await loadCategoryTopics(store, 78, 6, {
        requireImage: true,
      });

      assert.deepEqual(
        topics.map((t) => t.id),
        [11]
      );
    });

    test("filters before slicing, so the grid still fills its cells", async function (assert) {
      // Slicing first would let a definition topic and two imageless topics eat
      // the lane's whole budget and leave one card on screen.
      const store = fakeStore([
        topic({ id: 2246, image_url: null }),
        topic({ id: 10, image_url: null }),
        topic({ id: 11, image_url: "https://example.com/a.png" }),
        topic({ id: 12, image_url: "https://example.com/b.png" }),
        topic({ id: 13, image_url: "https://example.com/c.png" }),
      ]);

      const topics = await loadCategoryTopics(store, 78, 2, {
        requireImage: true,
      });

      assert.deepEqual(
        topics.map((t) => t.id),
        [11, 12]
      );
    });

    test("falls through to empty when no topic carries an image", async function (assert) {
      const store = fakeStore([
        topic({ id: 10, image_url: null }),
        topic({ id: 11, image_url: null }),
      ]);

      assert.strictEqual(
        await loadCategoryTopics(store, 78, 6, { requireImage: true }),
        null,
        "the honest outcome for a gallery with nothing to hang"
      );
    });

    test("asks the server to filter by tag rather than trimming the page after", async function (assert) {
      // Filtering the fetched page client-side would only ever see the first
      // 30 topics. The póster subset of category 78 is a minority of 164 and
      // growing from the recent end, so a page filter would show a handful of
      // cards and call the rest absent. Verified against the live API:
      // c/62/l/latest.json?tags[]=markdown returns 6 of 16.
      const store = fakeStore([topic({ id: 10 })]);

      await loadCategoryTopics(store, 78, 6, { tag: "poster" });

      assert.deepEqual(store.calls[0], {
        type: "topicList",
        options: { filter: "c/78/l/latest", params: { tags: ["poster"] } },
      });
    });

    test("sends no tags param when the tag setting is unset", async function (assert) {
      // A guard, not a behaviour change: `tags: [""]` matches nothing, so a
      // naive `if (tag !== undefined)` would empty the lane the moment the
      // setting is added — silently, which is the failure mode settings.yml
      // warns about at the top.
      const store = fakeStore([topic({ id: 10 })]);

      await loadCategoryTopics(store, 78, 6, { tag: "" });

      assert.deepEqual(store.calls[0].options, { filter: "c/78/l/latest" });
    });
  }
);

acceptance(
  "Espublico Theme | category-topics | loadLatestTopics",
  function (needs) {
    needs.site({ categories: CATEGORIES });

    test("asks for the site-wide latest listing, with no category to point at", async function (assert) {
      const store = fakeStore([topic({ id: 10 })]);

      await loadLatestTopics(store, 4);

      assert.deepEqual(store.calls[0], {
        type: "topicList",
        options: { filter: "latest" },
      });
    });

    test("drops the definition topics a site-wide list surfaces from every category", async function (assert) {
      // The category-keyed lane only ever met one of these. `latest` meets all
      // of them, and they arrive as ordinary recent topics whenever a category
      // is created or edited.
      const store = fakeStore([
        topic({ id: 2246 }),
        topic({ id: 2201 }),
        topic({ id: 10, fancy_title: "A real topic" }),
      ]);

      const topics = await loadLatestTopics(store, 4);

      assert.deepEqual(
        topics.map((t) => t.id),
        [10]
      );
    });

    test("keeps the lane at its configured length", async function (assert) {
      const store = fakeStore([
        topic({ id: 10 }),
        topic({ id: 11 }),
        topic({ id: 12 }),
      ]);

      const topics = await loadLatestTopics(store, 2);

      assert.deepEqual(
        topics.map((t) => t.id),
        [10, 11]
      );
    });

    test("returns null rather than an empty array when nothing qualifies", async function (assert) {
      assert.strictEqual(await loadLatestTopics(fakeStore([]), 4), null);
      assert.strictEqual(
        await loadLatestTopics(fakeStore([topic({ id: 2246 })]), 4),
        null,
        "nothing left after the definition topics go"
      );
    });
  }
);

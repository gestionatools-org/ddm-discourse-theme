import { module, test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { definitionTopicIds } from "../../discourse/lib/category-topics";
import {
  extractCoverImage,
  extractPdfUrl,
  extractVideoId,
  loadLatestTaggedTopic,
  memberHasActivity,
  monthAndYear,
  paragraphsFromCooked,
  profileDetails,
  rankTopMember,
  uploadRefFromShortUrl,
  WEIGHTS,
  youtubeThumbnail,
} from "../../discourse/lib/highlights";

// The shape every newsletter on PRE has, trimmed: paragraphs of copy, then the
// cover image wrapped in an anchor to the PDF on storage, then the short-url
// attachment link, then a run of emoji. Both the cover and the PDF are last,
// not first, which is why neither extractor can key on position.
const EMOJI_IMG = `<img src="https://example.com/images/emoji/apple/up_arrow.png?v=15" title=":up_arrow:" class="emoji" alt=":up_arrow:">`;
const NEWSLETTER_COOKED = `
<p>Buenos días <a class="mention-group notify" href="/groups/certificaci%C3%B3n">@Certificación</a></p>
<p>Con el verano recién estrenado llega un nuevo número de nuestra revista.</p>
<p><a href="https://cdck-file-uploads.example.com/original/2X/3/398f.pdf"><img src="//cdck-file-uploads.example.com/original/2X/d/d180.jpeg" alt="Revista 14" width="280" height="375"></a></p>
<p><a class="attachment" href="/uploads/short-url/8dccSWOMxhvIuYP1rQiiyh8KKmi.pdf">Revista 14</a></p>
<p>${EMOJI_IMG} ${EMOJI_IMG}</p>
`;

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
      extractVideoId(
        `<a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=1">x</a>`
      ),
      "dQw4w9WgXcQ"
    );
  });

  test("falls back to an /embed/ url", function (assert) {
    assert.strictEqual(
      extractVideoId(
        `<iframe src="https://www.youtube-nocookie.com/embed/abcdefghijk"></iframe>`
      ),
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

module("Espublico Theme | Unit | highlights | extractCoverImage", function () {
  test("returns the cover of a real newsletter post", function (assert) {
    assert.strictEqual(
      extractCoverImage(NEWSLETTER_COOKED),
      "//cdck-file-uploads.example.com/original/2X/d/d180.jpeg",
      "the protocol-relative src, unresolved"
    );
  });

  test("skips emoji that come before the cover", function (assert) {
    const cooked = `<p>${EMOJI_IMG}</p><p><img src="/uploads/cover.png"></p>`;
    assert.strictEqual(extractCoverImage(cooked), "/uploads/cover.png");
  });

  test("skips an emoji served from /images/emoji/ without the class", function (assert) {
    const cooked = `<p><img src="/images/emoji/apple/wave.png?v=15" alt=":wave:"></p><p><img src="/uploads/cover.png"></p>`;
    assert.strictEqual(extractCoverImage(cooked), "/uploads/cover.png");
  });

  test("returns null when the post has only emoji, no images, or nothing", function (assert) {
    assert.strictEqual(extractCoverImage(`<p>${EMOJI_IMG}</p>`), null);
    assert.strictEqual(extractCoverImage(`<p>Solo texto.</p>`), null);
    assert.strictEqual(extractCoverImage(""), null);
    assert.strictEqual(extractCoverImage(null), null);
  });
});

module("Espublico Theme | Unit | highlights | extractPdfUrl", function () {
  test("prefers an absolute URL over the short-url placeholder", function (assert) {
    // The order that matters, and the opposite of what it first looked like:
    // measured on PRE, every same-origin /uploads/** route answers 404 while
    // the storage URL answers 200 application/pdf.
    assert.strictEqual(
      extractPdfUrl(NEWSLETTER_COOKED),
      "https://cdck-file-uploads.example.com/original/2X/3/398f.pdf"
    );
  });

  test("prefers an absolute URL even when the short-url comes first", function (assert) {
    const cooked = `<p><a href="/uploads/short-url/8dcc.pdf">a</a><a href="//cdck.example.com/original/2X/3/398f.pdf">b</a></p>`;
    assert.strictEqual(
      extractPdfUrl(cooked),
      "//cdck.example.com/original/2X/3/398f.pdf",
      "protocol-relative counts as absolute"
    );
  });

  test("falls back to the short-url when that is the only PDF link", function (assert) {
    // 9 of the 14 newsletters are this shape, so it cannot simply be dropped —
    // the block resolves it through /uploads/lookup-urls.
    const cooked = `<p><a href="/uploads/short-url/9BUfTFfwTe0o0jB5KhlxNhYazPo.pdf">Revista 12</a></p>`;
    assert.strictEqual(
      extractPdfUrl(cooked),
      "/uploads/short-url/9BUfTFfwTe0o0jB5KhlxNhYazPo.pdf"
    );
  });

  test("matches an attachment anchor that carries no class", function (assert) {
    // Measured on PRE: /t/2177's attachment anchor has no class="attachment",
    // so the class cannot be the discriminator.
    const cooked = `<p><a href="/uploads/short-url/9BUf.pdf">Revista 12</a></p>`;
    assert.strictEqual(extractPdfUrl(cooked), "/uploads/short-url/9BUf.pdf");
  });

  test("ignores a query string or fragment when matching the extension", function (assert) {
    const cooked = `<p><a href="https://cdck.example.com/x.pdf?dl=1#page=3">Revista</a></p>`;
    assert.strictEqual(
      extractPdfUrl(cooked),
      "https://cdck.example.com/x.pdf?dl=1#page=3",
      "the href is returned whole, only the match ignores the suffix"
    );
  });

  test("returns null when nothing links to a PDF", function (assert) {
    const cooked = `<p><a href="/t/otro-tema/42">Un tema</a><a href="/uploads/x.png">Imagen</a></p>`;
    assert.strictEqual(extractPdfUrl(cooked), null);
    assert.strictEqual(extractPdfUrl(""), null);
    assert.strictEqual(extractPdfUrl(null), null);
  });
});

module(
  "Espublico Theme | Unit | highlights | uploadRefFromShortUrl",
  function () {
    test("builds the upload:// reference lookup-urls expects", function (assert) {
      assert.strictEqual(
        uploadRefFromShortUrl(
          "/uploads/short-url/8dccSWOMxhvIuYP1rQiiyh8KKmi.pdf"
        ),
        "upload://8dccSWOMxhvIuYP1rQiiyh8KKmi.pdf"
      );
    });

    test("keeps working without an extension", function (assert) {
      assert.strictEqual(
        uploadRefFromShortUrl("/uploads/short-url/8dcc"),
        "upload://8dcc"
      );
    });

    test("returns null for anything that is not a short-url", function (assert) {
      assert.strictEqual(
        uploadRefFromShortUrl(
          "https://cdck.example.com/original/2X/3/398f.pdf"
        ),
        null,
        "an absolute URL needs no resolving"
      );
      assert.strictEqual(uploadRefFromShortUrl("/t/nl-14/2592"), null);
      assert.strictEqual(uploadRefFromShortUrl(null), null);
      assert.strictEqual(uploadRefFromShortUrl(undefined), null);
    });
  }
);

module(
  "Espublico Theme | Unit | highlights | paragraphsFromCooked",
  function () {
    test("keeps the post's top-level blocks as separate paragraphs", function (assert) {
      assert.deepEqual(paragraphsFromCooked(NEWSLETTER_COOKED, 400), [
        "Buenos días @Certificación",
        "Con el verano recién estrenado llega un nuevo número de nuestra revista.",
        "Revista 14",
      ]);
    });

    test("keeps the greeting line", function (assert) {
      // Deliberate: a rule that skipped it would be one more thing to maintain,
      // and the copy of a single post is easier to adjust by hand.
      assert.strictEqual(
        paragraphsFromCooked(NEWSLETTER_COOKED, 400)[0],
        "Buenos días @Certificación"
      );
    });

    test("reads a paragraph inside a quote once, not twice", function (assert) {
      const cooked = `<blockquote><p>Citado.</p></blockquote><p>Propio.</p>`;
      assert.deepEqual(paragraphsFromCooked(cooked, 400), [
        "Citado.",
        "Propio.",
      ]);
    });

    test("spends the budget across paragraphs and stops", function (assert) {
      const cooked = `<p>${"a".repeat(30)}</p><p>${"b".repeat(30)}</p><p>ccc</p>`;
      assert.deepEqual(
        paragraphsFromCooked(cooked, 60),
        ["a".repeat(30), "b".repeat(30)],
        "the third paragraph has no budget left"
      );
    });

    test("truncates the paragraph that overruns, on a word boundary", function (assert) {
      const cooked = `<p>${"a".repeat(50)}</p><p>uno dos tres cuatro cinco seis siete ocho nueve diez once doce</p>`;
      const [, tail] = paragraphsFromCooked(cooked, 95);
      assert.strictEqual(
        tail,
        "uno dos tres cuatro cinco seis siete ocho…",
        "45 characters of budget, cut at the last space that fits"
      );
    });

    test("drops a tail too short to read as a sentence", function (assert) {
      const cooked = `<p>${"a".repeat(50)}</p><p>uno dos tres cuatro cinco</p>`;
      assert.deepEqual(
        paragraphsFromCooked(cooked, 60),
        ["a".repeat(50)],
        "10 characters left is a fragment, not a paragraph"
      );
    });

    test("strips punctuation stranded by the cut", function (assert) {
      const cooked = `<p>${"uno dos, tres cuatro cinco seis siete ocho nueve diez"}</p>`;
      assert.strictEqual(
        paragraphsFromCooked(cooked, 41)[0],
        "uno dos, tres cuatro cinco seis siete…",
        "the comma survives mid-text; only a stranded one is stripped"
      );
    });

    test("returns null for a post with no text", function (assert) {
      assert.strictEqual(
        paragraphsFromCooked(`<p>${EMOJI_IMG}</p>`, 400),
        null
      );
      assert.strictEqual(paragraphsFromCooked("", 400), null);
      assert.strictEqual(paragraphsFromCooked(null, 400), null);
    });
  }
);

module("Espublico Theme | Unit | highlights | profileDetails", function () {
  // Jorge Redondo's real payload, trimmed. Fields 1 and 3 are a NIF and a CIF
  // carrying show_on_profile:false — a member's session never receives them,
  // an administrator's does, which is exactly why they are here.
  const user = {
    location: "Cuéllar",
    website: "http://www.dipsegovia.es",
    website_name: "dipsegovia.es",
    created_at: "2024-02-14T14:25:34.718Z",
    user_fields: {
      1: "03460654M",
      2: "Diputación de Segovia",
      3: "P4000000B",
      4: "Técnico Auxiliar de Informática",
    },
  };

  test("reads only the two configured fields, never the rest", function (assert) {
    const details = profileDetails(user, { entityFieldId: 2, roleFieldId: 4 });

    assert.strictEqual(details.entity, "Diputación de Segovia");
    assert.strictEqual(details.role, "Técnico Auxiliar de Informática");
    assert.false(
      JSON.stringify(details).includes("03460654M"),
      "nor anywhere in the returned object"
    );
    assert.false(
      JSON.stringify(details).includes("P4000000B"),
      "and neither is the CIF"
    );
  });

  test("carries location, website and the join date", function (assert) {
    const details = profileDetails(user, { entityFieldId: 2, roleFieldId: 4 });

    assert.strictEqual(details.location, "Cuéllar");
    assert.strictEqual(details.websiteName, "dipsegovia.es");
    assert.strictEqual(details.websiteUrl, "http://www.dipsegovia.es");
    assert.strictEqual(details.memberSince, "2024-02-14T14:25:34.718Z");
  });

  test("a field id of 0 reads as absent", function (assert) {
    const details = profileDetails(user, { entityFieldId: 0, roleFieldId: 0 });
    assert.strictEqual(details.entity, null);
    assert.strictEqual(details.role, null);
  });

  test("a member missing a field gets null, not undefined", function (assert) {
    // Ricardo Penalver's shape: everything but the job title.
    const details = profileDetails(
      { location: "Zaragoza", user_fields: { 2: "Espublico Gestiona" } },
      { entityFieldId: 2, roleFieldId: 4 }
    );
    assert.strictEqual(details.role, null);
    assert.strictEqual(details.websiteName, null);
    assert.strictEqual(details.entity, "Espublico Gestiona");
  });

  test("returns null for no user at all", function (assert) {
    assert.strictEqual(profileDetails(null, {}), null);
    assert.strictEqual(profileDetails(undefined), null);
  });
});

module("Espublico Theme | Unit | highlights | monthAndYear", function () {
  test("formats an ISO timestamp as month and year", function (assert) {
    assert.strictEqual(
      monthAndYear("2024-02-14T14:25:34.718Z", "es"),
      "febrero de 2024"
    );
    assert.strictEqual(
      monthAndYear("2024-01-15T11:31:49.027Z", "en"),
      "January 2024"
    );
  });

  test("returns null for anything unparseable", function (assert) {
    assert.strictEqual(monthAndYear(null, "es"), null);
    assert.strictEqual(monthAndYear("", "es"), null);
    assert.strictEqual(monthAndYear("not a date", "es"), null);
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
    // `wide` leads every field by a clear margin -> unambiguous winner, no
    // floating-point knife-edge.
    const narrow = { post_count: 2, likes_received: 2, days_visited: 2 };
    const wide = { post_count: 6, likes_received: 6, days_visited: 6 };
    assert.strictEqual(rankTopMember([narrow, wide], WEIGHTS), wide);
  });

  test("a big lead on the weighted field beats a big lead on a light one", function (assert) {
    // `poster` trails on likes and days but its post lead, at weight 0.5,
    // outweighs the other's lead at 0.35 + 0.15.
    // poster.score = .5*1   + .35*0   + .15*0   = .500
    // liker.score  = .5*0   + .35*1   + .15*1   = 0.35 + 0.15 = .500  -> tie
    // Make it not a tie: give the poster a sliver on days too.
    const poster = { post_count: 20, likes_received: 0, days_visited: 1 };
    const liker = { post_count: 0, likes_received: 20, days_visited: 20 };
    // poster: .5*1 + 0 + .15*(1/20) = .5075 ; liker: 0 + .35 + .15 = .5
    assert.strictEqual(rankTopMember([poster, liker], WEIGHTS), poster);
  });

  test("treats a field whose max is zero as contributing nothing", function (assert) {
    const x = { post_count: 0, likes_received: 5, days_visited: 0 };
    const y = { post_count: 0, likes_received: 2, days_visited: 0 };
    assert.strictEqual(rankTopMember([x, y], WEIGHTS), x);
  });

  test("a tie keeps the earlier item", function (assert) {
    // Identical composite scores: the reduce keeps `best` on a non-strict-
    // greater score, so the first item in the list wins.
    const first = { post_count: 5, likes_received: 5, days_visited: 5 };
    const second = { post_count: 5, likes_received: 5, days_visited: 5 };
    assert.strictEqual(
      rankTopMember([first, second], WEIGHTS),
      first,
      "the earlier of two equal items"
    );
  });
});

module("Espublico Theme | Unit | highlights | memberHasActivity", function () {
  test("true when there are posts or likes", function (assert) {
    assert.true(memberHasActivity({ post_count: 1, likes_received: 0 }));
    assert.true(memberHasActivity({ post_count: 0, likes_received: 4 }));
  });

  test("true for a member who only turned up", function (assert) {
    // The case that matters here: PRE's 30-day directory has 50 people and not
    // one post or like between them, only visits. Requiring a post left the
    // card permanently empty.
    assert.true(
      memberHasActivity({ post_count: 0, likes_received: 0, days_visited: 20 })
    );
  });

  test("false for a genuinely absent member or nothing", function (assert) {
    assert.false(
      memberHasActivity({ post_count: 0, likes_received: 0, days_visited: 0 })
    );
    assert.false(memberHasActivity(null));
    assert.false(memberHasActivity(undefined));
  });
});

acceptance(
  "Espublico Theme | Unit | highlights | loadLatestTaggedTopic",
  function (needs) {
    needs.user();
    // One category whose definition topic id (the trailing number of its
    // `topic_url`) is known, so the filter below can be shown to drop it.
    // `needs.site` replaces the preloaded category list, so this is the whole
    // set `definitionTopicIds()` sees here.
    needs.site({
      categories: [
        {
          id: 4242,
          name: "Podcast",
          slug: "podcast-cat",
          color: "0088CC",
          topic_count: 0,
          topic_url: "/t/acerca-de-la-categoria-podcast/424242",
        },
      ],
    });

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

    test("drops a category definition topic and returns the next", async function (assert) {
      assert.true(
        definitionTopicIds().has(424242),
        "the seeded category's definition topic is in the drop set"
      );

      const store = {
        findFiltered: async () => ({
          topics: [
            { id: 424242, fancy_title: "Acerca de la categoría Podcast" },
            { id: 900002, fancy_title: "Episodio real" },
          ],
        }),
      };

      const topic = await loadLatestTaggedTopic(store, "podcast");
      assert.strictEqual(
        topic.id,
        900002,
        "the pinned definition topic is skipped, not returned first"
      );
    });
  }
);

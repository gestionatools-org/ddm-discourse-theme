import { module, test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { definitionTopicIds } from "../../discourse/lib/category-topics";
import {
  excerptFromCooked,
  extractCoverImage,
  extractPdfUrl,
  extractVideoId,
  loadLatestTaggedTopic,
  memberHasActivity,
  rankTopMember,
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
  test("prefers the short-url attachment over the storage URL", function (assert) {
    assert.strictEqual(
      extractPdfUrl(NEWSLETTER_COOKED),
      "/uploads/short-url/8dccSWOMxhvIuYP1rQiiyh8KKmi.pdf",
      "even though the storage URL appears first in the post"
    );
  });

  test("matches an attachment anchor that carries no class", function (assert) {
    // Measured on PRE: /t/2177's attachment anchor has no class="attachment",
    // so the class cannot be the discriminator.
    const cooked = `<p><a href="/uploads/short-url/9BUfTFfwTe0o0jB5KhlxNhYazPo.pdf">Revista 12</a></p>`;
    assert.strictEqual(
      extractPdfUrl(cooked),
      "/uploads/short-url/9BUfTFfwTe0o0jB5KhlxNhYazPo.pdf"
    );
  });

  test("falls back to the storage URL when there is no short-url link", function (assert) {
    const cooked = `<p><a href="https://cdck.example.com/original/2X/3/398f.pdf">Revista</a></p>`;
    assert.strictEqual(
      extractPdfUrl(cooked),
      "https://cdck.example.com/original/2X/3/398f.pdf"
    );
  });

  test("ignores a query string or fragment when matching the extension", function (assert) {
    const cooked = `<p><a href="/uploads/short-url/abc.pdf?dl=1#page=3">Revista</a></p>`;
    assert.strictEqual(
      extractPdfUrl(cooked),
      "/uploads/short-url/abc.pdf?dl=1#page=3",
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

module("Espublico Theme | Unit | highlights | excerptFromCooked", function () {
  test("joins the post's top-level blocks into one line of text", function (assert) {
    assert.strictEqual(
      excerptFromCooked(NEWSLETTER_COOKED, 400),
      "Buenos días @Certificación Con el verano recién estrenado llega un nuevo número de nuestra revista. Revista 14",
      "the greeting is kept — a rule that skipped it would be one more thing to maintain"
    );
  });

  test("reads a paragraph inside a quote once, not twice", function (assert) {
    const cooked = `<blockquote><p>Citado.</p></blockquote><p>Propio.</p>`;
    assert.strictEqual(excerptFromCooked(cooked, 400), "Citado. Propio.");
  });

  test("truncates on a word boundary and appends an ellipsis", function (assert) {
    const cooked = `<p>uno dos tres cuatro cinco</p>`;
    assert.strictEqual(
      excerptFromCooked(cooked, 12),
      "uno dos tres…",
      "cuts at the space before the budget, not mid-word"
    );
  });

  test("strips punctuation stranded by the cut", function (assert) {
    const cooked = `<p>uno dos, tres cuatro</p>`;
    assert.strictEqual(excerptFromCooked(cooked, 9), "uno dos…");
  });

  test("returns the whole text when it fits", function (assert) {
    assert.strictEqual(
      excerptFromCooked(`<p>Corto.</p>`, 400),
      "Corto.",
      "no ellipsis"
    );
  });

  test("returns null for a post with no text", function (assert) {
    assert.strictEqual(excerptFromCooked(`<p>${EMOJI_IMG}</p>`, 400), null);
    assert.strictEqual(excerptFromCooked("", 400), null);
    assert.strictEqual(excerptFromCooked(null, 400), null);
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

  test("false for a zero-activity item or nothing", function (assert) {
    assert.false(
      memberHasActivity({ post_count: 0, likes_received: 0, days_visited: 20 })
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

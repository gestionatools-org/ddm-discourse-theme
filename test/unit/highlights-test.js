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
  }
);

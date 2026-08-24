import { module, test } from "qunit";
import {
  definitionTopicId,
  parseCategoryIds,
} from "../../javascripts/discourse/lib/category-topics";

// The two functions here are pure — no `Category`, no store, no app — so they
// are tested without booting one. Everything in `category-topics.js` that
// reaches for `Category.list()` is covered in
// `test/acceptance/category-topics-test.js` instead.

module(
  "Espublico Theme | Unit | category-topics | parseCategoryIds",
  function () {
    // Discourse hands `type: list` settings to JavaScript as a pipe-separated
    // string. Assuming an array here is what aborted the theme's whole JS bundle
    // once — the block's arg validation rejected the value at registration, and
    // seven core-feature examples failed rather than just the homepage ones.
    test("splits the pipe-separated string a list setting actually arrives as", function (assert) {
      assert.deepEqual(parseCategoryIds("73|85|14"), [73, 85, 14]);
    });

    test("reads a single id with no separator in it", function (assert) {
      assert.deepEqual(parseCategoryIds("73"), [73]);
    });

    test("returns an empty array for an unset setting", function (assert) {
      // "" would split to [""], and parseInt("") is NaN, so without the guard
      // the lane would try to resolve NaN as a category id.
      assert.deepEqual(parseCategoryIds(""), [], "empty string");
      assert.deepEqual(parseCategoryIds(null), [], "null");
      assert.deepEqual(parseCategoryIds(undefined), [], "undefined");
    });

    test("drops entries that are not numbers rather than passing on NaN", function (assert) {
      assert.deepEqual(parseCategoryIds("73|not-an-id|85"), [73, 85]);
    });

    test("drops a trailing separator without producing a NaN", function (assert) {
      assert.deepEqual(parseCategoryIds("73|85|"), [73, 85]);
    });
  }
);

module(
  "Espublico Theme | Unit | category-topics | definitionTopicId",
  function () {
    // `topic_id` is not serialized onto the preloaded site categories at all.
    // `topic_url` is, and it ends in the id — which is the only reason the
    // showcase grid can recognise a category definition topic and drop it.
    test("reads the id off the end of a category's topic_url", function (assert) {
      assert.strictEqual(
        definitionTopicId({
          topic_url:
            "/t/acerca-de-la-categoria-nuevos-usuarios-certificados-posters/2246",
        }),
        2246
      );
    });

    test("stops at a query string or a fragment", function (assert) {
      assert.strictEqual(
        definitionTopicId({
          topic_url: "/t/acerca-de-la-categoria/2246?u=alice",
        }),
        2246,
        "query string"
      );
      assert.strictEqual(
        definitionTopicId({
          topic_url: "/t/acerca-de-la-categoria/2246#post_2",
        }),
        2246,
        "fragment"
      );
    });

    test("is not fooled by digits inside the slug", function (assert) {
      // A slug like "campana-ideas-febrero-2025" puts digits in the path ahead of
      // the real id. They are not followed by a delimiter, so they must not match.
      assert.strictEqual(
        definitionTopicId({ topic_url: "/t/campana-ideas-febrero-2025/1904" }),
        1904
      );
    });

    test("returns null when there is no topic_url to read", function (assert) {
      assert.strictEqual(definitionTopicId({}), null, "category without one");
      assert.strictEqual(definitionTopicId(null), null, "no category at all");
      assert.strictEqual(
        definitionTopicId({ topic_url: "/t/no-id-here" }),
        null,
        "a url that ends in no id"
      );
    });
  }
);

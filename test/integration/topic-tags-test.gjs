import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import TopicFooterTags from "../../discourse/components/topic-footer-tags";
import TopicTagsIcon from "../../discourse/components/topic-tags-icon";

// Both components are rendered directly rather than through their outlets.
// `topic-category` and `topic-above-footer-buttons` belong to core's topic
// template, which needs a topic route and a loaded post stream; the
// registration itself is one line of `renderInOutlet` in each initializer and
// is what CI's system specs exercise.
//
// What no test here can reach: the `order` + `:has()` reordering in
// `tagging.scss` that puts the icon in front of the tag row, and the outlined
// chip itself. Those are cascade questions, and the theme's compiled sheet is
// not in the JS test bundle. They were measured on PRE instead, by inserting
// the rules into the theme's own stylesheet — see the commit message for the
// figures, and `CLAUDE.md` for why a `<style>` in `<head>` would not have been
// a faithful check.

// `renderTags` (core's `lib/render-tags.js`) reads exactly two things off the
// topic: `.tags`, and `.get(…)` — for `isPrivateMessage` always, and for
// `visibleListTags` only when `mode="list"` is passed. An object answering
// both is a complete double for that contract and keeps these tests off the
// store; the last test below then proves the real model shape works too.
//
// `visibleListTags` is deliberately given a *different* value from `tags`.
// That is the only way the "no `mode='list'`" decision in
// `topic-footer-tags.gjs` is testable at all: the two lists coincide unless
// `suppress_overlapping_tags_in_list` is on, so a double is what separates
// them without reaching for a site setting.
function topicDouble(tags, visibleListTags = []) {
  const topic = { tags, visibleListTags, get: (key) => topic[key] };
  return topic;
}

module("Espublico Theme | Integration | topic tags", function (hooks) {
  setupRenderingTest(hooks);

  test("the icon fronts a topic that has tags", async function (assert) {
    const args = { topic: topicDouble(["ideas-2025"]) };

    await render(<template><TopicTagsIcon @outletArgs={{args}} /></template>);

    assert.dom(".topic-tags-icon").exists();
    assert
      .dom(".topic-tags-icon .d-icon-tag")
      .exists("the tag glyph, not another");
  });

  // The guard the `:has()` selectors in `tagging.scss` depend on. If the icon
  // rendered an empty wrapper for an untagged topic, that wrapper would take an
  // `order` and collect the row's 0.5em `gap`, moving a topic that has no tags
  // at all. Measured on PRE: with the guard, such a row is pixel-identical to
  // core.
  test("the icon stays away from a topic with no tags", async function (assert) {
    const args = { topic: topicDouble([]) };

    await render(<template><TopicTagsIcon @outletArgs={{args}} /></template>);

    assert.dom(".topic-tags-icon").doesNotExist();
  });

  test("the icon stays away when the topic carries no tags field", async function (assert) {
    const args = { topic: topicDouble(undefined) };

    await render(<template><TopicTagsIcon @outletArgs={{args}} /></template>);

    assert.dom(".topic-tags-icon").doesNotExist();
  });

  // The `<ul>` core builds already carries `aria-label="{{tagging.tags}}"`, so
  // an icon exposed to a screen reader would only announce the same thing
  // twice.
  test("the icon is hidden from assistive technology", async function (assert) {
    const args = { topic: topicDouble(["ideas-2025"]) };

    await render(<template><TopicTagsIcon @outletArgs={{args}} /></template>);

    assert.dom(".topic-tags-icon").hasAttribute("aria-hidden", "true");
  });

  test("the foot of the topic repeats every tag", async function (assert) {
    const args = {
      model: topicDouble(["ideas", "ideas-2025", "poster-evf"]),
    };

    await render(<template><TopicFooterTags @outletArgs={{args}} /></template>);

    assert.dom(".topic-footer-tags").exists();
    assert
      .dom(".topic-footer-tags .discourse-tag")
      .exists({ count: 3 }, "all three, in one row");
    assert.dom('.topic-footer-tags [data-tag-name="poster-evf"]').exists();
    assert
      .dom(".topic-footer-tags .d-icon-tag")
      .exists("the same glyph as under the title");
  });

  test("the foot renders nothing for an untagged topic", async function (assert) {
    const args = { model: topicDouble([]) };

    await render(<template><TopicFooterTags @outletArgs={{args}} /></template>);

    assert.dom(".topic-footer-tags").doesNotExist("no empty row either");
  });

  test("the foot renders nothing when the topic carries no tags field", async function (assert) {
    const args = { model: topicDouble(undefined) };

    await render(<template><TopicFooterTags @outletArgs={{args}} /></template>);

    assert.dom(".topic-footer-tags").doesNotExist();
  });

  // The decision this pins: the foot shows the topic's full tag set, not the
  // trimmed set a listing shows. `visibleListTags` is empty here, so passing
  // `mode="list"` to the helper would render an empty row — which is exactly
  // what a future "make it consistent with the header" edit would do.
  test("the foot shows the full set, not a listing's trimmed set", async function (assert) {
    const args = { model: topicDouble(["ideas", "poster-evf"], []) };

    await render(<template><TopicFooterTags @outletArgs={{args}} /></template>);

    assert
      .dom(".topic-footer-tags .discourse-tag")
      .exists({ count: 2 }, "both, despite visibleListTags being empty");
  });

  // The double above satisfies the helper's contract but is not what production
  // hands the outlet. `renderTags` calls `topic.get(…)`, so a plain object
  // without it raises "topic.get is not a function" as an uncaught global error
  // that fails the run without naming a test — the same trap the homepage lanes
  // hit. This is the test that would catch it.
  test("the foot renders from a real Topic model", async function (assert) {
    const store = this.owner.lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 900001,
      fancy_title: "Un tema con etiquetas",
      tags: ["eventos"],
    });
    const args = { model: topic };

    await render(<template><TopicFooterTags @outletArgs={{args}} /></template>);

    assert.dom('.topic-footer-tags [data-tag-name="eventos"]').exists();
  });
});

import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import HighlightPodcastCard from "../../discourse/components/highlight-podcast-card";

// Components render directly — they are plain Glimmer components, not Blocks, so
// they do not need the `<BlockOutlet>` dance the block tests below use. Data
// arrives as args; the block owns the fetching.

module(
  "Espublico Theme | Integration | highlights | podcast card",
  function (hooks) {
    setupRenderingTest(hooks);

    const topic = {
      url: "/t/episodio-7/2597",
      fancy_title: "Episodio 7 &mdash; Contrataci&oacute;n con IA",
      image_url: null,
    };

    test("shows a play button that swaps the thumbnail for an embedded player", async function (assert) {
      await render(
        <template>
          <HighlightPodcastCard @topic={{topic}} @videoId="1qH2Ye8IJrE" />
        </template>
      );

      assert
        .dom(".highlight-podcast__play")
        .exists("a play button before pressing");
      assert.dom(".highlight-podcast__player").doesNotExist("no iframe yet");
      assert
        .dom(".highlight-podcast__play img")
        .hasAttribute(
          "src",
          "https://i.ytimg.com/vi/1qH2Ye8IJrE/hqdefault.jpg"
        );

      await click(".highlight-podcast__play");

      assert
        .dom(".highlight-podcast__player")
        .exists("the iframe after pressing");
      assert
        .dom(".highlight-podcast__player")
        .hasAttribute("src", /\/embed\/1qH2Ye8IJrE/, "embeds the right video");
      assert
        .dom(".highlight-podcast__play")
        .doesNotExist("play button is gone");
    });

    test("with no video, the thumbnail is a link to the topic and there is no play button", async function (assert) {
      await render(
        <template>
          <HighlightPodcastCard @topic={{topic}} @videoId={{null}} />
        </template>
      );

      assert.dom(".highlight-podcast__play").doesNotExist();
      assert
        .dom(".highlight-podcast__link")
        .hasAttribute("href", "/t/episodio-7/2597");
    });

    test("renders the title entities as characters, not markup", async function (assert) {
      await render(
        <template>
          <HighlightPodcastCard @topic={{topic}} @videoId="1qH2Ye8IJrE" />
        </template>
      );
      assert
        .dom(".highlight-card__title")
        .includesText("Episodio 7 — Contratación con IA");
    });
  }
);

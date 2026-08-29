import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import HighlightMemberCard from "../../discourse/components/highlight-member-card";
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

module(
  "Espublico Theme | Integration | highlights | member card",
  function (hooks) {
    setupRenderingTest(hooks);

    const member = {
      post_count: 40,
      likes_received: 96,
      days_visited: 12,
      user: {
        username: "msanz",
        name: "María Sanz",
        avatar_template: "/letter_avatar/msanz/{size}/1.png",
      },
    };

    test("shows the badge, the figures and a profile link", async function (assert) {
      await render(
        <template><HighlightMemberCard @member={{member}} /></template>
      );

      assert.dom(".highlight-member").includesText("Member of the month");
      assert.dom(".highlight-member__figures").includesText("40 posts");
      assert.dom(".highlight-member__figures").includesText("96 likes");
      assert.dom(".highlight-member__figures").includesText("12 active days");
      assert
        .dom(".highlight-card__cta")
        .hasAttribute("href", "/u/msanz/summary");
      assert
        .dom(".highlight-member__avatar")
        .hasAttribute("href", "/u/msanz/summary");
    });

    test("falls back to the username when the member has no display name", async function (assert) {
      const noName = { ...member, user: { ...member.user, name: null } };
      await render(
        <template><HighlightMemberCard @member={{noName}} /></template>
      );
      assert.dom(".highlight-card__title").hasText("msanz");
    });

    test("with no member, renders the take-part CTA instead", async function (assert) {
      await render(
        <template><HighlightMemberCard @member={{null}} /></template>
      );

      assert.dom(".highlight-member__empty").exists();
      assert
        .dom(".highlight-member__empty")
        .includesText("Post and take part this month");
      assert.dom(".highlight-card__cta").hasAttribute("href", "/new-topic");
      assert.dom(".highlight-member__figures").doesNotExist();
    });
  }
);

import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockHighlights from "../../discourse/blocks/block-highlights";
import HighlightMemberCard from "../../discourse/components/highlight-member-card";
import HighlightPodcastCard from "../../discourse/components/highlight-podcast-card";

// Components render directly — they are plain Glimmer components, not Blocks, so
// they do not need the `<BlockOutlet>` dance the block tests below use. Data
// arrives as args; the block owns the fetching.

function stubStore(owner, byFilter) {
  // byFilter: { "tag/podcast/l/latest": [topic, …], … }. A filter with no entry
  // resolves to an empty list.
  owner.unregister("service:store");
  owner.register(
    "service:store",
    {
      findFiltered: async (_type, { filter }) => ({
        topics: byFilter[filter] || [],
      }),
    },
    { instantiate: false }
  );
}

function renderHighlights(args) {
  withPluginApi((api) =>
    api.renderBlocks("main-outlet-blocks", [{ block: BlockHighlights, args }])
  );
  return render(
    <template><BlockOutlet @name="main-outlet-blocks" /></template>
  );
}

const DEFAULT_ARGS = {
  title: "homepage.highlights.title",
  podcastTag: "podcast",
  newsletterTag: "newsletter",
  newsTag: "nueva-version-gestiona",
  memberPeriod: "monthly",
};

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

module(
  "Espublico Theme | Integration | highlights | section",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders the heading and the newsletter and novedad cards", async function (assert) {
      stubStore(this.owner, {
        "tag/newsletter/l/latest": [
          {
            id: 900101,
            fancy_title: "Newsletter 14",
            url: "/t/nl-14/900101",
            excerpt: "Resumen de julio.",
            image_url: null,
          },
        ],
        "tag/nueva-version-gestiona/l/latest": [
          {
            id: 900102,
            fancy_title: "Gestiona V9.3",
            url: "/t/v93/900102",
            excerpt: "Firma en lote.",
            image_url: null,
          },
        ],
      });

      await renderHighlights(DEFAULT_ARGS);

      assert.dom(".block-highlights__title").hasText("Community highlights");
      assert
        .dom(".block-highlights__cell.--news .highlight-card__title")
        .includesText("Newsletter 14");
      assert
        .dom(".block-highlights__cell.--news .highlight-card__excerpt")
        .hasText("Resumen de julio.");
      assert
        .dom(".block-highlights__cell.--novedad .highlight-card__title")
        .includesText("Gestiona V9.3");
      // novedad is the compact variant — no excerpt
      assert
        .dom(".block-highlights__cell.--novedad .highlight-card__excerpt")
        .doesNotExist();
    });

    test("a content card with no topic shows the coming-soon placeholder", async function (assert) {
      stubStore(this.owner, {}); // every filter empty

      await renderHighlights(DEFAULT_ARGS);

      assert
        .dom(".block-highlights__cell.--news .highlight-card.--empty")
        .exists();
      assert.dom(".block-highlights__cell.--news").includesText("Coming soon");
    });

    test("a content card with a topic but no image shows the placeholder icon, not a broken img", async function (assert) {
      stubStore(this.owner, {
        "tag/newsletter/l/latest": [
          {
            id: 900103,
            fancy_title: "Sin imagen",
            url: "/t/x/900103",
            excerpt: "x",
            image_url: null,
          },
        ],
      });

      await renderHighlights(DEFAULT_ARGS);

      assert
        .dom(".block-highlights__cell.--news .highlight-card__media img")
        .doesNotExist();
      assert
        .dom(".block-highlights__cell.--news .highlight-card__placeholder")
        .exists();
    });

    test("the section does not render when all three tags are empty", async function (assert) {
      stubStore(this.owner, {});

      await renderHighlights({
        ...DEFAULT_ARGS,
        podcastTag: "",
        newsletterTag: "",
        newsTag: "",
      });

      assert.dom(".block-highlights").doesNotExist();
    });

    // Two separate tests, not one: a second `renderBlocks("main-outlet-blocks", …)`
    // inside one test body raises "already has a layout registered" — the reset is
    // between rendering tests, not within (see homepage-lanes-test.gjs).
    test("the grid modifier is --count-4 with all three tags set", async function (assert) {
      stubStore(this.owner, {});
      await renderHighlights(DEFAULT_ARGS);
      assert
        .dom(".block-highlights__grid.--count-4")
        .exists("podcast + newsletter + novedad + member");
    });

    test("the grid modifier drops to --count-3 when a content tag is empty", async function (assert) {
      stubStore(this.owner, {});
      await renderHighlights({ ...DEFAULT_ARGS, newsTag: "" });
      assert.dom(".block-highlights__grid.--count-3").exists();
      assert
        .dom(".block-highlights__cell.--novedad")
        .doesNotExist("no novedad cell");
    });
  }
);

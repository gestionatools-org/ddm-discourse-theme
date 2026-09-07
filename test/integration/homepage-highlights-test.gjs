import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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
        .hasAttribute(
          "src",
          "https://www.youtube.com/embed/1qH2Ye8IJrE?autoplay=1",
          "embeds the right video on www.youtube.com, not the -nocookie host"
        );
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

    test("below the thumbnail there is the heading, the title, the excerpt and the CTA", async function (assert) {
      await render(
        <template>
          <HighlightPodcastCard @topic={{topic}} @videoId="1qH2Ye8IJrE" />
        </template>
      );

      assert
        .dom(".highlight-podcast .highlight-card__label")
        .includesText("Podcast", "the heading the other three cards wear");
      assert
        .dom(".highlight-podcast .highlight-card__label .d-icon-podcast")
        .exists("with its icon");
      assert
        .dom(".highlight-podcast .highlight-card__body > *")
        .exists({ count: 4 }, "heading, title, excerpt and CTA, nothing else");
      assert
        .dom(".highlight-podcast .highlight-card__cta")
        .hasAttribute("href", "/t/episodio-7/2597");
      // The label's locale key stays in use as the player's accessible title.
      assert
        .dom(".highlight-podcast__play")
        .hasAttribute("aria-label", "Play the episode");
    });

    test("the excerpt renders the post's paragraphs", async function (assert) {
      const paragraphs = ["Primer párrafo.", "Segundo párrafo."];
      await render(
        <template>
          <HighlightPodcastCard
            @topic={{topic}}
            @videoId="1qH2Ye8IJrE"
            @paragraphs={{paragraphs}}
          />
        </template>
      );

      assert
        .dom(".highlight-podcast .highlight-card__excerpt p")
        .exists({ count: 2 });
      assert
        .dom(".highlight-podcast .highlight-card__excerpt")
        .includesText("Primer párrafo.");
    });

    test("the excerpt box is rendered even with no paragraphs", async function (assert) {
      // It is what absorbs the difference between this card and the taller
      // newsletter card beside it, so the geometry has to be the same either
      // way — an episode posted without copy still gets a card that fills its
      // row rather than one with a gap above the CTA.
      await render(
        <template>
          <HighlightPodcastCard @topic={{topic}} @videoId="1qH2Ye8IJrE" />
        </template>
      );

      assert.dom(".highlight-podcast .highlight-card__excerpt").exists();
      assert
        .dom(".highlight-podcast .highlight-card__excerpt p")
        .doesNotExist();
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
        <template>
          <HighlightMemberCard @member={{member}} @period="monthly" />
        </template>
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

    test("shows the user's title as their cargo, and nothing when they have none", async function (assert) {
      const titled = {
        ...member,
        user: { ...member.user, title: "Directora de Organización" },
      };
      await render(
        <template><HighlightMemberCard @member={{titled}} /></template>
      );
      assert
        .dom(".highlight-member__cargo")
        .hasText("Directora de Organización");
      // The figures stay: they are what justifies the badge.
      assert.dom(".highlight-member__figures").includesText("40 posts");

      await render(
        <template><HighlightMemberCard @member={{member}} /></template>
      );
      assert
        .dom(".highlight-member__cargo")
        .doesNotExist("no line at all for a member without a title");
    });

    test("the badge names the window the member actually won", async function (assert) {
      // The block widens the window when a narrower one has nobody, so the
      // badge must not keep claiming the month over the quarter's figures.
      await render(
        <template>
          <HighlightMemberCard @member={{member}} @period="quarterly" />
        </template>
      );
      assert.dom(".highlight-member").includesText("Member of the quarter");

      await render(
        <template>
          <HighlightMemberCard @member={{member}} @period="all" />
        </template>
      );
      assert.dom(".highlight-member").includesText("Community member");
    });

    test("an unrecognised window falls to the period-neutral badge", async function (assert) {
      await render(
        <template>
          <HighlightMemberCard @member={{member}} @period="fortnightly" />
        </template>
      );
      assert
        .dom(".highlight-member")
        .includesText("Community member", "not a missing-translation key");
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

    // Wiring `fetchMember` (Task 6) means every render of the section now hits
    // `/directory_items.json`. Core ships no default handler for it and an
    // unhandled request throws, so hand every section test an empty directory
    // by default; the member-cell tests below override this in their own body
    // (route-recognizer keeps the last registration for an identical path).
    hooks.beforeEach(function () {
      pretender.get("/directory_items.json", () =>
        response({ directory_items: [] })
      );
    });

    test("renders the heading and the newsletter and novedad cards", async function (assert) {
      // The newsletter and novedad cells both read their topic's first post, so
      // every test whose tags resolve to a topic has to answer those requests.
      pretender.get("/t/900101.json", () =>
        response({
          post_stream: { posts: [{ cooked: `<p>Resumen de julio.</p>` }] },
        })
      );
      pretender.get("/t/900102.json", () =>
        response({
          post_stream: {
            posts: [
              {
                cooked: `<p>Firma en lote.</p>`,
                username: "rargente",
                name: "Raul Argente",
                avatar_template: "/letter_avatar/rargente/{size}/1.png",
              },
            ],
          },
        })
      );
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
      assert
        .dom(".block-highlights__cell.--novedad .highlight-card__excerpt")
        .hasText("Firma en lote.", "the post's text, like the other cards");
      assert
        .dom(".block-highlights__cell.--novedad .highlight-card__byline")
        .includesText("Raul Argente", "who published the release note");
      // Order matters and is the point of the last two rounds on this card:
      // heading, then who wrote it, then the headline it belongs to.
      assert
        .dom(
          ".block-highlights__cell.--novedad .highlight-card__byline + .highlight-card__title"
        )
        .exists("the byline sits immediately above the title");
      assert
        .dom(".block-highlights__cell.--novedad .highlight-card__media")
        .doesNotExist("compact still means no media slot");
    });

    test("the novedad byline falls away when the post is unreachable", async function (assert) {
      pretender.get("/t/900102.json", () =>
        response(403, { errors: ["forbidden"] })
      );
      stubStore(this.owner, {
        "tag/nueva-version-gestiona/l/latest": [
          {
            id: 900102,
            fancy_title: "Gestiona V9.3",
            url: "/t/v93/900102",
            excerpt: "Recorte del listado.",
            image_url: null,
          },
        ],
      });

      await renderHighlights({
        ...DEFAULT_ARGS,
        podcastTag: "",
        newsletterTag: "",
      });

      assert
        .dom(".block-highlights__cell.--novedad .highlight-card__byline")
        .doesNotExist();
      assert
        .dom(".block-highlights__cell.--novedad .highlight-card__excerpt")
        .hasText("Recorte del listado.", "back to the topic list's excerpt");
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
      pretender.get("/t/900103.json", () =>
        response({
          post_stream: { posts: [{ cooked: `<p>Sin portada.</p>` }] },
        })
      );
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

    test("the podcast cell embeds the video from the topic's first post", async function (assert) {
      stubStore(this.owner, {
        "tag/podcast/l/latest": [
          {
            id: 2597,
            fancy_title: "Episodio 7",
            url: "/t/ep-7/2597",
            image_url: null,
          },
        ],
      });
      pretender.get("/t/2597.json", () =>
        response({
          post_stream: {
            posts: [
              {
                cooked: `<div class="lazy-video-container" data-video-id="1qH2Ye8IJrE"></div>`,
              },
            ],
          },
        })
      );

      await renderHighlights({
        ...DEFAULT_ARGS,
        newsletterTag: "",
        newsTag: "",
      });

      assert
        .dom(".block-highlights__cell.--podcast .highlight-podcast__play")
        .exists();
    });

    test("the podcast cell reads its copy out of the same post as the video", async function (assert) {
      stubStore(this.owner, {
        "tag/podcast/l/latest": [
          {
            id: 2597,
            fancy_title: "Episodio 7",
            url: "/t/ep-7/2597",
            image_url: null,
          },
        ],
      });
      pretender.get("/t/2597.json", () =>
        response({
          post_stream: {
            posts: [
              {
                cooked: `<p>Iniciamos semana hablando de tramitación.</p>
                  <div class="lazy-video-container" data-video-id="1qH2Ye8IJrE"><a href="#"><img src="/x.jpg"></a></div>
                  <p>Fátima llegó al Ayuntamiento en 2019.</p>`,
              },
            ],
          },
        })
      );

      await renderHighlights({
        ...DEFAULT_ARGS,
        newsletterTag: "",
        newsTag: "",
      });

      assert
        .dom(".block-highlights__cell.--podcast .highlight-podcast__play")
        .exists("the video still resolves");
      assert
        .dom(".block-highlights__cell.--podcast .highlight-card__excerpt p")
        .exists(
          { count: 2 },
          "the two paragraphs — the video container contributes none"
        );
    });

    test("the podcast cell degrades to a topic link when the first post has no video", async function (assert) {
      stubStore(this.owner, {
        "tag/podcast/l/latest": [
          {
            id: 2592,
            fancy_title: "Newsletter 14",
            url: "/t/nl-14/2592",
            image_url: null,
          },
        ],
      });
      pretender.get("/t/2592.json", () =>
        response({
          post_stream: { posts: [{ cooked: `<p>No video here.</p>` }] },
        })
      );

      await renderHighlights({
        ...DEFAULT_ARGS,
        newsletterTag: "",
        newsTag: "",
      });

      assert
        .dom(".block-highlights__cell.--podcast .highlight-podcast__play")
        .doesNotExist();
      assert
        .dom(".block-highlights__cell.--podcast .highlight-podcast__link")
        .exists();
    });

    // The newsletter cell, whose whole point is that the topic list carries
    // none of what the card shows: `image_url` is null on all 14 newsletters,
    // the magazine is a PDF attachment, and `topic.excerpt` stops at 220
    // characters. Everything below comes out of the first post instead.
    const NEWSLETTER_TOPIC = {
      id: 2592,
      fancy_title: "Newsletter 14",
      url: "/t/nl-14/2592",
      excerpt: "Recorte de 220 caracteres.",
      image_url: null,
    };

    function stubNewsletter(owner, cooked, status = 200) {
      stubStore(owner, { "tag/newsletter/l/latest": [NEWSLETTER_TOPIC] });
      pretender.get("/t/2592.json", () =>
        status === 200
          ? response({ post_stream: { posts: [{ cooked }] } })
          : response(status, { errors: ["forbidden"] })
      );
    }

    // Core's own resolver for `/uploads/short-url/…` placeholders. The cell has
    // to go through it because on this instance no same-origin `/uploads/**`
    // route serves anything — every one of them 404s, so the raw placeholder
    // would be a dead link.
    function stubLookupUrls(url) {
      pretender.post("/uploads/lookup-urls", () =>
        url === null
          ? response(403, { errors: ["forbidden"] })
          : response([
              {
                short_url: "upload://8dcc.pdf",
                url,
                short_path: "/uploads/short-url/8dcc.pdf",
              },
            ])
      );
    }

    const NEWSLETTER_ARGS = {
      ...DEFAULT_ARGS,
      podcastTag: "",
      newsTag: "",
    };

    test("the newsletter cell shows the cover and points the CTA at the storage URL", async function (assert) {
      // The shape of the five newest newsletters: the cover wrapped in an
      // anchor to the PDF on storage, then the short-url attachment link.
      stubNewsletter(
        this.owner,
        `<p>Con el verano recién estrenado llega un nuevo número.</p>
         <p><a href="https://cdck.example.com/original/2X/3/398f.pdf"><img src="//cdck.example.com/original/2X/d/d180.jpeg" alt="Revista 14"></a></p>
         <p><a class="attachment" href="/uploads/short-url/8dcc.pdf">Revista 14</a></p>`
      );

      await renderHighlights(NEWSLETTER_ARGS);

      assert
        .dom(".block-highlights__cell.--news .highlight-card__media img")
        .hasAttribute(
          "src",
          "//cdck.example.com/original/2X/d/d180.jpeg",
          "the cover, not the null image_url the topic list carries"
        );
      assert
        .dom(".block-highlights__cell.--news .highlight-card__placeholder")
        .doesNotExist("no placeholder icon once there is a cover");

      assert
        .dom(".block-highlights__cell.--news .highlight-card__cta")
        .hasAttribute(
          "href",
          "https://cdck.example.com/original/2X/3/398f.pdf",
          "the absolute URL, never the /uploads/short-url/ placeholder"
        );
      assert
        .dom(".block-highlights__cell.--news .highlight-card__cta")
        .hasAttribute("target", "_blank", "the PDF leaves the forum");

      assert
        .dom(".block-highlights__cell.--news .highlight-card__title a")
        .hasAttribute(
          "href",
          "/t/nl-14/2592",
          "the title still goes to the conversation"
        );
      assert
        .dom(".block-highlights__cell.--news .highlight-card__excerpt p")
        .exists(
          { count: 2 },
          "separate paragraphs, and the image-only block contributes none"
        );
      assert
        .dom(".block-highlights__cell.--news .highlight-card__excerpt")
        .includesText(
          "Con el verano recién estrenado llega un nuevo número.",
          "the post's own text, not the 220-character topic excerpt"
        );
    });

    test("a short-url-only PDF is resolved through core's lookup endpoint", async function (assert) {
      // 9 of the 14 newsletters are this shape: no absolute PDF link anywhere
      // in the post, only the placeholder — which 404s if rendered raw.
      stubNewsletter(
        this.owner,
        `<p>Un número antiguo.</p><p><a class="attachment" href="/uploads/short-url/8dcc.pdf">Revista 01</a></p>`
      );
      stubLookupUrls("//cdck.example.com/original/2X/9/9c1a.pdf");

      await renderHighlights(NEWSLETTER_ARGS);

      assert
        .dom(".block-highlights__cell.--news .highlight-card__cta")
        .hasAttribute(
          "href",
          "//cdck.example.com/original/2X/9/9c1a.pdf",
          "the resolved URL, not the placeholder that was in the post"
        );
    });

    test("an unresolvable short-url falls back to the topic rather than a dead link", async function (assert) {
      stubNewsletter(
        this.owner,
        `<p>Un número antiguo.</p><p><a class="attachment" href="/uploads/short-url/8dcc.pdf">Revista 01</a></p>`
      );
      stubLookupUrls(null); // the lookup itself fails

      await renderHighlights(NEWSLETTER_ARGS);

      assert
        .dom(".block-highlights__cell.--news .highlight-card__cta")
        .hasAttribute("href", "/t/nl-14/2592");
      assert
        .dom(".block-highlights__cell.--news .highlight-card__cta")
        .doesNotHaveAttribute(
          "target",
          "an internal link stays in the same tab"
        );
    });

    test("the newsletter CTA falls back to the topic when the post links no PDF", async function (assert) {
      stubNewsletter(
        this.owner,
        `<p>Un número sin adjunto.</p><p><img src="/uploads/cover.png"></p>`
      );

      await renderHighlights(NEWSLETTER_ARGS);

      assert
        .dom(".block-highlights__cell.--news .highlight-card__cta")
        .hasAttribute("href", "/t/nl-14/2592");
      assert
        .dom(".block-highlights__cell.--news .highlight-card__media img")
        .hasAttribute("src", "/uploads/cover.png", "the cover still resolves");
    });

    test("the newsletter cell falls back to the topic list when the post is unreachable", async function (assert) {
      stubNewsletter(this.owner, null, 403);

      await renderHighlights(NEWSLETTER_ARGS);

      assert
        .dom(".block-highlights__cell.--news .highlight-card__title")
        .includesText("Newsletter 14", "the card still renders");
      assert
        .dom(".block-highlights__cell.--news .highlight-card__excerpt")
        .hasText("Recorte de 220 caracteres.", "back to topic.excerpt");
      assert
        .dom(".block-highlights__cell.--news .highlight-card__cta")
        .hasAttribute("href", "/t/nl-14/2592", "back to the topic link");
      assert
        .dom(".block-highlights__cell.--news .highlight-card__placeholder")
        .exists("and back to the placeholder icon");
    });

    test("the member cell crowns the highest composite and shows the figures", async function (assert) {
      stubStore(this.owner, {});
      pretender.get("/directory_items.json", () =>
        response({
          directory_items: [
            {
              post_count: 2,
              likes_received: 1,
              days_visited: 3,
              user: {
                username: "a",
                name: "A",
                avatar_template: "/a/{size}.png",
              },
            },
            {
              post_count: 40,
              likes_received: 96,
              days_visited: 12,
              user: {
                username: "msanz",
                name: "María Sanz",
                avatar_template: "/m/{size}.png",
              },
            },
          ],
        })
      );

      await renderHighlights({
        ...DEFAULT_ARGS,
        podcastTag: "",
        newsletterTag: "",
        newsTag: "nueva-version-gestiona",
      });
      // (newsTag kept non-empty only so the section renders; its cell is a placeholder)

      assert
        .dom(".block-highlights__cell.--miembro .highlight-card__title")
        .hasText("María Sanz");
      assert
        .dom(".block-highlights__cell.--miembro .highlight-member__figures")
        .includesText("40 posts");
    });

    test("the member cell widens the window when the month has nobody", async function (assert) {
      // PRE's own shape, measured 2026-09-07: the 30-day directory returns
      // people but none with a post or a like, while the quarter has plenty.
      stubStore(this.owner, {});
      const asked = [];
      pretender.get("/directory_items.json", (request) => {
        asked.push(request.queryParams.period);
        if (request.queryParams.period === "monthly") {
          return response({
            directory_items: [
              {
                post_count: 0,
                likes_received: 0,
                days_visited: 23,
                user: {
                  username: "quiet",
                  name: "Q",
                  avatar_template: "/q.png",
                },
              },
            ],
          });
        }
        return response({
          directory_items: [
            {
              post_count: 36,
              likes_received: 34,
              days_visited: 48,
              user: {
                username: "jredondo",
                name: "Jorge Redondo",
                avatar_template: "/j.png",
              },
            },
          ],
        });
      });

      await renderHighlights({
        ...DEFAULT_ARGS,
        podcastTag: "",
        newsletterTag: "",
      });

      assert.deepEqual(
        asked,
        ["monthly", "quarterly"],
        "it stops at the first window that qualifies"
      );
      assert
        .dom(".block-highlights__cell.--miembro .highlight-card__title")
        .hasText("Jorge Redondo");
      assert
        .dom(".block-highlights__cell.--miembro .highlight-card__label")
        .includesText(
          "Member of the quarter",
          "the badge names the window, not the month"
        );
    });

    test("the member cell falls to the CTA when the directory is all zeros", async function (assert) {
      stubStore(this.owner, {});
      pretender.get("/directory_items.json", () =>
        response({
          directory_items: [
            {
              post_count: 0,
              likes_received: 0,
              days_visited: 9,
              user: {
                username: "z",
                name: "Z",
                avatar_template: "/z/{size}.png",
              },
            },
          ],
        })
      );

      await renderHighlights({
        ...DEFAULT_ARGS,
        podcastTag: "",
        newsletterTag: "",
      });

      assert
        .dom(".block-highlights__cell.--miembro .highlight-member__empty")
        .exists();
    });

    test("the member cell falls to the CTA when the directory request fails", async function (assert) {
      stubStore(this.owner, {});
      pretender.get("/directory_items.json", () =>
        response(403, { errors: ["forbidden"] })
      );

      await renderHighlights({
        ...DEFAULT_ARGS,
        podcastTag: "",
        newsletterTag: "",
      });

      assert
        .dom(".block-highlights__cell.--miembro .highlight-member__empty")
        .exists();
    });
  }
);

import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { eq, or } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import HighlightMemberCard from "../components/highlight-member-card";
import HighlightPodcastCard from "../components/highlight-podcast-card";
import {
  extractCoverImage,
  extractPdfUrl,
  extractVideoId,
  loadLatestTaggedTopic,
  memberHasActivity,
  paragraphsFromCooked,
  rankTopMember,
  uploadRefFromShortUrl,
  WEIGHTS,
} from "../lib/highlights";

// How much of its own post a card shows — the newsletter and the podcast, the
// two cards with room for prose. It is a theme-side dial precisely because the
// alternative — raising `topic_excerpt_maxlength`, which caps `topic.excerpt` at
// 220 — is a site setting that would lengthen every listing on the forum.
//
// It is deliberately more text than any card is tall. The excerpt box grows into
// whatever space its row leaves and clips the surplus behind a fade
// (`block-highlights.scss`), so an over-budget makes the text reach the bottom at
// every card height without a per-breakpoint line count to tune.
const CARD_EXCERPT_MAX = 900;

// A content card for the newsletter and novedad cells: an optional cover image
// (or a branded placeholder), a label, the topic title, an optional byline, the
// post's own text and a CTA. `fancy_title` is already cooked HTML — `trustHTML`,
// as everywhere else in these blocks.
//
// Both cells read `@paragraphs` from their post rather than from the topic list,
// and both fall back to `topic.excerpt` when the post is unreachable.
// `@image`/`@ctaHref` are the newsletter's alone; `@author` is the novedad's.
// `@ctaHref` leaving the forum (it points at the PDF on the upload store) is why
// the CTA opens in a new tab whenever it is set — DButton renders an `<a>` for
// `@href` and forwards `...attributes`.
const ContentCard = <template>
  <article class="highlight-card highlight-content --{{@variant}}">
    {{#unless (eq @variant "compact")}}
      {{! The compact novedad card has no image — the media slot would only
          carry a placeholder icon that the label already shows. }}
      <div class="highlight-card__media">
        {{#if (or @image @topic.image_url)}}
          <img src={{or @image @topic.image_url}} alt="" loading="lazy" />
        {{else}}
          <span class="highlight-card__placeholder">{{dIcon @icon}}</span>
        {{/if}}
      </div>
    {{/unless}}
    <div class="highlight-card__body">
      <div class="highlight-card__label">
        {{dIcon @icon}}
        {{i18n (themePrefix @label)}}
      </div>
      <h3 class="highlight-card__title">
        {{! The title always goes to the topic, even when the CTA does not: the
            conversation is where a reader replies, and the PDF is a dead end. }}
        <a href={{@topic.url}}>{{trustHTML @topic.fancy_title}}</a>
      </h3>
      <div class="highlight-card__excerpt">
        {{#if @paragraphs}}
          {{#each @paragraphs as |paragraph|}}
            <p>{{paragraph}}</p>
          {{/each}}
        {{else}}
          <p>{{@topic.excerpt}}</p>
        {{/if}}
      </div>
      {{! The foot: who wrote it, then the link. It is the foot rather than the
          CTA alone that is pushed to the bottom of the body, so the byline
          travels with the link instead of being left behind at the end of the
          text. The avatar is decorative beside a name that is already text, so
          it takes no alt. }}
      <div class="highlight-card__foot">
        {{#if @author}}
          <p class="highlight-card__byline">
            {{dAvatar @author imageSize="small"}}
            <span>{{or @author.name @author.username}}</span>
          </p>
        {{/if}}
        {{#if @ctaHref}}
          <DButton
            class="btn-flat highlight-card__cta"
            target="_blank"
            rel="noopener"
            @href={{@ctaHref}}
            @translatedLabel={{i18n (themePrefix @cta)}}
          />
        {{else}}
          <DButton
            class="btn-flat highlight-card__cta"
            @href={{@topic.url}}
            @translatedLabel={{i18n (themePrefix @cta)}}
          />
        {{/if}}
      </div>
    </div>
  </article>
</template>;

// Shown in a content cell whose tag is set but currently has no topic. It has
// no media slot, so it takes no variant — the body is centred the same way in
// every cell.
const Placeholder = <template>
  <article class="highlight-card highlight-content --empty">
    <div class="highlight-card__body">
      <span class="highlight-card__placeholder">{{dIcon @icon}}</span>
      <p>{{i18n (themePrefix "homepage.highlights.soon")}}</p>
    </div>
  </article>
</template>;

// While a cell's fetch is in flight. Same markup the events, latest and forum
// lanes give their own `<DAsyncContent>`; one copy for all four cells here.
const CellLoading = <template>
  <div class="block-highlights__loading"><div class="spinner" /></div>
</template>;

// Section 2 of the homepage: a bento of four cards. Each cell has its own
// `<DAsyncContent>` so the fetches load and fail independently — there is no
// combined fetch phase, which is why newsletter and podcast can (today) resolve
// to the same topic and the fix for that is tag hygiene, not code.
//
// The section renders only when at least one content tag is set. The member card
// is a companion — it never keeps the section alive on its own.
@block("theme:espublico:highlights", {
  description:
    "A bento of the community's podcast, newsletter, latest release and top member",
  args: {
    title: { type: "string" },
    podcastTag: { type: "string", default: "" },
    newsletterTag: { type: "string", default: "" },
    newsTag: { type: "string", default: "" },
    memberPeriod: { type: "string", default: "monthly" },
  },
})
export default class BlockHighlights extends Component {
  @service store;

  get active() {
    return Boolean(
      this.args.podcastTag || this.args.newsletterTag || this.args.newsTag
    );
  }

  // Podcast + newsletter + novedad, whichever have a tag set, plus the member
  // card, which is always present (it renders a CTA when nobody qualifies).
  get cellCount() {
    return (
      1 +
      (this.args.podcastTag ? 1 : 0) +
      (this.args.newsletterTag ? 1 : 0) +
      (this.args.newsTag ? 1 : 0)
    );
  }

  @bind
  async fetchNewsletter() {
    const topic = await loadLatestTaggedTopic(
      this.store,
      this.args.newsletterTag
    );
    if (!topic) {
      return null;
    }
    // The same second hop the podcast cell makes, for three things the topic
    // list does not carry. Measured on PRE 2026-09-07: all 14 newsletters have
    // `image_url: null` — the cover is an `<img>` inside the post, and the
    // magazine itself is a PDF attachment, so without this hop the card is a
    // placeholder icon over a 220-character excerpt with a link to the thread.
    let cooked = null;
    try {
      const full = await ajax(`/t/${topic.id}.json`);
      cooked = full?.post_stream?.posts?.[0]?.cooked ?? null;
    } catch {
      // no reachable first post: every field below is null and the card falls
      // back to what the topic list gave it
    }
    return {
      topic,
      image: extractCoverImage(cooked),
      pdfUrl: await this.resolveUploadUrl(extractPdfUrl(cooked)),
      paragraphs: paragraphsFromCooked(cooked, CARD_EXCERPT_MAX),
    };
  }

  // A `/uploads/short-url/…` href is a placeholder, not a location. Core's own
  // client resolves the ones it tagged with `data-orig-href`; a cooked
  // attachment anchor carries no such tag, so nothing resolves it and the raw
  // path reaches the browser — where, on this instance, every same-origin
  // `/uploads/**` route answers 404 (measured on PRE 2026-09-07; see
  // `extractPdfUrl`). Dropping it instead is not an option either: 9 of the 14
  // newsletters link the PDF only that way.
  //
  // So resolve it the way core does, through its own endpoint. Returning null
  // on failure is deliberate: the CTA then falls back to the topic, which is a
  // link that works, rather than one that is known to 404.
  async resolveUploadUrl(href) {
    const ref = uploadRefFromShortUrl(href);
    if (!ref) {
      return href;
    }
    try {
      const [upload] = await ajax("/uploads/lookup-urls", {
        type: "POST",
        data: { short_urls: [ref] },
      });
      return upload?.url ?? null;
    } catch {
      return null;
    }
  }

  @bind
  async fetchNews() {
    const topic = await loadLatestTaggedTopic(this.store, this.args.newsTag);
    if (!topic) {
      return null;
    }
    // The third cell to make this hop, and for the same reason as the other
    // two: the topic list carries neither the post's text nor who wrote it.
    // `posters` on the list item would name the author, but it is the *last*
    // poster as often as the first, and a release note is worth attributing to
    // whoever published it.
    let post = null;
    try {
      const full = await ajax(`/t/${topic.id}.json`);
      post = full?.post_stream?.posts?.[0] ?? null;
    } catch {
      // no reachable first post: no byline and no text, and the card falls back
      // to the topic list's own excerpt
    }
    return {
      topic,
      paragraphs: paragraphsFromCooked(post?.cooked, CARD_EXCERPT_MAX),
      author: post?.username
        ? {
            username: post.username,
            name: post.name,
            avatar_template: post.avatar_template,
          }
        : null,
    };
  }

  @bind
  async fetchPodcast() {
    const topic = await loadLatestTaggedTopic(this.store, this.args.podcastTag);
    if (!topic) {
      return null;
    }
    // Cheap second hop: the topic list carries no post bodies, and both the
    // video id and the copy live in the first post's cooked HTML. A removed or
    // access-controlled topic just means no inline player and no text.
    //
    // The video embed contributes no paragraph of its own — core's
    // `lazy-video-container` holds a thumbnail and no text, so it drops out of
    // `paragraphsFromCooked` on the same rule that drops the emoji runs.
    let cooked = null;
    try {
      const full = await ajax(`/t/${topic.id}.json`);
      cooked = full?.post_stream?.posts?.[0]?.cooked ?? null;
    } catch {
      // no reachable first post: the card falls back to a plain topic link
    }
    return {
      topic,
      videoId: extractVideoId(cooked),
      paragraphs: paragraphsFromCooked(cooked, CARD_EXCERPT_MAX),
    };
  }

  @bind
  async fetchMember() {
    // A directory that is switched off or unreachable is the same as nobody
    // qualifying: the card falls to its take-part nudge. Any `order` works —
    // rankTopMember re-ranks — so the directory's own default is fine.
    let member = null;
    try {
      const { directory_items } = await ajax(
        `/directory_items.json?period=${this.args.memberPeriod}&order=likes_received&limit=50`
      );
      const top = rankTopMember(directory_items, WEIGHTS);
      member = memberHasActivity(top) ? top : null;
    } catch {
      // directory switched off or unreachable: nobody qualifies, show the CTA
    }
    return { member };
  }

  <template>
    {{#if this.active}}
      <section class="block-highlights">
        <header class="block-highlights__header">
          {{! No icon: this heading takes the category-header treatment (a
              full-bleed band, Roboto Slab), and a category header carries
              none. }}
          <h2 class="block-highlights__title">
            {{i18n (themePrefix @title)}}
          </h2>
        </header>

        <div class="block-highlights__grid --count-{{this.cellCount}}">
          {{#if @newsletterTag}}
            <div class="block-highlights__cell --news">
              <DAsyncContent @asyncData={{this.fetchNewsletter}}>
                <:loading><CellLoading /></:loading>
                <:content as |data|>
                  <ContentCard
                    @topic={{data.topic}}
                    @image={{data.image}}
                    @paragraphs={{data.paragraphs}}
                    @ctaHref={{data.pdfUrl}}
                    @variant="tall"
                    @icon="envelope"
                    @label="homepage.highlights.newsletter.label"
                    @cta="homepage.highlights.newsletter.cta"
                  />
                </:content>
                <:empty>
                  <Placeholder @icon="envelope" />
                </:empty>
              </DAsyncContent>
            </div>
          {{/if}}

          {{#if @podcastTag}}
            <div class="block-highlights__cell --podcast">
              <DAsyncContent @asyncData={{this.fetchPodcast}}>
                <:loading><CellLoading /></:loading>
                <:content as |data|>
                  <HighlightPodcastCard
                    @topic={{data.topic}}
                    @videoId={{data.videoId}}
                    @paragraphs={{data.paragraphs}}
                  />
                </:content>
                <:empty>
                  <Placeholder @icon="podcast" />
                </:empty>
              </DAsyncContent>
            </div>
          {{/if}}

          {{#if @newsTag}}
            <div class="block-highlights__cell --novedad">
              <DAsyncContent @asyncData={{this.fetchNews}}>
                <:loading><CellLoading /></:loading>
                <:content as |data|>
                  <ContentCard
                    @topic={{data.topic}}
                    @paragraphs={{data.paragraphs}}
                    @author={{data.author}}
                    @variant="compact"
                    @icon="rocket"
                    @label="homepage.highlights.news.label"
                    @cta="homepage.highlights.news.cta"
                  />
                </:content>
                <:empty>
                  <Placeholder @icon="rocket" />
                </:empty>
              </DAsyncContent>
            </div>
          {{/if}}

          <div class="block-highlights__cell --miembro">
            <DAsyncContent @asyncData={{this.fetchMember}}>
              <:loading><CellLoading /></:loading>
              <:content as |data|>
                <HighlightMemberCard @member={{data.member}} />
              </:content>
            </DAsyncContent>
          </div>
        </div>
      </section>
    {{/if}}
  </template>
}

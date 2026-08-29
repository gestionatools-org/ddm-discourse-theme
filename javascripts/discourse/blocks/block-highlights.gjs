import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { eq } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import HighlightMemberCard from "../components/highlight-member-card";
import HighlightPodcastCard from "../components/highlight-podcast-card";
import {
  extractVideoId,
  loadLatestTaggedTopic,
  memberHasActivity,
  rankTopMember,
  WEIGHTS,
} from "../lib/highlights";

// A content card for the newsletter and novedad cells: an optional cover image
// (or a branded placeholder), a label, the topic title and a CTA. `fancy_title`
// is already cooked HTML — `trustHTML`, as everywhere else in these blocks. The
// excerpt shows only on the tall variant; `serialize_topic_excerpts` (about.json)
// is what serialises it.
const ContentCard = <template>
  <article class="highlight-card highlight-content --{{@variant}}">
    {{#unless (eq @variant "compact")}}
      {{! The compact novedad card has no image — the media slot would only
          carry a placeholder icon that the label already shows. }}
      <div class="highlight-card__media">
        {{#if @topic.image_url}}
          <img src={{@topic.image_url}} alt="" loading="lazy" />
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
        <a href={{@topic.url}}>{{trustHTML @topic.fancy_title}}</a>
      </h3>
      {{#if (eq @variant "tall")}}
        <p class="highlight-card__excerpt">{{@topic.excerpt}}</p>
      {{/if}}
      <DButton
        class="btn-flat highlight-card__cta"
        @href={{@topic.url}}
        @translatedLabel={{i18n (themePrefix @cta)}}
      />
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
  fetchNewsletter() {
    return loadLatestTaggedTopic(this.store, this.args.newsletterTag);
  }

  @bind
  fetchNews() {
    return loadLatestTaggedTopic(this.store, this.args.newsTag);
  }

  @bind
  async fetchPodcast() {
    const topic = await loadLatestTaggedTopic(this.store, this.args.podcastTag);
    if (!topic) {
      return null;
    }
    // Cheap second hop: the topic list carries no post bodies, and the video id
    // lives in the first post's cooked HTML. A removed or access-controlled
    // topic just means no inline player.
    let videoId = null;
    try {
      const full = await ajax(`/t/${topic.id}.json`);
      videoId = extractVideoId(full?.post_stream?.posts?.[0]?.cooked);
    } catch {
      // no reachable first post: the card falls back to a plain topic link
    }
    return { topic, videoId };
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
          <h2 class="block-highlights__title">
            {{dIcon "star"}}
            {{i18n (themePrefix @title)}}
          </h2>
        </header>

        <div class="block-highlights__grid --count-{{this.cellCount}}">
          {{#if @newsletterTag}}
            <div class="block-highlights__cell --news">
              <DAsyncContent @asyncData={{this.fetchNewsletter}}>
                <:loading><CellLoading /></:loading>
                <:content as |topic|>
                  <ContentCard
                    @topic={{topic}}
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
                <:content as |topic|>
                  <ContentCard
                    @topic={{topic}}
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

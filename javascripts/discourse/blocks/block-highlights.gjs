import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import { eq } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { loadLatestTaggedTopic } from "../lib/highlights";

// A content card for the newsletter and novedad cells: an optional cover image
// (or a branded placeholder), a label, the topic title and a CTA. `fancy_title`
// is already cooked HTML — `trustHTML`, as everywhere else in these blocks. The
// excerpt shows only on the tall variant; `serialize_topic_excerpts` (about.json)
// is what serialises it.
const ContentCard = <template>
  <article class="highlight-card highlight-content --{{@variant}}">
    <div class="highlight-card__media">
      {{#if @topic.image_url}}
        <img src={{@topic.image_url}} alt="" loading="lazy" />
      {{else}}
        <span class="highlight-card__placeholder">{{dIcon @icon}}</span>
      {{/if}}
    </div>
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

// Shown in a content cell whose tag is set but currently has no topic.
const Placeholder = <template>
  <article class="highlight-card highlight-content --{{@variant}} --empty">
    <div class="highlight-card__body">
      <span class="highlight-card__placeholder">{{dIcon @icon}}</span>
      <p>{{i18n (themePrefix "homepage.highlights.soon")}}</p>
    </div>
  </article>
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
                  <Placeholder @variant="tall" @icon="envelope" />
                </:empty>
              </DAsyncContent>
            </div>
          {{/if}}

          {{#if @newsTag}}
            <div class="block-highlights__cell --novedad">
              <DAsyncContent @asyncData={{this.fetchNews}}>
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
                  <Placeholder @variant="compact" @icon="rocket" />
                </:empty>
              </DAsyncContent>
            </div>
          {{/if}}

          {{! podcast cell and the always-present member cell are wired in Task 6,
              between the newsletter cell and the novedad cell / after novedad }}
        </div>
      </section>
    {{/if}}
  </template>
}

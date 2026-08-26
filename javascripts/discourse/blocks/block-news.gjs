import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import { emojiUnescape } from "discourse/lib/text";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { loadCategoryTopics } from "../lib/category-topics";

@block("theme:espublico:news", {
  description: "Latest announcements, shown with excerpts",
  args: {
    title: { type: "string" },
    linkText: { type: "string" },
    linkUrl: { type: "string" },
    // Not required any more, so the lane can be registered with no category at
    // all. Still consumed below: making it optional is what lets the site-wide
    // test run, not what makes it pass.
    categoryId: { type: "number" },
    count: { type: "number", default: 4 },
  },
})
export default class BlockNews extends Component {
  @service store;

  @bind
  async fetchTopics() {
    return await loadCategoryTopics(
      this.store,
      this.args.categoryId,
      this.args.count
    );
  }

  <template>
    <section class="block-news">
      <header class="block-news__header">
        <h2 class="block-news__title">
          {{dIcon "newspaper"}}
          {{i18n (themePrefix @title)}}
        </h2>
        {{#if @linkUrl}}
          <DButton
            class="btn-flat block-news__link"
            @href={{@linkUrl}}
            @translatedLabel={{i18n (themePrefix @linkText)}}
          />
        {{/if}}
      </header>

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="block-news__loading"><div class="spinner" /></div>
        </:loading>

        <:empty>
          <p class="block-news__empty">{{i18n
              (themePrefix "homepage.news.empty")
            }}</p>
        </:empty>

        <:content as |topics|>
          <ul class="block-news__list">
            {{#each topics as |topic|}}
              <li class="block-news__item">
                <a class="block-news__item-link" href={{topic.url}}>
                  <h3 class="block-news__item-title">
                    {{! `fancy_title` is already HTML. dReplaceEmoji escapes its input
                        before substituting, so passing it through here double-encodes and
                        renders "&rsquo;" as literal text. Core renders it raw too. }}
                    {{trustHTML topic.fancy_title}}
                  </h3>
                  {{#if topic.excerpt}}
                    <p class="block-news__item-excerpt">
                      {{! An excerpt is HTML-encoded text with the tags
                          stripped, and Discourse's ExcerptParser turns the
                          emoji images back into their `:shortcode:` — so
                          without this, one news excerpt in four printed
                          ":automobile:" as words.

                          emojiUnescape, not the dReplaceEmoji used elsewhere:
                          that one escapes its input first, which is right for
                          plain text like a category name but would re-encode
                          the entities this string already carries — the same
                          double-encoding that made titles read "&rsquo;". }}
                      {{trustHTML (emojiUnescape topic.excerpt)}}
                    </p>
                  {{/if}}
                </a>
              </li>
            {{/each}}
          </ul>
        </:content>
      </DAsyncContent>
    </section>
  </template>
}

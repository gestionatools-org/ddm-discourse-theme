import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import { loadCategoryTopics } from "../lib/category-topics";

@block("theme:espublico:forum", {
  description: "Recent discussion, with reply counts as the primary signal",
  args: {
    title: { type: "string" },
    linkText: { type: "string" },
    linkUrl: { type: "string" },
    categoryId: { type: "number", required: true },
    count: { type: "number", default: 6 },
  },
})
export default class BlockForum extends Component {
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
    <section class="block-forum">
      <header class="block-forum__header">
        <h2 class="block-forum__title">
          {{dIcon "far-comments"}}
          {{i18n (themePrefix @title)}}
        </h2>
        {{#if @linkUrl}}
          <DButton
            class="btn-flat block-forum__link"
            @href={{@linkUrl}}
            @translatedLabel={{i18n (themePrefix @linkText)}}
          />
        {{/if}}
      </header>

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="block-forum__loading"><div class="spinner" /></div>
        </:loading>

        <:empty>
          <p class="block-forum__empty">{{i18n
              (themePrefix "homepage.forum.empty")
            }}</p>
        </:empty>

        <:content as |topics|>
          <ul class="block-forum__list">
            {{#each topics as |topic|}}
              <li class="block-forum__item">
                <a class="block-forum__item-link" href={{topic.url}}>
                  <span class="block-forum__item-title">
                    {{trustHTML (dReplaceEmoji topic.fancy_title)}}
                  </span>
                </a>
                {{! Reply count is this lane's reason to exist: these threads
                    average 4.5 replies, so the number is the proof of life. }}
                <span
                  class="block-forum__item-replies"
                  aria-label={{i18n
                    (themePrefix "homepage.forum.replies")
                    count=topic.reply_count
                  }}
                >
                  {{dIcon "reply"}}
                  <span aria-hidden="true">{{topic.reply_count}}</span>
                </span>
              </li>
            {{/each}}
          </ul>
        </:content>
      </DAsyncContent>
    </section>
  </template>
}

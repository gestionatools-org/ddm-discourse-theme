import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import { loadCategoryTopics } from "../lib/category-topics";

@block("theme:espublico:events", {
  description: "Compact, date-forward listing of the events category",
  args: {
    title: { type: "string" },
    linkText: { type: "string" },
    linkUrl: { type: "string" },
    categoryId: { type: "number", required: true },
    count: { type: "number", default: 4 },
  },
})
export default class BlockEvents extends Component {
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
    <section class="block-events">
      <header class="block-events__header">
        <h2 class="block-events__title">
          {{dIcon "calendar-days"}}
          {{i18n (themePrefix @title)}}
        </h2>
      </header>

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="block-events__loading"><div class="spinner" /></div>
        </:loading>

        <:empty>
          <p class="block-events__empty">{{i18n
              (themePrefix "homepage.events.empty")
            }}</p>
        </:empty>

        <:content as |topics|>
          <ul class="block-events__list">
            {{#each topics as |topic|}}
              <li class="block-events__item">
                <a class="block-events__item-link" href={{topic.url}}>
                  {{! `calendar_enabled` is off on this site, so no real event
                      date is serialized. This is the topic's own date, which
                      is honest but is not a start time. }}
                  <span class="block-events__item-date">
                    {{dFormatDate topic.created_at format="tiny"}}
                  </span>
                  <span class="block-events__item-title">
                    {{trustHTML (dReplaceEmoji topic.fancy_title)}}
                  </span>
                </a>
              </li>
            {{/each}}
          </ul>
        </:content>
      </DAsyncContent>

      {{#if @linkUrl}}
        <footer class="block-events__footer">
          <DButton
            class="btn-flat block-events__link"
            @href={{@linkUrl}}
            @translatedLabel={{i18n (themePrefix @linkText)}}
          />
        </footer>
      {{/if}}
    </section>
  </template>
}

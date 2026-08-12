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

/**
 * Format a real event start date.
 *
 * Core's date helpers are built for the past and mislead on future dates:
 * `format="medium"` renders anything ahead of now as "now" (`relativeAgeMedium`
 * compares `now - date` against a one-minute threshold, and a negative distance
 * clears it), while `format="tiny"` drops the sign, so an event three days out
 * reads exactly like a topic bumped three days ago. Event dates are therefore
 * absolute; the topic-date fallback keeps the relative helper, which is what it
 * was built for.
 *
 * The locale comes from `<html lang>` so it follows the Discourse UI rather
 * than the browser, which can differ.
 */
function formatEventStart(value) {
  const date = new Date(value);
  const sameYear = date.getFullYear() === new Date().getFullYear();

  return new Intl.DateTimeFormat(document.documentElement.lang || undefined, {
    day: "numeric",
    month: "short",
    year: sameYear ? undefined : "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

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
                  {{! `event_starts_at` only reaches the topic list for topics
                      carrying an `[event]` block, and only while the calendar
                      plugin is enabled. The category holds both kinds, so the
                      lane shows a real start time where there is one and falls
                      back to the topic's own date everywhere else. }}
                  {{#if topic.event_starts_at}}
                    <time
                      class="block-events__item-date --scheduled"
                      datetime={{topic.event_starts_at}}
                    >
                      {{formatEventStart topic.event_starts_at}}
                    </time>
                  {{else}}
                    <time
                      class="block-events__item-date"
                      datetime={{topic.created_at}}
                    >
                      {{dFormatDate topic.created_at format="tiny"}}
                    </time>
                  {{/if}}
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

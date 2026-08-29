import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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

// One row, used by both groups. The mixed date precision is deliberate and
// carries meaning: a real event brings a day and a time, a write-up of one
// brings only a month. That difference is what separates a date you can still
// act on from a record of one that has passed.
const EventItem = <template>
  <li class="block-events__item">
    <a class="block-events__item-link" href={{@topic.url}}>
      {{! `event_starts_at` only reaches the topic list for topics carrying an
          `[event]` block, and only while the calendar plugin is enabled. The
          category holds both kinds, so the lane shows a real start time where
          there is one and falls back to the topic's own date everywhere
          else. }}
      {{#if @topic.event_starts_at}}
        <time
          class="block-events__item-date --scheduled"
          datetime={{@topic.event_starts_at}}
        >
          {{formatEventStart @topic.event_starts_at}}
        </time>
      {{else}}
        <time class="block-events__item-date" datetime={{@topic.created_at}}>
          {{dFormatDate @topic.created_at format="tiny"}}
        </time>
      {{/if}}
      <span class="block-events__item-title">
        {{! `fancy_title` is already HTML. dReplaceEmoji escapes its input
            before substituting, so passing it through here double-encodes and
            renders "&rsquo;" as literal text. Core renders it raw too. }}
        {{trustHTML @topic.fancy_title}}
      </span>
    </a>
  </li>
</template>;

/**
 * The community's events, upcoming and past.
 *
 * The lane is a record as much as an announcement: write-ups of past meetups
 * belong here alongside the next date. What must never happen is the next date
 * being buried by them.
 *
 * That was the live behaviour until v0.16.0. Category 59 carries
 * `sort_topics_by_event_start_date`, but the listing it serves is *exactly*
 * `bumped_at` descending — verified against the instance — so the setting
 * changes nothing here. The one upcoming event led the lane only because it
 * happened to be the most recently bumped topic. Four write-ups later it would
 * have dropped off a four-row lane entirely.
 *
 * So the split is done client-side and the groups are labelled. Upcoming
 * events are sorted soonest-first, since the nearest date is the one a reader
 * can still act on; everything else keeps recency order.
 */
@block("theme:espublico:events", {
  description: "Community events, upcoming first, then past",
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
    // Unsliced on purpose: the split has to see the whole page, or an upcoming
    // event sitting below the cut would be discarded before it could be
    // promoted — which is the bug this block exists to avoid.
    const topics = await loadCategoryTopics(
      this.store,
      this.args.categoryId,
      undefined
    );

    if (!topics?.length) {
      return null;
    }

    const now = Date.now();
    const upcoming = topics
      .filter(
        (topic) =>
          topic.event_starts_at &&
          new Date(topic.event_starts_at).getTime() >= now
      )
      .sort(
        (a, b) => new Date(a.event_starts_at) - new Date(b.event_starts_at)
      );

    const promoted = new Set(upcoming.map((topic) => topic.id));
    const past = topics.filter((topic) => !promoted.has(topic.id));

    // Upcoming events take the lane's budget first. If they ever fill it the
    // past group disappears, which is the right way round: a reader cannot act
    // on what already happened.
    const limit = this.args.count;
    const shownUpcoming = upcoming.slice(0, limit);

    return {
      upcoming: shownUpcoming,
      past: past.slice(0, Math.max(0, limit - shownUpcoming.length)),
    };
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

        <:content as |groups|>
          {{#if groups.upcoming.length}}
            <div class="block-events__group">
              <h3 class="block-events__group-title">
                {{i18n (themePrefix "homepage.events.upcoming")}}
              </h3>
              <ul class="block-events__list">
                {{#each groups.upcoming as |topic|}}
                  <EventItem @topic={{topic}} />
                {{/each}}
              </ul>
            </div>
          {{/if}}

          {{#if groups.past.length}}
            <div class="block-events__group">
              <h3 class="block-events__group-title">
                {{i18n (themePrefix "homepage.events.past")}}
              </h3>
              <ul class="block-events__list">
                {{#each groups.past as |topic|}}
                  <EventItem @topic={{topic}} />
                {{/each}}
              </ul>
            </div>
          {{/if}}
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

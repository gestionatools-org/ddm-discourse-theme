import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { loadCategoryTopics } from "../lib/category-topics";

/**
 * Split a date into the two parts the chip renders.
 *
 * Core's date helpers are no use here. `dFormatDate` has no format that yields
 * the month and the day separately, and its relative formats mislead on future
 * dates anyway: `format="medium"` renders anything ahead of now as "now"
 * (`relativeAgeMedium` compares `now - date` against a one-minute threshold,
 * and a negative distance clears it), while `format="tiny"` drops the sign, so
 * an event three days out reads exactly like a topic bumped three days ago.
 *
 * Every row carries a chip, and the date behind it is the event's start where
 * the topic has one and the topic's own date everywhere else — on this
 * instance only one topic in the category holds a real `event_starts_at`, so a
 * chip reserved for those would leave the lane ragged. What keeps the two
 * honest is the `--scheduled` modifier the template adds, not the chip itself.
 *
 * The locale comes from `<html lang>` so it follows the Discourse UI rather
 * than the browser, which can differ.
 */
function dateChip(topic) {
  const date = new Date(topic.event_starts_at || topic.created_at);
  const locale = document.documentElement.lang || undefined;
  const part = (options) =>
    new Intl.DateTimeFormat(locale, options).format(date);

  return {
    month: part({ month: "short" }),
    day: part({ day: "numeric" }),
    iso: date.toISOString(),
    when: eventWhen(topic, locale),
  };
}

const DAY_PARTS = { day: "numeric", month: "long", year: "numeric" };
const TIME_PARTS = { hour: "2-digit", minute: "2-digit" };

/**
 * The grey line under the title: when the thing happens, or when the write-up
 * was posted.
 *
 * Three shapes, and which one a row gets is decided by the data rather than by
 * the group it sits in:
 *
 *   a real event spanning days  ->  "12–15 de octubre de 2026"
 *   a real event on one day     ->  "5 de noviembre de 2026, 10:00–18:00"
 *   no `[event]` at all         ->  "14 de julio de 2026"
 *
 * `Intl.formatRange` builds the first two, which is why neither needs a locale
 * string of its own: it collapses the shared parts per locale — English gets
 * "October 12 – 15, 2026", Spanish "12–15 de octubre de 2026" — and a
 * hand-rolled "x – y" could not. Nothing here reaches `locales/`.
 *
 * **Only one topic in category 59 carries an `[event]` block**, so in practice
 * the third shape is almost every row and the first has never rendered on the
 * instance at all. The multi-day branch is guarded by tests for exactly that
 * reason — there is no fixture on PRE that would exercise it.
 *
 * Times are rendered in the reader's own timezone, not the event's: the topic
 * list serializes `event_starts_at` as UTC and carries no timezone field, and
 * a local time is the one a reader can act on.
 */
function eventWhen(topic, locale) {
  const format = (options) => new Intl.DateTimeFormat(locale, options);

  if (!topic.event_starts_at) {
    return format(DAY_PARTS).format(new Date(topic.created_at));
  }

  const start = new Date(topic.event_starts_at);
  const end = topic.event_ends_at ? new Date(topic.event_ends_at) : null;

  if (!end) {
    return format({ ...DAY_PARTS, ...TIME_PARTS }).format(start);
  }

  // `toDateString` compares in the reader's timezone, which is the one the
  // row renders in — an event that ends at 00:30 UTC is still the same
  // evening in Madrid, and must not sprout a second day.
  const spansDays = start.toDateString() !== end.toDateString();

  return spansDays
    ? format(DAY_PARTS).formatRange(start, end)
    : format({ ...DAY_PARTS, ...TIME_PARTS }).formatRange(start, end);
}

// One row, used by both groups: a calendar chip, then a column holding the
// title over the date. Modelled on the `upcoming-events-list` widget at
// devcommunity.amd.com — measured there, not guessed: the chip is a 42px
// square, the content column is top-aligned with it rather than centred, the
// name is solid black at body size, and the line under it runs at 12px in
// grey.
//
// Two deliberate departures from that reference, both because the data differs
// from AMD's. Its widget lists only real events, so every row there has a time
// or a range; ours is a record as much as an announcement, so most rows fall
// back to the day the write-up was posted. And the title keeps `font-weight:
// 700`, where AMD's runs at 400 — the ideas lane directly below shares this
// panel and sets its titles bold, and one column of bold titles over another
// of regular ones reads as two tiers rather than one list.
const EventItem = <template>
  <li class="block-events__item">
    <a class="block-events__item-link" href={{@topic.url}}>
      {{#let (dateChip @topic) as |chip|}}
        {{! `event_starts_at` only reaches the topic list for topics carrying
            an `[event]` block, and only while the calendar plugin is enabled.
            The category holds both kinds, so its presence — not the chip — is
            what marks a date the reader can still act on. }}
        <time
          class="block-events__item-date
            {{if @topic.event_starts_at '--scheduled'}}"
          datetime={{chip.iso}}
        >
          <span class="block-events__item-date-month">{{chip.month}}</span>
          <span class="block-events__item-date-day">{{chip.day}}</span>
        </time>
        <span class="block-events__item-content">
          <span class="block-events__item-title">
            {{! `fancy_title` is already HTML. dReplaceEmoji escapes its input
                before substituting, so passing it through here double-encodes
                and renders "&rsquo;" as literal text. Core renders it raw
                too. }}
            {{trustHTML @topic.fancy_title}}
          </span>
          <span class="block-events__item-when">{{chip.when}}</span>
        </span>
      {{/let}}
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

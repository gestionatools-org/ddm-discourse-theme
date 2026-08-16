import Component from "@glimmer/component";
import { service } from "@ember/service";
import I18n, { i18n } from "discourse-i18n";

// The band carries two different kinds of number, and mixing them was the
// original mistake. `users_count` is a lifetime total; the other three are
// 30-day windows. Until v0.13.0 each figure carried its own period suffix —
// "79 mensajes este mes", "54 me gusta este mes" — which repeated the phrase
// and, worse, left `active_users_30_days` labelled as a bare "usuarios
// activos". Next to two figures that said "este mes", that reads as an
// all-time count, which is the opposite of what it measures.
//
// So the total stands alone and the three windows sit behind one shared
// "Este mes:" lead-in. The period is stated once, and it now governs the
// active-users figure too.
const TOTAL = { key: "topbar.stats.members", stat: "users_count" };

// `topics_30_days` was here until v0.12.0 and is deliberately gone. It read 9
// against 114 active members, which invites the reader to do the division and
// conclude nobody writes. It also measures the wrong thing: this community
// lives in replies, not in new threads — category 5 averages 1.7 and 4.5
// replies per topic, category 78 reaches 5.7, and category 73's whole tree has
// never received one. `posts_30_days` counts the replies as well as the
// openings, so it measures participation rather than initiative.
//
// Note the two are not filtered alike: `topics` counted `Topic.listable_topics`
// while `posts` is a bare `Post.where(created_at > …)`, so it includes private
// messages and restricted categories. Hence the label "messages" — "replies"
// would be a specific claim this number cannot support.
//
// Active users leads the group on purpose. `secondary` marks the two that give
// up their space below lg, and putting the survivor first means the phone
// renders "Este mes: 113 usuarios activos" as one contiguous run rather than
// leaving the lead-in stranded ahead of a gap. Size and reach are what a
// reader keeps; volume and appreciation are what they can do without.
const PERIOD = [
  { key: "topbar.stats.active", stat: "active_users_30_days" },
  { key: "topbar.stats.posts", stat: "posts_30_days", secondary: true },
  { key: "topbar.stats.likes", stat: "likes_30_days", secondary: true },
];

// A key core stops serializing degrades to one missing figure rather than to
// "NaN miembros".
function buildFigures(definitions, stats) {
  return definitions
    .map(({ key, stat, secondary }) => ({ key, secondary, count: stats[stat] }))
    .filter(({ count }) => Number.isFinite(count))
    .map((figure) => ({
      ...figure,
      // I18n.toNumber, not core's number() from discourse/lib/formatter: that
      // one abbreviates everything past 999, so a users_count of 1240 would
      // render "1.2k". Core wants that in narrow topic-list cells. The band
      // has room, and this is the one lifetime total on display.
      value: I18n.toNumber(figure.count, { precision: 0 }),
    }));
}

export default class TopbarStats extends Component {
  @service siteStats;

  constructor() {
    super(...arguments);
    this.siteStats.load();
  }

  get total() {
    const stats = this.siteStats.stats;
    return stats ? (buildFigures([TOTAL], stats)[0] ?? null) : null;
  }

  get period() {
    const stats = this.siteStats.stats;

    if (!stats) {
      return null;
    }

    // An empty group would otherwise render the "Este mes:" lead-in with
    // nothing behind it.
    const figures = buildFigures(PERIOD, stats);
    return figures.length ? figures : null;
  }

  get hasFigures() {
    return Boolean(this.total || this.period);
  }

  <template>
    {{#if this.hasFigures}}
      <div
        class="topbar-stats"
        role="group"
        aria-label={{i18n (themePrefix "topbar.stats.aria_label")}}
      >
        {{#if this.total}}
          <div class="topbar-stats__figure --total">
            <span class="topbar-stats__value">{{this.total.value}}</span>
            <span class="topbar-stats__label">
              {{i18n (themePrefix this.total.key) count=this.total.count}}
            </span>
          </div>
        {{/if}}

        {{#if this.period}}
          <div class="topbar-stats__period">
            <span class="topbar-stats__period-label">
              {{i18n (themePrefix "topbar.stats.period_label")}}
            </span>
            {{! `role="list"` is required, not decorative: `list-style: none` in
                topbar.scss strips the implicit list role in WebKit, and an
                aria-label on a role-less generic element is ignored — without
                this the group name is silently lost to Safari/VoiceOver. }}
            <ul
              class="topbar-stats__list"
              role="list"
              aria-label={{i18n (themePrefix "topbar.stats.period_aria_label")}}
            >
              {{#each this.period as |figure|}}
                <li
                  class="topbar-stats__figure
                    {{if figure.secondary '--secondary'}}"
                >
                  <span class="topbar-stats__value">{{figure.value}}</span>
                  <span class="topbar-stats__label">
                    {{i18n (themePrefix figure.key) count=figure.count}}
                  </span>
                </li>
              {{/each}}
            </ul>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}

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
// Two totals, not one. `users_count` says how big the community is;
// `topics_count` says how much is in it, which for a certification programme's
// forum is the question a member actually arrives with — "¿está aquí mi
// problema?" rather than "¿cuánta gente hay?". It is also the honest number:
// 1 297 on PROD against the 1 261 the subject-layer crawl walked, so it counts
// the listable topics a reader can reach, not an inflated internal total.
const TOTALS = [
  { key: "topbar.stats.members", stat: "users_count" },
  { key: "topbar.stats.topics", stat: "topics_count", secondary: true },
];

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
// `likes_30_days` was here until v0.41.0 and is deliberately gone. Appreciation
// is the weakest thing this band can report about a support forum — it says
// nothing about whether the place will answer your question — and it was
// already one of the two figures that stood down on a phone, so it was earning
// its keep on wide viewports alone.
//
// Beware of judging it from PRE. PRE is a restored snapshot nobody browses, so
// its 30-day windows decay to nothing: measured 2026-09-07, PRE reported
// `likes_30_days` 0 and `active_users_30_days` 3 while PROD reported 154 and
// 168 the same minute. The band is not broken on PRE, PRE is; never retune a
// window figure against that instance.
//
// Active users leads the group on purpose. `secondary` marks the figures that
// give up their space below lg, and putting the survivor first means the phone
// renders "Este mes: 168 usuarios activos" as one contiguous run rather than
// leaving the lead-in stranded ahead of a gap. Size and reach are what a
// reader keeps; volume is what they can do without.
const PERIOD = [
  { key: "topbar.stats.active", stat: "active_users_30_days" },
  { key: "topbar.stats.posts", stat: "posts_30_days", secondary: true },
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

  // `topics` is marked secondary rather than `members` so the phone renders
  // exactly what it rendered before this figure existed — "372 miembros ·
  // Este mes: 168 usuarios activos", measured correct at 390px on 2026-08-16.
  // Both additions are wide: the totals are four-digit numbers, and the note
  // in `CLAUDE.local.md` already flags that "1.240 miembros" is wider than
  // "374 miembros". Keeping them to wide viewports means no new width has to
  // be argued from arithmetic, which is how the band's last width claim came
  // to be wrong. Putting `temas` on a phone instead of `miembros` is a
  // defensible swap, but it needs a real measurement pass first.
  get totals() {
    const stats = this.siteStats.stats;

    if (!stats) {
      return null;
    }

    const figures = buildFigures(TOTALS, stats);
    return figures.length ? figures : null;
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
    return Boolean(this.totals || this.period);
  }

  <template>
    {{#if this.hasFigures}}
      <div
        class="topbar-stats"
        role="group"
        aria-label={{i18n (themePrefix "topbar.stats.aria_label")}}
      >
        {{! Siblings of the period group rather than a wrapper of their own:
            `.topbar-stats` is the flex row and its gap is what spaces them,
            so a second total needs no layout of its own. }}
        {{#each this.totals as |figure|}}
          <div
            class="topbar-stats__figure --total
              {{if figure.secondary '--secondary'}}"
          >
            <span class="topbar-stats__value">{{figure.value}}</span>
            <span class="topbar-stats__label">
              {{i18n (themePrefix figure.key) count=figure.count}}
            </span>
          </div>
        {{/each}}

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

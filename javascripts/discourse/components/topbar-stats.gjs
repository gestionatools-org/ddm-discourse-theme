import Component from "@glimmer/component";
import { service } from "@ember/service";
import I18n, { i18n } from "discourse-i18n";

// Members plus three 30-day windows, not lifetime totals. Zapier can show
// lifetime figures because theirs are in the tens of thousands; this is a
// closed community around a certification programme, where the totals are
// three or four figures and read as an empty forum. Recent activity reads as a
// live one.
//
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
// `secondary` marks the two that give up their space below lg. Four figures
// need roughly 396px at --font-down-2 and a 375px phone leaves about 343px of
// line, where the figures are the only thing the band still carries. Size and
// reach are what a reader keeps; volume and appreciation are what they can do
// without.
const FIGURES = [
  { key: "topbar.stats.members", stat: "users_count" },
  { key: "topbar.stats.posts", stat: "posts_30_days", secondary: true },
  { key: "topbar.stats.likes", stat: "likes_30_days", secondary: true },
  { key: "topbar.stats.active", stat: "active_users_30_days" },
];

export default class TopbarStats extends Component {
  @service siteStats;

  constructor() {
    super(...arguments);
    this.siteStats.load();
  }

  get figures() {
    const stats = this.siteStats.stats;

    if (!stats) {
      return null;
    }

    // A key core stops serializing degrades to one missing figure rather than
    // to "NaN members".
    return FIGURES.map(({ key, stat, secondary }) => ({
      key,
      secondary,
      count: stats[stat],
    }))
      .filter(({ count }) => Number.isFinite(count))
      .map((figure) => ({
        ...figure,
        // I18n.toNumber, not core's number() from discourse/lib/formatter:
        // that one abbreviates everything past 999, so a users_count of 1240
        // would render "1.2k". Core wants that in narrow topic-list cells. The
        // band has room, and this is the one lifetime total on display.
        value: I18n.toNumber(figure.count, { precision: 0 }),
      }));
  }

  <template>
    {{#if this.figures}}
      {{! `role="list"` is required, not decorative: `list-style: none` in
          topbar.scss strips the implicit list role in WebKit, and an
          aria-label on a role-less generic element is ignored — without this
          the group name is silently lost to Safari/VoiceOver. }}
      <ul
        class="topbar-stats"
        role="list"
        aria-label={{i18n (themePrefix "topbar.stats.aria_label")}}
      >
        {{#each this.figures as |figure|}}
          <li
            class="topbar-stats__figure {{if figure.secondary '--secondary'}}"
          >
            <span class="topbar-stats__value">{{figure.value}}</span>
            <span class="topbar-stats__label">
              {{i18n (themePrefix figure.key) count=figure.count}}
            </span>
          </li>
        {{/each}}
      </ul>
    {{/if}}
  </template>
}

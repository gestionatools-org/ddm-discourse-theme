import Component from "@glimmer/component";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// The bottom-right twin card. Presentational: the block hands down the ranked
// directory item, or nothing. With a member it is an avatar, their cargo and
// the raw figures for the window the block ranked over. With nobody eligible —
// or the directory switched off — it is a nudge to take part, which also stops
// the bento grid growing a hole.
export default class HighlightMemberCard extends Component {
  get user() {
    return this.args.member?.user;
  }

  get displayName() {
    return this.user.name || this.user.username;
  }

  get profileUrl() {
    return `/u/${this.user.username}/summary`;
  }

  <template>
    <article class="highlight-card highlight-member">
      {{#if @member}}
        <div class="highlight-card__body">
          <div class="highlight-card__label">
            {{dIcon "star"}}
            {{i18n (themePrefix "homepage.highlights.member.badge")}}
          </div>
          {{! Avatar beside the name, under the badge, rather than a band across
              the top of the card. The name and the cargo are grouped together
              beside it so the cargo lines up under the name instead of under
              the picture. }}
          <div class="highlight-member__identity">
            {{! The third link to the same profile — the name and the "Ver
                perfil" button already carry text. It wraps only a decorative
                avatar, so hide it from assistive tech and skip it in the tab
                order rather than expose a nameless duplicate link. }}
            <a
              href={{this.profileUrl}}
              class="highlight-member__avatar"
              aria-hidden="true"
              tabindex="-1"
            >
              {{dAvatar this.user imageSize="large"}}
            </a>
            <div class="highlight-member__who">
              <h3 class="highlight-card__title">
                <a href={{this.profileUrl}}>{{this.displayName}}</a>
              </h3>
              {{! The user's title — "cargo" — which the directory serialises
                  already, so it costs no request. 17 of the top 20 members
                  carry one; the rest simply render no line. The bio is
                  deliberately not here: it is empty for 7 of 10 and would have
                  cost a hop per render to show nothing. }}
              {{#if this.user.title}}
                <p class="highlight-member__cargo">{{this.user.title}}</p>
              {{/if}}
            </div>
          </div>
          <p class="highlight-member__figures">
            <span>{{i18n
                (themePrefix "homepage.highlights.member.posts")
                count=@member.post_count
              }}</span>
            <span>{{i18n
                (themePrefix "homepage.highlights.member.likes")
                count=@member.likes_received
              }}</span>
            <span>{{i18n
                (themePrefix "homepage.highlights.member.days")
                count=@member.days_visited
              }}</span>
          </p>
          <DButton
            class="btn-flat highlight-card__cta"
            @href={{this.profileUrl}}
            @translatedLabel={{i18n
              (themePrefix "homepage.highlights.member.profile")
            }}
          />
        </div>
      {{else}}
        <div class="highlight-card__body highlight-member__empty">
          <span class="highlight-card__placeholder">{{dIcon "star"}}</span>
          <p>{{i18n (themePrefix "homepage.highlights.member.cta_empty")}}</p>
          <DButton
            class="btn-flat highlight-card__cta"
            @href="/new-topic"
            @translatedLabel={{i18n
              (themePrefix "homepage.highlights.member.cta_empty_button")
            }}
          />
        </div>
      {{/if}}
    </article>
  </template>
}

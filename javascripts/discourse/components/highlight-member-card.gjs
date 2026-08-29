import Component from "@glimmer/component";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// The bottom-right twin card. Presentational: the block hands down the ranked
// directory item, or nothing. With a member it is an avatar, the raw figures
// that earned the spot, and a "member of the month" badge. With nobody eligible
// — a quiet month, or the directory switched off — it is a nudge to take part,
// which also stops the bento grid growing a hole.
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
        <a href={{this.profileUrl}} class="highlight-member__avatar">
          {{dAvatar this.user imageSize="large"}}
        </a>
        <div class="highlight-card__body">
          <div class="highlight-card__label">
            {{dIcon "star"}}
            {{i18n (themePrefix "homepage.highlights.member.badge")}}
          </div>
          <h3 class="highlight-card__title">
            <a href={{this.profileUrl}}>{{this.displayName}}</a>
          </h3>
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

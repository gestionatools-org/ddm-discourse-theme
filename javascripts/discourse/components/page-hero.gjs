import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

// The heading band at the top of the homepage and every listing.
//
// Presentational and context-free: it is handed a HeroContent and renders it.
// Deciding what that content is belongs to `lib/hero-content.js`, which is
// pure and unit-tested; deciding where the band appears belongs to the two
// mounting points. This component knows neither.
export default class PageHero extends Component {
  @service composer;
  @service currentUser;

  // Exactly one of `title` / `titleKey` is ever set — see the HeroContent
  // typedef. A category supplies a literal name; everything else a locale key.
  get title() {
    const { title, titleKey, titleArgs } = this.args.content;
    return title ?? i18n(themePrefix(titleKey), titleArgs ?? {});
  }

  get subtitle() {
    const { subtitle, subtitleKey } = this.args.content;

    if (subtitle) {
      return subtitle;
    }

    // Null rather than an empty string: 5 of the 17 categories on PRE carry no
    // description, and the template drops the element entirely rather than
    // rendering an empty paragraph that still takes up its margin.
    return subtitleKey ? i18n(themePrefix(subtitleKey)) : null;
  }

  // Two conditions, and the second only where there is a category.
  //
  // The permission cannot be read over the API — /categories.json answers with
  // the permissions of the key's own user, who is an admin and can write
  // everywhere — so which categories land on the false branch is verified on
  // PRE with a non-admin account rather than asserted here.
  //
  // `currentUser` is null for an anonymous visitor. The instance is
  // login_required so that is the login page alone, but it is also the one page
  // where an exception would be on show.
  get canCreateTopic() {
    if (!this.currentUser?.can_create_topic) {
      return false;
    }

    const { category } = this.args.content;
    return category ? category.permission === 1 : true;
  }

  @action
  openComposer() {
    this.composer.openNewTopic({ category: this.args.content.category });
  }

  <template>
    <section class="page-hero">
      <div class="page-hero__inner">
        {{! `dReplaceEmoji`, not the `emojiUnescape` used on news excerpts. The
            discriminator is what the field already holds: an excerpt is
            HTML-encoded and escaping it again prints "&rsquo;" verbatim, while
            a category name and its description_text are plain text and must be
            escaped before the emoji images are substituted in. `block-library`
            applies the same helper to a category name for the same reason. }}
        <h1 class="page-hero__title">{{trustHTML
            (dReplaceEmoji this.title)
          }}</h1>

        {{#if this.subtitle}}
          <p class="page-hero__subtitle">{{trustHTML
              (dReplaceEmoji this.subtitle)
            }}</p>
        {{/if}}

        {{#if this.canCreateTopic}}
          <DButton
            class="btn-primary page-hero__button"
            @action={{this.openComposer}}
            @translatedLabel={{i18n (themePrefix "hero.button")}}
          />
        {{/if}}
      </div>
    </section>
  </template>
}

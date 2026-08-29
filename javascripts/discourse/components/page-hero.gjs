import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PermissionType from "discourse/models/permission-type";
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

  // Core already renders its own `<h1 id="topic-list-heading" class="sr-only">`
  // on every discovery page (`accessible-discovery-heading.gjs`) — a second,
  // visible `<h1>` with different text would be a duplicate top-level heading.
  // Accessibility is a legal requirement here (RD 1112/2018), so the mount
  // decides the level rather than the component defaulting it away: the
  // homepage renders no core `h1` and stays at the default.
  get isH1() {
    return (this.args.headingLevel ?? "h1") === "h1";
  }

  // The homepage lane needs none of this — `homepage.scss` already supplies
  // the spacing between lanes via grid `gap`. The discovery mount has nothing
  // else providing it, so it opts in with a standalone modifier rather than
  // the base rule carrying a margin every caller must then fight.
  get sectionClass() {
    return this.args.standalone ? "page-hero --standalone" : "page-hero";
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
  // Strict equality against `PermissionType.FULL`, not a truthiness check or a
  // fallback for the absent case. Core writes the field itself, conditionally:
  // `app/models/site.rb` sets `category[:permission] = permission_types[:full]`
  // only `if allowed_topic_create&.include?(category[:id]) || @guardian.is_admin?`
  // — there is no `else`, so the key is absent precisely when the user may NOT
  // create a topic there. Core's own getter agrees:
  // `frontend/discourse/app/models/category.js`'s `canCreateTopic` is
  // `this.permission === PermissionType.FULL`, with no absent-case fallback.
  // So absence must read as false here too. (This line has been got wrong
  // twice — once treating absence as "unknown, show it anyway" — so the
  // reasoning is spelled out rather than left to be re-derived.)
  //
  // `category.permission` is compared directly rather than through
  // `category.canCreateTopic`: the test fixtures are plain objects, not
  // `Category` model instances, and have no such getter.
  //
  // `currentUser` is null for an anonymous visitor. The instance is
  // login_required so that is the login page alone, but it is also the one page
  // where an exception would be on show.
  get canCreateTopic() {
    if (!this.currentUser?.can_create_topic) {
      return false;
    }

    const { category } = this.args.content;
    if (!category) {
      return true;
    }

    return category.permission === PermissionType.FULL;
  }

  @action
  openComposer() {
    this.composer.openNewTopic({ category: this.args.content.category });
  }

  <template>
    <section class={{this.sectionClass}}>
      <div class="page-hero__inner">
        {{! `dReplaceEmoji`, not `emojiUnescape`. The discriminator is what the
            field already holds: an HTML-encoded excerpt escaped again prints
            "&rsquo;" verbatim, while a category name and its description_text
            are plain text and must be escaped before the emoji images are
            substituted in. }}
        {{#if this.isH1}}
          <h1 class="page-hero__title">{{trustHTML
              (dReplaceEmoji this.title)
            }}</h1>
        {{else}}
          <h2 class="page-hero__title">{{trustHTML
              (dReplaceEmoji this.title)
            }}</h2>
        {{/if}}

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

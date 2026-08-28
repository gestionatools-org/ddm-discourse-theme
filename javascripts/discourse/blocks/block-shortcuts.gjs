import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { destinationLinks } from "../lib/destination-links";

// The short card at the top of the homepage's panel.
//
// It holds the one action this community wants a member to take — start a topic
// — and the destinations that live outside the forum. It is the slot the
// reference fills with its newsletter card: something to do, beside something
// to read.
//
// The destinations are the same three the header carries, on purpose. In the
// header they are small text at the very top of the window; here they are a
// card beside the reading column, which is where somebody who has just arrived
// actually looks. Sharing `destinationLinks()` means they can never disagree
// about a name or a URL.
@block("theme:espublico:shortcuts", {
  description: "A short card of destinations, beside the latest list",
  args: {
    title: { type: "string" },
    newTopicText: { type: "string" },
  },
})
export default class BlockShortcuts extends Component {
  @service composer;
  @service currentUser;

  get links() {
    return destinationLinks();
  }

  // No category is involved, so this is the site-wide permission alone — unlike
  // the hero band, which also has to weigh the category it is standing in. A
  // null `currentUser` is an anonymous visitor: the instance is login_required,
  // so that is the login page, and the card is not on it.
  get canCreateTopic() {
    return !!this.currentUser?.can_create_topic;
  }

  @action
  openComposer() {
    this.composer.openNewTopic({});
  }

  <template>
    <section class="block-shortcuts">
      <h2 class="block-shortcuts__title">{{i18n (themePrefix @title)}}</h2>

      {{#if this.canCreateTopic}}
        <DButton
          class="btn-primary block-shortcuts__new-topic"
          @action={{this.openComposer}}
          @translatedLabel={{i18n (themePrefix @newTopicText)}}
        />
      {{/if}}

      {{#if this.links}}
        <ul class="block-shortcuts__list">
          {{#each this.links as |link|}}
            <li class="block-shortcuts__item">
              <a class="block-shortcuts__link" href={{link.url}}>
                {{i18n (themePrefix link.key)}}
              </a>
            </li>
          {{/each}}
        </ul>
      {{/if}}
    </section>
  </template>
}

import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import { destinationLinks } from "../lib/destination-links";

// Destination links in the site header: Academy, Demo Gestiona, Primeros pasos.
//
// The list, the trim and the drop-if-empty rule moved to
// `lib/destination-links.js` when the homepage's shortcuts card became a second
// consumer of the same three destinations. This component owns the header's
// presentation of them and nothing else.
//
// A link with no URL configured renders nothing rather than pointing at "#",
// and the nav element itself disappears when none is set.
export default class HeaderLinks extends Component {
  get links() {
    return destinationLinks();
  }

  <template>
    {{#if this.links}}
      <nav
        class="header-links"
        aria-label={{i18n (themePrefix "header.links.aria_label")}}
      >
        {{#each this.links as |link|}}
          <a class="header-links__link" href={{link.url}}>
            {{i18n (themePrefix link.key)}}
          </a>
        {{/each}}
      </nav>
    {{/if}}
  </template>
}

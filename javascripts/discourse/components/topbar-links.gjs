import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import { configuredLinks } from "../lib/topbar-links";

export default class TopbarLinks extends Component {
  get links() {
    return configuredLinks();
  }

  <template>
    {{#if this.links}}
      <nav
        class="topbar-links"
        aria-label={{i18n (themePrefix "topbar.links.aria_label")}}
      >
        {{#each this.links as |link|}}
          <a class="topbar-links__link" href={{link.url}}>
            {{i18n (themePrefix link.key)}}
          </a>
        {{/each}}
      </nav>
    {{/if}}
  </template>
}

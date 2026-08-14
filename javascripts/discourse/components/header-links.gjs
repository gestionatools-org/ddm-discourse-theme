import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

// Destination links in the site header: Academy, Demo Gestiona, Primeros pasos.
//
// Labels are i18n keys and live in locales/*.yml; only the URLs are settings.
// That split is the theme's rule — settings.yml is functional configuration,
// every user-visible string is a translation.
//
// A link with no URL configured renders nothing rather than pointing at "#".
// The three destinations are being decided after the design is signed off, so
// the empty state here is the expected one for now, not a fault: the header
// simply carries no links until a URL is filled in.
const LINKS = [
  { key: "header.links.academy", url: () => settings.academy_url },
  { key: "header.links.demo", url: () => settings.demo_url },
  { key: "header.links.first_steps", url: () => settings.first_steps_url },
];

export default class HeaderLinks extends Component {
  get links() {
    return LINKS.map(({ key, url }) => ({ key, url: url()?.trim() })).filter(
      (link) => link.url
    );
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

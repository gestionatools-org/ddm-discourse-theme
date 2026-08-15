import Component from "@glimmer/component";
import { service } from "@ember/service";
import { configuredLinks } from "../lib/topbar-links";
import TopbarLinks from "./topbar-links";

export default class Topbar extends Component {
  @service router;

  // `above-site-header` renders on every route, including /admin, where a
  // band of community links is noise on top of a different chrome. Same test
  // core's own `isCurrentAdminRoute` uses.
  get onAdminRoute() {
    return this.router.currentRouteName?.startsWith("admin");
  }

  get hasLinks() {
    return configuredLinks().length > 0;
  }

  get visible() {
    return !this.onAdminRoute && this.hasLinks;
  }

  <template>
    {{#if this.visible}}
      <div class="topbar">
        {{! `wrap` is core's own container class: it applies --d-max-width and
            the page gutters, and widens itself on sidebar pages. Reusing it is
            what keeps the band's left edge on the header logo at every page
            shape. }}
        <div class="wrap">
          <TopbarLinks />
        </div>
      </div>
    {{/if}}
  </template>
}

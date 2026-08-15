import Component from "@glimmer/component";
import { service } from "@ember/service";
import { configuredLinks } from "../lib/topbar-links";
import TopbarLinks from "./topbar-links";
import TopbarStats from "./topbar-stats";

export default class Topbar extends Component {
  @service router;
  @service siteStats;

  // `above-site-header` renders on every route, including /admin, where a
  // band of community links is noise on top of a different chrome. Same test
  // core's own `isCurrentAdminRoute` uses.
  get onAdminRoute() {
    return this.router.currentRouteName?.startsWith("admin");
  }

  get hasLinks() {
    return configuredLinks().length > 0;
  }

  // `loaded &&`, never a bare `!stats`. While the request is in flight the band
  // renders and reserves its height, and the figures appear inside it. Treating
  // "loading" as "unavailable" would make the band absent on mobile and then
  // push the whole page down when the request landed.
  get statsUnavailable() {
    return this.siteStats.loaded && !this.siteStats.stats;
  }

  // Load-bearing: `siteStats.load()` is only ever called from TopbarStats's
  // constructor, and TopbarStats only renders — so only constructs — once
  // this getter is already true. It works today because the loading state
  // (`loaded === false`) makes `statsUnavailable` false, which makes this
  // true, which lets TopbarStats mount and the request start. Making this
  // getter stricter (e.g. requiring `loaded`) would leave nothing to ever
  // trigger the load, deadlocking the band into permanent invisibility.
  // Do not fix that by calling `load()` here: Topbar is constructed on every
  // route including /admin, and firing /about.json there is worse than the
  // risk this comment is flagging.
  get visible() {
    return !this.onAdminRoute && (this.hasLinks || !this.statsUnavailable);
  }

  <template>
    {{#if this.visible}}
      <div class="topbar {{if this.statsUnavailable '--no-stats'}}">
        {{! `wrap` is core's own container class: it applies --d-max-width and
            the page gutters, and widens itself on sidebar pages. Reusing it is
            what keeps the band's left edge on the header logo at every page
            shape. }}
        <div class="wrap">
          <TopbarLinks />
          <TopbarStats />
        </div>
      </div>
    {{/if}}
  </template>
}

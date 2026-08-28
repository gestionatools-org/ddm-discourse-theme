import Component from "@glimmer/component";
import { heroContentFor } from "../lib/hero-content";
import PageHero from "./page-hero";

// The listings' copy of the band.
//
// A thin wrapper, not a template helper: `heroContentFor` is a plain function,
// and Ember does not accept named arguments on a helper invoked as a bare
// function call in a template. Mirrors `block-hero.gjs`'s shape — the same
// component, fed by the same resolver — but takes `category`/`tag` as args
// instead of calling the resolver with no context, since the discovery outlet
// supplies both as outlet arguments rather than nothing.
export default class DiscoveryHero extends Component {
  get content() {
    return heroContentFor({
      category: this.args.category,
      tag: this.args.tag,
    });
  }

  <template><PageHero @content={{this.content}} /></template>
}

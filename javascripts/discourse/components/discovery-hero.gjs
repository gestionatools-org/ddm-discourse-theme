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
      // Normalised at this boundary, not inside the resolver: core hands the
      // outlet a `Tag` model (`frontend/discourse/app/routes/tag/show.js`
      // builds it with `this.store.createRecord("tag", {...})`, and
      // `discovery/layout.gjs` passes it straight through as `tag=@model.tag`),
      // but `heroContentFor` interpolates `tag` into a locale string as a
      // plain string and has its own unit tests asserting that contract.
      // Reducing to `.name` here keeps the resolver's contract untouched.
      tag: this.args.tag?.name ?? this.args.tag,
    });
  }

  <template>
    <PageHero
      @content={{this.content}}
      @headingLevel="h2"
      @standalone={{true}}
    />
  </template>
}

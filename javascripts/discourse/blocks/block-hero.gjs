import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import PageHero from "../components/page-hero";
import { heroContentFor } from "../lib/hero-content";

// The homepage's copy of the band.
//
// A Block only because the homepage is a custom route and does not render the
// discovery outlets — there is no single mount that reaches both it and the
// category pages. Everything it does is delegated: the same component the
// listings use, fed by the same resolver, called with no context so it returns
// the community copy.
//
// It declares no args. Adding one later means declaring it inert first and
// honouring it in a second commit: an undeclared arg aborts the entire QUnit
// run with an uncaught BlockError, taking down tests unrelated to blocks.
@block("theme:espublico:hero", {
  description: "The heading band at the top of the homepage",
  args: {},
})
export default class BlockHero extends Component {
  get content() {
    return heroContentFor();
  }

  <template><PageHero @content={{this.content}} /></template>
}

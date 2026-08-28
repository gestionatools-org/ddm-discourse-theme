import { apiInitializer } from "discourse/lib/api";
import DiscoveryHero from "../components/discovery-hero";

// The heading band above every listing: categories, tags, /latest, /top,
// /unread. The homepage keeps its own copy, mounted as a Block — see
// `block-hero.gjs` for why a custom route needs a different mechanism.
//
// A plugin outlet rather than a block: the Blocks API is agreed to stay
// confined to the custom homepage, and outlets and SCSS carry every other
// surface. `discovery-list-container-top` is discovery-scoped, which excludes
// topic pages structurally, and Discourse's own theme-developer tutorial
// documents it being used with `{{#if @outletArgs.category}}` — the same
// argument this band depends on.
//
// The category (and tag) arrive as outlet arguments rather than being read
// from a service. That is the whole reason this mount was chosen over
// rendering once high and filtering by route name: Ember's autotracking
// updates the band when the argument changes as the user moves between
// categories, with no remount and no subscription to maintain.
export default apiInitializer((api) => {
  api.renderInOutlet(
    "discovery-list-container-top",
    <template>
      <DiscoveryHero
        @category={{@outletArgs.category}}
        @tag={{@outletArgs.tag}}
      />
    </template>
  );
});

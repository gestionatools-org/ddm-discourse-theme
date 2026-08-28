import { apiInitializer } from "discourse/lib/api";
import DiscoveryHero from "../components/discovery-hero";

// The heading band above every listing: categories, tags, /latest, /top,
// /unread. The homepage keeps its own copy, mounted as a Block — see
// `block-hero.gjs` for why a custom route needs a different mechanism.
//
// A plugin outlet rather than a block: the Blocks API is agreed to stay
// confined to the custom homepage, and outlets and SCSS carry every other
// surface. `discovery-list-controls-above` is discovery-scoped, which
// excludes topic pages structurally, and carries both `category` and `tag` as
// outlet arguments (verified via `gh api` against
// `frontend/discourse/app/components/discovery/layout.gjs`) — the same two
// arguments this band depends on.
//
// It sits above the entire navigation block, not just above the list: in
// `layout.gjs` it renders before `discovery-navigation-bar-above` and the nav
// tabs' `.list-controls`, both of which sit above `#list-area`. The outlet
// this band used before, `discovery-list-container-top`, is nested *inside*
// `#list-area`, below the nav tabs and below core's own New Topic button — so
// the band rendered mid-page with its button duplicating an affordance a few
// pixels above it. This outlet puts it where the spec asks: at the top of the
// page, above the whole navigation block.
//
// The category (and tag) arrive as outlet arguments rather than being read
// from a service. That is the whole reason this mount was chosen over
// rendering once high and filtering by route name: Ember's autotracking
// updates the band when the argument changes as the user moves between
// categories, with no remount and no subscription to maintain.
export default apiInitializer((api) => {
  api.renderInOutlet(
    "discovery-list-controls-above",
    <template>
      <DiscoveryHero
        @category={{@outletArgs.category}}
        @tag={{@outletArgs.tag}}
      />
    </template>
  );
});

import { apiInitializer } from "discourse/lib/api";
import Topbar from "../components/topbar";

// The information band above the site header.
//
// A plugin outlet rather than a block: the Blocks API has no header outlet, and
// themes cannot register new ones — only plugins can. This is also the agreed
// split for this theme, which keeps Blocks to the custom homepage and uses
// outlets and SCSS everywhere else.
//
// `above-site-header` is rendered in core's application.gjs immediately before
// <GlimmerSiteHeader> and outside it. Sitting in normal flow above a sticky
// header is what makes the band scroll away while the header stays pinned —
// there is no --header-offset to maintain and nothing to measure. It is the
// same outlet Discourse's own discourse-brand-header component uses.
export default apiInitializer((api) => {
  api.renderInOutlet("above-site-header", Topbar);
});

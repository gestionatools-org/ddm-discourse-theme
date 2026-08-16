import { apiInitializer } from "discourse/lib/api";
import HeaderLinks from "../components/header-links";

// Header destination links.
//
// A plugin outlet rather than a block: the Blocks API has no header outlet, and
// themes cannot register new ones — only plugins can. This is also the agreed
// split for this theme, which keeps Blocks to the custom homepage and uses
// outlets and SCSS everywhere else.
//
// `before-header-panel` sits between the search field and the icons panel
// (header/contents.gjs: logo, search, THIS, panel, after-header-panel), which
// puts the links to the right of the search and left of the avatar. There is no
// outlet between the logo and the search, so placing them on the search's left
// would mean rendering into `home-logo-wrapper` — a wrapper outlet whose default
// content is the logo itself, and not worth the risk of displacing it.
export default apiInitializer((api) => {
  api.renderInOutlet("before-header-panel", HeaderLinks);
});

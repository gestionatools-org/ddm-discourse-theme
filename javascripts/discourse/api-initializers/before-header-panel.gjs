import { apiInitializer } from "discourse/lib/api";
import HeaderLinks from "../components/header-links";

// Header links to the programme rooms.
//
// A plugin outlet rather than a block: the Blocks API has no header outlet, and
// themes cannot register new ones — only plugins can. This is also the agreed
// split for this theme, which keeps Blocks to the custom homepage and uses
// outlets and SCSS everywhere else.
//
// `before-header-panel` sits between the search slot and the icons panel
// (header/contents.gjs: logo, search, THIS, panel, after-header-panel). With
// `search_experience: search_icon` the search slot is empty and the magnifier
// lives in the panel, so header.scss pushes the links right, beside it.
export default apiInitializer((api) => {
  api.renderInOutlet("before-header-panel", HeaderLinks);
});

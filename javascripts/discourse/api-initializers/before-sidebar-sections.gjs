import { apiInitializer } from "discourse/lib/api";
import SidebarGettingStarted from "../components/sidebar-getting-started";

// `before-sidebar-sections` is declared twice in core, with the same name: in
// `sidebar.gjs` (the desktop rail) and in `sidebar/hamburger-dropdown.gjs` (the
// mobile menu). One registration therefore reaches both, above Community.
export default apiInitializer((api) => {
  api.renderInOutlet("before-sidebar-sections", SidebarGettingStarted);
});

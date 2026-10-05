import { apiInitializer } from "discourse/lib/api";
import LoginLanding from "../components/login-landing";

// The page an anonymous visitor reaches, since `login_required` is on.
//
// `login-required` is a *wrapper* outlet: core's
// templates/discovery/login-required.gjs wraps its whole content in it, so
// rendering here replaces the stock splash — including the helpers that hide
// the header buttons and sidebar, which LoginLanding therefore calls itself.
// Deleting this file restores core's splash and its site texts.
export default apiInitializer((api) => {
  api.renderInOutlet("login-required", LoginLanding);
});

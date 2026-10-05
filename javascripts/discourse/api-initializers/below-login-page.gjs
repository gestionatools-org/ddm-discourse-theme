import { apiInitializer } from "discourse/lib/api";
import LoginHelp from "../components/login-help";

// The "can't get in?" exits under the /login form. `below-login-page` and not
// `login-after-modal-footer`: the latter is inside core's LoginPageCta, which
// is not rendered while the email-code form is open.
export default apiInitializer((api) => {
  api.renderInOutlet("below-login-page", LoginHelp);
});

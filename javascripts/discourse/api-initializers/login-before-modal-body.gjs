import { apiInitializer } from "discourse/lib/api";
import LoginMasthead from "../components/login-masthead";

// The logo at the top of the /login card. Core renders this outlet inside
// `.login-body`, before the form, on desktop and mobile alike.
export default apiInitializer((api) => {
  api.renderInOutlet("login-before-modal-body", LoginMasthead);
});

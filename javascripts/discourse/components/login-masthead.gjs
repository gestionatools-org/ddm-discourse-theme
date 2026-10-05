import bodyClass from "discourse/helpers/body-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import LoginLogo from "./login-logo";

// The top of the /login card. `static-login` is the body class core sets on
// the login-required splash to hide the site header; setting it here too gives
// /login the same frame as the landing — no header, card at the same height,
// logo at the same size in the same place — so moving between them only
// changes what sits under the logo.
//
// With the header gone, a quiet "back" link in the card's corner is the
// explicit way back to the landing; the logo links there too.
const LoginMasthead = <template>
  {{bodyClass "static-login"}}
  <a class="login-masthead__back" href="/">
    {{dIcon "arrow-left"}}
    <span>{{i18n (themePrefix "login_masthead.back")}}</span>
  </a>
  <LoginLogo @href="/" />
</template>;

export default LoginMasthead;

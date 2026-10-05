import bodyClass from "discourse/helpers/body-class";
import LoginLogo from "./login-logo";

// The top of the /login card. `static-login` is the body class core sets on
// the login-required splash to hide the site header; setting it here too gives
// /login the same frame as the landing — no header, card at the same height,
// logo at the same size in the same place — so moving between them only
// changes what sits under the logo.
const LoginMasthead = <template>
  {{bodyClass "static-login"}}
  <LoginLogo @href="/" />
</template>;

export default LoginMasthead;

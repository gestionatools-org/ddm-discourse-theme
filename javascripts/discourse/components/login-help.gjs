import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

// The two ways out for a visitor who cannot sign in. Registration is closed,
// so this is the only place the site answers "how do I get in?".
//
// Shared by the login landing and /login. On /login it is mounted through
// `below-login-page` rather than `login-after-modal-footer`: the latter lives
// inside core's LoginPageCta, which is not rendered while the email-code form
// is open — exactly when someone is struggling to get in.
export default class LoginHelp extends Component {
  get email() {
    return settings.access_contact_email?.trim();
  }

  get certificationUrl() {
    return settings.certification_url?.trim();
  }

  get mailto() {
    return `mailto:${this.email}`;
  }

  get visible() {
    return Boolean(this.email || this.certificationUrl);
  }

  <template>
    {{#if this.visible}}
      <section class="login-help">
        <h2 class="login-help__title">
          {{i18n (themePrefix "login_help.title")}}
        </h2>
        <ul class="login-help__list">
          {{#if this.email}}
            <li class="login-help__item --no-account">
              <h3 class="login-help__item-title">
                {{i18n (themePrefix "login_help.no_account.title")}}
              </h3>
              <p class="login-help__item-body">
                {{i18n (themePrefix "login_help.no_account.body")}}
                <a class="login-help__link" href={{this.mailto}}>
                  {{this.email}}
                </a>
              </p>
            </li>
          {{/if}}
          {{#if this.certificationUrl}}
            <li class="login-help__item --certify">
              <h3 class="login-help__item-title">
                {{i18n (themePrefix "login_help.certify.title")}}
              </h3>
              <p class="login-help__item-body">
                <a
                  class="login-help__link"
                  href={{this.certificationUrl}}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{i18n (themePrefix "login_help.certify.link")}}
                </a>
              </p>
            </li>
          {{/if}}
        </ul>
      </section>
    {{/if}}
  </template>
}

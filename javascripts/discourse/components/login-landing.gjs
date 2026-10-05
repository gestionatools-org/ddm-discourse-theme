import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import routeAction from "discourse/helpers/route-action";
import { findAll } from "discourse/models/login-method";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import LoginHelp from "./login-help";
import LoginLogo from "./login-logo";

// What the community holds, in the order the landing lists it. Each entry
// describes a section that exists today: the programme rooms in the header,
// the events lane, and the ideas lane plus the podcast/newsletter highlights.
const INSIDE = [
  { key: "rooms", icon: "users" },
  { key: "events", icon: "calendar-days" },
  { key: "ideas", icon: "lightbulb" },
];

// The login-required landing. Static by necessity: under `login_required` an
// anonymous visitor cannot read anything from the forum, so every word comes
// from the theme's locales and the two exits from its settings.
export default class LoginLanding extends Component {
  @service siteSettings;

  // External providers (Academy's OAuth2 on PROD). When there is one, the
  // landing launches it directly, so whoever signs in with it never sees
  // /login; the form stays one quieter step away. Their labels are the
  // instance's own (`oauth2_button_title`), not theme copy.
  get ssoMethods() {
    return findAll();
  }

  get localLoginEnabled() {
    return this.siteSettings.enable_local_logins;
  }

  // The same call core's login buttons make: a POST to /auth/<provider>.
  @action
  ssoLogin(method) {
    method.doLogin();
  }

  get insideItems() {
    return INSIDE.map(({ key, icon }) => ({
      key,
      icon,
      title: i18n(themePrefix(`login_landing.inside.${key}.title`)),
      body: i18n(themePrefix(`login_landing.inside.${key}.body`)),
    }));
  }

  <template>
    {{hideApplicationHeaderButtons "search" "login" "signup" "menu"}}
    {{hideApplicationSidebar}}
    {{bodyClass "login-page"}}
    {{bodyClass "static-login"}}

    <div class="login-landing">
      <section class="login-landing__hero">
        <LoginLogo />

        <h1 class="login-landing__title">
          {{i18n (themePrefix "login_landing.title")}}
        </h1>
        <p class="login-landing__subtitle">
          {{i18n (themePrefix "login_landing.subtitle")}}
        </p>

        {{#if this.ssoMethods.length}}
          {{#each this.ssoMethods as |method|}}
            <DButton
              class="btn-primary login-landing__cta login-landing__sso"
              @action={{fn this.ssoLogin method}}
              @translatedLabel={{method.title}}
            />
          {{/each}}
          {{#if this.localLoginEnabled}}
            <DButton
              class="btn-flat login-button login-landing__local"
              @action={{routeAction "showLogin"}}
              @translatedLabel={{i18n (themePrefix "login_landing.cta_local")}}
            />
          {{/if}}
        {{else}}
          <DButton
            class="btn-primary login-button login-landing__cta"
            @action={{routeAction "showLogin"}}
            @translatedLabel={{i18n (themePrefix "login_landing.cta")}}
          />
        {{/if}}

        <p class="login-landing__restricted">
          {{dIcon "circle-info"}}
          <span>{{i18n (themePrefix "login_landing.restricted")}}</span>
        </p>
      </section>

      <section class="login-landing__inside">
        <h2 class="login-landing__section-title">
          {{i18n (themePrefix "login_landing.inside.title")}}
        </h2>
        <ul class="login-landing__inside-list">
          {{#each this.insideItems as |item|}}
            <li class="login-landing__inside-item">
              {{dIcon item.icon}}
              <h3 class="login-landing__inside-title">{{item.title}}</h3>
              <p class="login-landing__inside-body">{{item.body}}</p>
            </li>
          {{/each}}
        </ul>
      </section>

      <div class="login-landing__help">
        <LoginHelp />
      </div>
    </div>
  </template>
}

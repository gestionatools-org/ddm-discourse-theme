import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import LoginHelp from "./login-help";

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

  // Read from the site's own logo rather than a theme asset, so the "Forum"
  // logo is swapped from the admin panel and updates header and landing at once.
  get logoUrl() {
    return this.siteSettings.site_logo_url;
  }

  get logoDarkUrl() {
    return this.siteSettings.site_logo_dark_url;
  }

  get siteTitle() {
    return this.siteSettings.title;
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
        {{#if this.logoUrl}}
          <picture>
            {{#if this.logoDarkUrl}}
              <source
                srcset={{this.logoDarkUrl}}
                media="(prefers-color-scheme: dark)"
              />
            {{/if}}
            <img
              class="login-landing__logo"
              src={{this.logoUrl}}
              alt={{this.siteTitle}}
            />
          </picture>
        {{else}}
          <p class="login-landing__site-title">{{this.siteTitle}}</p>
        {{/if}}

        <h1 class="login-landing__title">
          {{i18n (themePrefix "login_landing.title")}}
        </h1>
        <p class="login-landing__subtitle">
          {{i18n (themePrefix "login_landing.subtitle")}}
        </p>

        <DButton
          class="btn-primary login-button login-landing__cta"
          @action={{routeAction "showLogin"}}
          @translatedLabel={{i18n (themePrefix "login_landing.cta")}}
        />

        <p class="login-landing__restricted">
          {{dIcon "lock"}}
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

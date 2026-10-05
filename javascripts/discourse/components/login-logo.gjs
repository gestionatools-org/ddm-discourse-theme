import Component from "@glimmer/component";
import { service } from "@ember/service";

// The mark itself: the logo with its dark-scheme variant, or the site title as
// text when no logo is set.
const LogoMark = <template>
  {{#if @logoUrl}}
    <picture>
      {{#if @logoDarkUrl}}
        <source srcset={{@logoDarkUrl}} media="(prefers-color-scheme: dark)" />
      {{/if}}
      <img class="login-logo__image" src={{@logoUrl}} alt={{@siteTitle}} />
    </picture>
  {{else}}
    <span class="login-logo__title">{{@siteTitle}}</span>
  {{/if}}
</template>;

// The masthead logo shared by the login landing and /login, so the two
// screens put the same mark at the same size in the same place.
//
// Read from the site's own logo rather than a theme asset, so the "Forum"
// logo is swapped from the admin panel and updates every surface at once.
//
// `@href` makes it a link — /login hides the header, so the logo is the way
// back to the landing.
export default class LoginLogo extends Component {
  @service siteSettings;

  get logoUrl() {
    return this.siteSettings.site_logo_url;
  }

  get logoDarkUrl() {
    return this.siteSettings.site_logo_dark_url;
  }

  get siteTitle() {
    return this.siteSettings.title;
  }

  <template>
    <div class="login-logo">
      {{#if @href}}
        <a class="login-logo__link" href={{@href}}>
          <LogoMark
            @logoUrl={{this.logoUrl}}
            @logoDarkUrl={{this.logoDarkUrl}}
            @siteTitle={{this.siteTitle}}
          />
        </a>
      {{else}}
        <LogoMark
          @logoUrl={{this.logoUrl}}
          @logoDarkUrl={{this.logoDarkUrl}}
          @siteTitle={{this.siteTitle}}
        />
      {{/if}}
    </div>
  </template>
}

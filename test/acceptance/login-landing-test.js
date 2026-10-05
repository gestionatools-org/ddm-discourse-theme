import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { clearAuthMethods } from "discourse/models/login-method";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

// The topbar above the header asks for /about.json on every route. Under
// login_required an anonymous visitor gets a 403, which hides the band — the
// same thing production does.
function stubAbout(server, helper) {
  server.get("/about.json", () => helper.response(403, {}));
}

acceptance("Login landing", function (needs) {
  needs.settings({
    login_required: true,
    site_logo_url: "/images/logo.png",
    title: "Gestiona Avanza",
  });
  needs.pretender(stubAbout);
  needs.hooks.beforeEach(() => clearAuthMethods());

  test("replaces core's splash", async function (assert) {
    await visit("/");

    assert.dom(".login-landing").exists();
    assert
      .dom(".login-landing .login-logo__image")
      .hasAttribute("src", "/images/logo.png");
    assert.dom(".login-landing__restricted").exists();
    assert.dom(".login-landing__inside-item").exists({ count: 3 });
    assert.dom(".login-landing .login-help").exists();
    assert
      .dom(".login-welcome .login-content")
      .doesNotExist("core's server-composed block is gone");
  });

  test("the button opens /login", async function (assert) {
    await visit("/");
    await click(".login-landing .login-button");

    assert.strictEqual(currentURL(), "/login");
    assert.dom(".login-fullpage").exists();
  });
});

acceptance("Login landing | no site logo", function (needs) {
  needs.settings({
    login_required: true,
    site_logo_url: "",
    title: "Gestiona Avanza",
  });
  needs.pretender(stubAbout);
  needs.hooks.beforeEach(() => clearAuthMethods());

  test("falls back to the site title as text", async function (assert) {
    await visit("/");

    assert.dom(".login-landing .login-logo__image").doesNotExist();
    assert.dom(".login-landing .login-logo__title").hasText("Gestiona Avanza");
  });
});

acceptance("Login page | help", function (needs) {
  needs.settings({
    login_required: true,
    enable_local_logins_via_email: true,
    enable_local_logins_via_code: true,
  });
  needs.pretender(stubAbout);

  test("is under the form", async function (assert) {
    await visit("/login");

    assert.dom(".login-fullpage .login-help").exists();
  });

  // Same frame as the landing: no site header, the logo at the top of the
  // card, linking back to the landing.
  test("has the landing's masthead instead of the header", async function (assert) {
    await visit("/login");

    assert.dom(document.body).hasClass("static-login");
    assert
      .dom(".login-body .login-logo .login-logo__link")
      .hasAttribute("href", "/");
    assert.dom(".login-body .login-masthead__back").hasAttribute("href", "/");
  });

  // LoginPageCta disappears with the email-code form; the help must not go
  // with it — that is why it sits in `below-login-page`.
  test("stays with the email-code form open", async function (assert) {
    await visit("/login");
    await click("#one-time-code-link");

    assert.dom(".login-page-cta").doesNotExist();
    assert.dom(".login-fullpage .login-help").exists();
  });
});

// With an external provider (Academy's OAuth2 on PROD) the landing launches it
// directly — the SSO user never sees /login — and keeps a quieter way to the
// username-and-password form.
const ACADEMY = {
  name: "oauth2_basic",
  title_override: "Acceder con credenciales Academy",
  pretty_name_override: null,
  custom_url: null,
  frame_width: null,
  frame_height: null,
  can_connect: true,
  can_revoke: true,
};

acceptance("Login landing | external provider", function (needs) {
  needs.settings({ login_required: true, enable_local_logins: true });
  needs.site({ auth_providers: [ACADEMY] });
  needs.pretender(stubAbout);

  // `findAll()` caches the providers for the whole run; reset it so this
  // module and the ones without a provider each see their own site.
  needs.hooks.beforeEach(() => clearAuthMethods());
  needs.hooks.afterEach(() => clearAuthMethods());

  test("leads with the provider, keeps the form one step away", async function (assert) {
    await visit("/");

    assert
      .dom(".login-landing__sso")
      .hasText("Acceder con credenciales Academy");
    assert.dom(".login-landing__local").exists();

    await click(".login-landing__local");
    assert.strictEqual(currentURL(), "/login");
  });
});

acceptance("Login landing | external provider only", function (needs) {
  needs.settings({ login_required: true, enable_local_logins: false });
  needs.site({ auth_providers: [ACADEMY] });
  needs.pretender(stubAbout);
  needs.hooks.beforeEach(() => clearAuthMethods());
  needs.hooks.afterEach(() => clearAuthMethods());

  test("drops the form link when local logins are off", async function (assert) {
    await visit("/");

    assert.dom(".login-landing__sso").exists();
    assert.dom(".login-landing__local").doesNotExist();
  });
});

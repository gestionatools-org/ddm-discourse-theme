import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
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

  test("replaces core's splash", async function (assert) {
    await visit("/");

    assert.dom(".login-landing").exists();
    assert.dom(".login-landing__logo").hasAttribute("src", "/images/logo.png");
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

  test("falls back to the site title as text", async function (assert) {
    await visit("/");

    assert.dom(".login-landing__logo").doesNotExist();
    assert.dom(".login-landing__site-title").hasText("Gestiona Avanza");
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

  // LoginPageCta disappears with the email-code form; the help must not go
  // with it — that is why it sits in `below-login-page`.
  test("stays with the email-code form open", async function (assert) {
    await visit("/login");
    await click("#one-time-code-link");

    assert.dom(".login-page-cta").doesNotExist();
    assert.dom(".login-fullpage .login-help").exists();
  });
});

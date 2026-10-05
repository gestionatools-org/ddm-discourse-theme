import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LoginHelp from "../../discourse/components/login-help";

const EMAIL = "certificaciongestiona@espublico.com";
const URL = "https://www.espublicogestiona.com/es/certificaciones-espublico/";

module("Espublico Theme | Integration | login help", function (hooks) {
  setupRenderingTest(hooks);

  // `settings` is a shared global across the whole QUnit run: every test
  // starts from the shipped defaults, whatever the previous one left.
  hooks.beforeEach(function () {
    settings.access_contact_email = EMAIL;
    settings.certification_url = URL;
  });

  // …and leaves them as it found them: the acceptance tests for /login read
  // the shipped defaults, so a blank left behind here would fail them
  // depending on run order.
  hooks.afterEach(function () {
    settings.access_contact_email = EMAIL;
    settings.certification_url = URL;
  });

  test("both exits render with their links", async function (assert) {
    await render(<template><LoginHelp /></template>);

    assert.dom(".login-help__title").exists();
    assert
      .dom(".login-help__item.--no-account .login-help__link")
      .hasAttribute("href", `mailto:${EMAIL}`)
      .hasText(EMAIL);
    assert
      .dom(".login-help__item.--certify .login-help__link")
      .hasAttribute("href", URL)
      .hasAttribute("target", "_blank")
      .hasAttribute("rel", "noopener noreferrer");
  });

  test("a blank email hides only its exit", async function (assert) {
    settings.access_contact_email = "  ";
    await render(<template><LoginHelp /></template>);

    assert.dom(".login-help__item.--no-account").doesNotExist();
    assert.dom(".login-help__item.--certify").exists();
  });

  test("a blank URL hides only its exit", async function (assert) {
    settings.certification_url = "";
    await render(<template><LoginHelp /></template>);

    assert.dom(".login-help__item.--certify").doesNotExist();
    assert.dom(".login-help__item.--no-account").exists();
  });

  test("both blank renders nothing, heading included", async function (assert) {
    settings.access_contact_email = "";
    settings.certification_url = "";
    await render(<template><LoginHelp /></template>);

    assert.dom(".login-help").doesNotExist();
  });
});

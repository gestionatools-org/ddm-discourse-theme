import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

// The theme sets the `custom_homepage` modifier, so "/" is the theme's own
// homepage and its lanes fetch category topics. These tests visit /latest
// instead: the band is site-wide, and /latest exercises it without dragging
// the homepage blocks and their requests into the assertion.

function clearLinkSettings() {
  settings.academy_url = "";
  settings.demo_url = "";
  settings.first_steps_url = "";
}

acceptance("Topbar - links", function (needs) {
  needs.user();

  needs.hooks.beforeEach(function () {
    settings.academy_url = "https://academy.example.com";
    settings.demo_url = "";
    settings.first_steps_url = "/t/primeros-pasos/1";
  });

  needs.hooks.afterEach(clearLinkSettings);

  test("renders one link per configured URL", async function (assert) {
    await visit("/latest");

    assert.dom(".topbar").exists("the band renders");
    assert
      .dom(".topbar-links__link")
      .exists({ count: 2 }, "the blank demo_url contributes no link");
  });

  test("uses the configured URL as the href", async function (assert) {
    await visit("/latest");

    assert
      .dom(".topbar-links__link")
      .hasAttribute("href", "https://academy.example.com");
  });

  test("no longer renders the links inside the header", async function (assert) {
    await visit("/latest");

    assert
      .dom(".d-header .topbar-links")
      .doesNotExist("the links live above the header, not inside it");
    assert
      .dom(".header-links")
      .doesNotExist("the old header-links block is gone entirely");
  });
});

acceptance("Topbar - nothing configured", function (needs) {
  needs.user();

  needs.hooks.beforeEach(clearLinkSettings);

  test("renders no band at all", async function (assert) {
    await visit("/latest");

    assert
      .dom(".topbar")
      .doesNotExist("an empty strip above the header is worse than no band");
  });
});

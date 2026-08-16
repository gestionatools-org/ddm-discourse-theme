import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

// Destination links rendered into `before-header-panel`, between the search
// field and the user icons.
//
// The theme sets the `custom_homepage` modifier, so "/" is the theme's own
// homepage and its lanes fetch category topics. These tests visit /latest
// instead: the header is site-wide, and /latest exercises it without dragging
// the homepage blocks and their requests into the assertion.

function clearLinkSettings() {
  settings.academy_url = "";
  settings.demo_url = "";
  settings.first_steps_url = "";
}

// The band above the header loads this on every route. Stubbed so these tests
// assert on the header alone and never depend on the figures arriving.
function stubAbout(server, helper) {
  server.get("/about.json", () =>
    helper.response({ about: { stats: { users_count: 1240 } } })
  );
}

acceptance("Header links", function (needs) {
  needs.user();
  needs.pretender(stubAbout);

  needs.hooks.beforeEach(function () {
    settings.academy_url = "https://academy.example.com";
    settings.demo_url = "";
    settings.first_steps_url = "/t/primeros-pasos/1";
  });

  needs.hooks.afterEach(clearLinkSettings);

  test("renders one link per configured URL", async function (assert) {
    await visit("/latest");

    assert
      .dom(".header-links__link")
      .exists({ count: 2 }, "the blank demo_url contributes no link");
  });

  test("uses the configured URL as the href", async function (assert) {
    await visit("/latest");

    assert
      .dom(".header-links__link")
      .hasAttribute("href", "https://academy.example.com");
  });

  test("renders inside the header, not in the band above it", async function (assert) {
    await visit("/latest");

    assert
      .dom(".d-header .header-links")
      .exists("the links live in the header itself");
    assert
      .dom(".topbar .header-links")
      .doesNotExist("the band carries figures only");
  });

  test("renders no nav at all when every URL is empty", async function (assert) {
    clearLinkSettings();

    await visit("/latest");

    assert
      .dom(".header-links")
      .doesNotExist("an empty nav would still take header space");
  });
});

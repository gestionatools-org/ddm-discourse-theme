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

const ABOUT = {
  about: {
    stats: {
      users_count: 1240,
      topics_30_days: 48,
      active_users_30_days: 120,
    },
  },
};

function stubAbout(server, helper) {
  server.get("/about.json", () => helper.response(ABOUT));
}

function failAbout(server, helper) {
  server.get("/about.json", () =>
    helper.response(403, {}, { errors: ["forbidden"] })
  );
}

acceptance("Topbar - links", function (needs) {
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

acceptance("Topbar - figures", function (needs) {
  needs.user();
  needs.pretender(stubAbout);
  needs.hooks.beforeEach(clearLinkSettings);

  test("renders the three figures", async function (assert) {
    await visit("/latest");

    assert.dom(".topbar-stats__figure").exists({ count: 3 });
  });

  test("formats the figure with a thousands separator", async function (assert) {
    await visit("/latest");

    assert
      .dom(".topbar-stats__figure:first-child .topbar-stats__value")
      .hasText("1,240", "not abbreviated to 1.2k");
  });

  test("renders the band on figures alone, with no links configured", async function (assert) {
    await visit("/latest");

    assert.dom(".topbar").exists();
    assert.dom(".topbar").doesNotHaveClass("--no-stats");
    assert.dom(".topbar-links").doesNotExist();
  });
});

acceptance("Topbar - figures unavailable", function (needs) {
  needs.user();
  needs.pretender(failAbout);

  needs.hooks.afterEach(clearLinkSettings);

  test("renders no band at all when nothing else is configured", async function (assert) {
    clearLinkSettings();

    await visit("/latest");

    assert
      .dom(".topbar")
      .doesNotExist("an empty strip above the header is worse than no band");
  });

  test("keeps the links and marks the band --no-stats", async function (assert) {
    clearLinkSettings();
    settings.academy_url = "https://academy.example.com";

    await visit("/latest");

    assert.dom(".topbar").exists("the links still justify the band");
    assert
      .dom(".topbar")
      .hasClass("--no-stats", "so the SCSS can hide it below lg");
    assert.dom(".topbar-stats").doesNotExist();
  });
});

acceptance("Topbar - admin routes", function (needs) {
  needs.user({ admin: true });

  needs.hooks.beforeEach(function () {
    settings.academy_url = "https://academy.example.com";
    settings.demo_url = "";
    settings.first_steps_url = "";
  });

  needs.hooks.afterEach(clearLinkSettings);

  test("renders no band on an admin route", async function (assert) {
    await visit("/admin");

    assert
      .dom(".topbar")
      .doesNotExist("the band is not part of the admin chrome");
  });
});

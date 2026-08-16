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
      posts_30_days: 3480,
      likes_30_days: 890,
      active_users_30_days: 120,
    },
  },
};

function stubAbout(server, helper) {
  server.get("/about.json", () => helper.response(ABOUT));
}

function failAbout(server, helper) {
  server.get("/about.json", () =>
    helper.response(403, { errors: ["forbidden"] })
  );
}

const PARTIAL_ABOUT = {
  about: {
    stats: {
      users_count: 1240,
    },
  },
};

function stubPartialAbout(server, helper) {
  server.get("/about.json", () => helper.response(PARTIAL_ABOUT));
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

  test("renders the four figures", async function (assert) {
    await visit("/latest");

    assert.dom(".topbar-stats__figure").exists({ count: 4 });
  });

  test("marks only the two figures that stand down below lg", async function (assert) {
    await visit("/latest");

    // The media query itself is not observable here, but the class that drives
    // it is, and getting the wrong two figures marked is the failure this
    // guards: it would leave the phone showing volume and appreciation while
    // hiding size and reach.
    assert.dom(".topbar-stats__figure.--secondary").exists({ count: 2 });
    assert
      .dom(".topbar-stats__figure:first-child")
      .doesNotHaveClass("--secondary", "members survives on a phone");
    assert
      .dom(".topbar-stats__figure:last-child")
      .doesNotHaveClass("--secondary", "active users survives on a phone");
  });

  test("formats the figure with a thousands separator", async function (assert) {
    await visit("/latest");

    assert
      .dom(".topbar-stats__figure:first-child .topbar-stats__value")
      .hasText("1,240", "not abbreviated to 1.2k");
  });

  test("pairs each label with its own stat key", async function (assert) {
    await visit("/latest");

    // Each of the three 30-day windows carries a different number in the
    // fixture, so a mis-pairing in FIGURES puts a visibly wrong count against
    // the label rather than an indistinguishable one.
    assert
      .dom(".topbar-stats__figure:nth-child(2)")
      .hasText("3,480 messages this month");
    assert
      .dom(".topbar-stats__figure:nth-child(3)")
      .hasText("890 likes this month");
    assert.dom(".topbar-stats__figure:last-child").hasText("120 people active");
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

acceptance("Topbar - figures with a missing stat", function (needs) {
  needs.user();
  needs.pretender(stubPartialAbout);
  needs.hooks.beforeEach(clearLinkSettings);

  test("drops a figure whose stat key is missing from the response", async function (assert) {
    await visit("/latest");

    assert
      .dom(".topbar-stats__figure")
      .exists(
        { count: 1 },
        "posts, likes and active-users are missing, not rendered as empty or NaN"
      );
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

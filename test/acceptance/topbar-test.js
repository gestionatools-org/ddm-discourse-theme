import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

// These tests visit /latest rather than "/": the band is site-wide, and
// /latest exercises it without dragging anything else into the assertion.
//
// This comment used to say that "/" is the theme's own homepage because of the
// `custom_homepage` modifier. That is true in production and false here — the
// modifier is applied server-side and does not reach the JS test environment,
// where "/" is core's discovery route and the `homepage-blocks` outlet never
// renders. The claim was never verified, since these tests deliberately avoid
// "/", and it cost a full CI cycle when the lane tests were first written
// against it. The lanes are rendered through `<BlockOutlet>` instead; see
// `test/integration/homepage-lanes-test.gjs`.

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

// Only the lifetime total survives: the whole 30-day group has to disappear,
// lead-in and divider included.
const TOTAL_ONLY_ABOUT = { about: { stats: { users_count: 1240 } } };

// The mirror image: no total, so the group has to stand on its own.
const PERIOD_ONLY_ABOUT = {
  about: {
    stats: {
      posts_30_days: 3480,
      likes_30_days: 890,
      active_users_30_days: 120,
    },
  },
};

acceptance("Topbar - figures", function (needs) {
  needs.user();
  needs.pretender(stubAbout);
  needs.hooks.beforeEach(clearLinkSettings);

  test("separates the lifetime total from the 30-day group", async function (assert) {
    await visit("/latest");

    assert.dom(".topbar-stats__figure").exists({ count: 4 });
    assert
      .dom(".topbar-stats__figure.--total")
      .exists({ count: 1 }, "exactly one figure is the lifetime total");
    assert
      .dom(".topbar-stats__period .topbar-stats__figure.--total")
      .doesNotExist("the total sits outside the period group, not within it");
    assert
      .dom(".topbar-stats__period .topbar-stats__figure")
      .exists({ count: 3 }, "the three 30-day windows are grouped together");
  });

  test("states the period once, in front of the group", async function (assert) {
    await visit("/latest");

    assert.dom(".topbar-stats__period-label").exists({ count: 1 });
    assert.dom(".topbar-stats__period-label").hasText("This month:");
    assert
      .dom(".topbar-stats__figure.--total")
      .hasText("1,240 members", "the total carries no period of its own");
  });

  test("formats the total with a thousands separator", async function (assert) {
    await visit("/latest");

    assert
      .dom(".topbar-stats__figure.--total .topbar-stats__value")
      .hasText("1,240", "not abbreviated to 1.2k");
  });

  test("pairs each label with its own stat key", async function (assert) {
    await visit("/latest");

    // Each of the three windows carries a different number in the fixture, so
    // a mis-pairing in PERIOD puts a visibly wrong count against the label
    // rather than an indistinguishable one.
    const figures = [
      ...document.querySelectorAll(
        ".topbar-stats__period .topbar-stats__figure"
      ),
    ].map((el) => el.textContent.replace(/\s+/g, " ").trim());

    assert.deepEqual(
      figures,
      ["120 active users", "3,480 messages", "890 likes"],
      "active users leads the group, so it is the one that survives on a phone"
    );
  });

  test("marks only the two figures that stand down below lg", async function (assert) {
    await visit("/latest");

    // The media query itself is not observable here, but the class that drives
    // it is, and getting the wrong figures marked is the failure this guards:
    // it would leave the phone showing volume and appreciation while hiding
    // size and reach.
    assert.dom(".topbar-stats__figure.--secondary").exists({ count: 2 });
    assert
      .dom(".topbar-stats__figure.--total")
      .doesNotHaveClass("--secondary", "members survives on a phone");
    assert
      .dom(".topbar-stats__period .topbar-stats__figure:first-child")
      .doesNotHaveClass("--secondary", "active users survives on a phone");
  });

  test("carries the figures and nothing else", async function (assert) {
    await visit("/latest");

    assert.dom(".topbar").exists();
    assert
      .dom(".topbar .header-links")
      .doesNotExist("the destination links belong to the header, not the band");
  });
});

acceptance("Topbar - figures unavailable", function (needs) {
  needs.user();
  needs.pretender(failAbout);

  needs.hooks.afterEach(clearLinkSettings);

  test("renders no band at all", async function (assert) {
    clearLinkSettings();

    await visit("/latest");

    assert
      .dom(".topbar")
      .doesNotExist("an empty strip above the header is worse than no band");
  });

  test("renders no band even when header links are configured", async function (assert) {
    clearLinkSettings();
    settings.academy_url = "https://academy.example.com";

    await visit("/latest");

    // The band used to survive a failed /about.json whenever a link was set,
    // marked --no-stats. Now that the links render in the header instead,
    // nothing is left to justify the strip and the whole band goes.
    assert.dom(".topbar").doesNotExist();
    assert
      .dom(".header-links__link")
      .exists(
        { count: 1 },
        "and the links are untouched by the failed request"
      );
  });
});

acceptance("Topbar - only the lifetime total is served", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/about.json", () => helper.response(TOTAL_ONLY_ABOUT));
  });
  needs.hooks.beforeEach(clearLinkSettings);

  test("drops the group, its lead-in and its divider together", async function (assert) {
    await visit("/latest");

    assert.dom(".topbar-stats__figure").exists({ count: 1 });
    assert.dom(".topbar-stats__figure.--total").hasText("1,240 members");
    assert
      .dom(".topbar-stats__period")
      .doesNotExist(
        "the divider hangs off the group, so it leaves with it rather than dangling after the total"
      );
    assert
      .dom(".topbar-stats__period-label")
      .doesNotExist("no 'This month:' with nothing behind it");
  });
});

acceptance("Topbar - only the 30-day group is served", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/about.json", () => helper.response(PERIOD_ONLY_ABOUT));
  });
  needs.hooks.beforeEach(clearLinkSettings);

  test("renders the group without a total in front of it", async function (assert) {
    await visit("/latest");

    assert.dom(".topbar-stats__figure.--total").doesNotExist();
    assert.dom(".topbar-stats__period-label").exists();
    assert
      .dom(".topbar-stats__period .topbar-stats__figure")
      .exists({ count: 3 });
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

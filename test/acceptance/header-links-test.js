import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import siteFixtures from "discourse/tests/fixtures/site-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

// Where the nav lands in the booted header. Which rooms render, in what order and
// with what label, is covered in test/integration/header-links-test.gjs.
//
// `needs.site` REPLACES the preloaded category list, and /latest's fixture topics
// point at core's fixture categories — so the rooms are appended to that list
// rather than substituted for it.
const CATEGORIES = [
  ...cloneJSON(siteFixtures["site.json"].site.categories),
  {
    id: 5,
    name: "Foro del Certificado",
    slug: "foro-del-certificado",
    color: "0088CC",
    text_color: "FFFFFF",
  },
  {
    id: 90,
    name: "Analítica de datos",
    slug: "foro-analitica-de-datos",
    parent_category_id: 5,
    color: "3AB54A",
    text_color: "FFFFFF",
  },
];

// The band above the header loads this on every route. Stubbed so these tests
// assert on the header alone and never depend on the figures arriving.
function stubAbout(server, helper) {
  server.get("/about.json", () =>
    helper.response({ about: { stats: { users_count: 1240 } } })
  );
}

acceptance("Header links", function (needs) {
  needs.user();
  needs.site({ categories: CATEGORIES });
  needs.pretender(stubAbout);

  needs.hooks.beforeEach(function () {
    settings.header_room_category_ids = "90";
  });

  needs.hooks.afterEach(function () {
    settings.header_room_category_ids = "89|90|91";
  });

  test("renders in the header, in the slot before the icons panel", async function (assert) {
    await visit("/latest");

    assert
      .dom(".d-header .before-header-panel-outlet .header-links")
      .exists("the links live in the header itself");
  });

  test("links the room by its own name and URL", async function (assert) {
    await visit("/latest");

    assert.dom(".header-links__link").hasText("Analítica de datos");
    assert.dom(".header-links__link").hasAttribute("href", /\/90$/);
  });

  test("stays out of the band above the header", async function (assert) {
    await visit("/latest");

    assert
      .dom(".topbar .header-links")
      .doesNotExist("the band carries figures only");
  });

  test("renders no nav when no configured room resolves", async function (assert) {
    settings.header_room_category_ids = "91";

    await visit("/latest");

    assert.dom(".header-links").doesNotExist();
  });
});

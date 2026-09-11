import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import HeaderLinks from "../../discourse/components/header-links";

// Which rooms, in what order, with which label and href. Placement in the real
// header is asserted in test/acceptance/header-links-test.js.
//
// `site.categories` holds only the categories the viewer may see — core's
// Site#categories is guardian-scoped — so "a member outside the room" is a
// category absent from this list. Stubbed by mutating the real service, as
// page-hero-test does, and restored after: `settings` and the site service are
// shared across the whole QUnit run.
const ROOMS = [
  {
    id: 89,
    name: "Administración Avanzada",
    url: "/c/foro-del-certificado/foro-administracion-avanzada/89",
  },
  {
    id: 90,
    name: "Analítica de datos",
    url: "/c/foro-del-certificado/foro-analitica-de-datos/90",
  },
  {
    id: 91,
    name: "Gestiona for Developers",
    url: "/c/foro-del-certificado/foro-gestiona-for-developers/91",
  },
];

function textsOf(selector) {
  return [...document.querySelectorAll(selector)].map((el) =>
    el.textContent.trim()
  );
}

module("Integration | Component | header-links", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.site = this.owner.lookup("service:site");
    this.originalCategories = this.site.categories;
    this.site.categories = ROOMS;
    settings.header_room_category_ids = "89|90|91";
  });

  hooks.afterEach(function () {
    this.site.categories = this.originalCategories;
    settings.header_room_category_ids = "89|90|91";
  });

  test("renders one link per configured room", async function (assert) {
    await render(<template><HeaderLinks /></template>);

    assert.dom(".header-links__link").exists({ count: 3 });
  });

  test("keeps the setting's order, not the site list's", async function (assert) {
    this.site.categories = [...ROOMS].reverse();
    settings.header_room_category_ids = "89|91";

    await render(<template><HeaderLinks /></template>);

    assert.deepEqual(textsOf(".header-links__link"), [
      "Administración Avanzada",
      "Gestiona for Developers",
    ]);
  });

  test("a room the viewer cannot see renders nothing", async function (assert) {
    this.site.categories = [ROOMS[0], ROOMS[2]];

    await render(<template><HeaderLinks /></template>);

    assert.deepEqual(
      textsOf(".header-links__link"),
      ["Administración Avanzada", "Gestiona for Developers"],
      "a member outside Analiza never gets a link into its room"
    );
  });

  test("label and href are the category's own", async function (assert) {
    settings.header_room_category_ids = "90";

    await render(<template><HeaderLinks /></template>);

    assert.dom(".header-links__link").hasText("Analítica de datos");
    assert.dom(".header-links__link").hasAttribute("href", ROOMS[1].url);
  });

  test("no visible room renders no nav at all", async function (assert) {
    this.site.categories = [];

    await render(<template><HeaderLinks /></template>);

    assert
      .dom(".header-links")
      .doesNotExist("an empty nav would still take header space");
  });

  test("an empty setting renders no nav", async function (assert) {
    settings.header_room_category_ids = "";

    await render(<template><HeaderLinks /></template>);

    assert.dom(".header-links").doesNotExist();
  });
});

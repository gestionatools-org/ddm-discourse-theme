import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PageHero from "../../discourse/components/page-hero";

// Rendered directly rather than through an outlet: this component is mounted
// two different ways in production and neither is what is under test here.

function stubComposer(owner) {
  const calls = [];
  owner.unregister("service:composer");
  owner.register(
    "service:composer",
    { openNewTopic: (options) => calls.push(options) },
    { instantiate: false }
  );
  return calls;
}

// The band must not throw when there is no signed-in user. The instance is
// login_required so this is the login page only, but that is the one page an
// exception would be visible on.
function stubCurrentUser(owner, user) {
  owner.unregister("service:current-user");
  owner.register("service:current-user", user, { instantiate: false });
}

module("Espublico Theme | Integration | page hero", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a category's own name and description", async function (assert) {
    stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: true });
    const content = {
      title: "Foro del Certificado",
      titleKey: null,
      titleArgs: null,
      subtitle: "Donde se resuelven las dudas.",
      subtitleKey: null,
      category: { id: 5, name: "Foro del Certificado" },
    };

    await render(<template><PageHero @content={{content}} /></template>);

    assert.dom(".page-hero__title").hasText("Foro del Certificado");
    assert.dom(".page-hero__subtitle").hasText("Donde se resuelven las dudas.");
  });

  test("omits the subtitle entirely when the category has no description", async function (assert) {
    stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: true });
    const content = {
      title: "Noticias",
      titleKey: null,
      titleArgs: null,
      subtitle: null,
      subtitleKey: null,
      category: { id: 4, name: "Noticias" },
    };

    await render(<template><PageHero @content={{content}} /></template>);

    assert.dom(".page-hero__title").hasText("Noticias");
    assert.dom(".page-hero__subtitle").doesNotExist("no empty element either");
  });

  test("clicking the button opens the composer on the category in scope", async function (assert) {
    const calls = stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: true });
    const category = { id: 5, name: "Foro del Certificado", permission: 1 };
    const content = {
      title: "Foro del Certificado",
      titleKey: null,
      titleArgs: null,
      subtitle: null,
      subtitleKey: null,
      category,
    };

    await render(<template><PageHero @content={{content}} /></template>);
    await click(".page-hero__button");

    assert.strictEqual(calls.length, 1, "opened once");
    assert.strictEqual(calls[0].category, category, "on this category");
  });

  test("opens the composer with no category on a generic listing", async function (assert) {
    const calls = stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: true });
    const content = {
      title: null,
      titleKey: "hero.home.title",
      titleArgs: null,
      subtitle: null,
      subtitleKey: "hero.home.subtitle",
      category: null,
    };

    await render(<template><PageHero @content={{content}} /></template>);
    await click(".page-hero__button");

    assert.strictEqual(
      calls[0].category,
      null,
      "user picks it in the composer"
    );
  });

  // Core (`app/models/site.rb`) writes `permission` only when the user may
  // create a topic in that category — there is no `else` branch, so the field
  // is absent precisely when the answer is no. An absent field must therefore
  // hide the button, the same as a present-but-not-full one below; treating
  // absence as "show it anyway" was the defect this test used to pin.
  test("hides the button when the category carries no permission field", async function (assert) {
    stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: true });
    const content = {
      title: "Foro del Certificado",
      titleKey: null,
      titleArgs: null,
      subtitle: null,
      subtitleKey: null,
      category: { id: 5, name: "Foro del Certificado" },
    };

    await render(<template><PageHero @content={{content}} /></template>);

    assert.dom(".page-hero__button").doesNotExist();
  });

  // The case that was missing entirely: the global gate is open
  // (`can_create_topic: true`) but the category itself refuses. Without this,
  // a category-level regression is invisible — the only other "hides the
  // button" test below exercises the global gate alone.
  test("hides the button for a readonly category even when the user can create topics elsewhere", async function (assert) {
    stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: true });
    const content = {
      title: "Administradores",
      titleKey: null,
      titleArgs: null,
      subtitle: null,
      subtitleKey: null,
      // 3 is Discourse's `readonly` permission constant — present, but not
      // `full` (1).
      category: { id: 3, name: "Administradores", permission: 3 },
    };

    await render(<template><PageHero @content={{content}} /></template>);

    assert.dom(".page-hero__title").exists("the band still renders");
    assert.dom(".page-hero__button").doesNotExist();
  });

  // The check the API keys cannot measure — /categories.json answers with the
  // admin key's own permissions. This is the unit that proves the branch works;
  // which categories fall on this side is verified on PRE with a non-admin.
  test("hides the button from a user who cannot create topics", async function (assert) {
    stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: false });
    const content = {
      title: "Administradores",
      titleKey: null,
      titleArgs: null,
      subtitle: null,
      subtitleKey: null,
      category: { id: 3, name: "Administradores" },
    };

    await render(<template><PageHero @content={{content}} /></template>);

    assert.dom(".page-hero__title").exists("the band still renders");
    assert.dom(".page-hero__button").doesNotExist("but not the action");
  });

  test("renders without a button and without throwing for an anonymous visitor", async function (assert) {
    stubComposer(this.owner);
    stubCurrentUser(this.owner, null);
    const content = {
      title: null,
      titleKey: "hero.home.title",
      titleArgs: null,
      subtitle: null,
      subtitleKey: "hero.home.subtitle",
      category: null,
    };

    await render(<template><PageHero @content={{content}} /></template>);

    assert.dom(".page-hero").exists();
    assert.dom(".page-hero__button").doesNotExist();
  });
});

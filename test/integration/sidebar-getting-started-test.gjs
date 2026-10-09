import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import SidebarGettingStarted from "../../discourse/components/sidebar-getting-started";

// Rendered directly rather than through `before-sidebar-sections`: the outlet
// lives in core's sidebar, which a rendering test does not mount, and the
// registration is one line of `renderInOutlet`.
//
// The user is a plain object. Core's `SectionLink` reads the same service, but
// only `user_option?.external_links_in_new_tab`, which a double without
// `user_option` answers safely.
//
// `site.categories` is guardian-scoped in production, so "a member who cannot
// see the category" is a category absent from this list. Stubbed by mutating
// the real service and restored after, as header-links-test does.
const GETTING_STARTED = {
  id: 78,
  name: "Centro de ayuda",
  url: "/c/centro-de-ayuda/78",
};

function stubCurrentUser(owner, user) {
  owner.unregister("service:current-user");
  owner.register("service:current-user", user, { instantiate: false });
}

module(
  "Espublico Theme | Integration | sidebar getting started",
  function (hooks) {
    setupRenderingTest(hooks);

    // `settings` is a shared global across the whole QUnit run, so every test
    // here starts from the shipped defaults rather than the previous test's.
    hooks.beforeEach(function () {
      this.site = this.owner.lookup("service:site");
      this.originalCategories = this.site.categories;
      this.site.categories = [GETTING_STARTED];
      settings.getting_started_category_id = 78;
    });

    hooks.afterEach(function () {
      this.site.categories = this.originalCategories;
    });

    test("a member sees the category, under its own name", async function (assert) {
      stubCurrentUser(this.owner, { trust_level: 0 });

      await render(<template><SidebarGettingStarted /></template>);

      assert
        .dom(".sidebar-getting-started .sidebar-section-link")
        .hasAttribute("href", "/c/centro-de-ayuda/78");
      assert
        .dom(".sidebar-getting-started .sidebar-section-link-content-text")
        .hasText("Centro de ayuda");
      assert.dom(".sidebar-getting-started .d-icon-circle-question").exists();
    });

    test("trust level does not hide it", async function (assert) {
      stubCurrentUser(this.owner, { trust_level: 4 });

      await render(<template><SidebarGettingStarted /></template>);

      assert.dom(".sidebar-getting-started").exists();
    });

    test("a category id of 0 hides the row", async function (assert) {
      settings.getting_started_category_id = 0;
      stubCurrentUser(this.owner, { trust_level: 0 });

      await render(<template><SidebarGettingStarted /></template>);

      assert.dom(".sidebar-getting-started").doesNotExist();
    });

    test("a category the member cannot see hides the row", async function (assert) {
      this.site.categories = [];
      stubCurrentUser(this.owner, { trust_level: 0 });

      await render(<template><SidebarGettingStarted /></template>);

      assert.dom(".sidebar-getting-started").doesNotExist();
    });
  }
);

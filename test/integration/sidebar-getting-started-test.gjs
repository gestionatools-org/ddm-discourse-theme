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
      settings.getting_started_topic_id = 2743;
      settings.getting_started_max_trust_level = 1;
    });

    test("a new member sees the link to the guide", async function (assert) {
      stubCurrentUser(this.owner, { trust_level: 0 });

      await render(<template><SidebarGettingStarted /></template>);

      assert
        .dom(".sidebar-getting-started .sidebar-section-link")
        .hasAttribute("href", /\/t\/2743$/);
      assert
        .dom(".sidebar-getting-started .sidebar-section-link-content-text")
        .hasText(/\S/, "labelled from the locale, not left empty");
      assert.dom(".sidebar-getting-started .d-icon-rocket").exists();
    });

    test("the cap is inclusive", async function (assert) {
      stubCurrentUser(this.owner, { trust_level: 1 });

      await render(<template><SidebarGettingStarted /></template>);

      assert.dom(".sidebar-getting-started").exists();
    });

    test("a member above the cap does not see it", async function (assert) {
      stubCurrentUser(this.owner, { trust_level: 2 });

      await render(<template><SidebarGettingStarted /></template>);

      assert.dom(".sidebar-getting-started").doesNotExist();
    });

    test("the cap is a setting", async function (assert) {
      settings.getting_started_max_trust_level = 2;
      stubCurrentUser(this.owner, { trust_level: 2 });

      await render(<template><SidebarGettingStarted /></template>);

      assert.dom(".sidebar-getting-started").exists();
    });

    test("a topic id of 0 hides the row", async function (assert) {
      settings.getting_started_topic_id = 0;
      stubCurrentUser(this.owner, { trust_level: 0 });

      await render(<template><SidebarGettingStarted /></template>);

      assert.dom(".sidebar-getting-started").doesNotExist();
    });
  }
);

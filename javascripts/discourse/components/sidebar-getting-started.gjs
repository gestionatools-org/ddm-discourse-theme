import Component from "@glimmer/component";
import { service } from "@ember/service";
import SectionLink from "discourse/components/sidebar/section-link";

// A single "Primeros pasos" row at the top of the sidebar, for newcomers only.
//
// Core's own `SectionLink` renders the row, so it inherits every sidebar link
// style — hover, focus, the filo in `sidebar.scss` — without a second copy of
// them here. The wrapper mimics a headerless section (`sidebar-section-wrapper`
// + `sidebar-section-content`), which is what gives the row core's padding and
// the hairline that separates it from Community below.
//
// It points at a category, looked up in `site.categories` the same way
// `header-links` resolves its rooms: that list is guardian-scoped, so a member
// who cannot see the category gets no row rather than an access error, and the
// label and href are the category's own, so a rename or a slug change in admin
// reaches the sidebar without a deploy. Category 78 "Primeros pasos" predates
// PRE's restore, so the default holds on both instances.
//
// Shown up to `getting_started_max_trust_level` (default 1). Trust level is the
// one signal core exposes that means "still new here"; it says nothing about
// staff, so an administrator at trust level 0–1 sees the row too.
export default class SidebarGettingStarted extends Component {
  @service currentUser;
  @service site;

  get category() {
    const id = settings.getting_started_category_id;
    if (!(id > 0)) {
      return null;
    }
    return (this.site.categories || []).find((c) => c.id === id) || null;
  }

  get shouldRender() {
    return (
      this.category &&
      this.currentUser &&
      this.currentUser.trust_level <= settings.getting_started_max_trust_level
    );
  }

  <template>
    {{#if this.shouldRender}}
      <div
        class="sidebar-section sidebar-section-wrapper sidebar-getting-started"
        data-section-name="getting-started"
      >
        <ul class="sidebar-section-content">
          <SectionLink
            @linkName="getting-started"
            @href={{this.category.url}}
            @content={{this.category.name}}
            @prefixType="icon"
            @prefixValue="rocket"
          />
        </ul>
      </div>
    {{/if}}
  </template>
}

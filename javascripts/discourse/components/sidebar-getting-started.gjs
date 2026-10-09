import Component from "@glimmer/component";
import { service } from "@ember/service";
import SectionLink from "discourse/components/sidebar/section-link";

// A single "Centro de ayuda" row at the top of the sidebar, for every member.
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
// reaches the sidebar without a deploy. Category 78 (renamed from "Primeros
// pasos" to "Centro de ayuda" on 2026-10-09) predates PRE's restore, so the
// default holds on both instances.
//
// Until 2026-10-09 the row stopped at trust level 1; the category became the
// forum's general help, so every signed-in member gets it.
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
    return this.category && this.currentUser;
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
            @prefixValue="circle-question"
          />
        </ul>
      </div>
    {{/if}}
  </template>
}

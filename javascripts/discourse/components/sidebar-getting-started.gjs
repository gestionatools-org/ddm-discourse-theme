import Component from "@glimmer/component";
import { service } from "@ember/service";
import SectionLink from "discourse/components/sidebar/section-link";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

// A single "Primeros pasos" row at the top of the sidebar, for newcomers only.
//
// Core's own `SectionLink` renders the row, so it inherits every sidebar link
// style — hover, focus, the filo in `sidebar.scss` — without a second copy of
// them here. The wrapper mimics a headerless section (`sidebar-section-wrapper`
// + `sidebar-section-content`), which is what gives the row core's padding and
// the hairline that separates it from Community below.
//
// It is a topic id, not a URL, because the topic is the stable thing: the slug
// follows the title, and `/t/<id>` redirects to wherever it lives now. The id is
// per-instance — PROD's guide is 2743, PRE's is 2622 — so PRE carries an
// override.
//
// Shown up to `getting_started_max_trust_level` (default 1). Trust level is the
// one signal core exposes that means "still new here"; it says nothing about
// staff, so an administrator at trust level 0–1 sees the row too.
export default class SidebarGettingStarted extends Component {
  @service currentUser;

  get href() {
    const id = settings.getting_started_topic_id;
    return id > 0 ? getURL(`/t/${id}`) : null;
  }

  get shouldRender() {
    return (
      this.href &&
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
            @href={{this.href}}
            @content={{i18n (themePrefix "sidebar.getting_started")}}
            @prefixType="icon"
            @prefixValue="rocket"
          />
        </ul>
      </div>
    {{/if}}
  </template>
}

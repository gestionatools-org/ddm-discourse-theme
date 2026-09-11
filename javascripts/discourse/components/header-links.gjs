import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import { parseCategoryIds } from "../lib/category-topics";

// One link per programme room, in the site header beside the search icon.
//
// Each configured id is looked up in `site.categories`, which core scopes to what
// the viewer may see (Site#categories is guardian-scoped, and /site.json on PRE
// carries every category — no lazy loading). So a member outside a room's group
// simply gets no link to it: no permission logic lives here, and nobody is sent
// to an access error. `page-hero` relies on the same fact.
//
// Label and href are the category's own name and URL, never a theme string or a
// hand-built path: a rename or a slug change in admin reaches the header without
// a deploy. The order is the setting's, not the site list's.
export default class HeaderLinks extends Component {
  @service site;

  get rooms() {
    const categories = this.site.categories || [];
    return parseCategoryIds(settings.header_room_category_ids)
      .map((id) => categories.find((category) => category.id === id))
      .filter(Boolean);
  }

  <template>
    {{#if this.rooms}}
      <nav
        class="header-links"
        aria-label={{i18n (themePrefix "header.links.aria_label")}}
      >
        {{#each this.rooms as |room|}}
          <a class="header-links__link" href={{room.url}}>{{room.name}}</a>
        {{/each}}
      </nav>
    {{/if}}
  </template>
}

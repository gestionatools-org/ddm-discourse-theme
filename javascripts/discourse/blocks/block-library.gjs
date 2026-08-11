import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import { resolveCategories } from "../lib/category-topics";

/**
 * Directory cards for reference categories.
 *
 * Deliberately renders no topic list. These categories are repositories, not
 * forums — category 73's whole tree holds 66 topics and has never received a
 * single reply — so a "latest topics" list would imply a conversation that
 * does not exist and would bury the structure people actually navigate by.
 * Cards surface the section count instead.
 *
 * Categories come from the preloaded site list, so no fetch is needed.
 */
@block("theme:espublico:library", {
  description: "Directory cards for reference categories",
  args: {
    title: { type: "string" },
    categoryIds: { type: "array" },
  },
})
export default class BlockLibrary extends Component {
  get categories() {
    return resolveCategories(this.args.categoryIds);
  }

  <template>
    {{#if this.categories.length}}
      <section class="block-library">
        <header class="block-library__header">
          <h2 class="block-library__title">
            {{dIcon "book-open-reader"}}
            {{i18n (themePrefix @title)}}
          </h2>
        </header>

        <ul class="block-library__grid">
          {{#each this.categories as |category|}}
            <li class="block-library__card">
              <a class="block-library__card-link" href={{category.url}}>
                <span
                  class="block-library__card-swatch"
                  style={{trustHTML (concat "background:#" category.color)}}
                  aria-hidden="true"
                ></span>
                <h3 class="block-library__card-title">
                  {{trustHTML (dReplaceEmoji category.name)}}
                </h3>
                {{#if category.description_excerpt}}
                  <p class="block-library__card-description">
                    {{trustHTML category.description_excerpt}}
                  </p>
                {{/if}}
                <p class="block-library__card-meta">
                  {{#if category.subcategory_count}}
                    {{i18n
                      (themePrefix "homepage.library.subcategories")
                      count=category.subcategory_count
                    }}
                  {{else}}
                    {{i18n
                      (themePrefix "homepage.library.documents")
                      count=category.topic_count
                    }}
                  {{/if}}
                </p>
              </a>
            </li>
          {{/each}}
        </ul>
      </section>
    {{/if}}
  </template>
}

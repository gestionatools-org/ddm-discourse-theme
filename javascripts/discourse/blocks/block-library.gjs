import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import { categoryStats, resolveCategories } from "../lib/category-topics";

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
  // Both counts are summed over the subtree in categoryStats — see the comment
  // there for why neither `topic_count` nor `subcategory_count` can be read
  // straight off the category.
  get cards() {
    return resolveCategories(this.args.categoryIds).map((category) => ({
      category,
      ...categoryStats(category),
    }));
  }

  <template>
    {{#if this.cards.length}}
      <section class="block-library">
        <header class="block-library__header">
          <h2 class="block-library__title">
            {{dIcon "book-open-reader"}}
            {{i18n (themePrefix @title)}}
          </h2>
        </header>

        <ul class="block-library__grid">
          {{#each this.cards as |card|}}
            <li class="block-library__card">
              <a class="block-library__card-link" href={{card.category.url}}>
                <span
                  class="block-library__card-swatch"
                  style={{trustHTML
                    (concat "background:#" card.category.color)
                  }}
                  aria-hidden="true"
                ></span>
                <h3 class="block-library__card-title">
                  {{! `name` is plain text, so it is escaped on the way in —
                      unlike a topic's `fancy_title`, which is already HTML and
                      must not pass through this helper. }}
                  {{trustHTML (dReplaceEmoji card.category.name)}}
                </h3>
                {{#if card.category.description_excerpt}}
                  <p class="block-library__card-description">
                    {{trustHTML card.category.description_excerpt}}
                  </p>
                {{/if}}
                <p class="block-library__card-meta">
                  {{#if card.sections}}
                    <span class="block-library__card-count">
                      {{i18n
                        (themePrefix "homepage.library.subcategories")
                        count=card.sections
                      }}
                    </span>
                  {{/if}}
                  <span class="block-library__card-count">
                    {{i18n
                      (themePrefix "homepage.library.documents")
                      count=card.documents
                    }}
                  </span>
                </p>
              </a>
            </li>
          {{/each}}
        </ul>
      </section>
    {{/if}}
  </template>
}

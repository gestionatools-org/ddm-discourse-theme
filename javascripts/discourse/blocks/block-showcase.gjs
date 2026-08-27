import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { loadCategoryTopics } from "../lib/category-topics";

/**
 * Image grid of the work members submit for their certification.
 *
 * A cover image is a requirement, not a nicety: this lane exists to exhibit
 * the work itself, and a card with no image exhibits nothing. Until v0.15.0
 * imageless topics still took a cell, filled with a grey box and a picture
 * glyph — on the live instance that was three of six cells, so half the grid
 * read as broken.
 *
 * Filtering costs nothing here: category 78 holds 12 topics with a cover image
 * against 6 cells. If that ever inverts, the lane simply shows fewer cards and
 * falls back to its empty state at zero, which is the honest outcome for a
 * gallery with nothing to hang.
 *
 * `tag` narrows the category before the image test, and the two are not
 * redundant. The category is not a gallery: every topic in it is an arrival
 * announcement, and the poster it announces is embedded as an image in some
 * and attached as a PDF in others. The tag says *this topic carries a poster*;
 * the image test says *and the grid can show it*. Dropping the tag would hang
 * whatever picture an announcement happens to carry — a photo, a screenshot of
 * a dashboard — under a heading about member work.
 */
@block("theme:espublico:showcase", {
  description: "Image grid of member work",
  args: {
    title: { type: "string" },
    linkText: { type: "string" },
    linkUrl: { type: "string" },
    categoryId: { type: "number", required: true },
    count: { type: "number", default: 6 },
    tag: { type: "string" },
  },
})
export default class BlockShowcase extends Component {
  @service store;

  @bind
  async fetchTopics() {
    return await loadCategoryTopics(
      this.store,
      this.args.categoryId,
      this.args.count,
      { requireImage: true, tag: this.args.tag }
    );
  }

  <template>
    <section class="block-showcase">
      <header class="block-showcase__header">
        <h2 class="block-showcase__title">
          {{dIcon "images"}}
          {{i18n (themePrefix @title)}}
        </h2>
        {{#if @linkUrl}}
          <DButton
            class="btn-flat block-showcase__link"
            @href={{@linkUrl}}
            @translatedLabel={{i18n (themePrefix @linkText)}}
          />
        {{/if}}
      </header>

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="block-showcase__loading"><div class="spinner" /></div>
        </:loading>

        <:empty>
          <p class="block-showcase__empty">{{i18n
              (themePrefix "homepage.showcase.empty")
            }}</p>
        </:empty>

        <:content as |topics|>
          <ul class="block-showcase__grid">
            {{#each topics as |topic|}}
              <li class="block-showcase__card">
                <a class="block-showcase__card-link" href={{topic.url}}>
                  {{! No fallback branch: fetchTopics only returns topics that
                      have a cover image, so an imageless card cannot reach
                      here. }}
                  {{! Decorative: the adjacent title is the accessible name,
                      so alt="" avoids a duplicate announcement. }}
                  <img
                    class="block-showcase__card-image"
                    src={{topic.image_url}}
                    alt=""
                    loading="lazy"
                  />
                  <span class="block-showcase__card-title">
                    {{! `fancy_title` is already HTML. dReplaceEmoji escapes its input
                        before substituting, so passing it through here double-encodes and
                        renders "&rsquo;" as literal text. Core renders it raw too. }}
                    {{trustHTML topic.fancy_title}}
                  </span>
                </a>
              </li>
            {{/each}}
          </ul>
        </:content>
      </DAsyncContent>
    </section>
  </template>
}

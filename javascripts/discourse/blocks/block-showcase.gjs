import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import { loadCategoryTopics } from "../lib/category-topics";

@block("theme:espublico:showcase", {
  description: "Image grid of member work",
  args: {
    title: { type: "string" },
    linkText: { type: "string" },
    linkUrl: { type: "string" },
    categoryId: { type: "number", required: true },
    count: { type: "number", default: 6 },
  },
})
export default class BlockShowcase extends Component {
  @service store;

  @bind
  async fetchTopics() {
    return await loadCategoryTopics(
      this.store,
      this.args.categoryId,
      this.args.count
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
                  {{#if topic.image_url}}
                    {{! Decorative: the adjacent title is the accessible name,
                        so alt="" avoids a duplicate announcement. }}
                    <img
                      class="block-showcase__card-image"
                      src={{topic.image_url}}
                      alt=""
                      loading="lazy"
                    />
                  {{else}}
                    <span
                      class="block-showcase__card-image --placeholder"
                      aria-hidden="true"
                    >
                      {{dIcon "image"}}
                    </span>
                  {{/if}}
                  <span class="block-showcase__card-title">
                    {{trustHTML (dReplaceEmoji topic.fancy_title)}}
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

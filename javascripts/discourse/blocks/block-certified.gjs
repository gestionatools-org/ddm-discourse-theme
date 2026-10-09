import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import Category from "discourse/models/category";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { loadCategoryTopics } from "../lib/category-topics";

// The newest certification posters. It replaced the ideas lane in the homepage
// panel on 2026-10-09.
//
// Titles, not images: even after the 2026-10-09 backfill only 83 of
// Comparte's ~178 `poster-evf` topics on PROD carry an `image_url`, so a
// thumbnail list would skip most new certifications — and images appear only
// in the carousel above Comparte's own listing, by agreement.
// "Administración Avanzada · 8 oct 2026": the programme is the poster's
// subcategory and the date is when it was posted. Short month so the line fits
// on one row at the panel's narrowest width; locale from `<html lang>` so it
// follows the Discourse UI rather than the browser.
function posterMeta(topic) {
  const programme = Category.findById(topic.category_id)?.name;
  const date = new Intl.DateTimeFormat(
    document.documentElement.lang || undefined,
    { day: "numeric", month: "short", year: "numeric" }
  ).format(new Date(topic.created_at));

  return {
    text: programme ? `${programme} · ${date}` : date,
    iso: new Date(topic.created_at).toISOString(),
  };
}

// One row: the title over a grey line, behind the 3px brand edge. No icon per
// row — the medal heads the lane once — and no avatar: the posters are
// published by tutors and staff on the certified user's behalf, so the avatar
// would show the wrong person.
const CertifiedItem = <template>
  <li class="block-certified__item">
    <a class="block-certified__item-link" href={{@topic.url}}>
      {{#let (posterMeta @topic) as |meta|}}
        <span class="block-certified__item-title">
          {{! `fancy_title` is already HTML; core renders it raw too. }}
          {{trustHTML @topic.fancy_title}}
        </span>
        <time class="block-certified__item-meta" datetime={{meta.iso}}>
          {{meta.text}}
        </time>
      {{/let}}
    </a>
  </li>
</template>;

@block("theme:espublico:certified", {
  description: "Newest certification posters, linked to their topics",
  args: {
    title: { type: "string" },
    linkText: { type: "string" },
    emptyText: { type: "string" },
    categoryId: { type: "number", required: true },
    count: { type: "number", default: 6 },
    // Matched server-side across the whole subtree. A tag that stops existing
    // empties the lane in silence — the listing answers 200 with no topics.
    tag: { type: "string", required: true },
  },
})
export default class BlockCertified extends Component {
  @service store;

  // The category's own "About" topic, read off its preloaded `topic_url`
  // rather than configured: on 2026-10-09 it was /t/2360 on both instances,
  // but nothing guarantees that ids stay in step between them.
  get linkUrl() {
    return Category.findById(this.args.categoryId)?.topic_url;
  }

  @bind
  async fetchTopics() {
    // Creation order: a reply to an old poster must not move it to the top of
    // a lane that announces the latest certifications.
    return await loadCategoryTopics(
      this.store,
      this.args.categoryId,
      this.args.count,
      { tag: this.args.tag, order: "created" }
    );
  }

  <template>
    <section class="block-certified">
      <header class="block-certified__header">
        {{! `medal` is outside core's default icon subset and is listed in
            about.json's `svg_icons` — without that it renders as an empty box
            and every test still passes. }}
        <h2 class="block-certified__title">
          {{dIcon "medal"}}
          {{i18n (themePrefix @title)}}
        </h2>
      </header>

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="block-certified__loading"><div class="spinner" /></div>
        </:loading>

        <:empty>
          <p class="block-certified__empty">
            {{i18n (themePrefix @emptyText)}}
          </p>
        </:empty>

        <:content as |topics|>
          <ul class="block-certified__list">
            {{#each topics key="id" as |topic|}}
              <CertifiedItem @topic={{topic}} />
            {{/each}}
          </ul>
        </:content>
      </DAsyncContent>

      {{! A footer, not a trailing heading link: at the panel's ~430px a heading
          with a link beside it wraps onto two lines. }}
      {{#if this.linkUrl}}
        <footer class="block-certified__footer">
          <DButton
            class="btn-flat block-certified__link"
            @href={{this.linkUrl}}
            @translatedLabel={{i18n (themePrefix @linkText)}}
          />
        </footer>
      {{/if}}
    </section>
  </template>
}

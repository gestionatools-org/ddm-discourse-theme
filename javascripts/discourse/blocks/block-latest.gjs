import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import TopicList from "discourse/components/topic-list/list";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { loadLatestTopics } from "../lib/category-topics";

// The site-wide latest topics, rendered with core's own topic list.
//
// This lane used to print a hand-rolled `<ul>` of titles and excerpts. It
// renders `discourse/components/topic-list/list` instead — the same component
// every listing uses — for three reasons, all of them measured rather than
// assumed:
//
//   - It is what the reference does. community.hubspot.com's own "Temas
//     recientes" section is a real `table.topic-list` with core's classes,
//     checked live on 2026-08-28: `main-link`, `posters`, `num posts`, `views`,
//     `activity`.
//   - The theme already styles that table — `stylesheets/app/topic-list.scss`
//     puts its header on `--ga-muted`, swaps core's borders for the brand
//     hairline and forces tabular figures. The list arrives on the homepage
//     already wearing the brand, with no new SCSS.
//   - Reply, view and activity counts are the signal a "what's new" lane is
//     for, and reimplementing any of them would be rebuilding core badly.
//
// What is given up here is the excerpt: the native list has no room for one.
// `serialize_topic_excerpts` (about.json) is still earned, though — the
// community-highlights content cards read `topic.excerpt`.
//
// `import TopicList from "discourse/components/topic-list/list"` and **not**
// `discourse/components/topic-list`, which is a deprecated shim that logs
// `discourse.legacy-topic-list` and curries straight through to this one.
@block("theme:espublico:latest", {
  description: "The site-wide latest topics, as core's own topic list",
  args: {
    title: { type: "string" },
    linkText: { type: "string" },
    linkUrl: { type: "string" },
    count: { type: "number", default: 8 },
  },
})
export default class BlockLatest extends Component {
  @service store;

  @bind
  async fetchTopics() {
    return await loadLatestTopics(this.store, this.args.count);
  }

  <template>
    <section class="block-latest">
      <header class="block-latest__header">
        <h2 class="block-latest__title">
          {{dIcon "newspaper"}}
          {{i18n (themePrefix @title)}}
        </h2>
        {{#if @linkUrl}}
          <DButton
            class="btn-flat block-latest__link"
            @href={{@linkUrl}}
            @translatedLabel={{i18n (themePrefix @linkText)}}
          />
        {{/if}}
      </header>

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="block-latest__loading"><div class="spinner" /></div>
        </:loading>

        <:empty>
          <p class="block-latest__empty">{{i18n
              (themePrefix "homepage.latest.empty")
            }}</p>
        </:empty>

        <:content as |topics|>
          {{! `showPosters` opts into the participants column — the one column
              that carries faces rather than numbers, and the reason the
              reference's list reads as a community rather than as a report.

              No `bulkSelectHelper` and no `canBulkSelect`: bulk selection
              belongs to a moderator working through a real listing, and the
              checkbox column would cost the title width it needs here. }}
          <TopicList @topics={{topics}} @showPosters={{true}} />
        </:content>
      </DAsyncContent>
    </section>
  </template>
}

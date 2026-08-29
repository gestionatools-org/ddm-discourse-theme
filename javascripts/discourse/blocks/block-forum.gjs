import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import { and, not } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { loadCategoryTopics } from "../lib/category-topics";

@block("theme:espublico:forum", {
  description: "Recent discussion, with reply counts as the primary signal",
  args: {
    title: { type: "string" },
    linkText: { type: "string" },
    linkUrl: { type: "string" },
    // An arg, not a constant: this component used to back two lanes — the forum
    // and "Tengo una idea" — and only the icon told them apart. The forum lane
    // is gone but the parameterisation stays, so a second lane can return
    // without forking the component. Any icon outside core's default Font
    // Awesome subset also needs an entry in about.json's `svg_icons`, which
    // nothing here can check: dIcon writes the `d-icon-<name>` class whether or
    // not the sprite carries the symbol, so a missing entry renders an empty
    // box and every test still passes.
    icon: { type: "string", default: "far-comments" },
    // Also an arg for reuse, not a constant. A lane that announces the wrong
    // absence — "no conversations" under a heading that asks for ideas — is the
    // kind of thing nobody notices and nobody can explain later. The ideas lane
    // passes `homepage.ideas.empty`; this default is the component's own.
    emptyText: { type: "string", default: "homepage.forum.empty" },
    categoryId: { type: "number", required: true },
    count: { type: "number", default: 6 },
    // The panel variant. In the homepage panel this lane is a list inside a
    // section, not a section of its own: at ~430px a heading with a trailing
    // link wraps onto two lines and starts reading as a second section. So the
    // modifier drops the link and the SCSS tightens the rest.
    compact: { type: "boolean", default: false },
  },
})
export default class BlockForum extends Component {
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
    {{! A standalone `--modifier` class, not `block-forum--compact`: the
        theme's BEM convention keeps modifiers separable so a rule can target
        the state without restating the block. }}
    <section class="block-forum {{if @compact '--compact'}}">
      <header class="block-forum__header">
        <h2 class="block-forum__title">
          {{dIcon @icon}}
          {{i18n (themePrefix @title)}}
        </h2>
        {{#if (and @linkUrl (not @compact))}}
          <DButton
            class="btn-flat block-forum__link"
            @href={{@linkUrl}}
            @translatedLabel={{i18n (themePrefix @linkText)}}
          />
        {{/if}}
      </header>

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="block-forum__loading"><div class="spinner" /></div>
        </:loading>

        <:empty>
          <p class="block-forum__empty">{{i18n (themePrefix @emptyText)}}</p>
        </:empty>

        <:content as |topics|>
          <ul class="block-forum__list">
            {{#each topics as |topic|}}
              <li class="block-forum__item">
                <a class="block-forum__item-link" href={{topic.url}}>
                  <span class="block-forum__item-title">
                    {{! `fancy_title` is already HTML. dReplaceEmoji escapes its input
                        before substituting, so passing it through here double-encodes and
                        renders "&rsquo;" as literal text. Core renders it raw too. }}
                    {{trustHTML topic.fancy_title}}
                  </span>
                </a>
                {{! Reply count is this lane's reason to exist: these threads
                    average 4.5 replies, so the number is the proof of life. }}
                <span
                  class="block-forum__item-replies"
                  aria-label={{i18n
                    (themePrefix "homepage.forum.replies")
                    count=topic.reply_count
                  }}
                >
                  {{dIcon "reply"}}
                  <span aria-hidden="true">{{topic.reply_count}}</span>
                </span>
              </li>
            {{/each}}
          </ul>
        </:content>
      </DAsyncContent>
    </section>
  </template>
}

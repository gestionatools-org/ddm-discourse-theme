import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import lightbox from "discourse/lib/lightbox";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { definitionTopicIds, parseCategoryIds } from "../lib/category-topics";
import { loadPosters, posterImage, posterSize } from "../lib/posters";

// Certified users' posters above the topic list of Comparte and its
// subcategories. Mounted next to `DiscoveryHero` in
// `discovery-list-controls-above` — a plugin outlet, not a Block: the Blocks
// API stays confined to the homepage.
//
// The image opens core's lightbox (the same PhotoSwipe a post uses, bound to
// every `.lightbox` anchor inside the track); the caption links to the topic.
// A portrait poster is unreadable at slide size, so the lightbox is how it is
// read without leaving the listing.
//
// No visible heading: the posters speak for themselves above the list. The
// region keeps its name for screen readers through `aria-label`.
export default class PosterCarousel extends Component {
  @service store;

  @tracked atStart = true;
  @tracked atEnd = false;

  track = null;

  bindLightbox = modifier((element) => {
    lightbox(element);
  });

  registerTrack = modifier((element) => {
    this.track = element;
    const update = () => this.updateEnds();
    // Not synchronously: these flags were read earlier in this same render,
    // and writing them now would trip Glimmer's backtracking assertion.
    schedule("afterRender", update);
    element.addEventListener("scroll", update, { passive: true });
    return () => {
      element.removeEventListener("scroll", update);
      this.track = null;
    };
  });

  get categoryId() {
    const id = Number(this.args.category?.id);
    const listed = parseCategoryIds(settings.poster_carousel_category_ids);
    return listed.includes(id) ? id : null;
  }

  // A new promise per category. `DAsyncContent` renders only the promise it
  // currently holds, so a response for a category the reader has already left
  // is never shown. `@context` is not used: the pinned `@discourse/types`
  // predate it and PRE runs core 2026.8.
  @cached
  get posters() {
    const categoryId = this.categoryId;
    if (!categoryId) {
      return null;
    }

    return loadPosters(this.store, categoryId, {
      tag: settings.poster_carousel_tag,
      count: settings.poster_carousel_count,
      excludeIds: definitionTopicIds(),
    }).then(
      (topics) =>
        topics.length >= settings.poster_carousel_min ? topics : null,
      // A member without access to a child gets a 403; the topic list below
      // must not be disturbed by a flash error for a decorative strip.
      () => null
    );
  }

  updateEnds() {
    const track = this.track;
    if (!track) {
      return;
    }
    this.atStart = track.scrollLeft <= 1;
    this.atEnd = track.scrollLeft + track.clientWidth >= track.scrollWidth - 1;
  }

  @action
  scroll(direction) {
    const reduce = window.matchMedia?.(
      "(prefers-reduced-motion: reduce)"
    ).matches;
    this.track?.scrollBy({
      left: direction * this.track.clientWidth,
      behavior: reduce ? "auto" : "smooth",
    });
  }

  <template>
    {{#if this.categoryId}}
      <DAsyncContent @asyncData={{this.posters}}>
        <:loading></:loading>
        <:empty></:empty>
        <:content as |topics|>
          <section
            class="poster-carousel"
            aria-label={{i18n (themePrefix "poster_carousel.title")}}
          >
            <header class="poster-carousel__header">
              <div class="poster-carousel__nav">
                <DButton
                  class="btn-flat poster-carousel__prev"
                  @icon="chevron-left"
                  @ariaLabel={{themePrefix "poster_carousel.previous"}}
                  @disabled={{this.atStart}}
                  @action={{fn this.scroll -1}}
                />
                <DButton
                  class="btn-flat poster-carousel__next"
                  @icon="chevron-right"
                  @ariaLabel={{themePrefix "poster_carousel.next"}}
                  @disabled={{this.atEnd}}
                  @action={{fn this.scroll 1}}
                />
              </div>
            </header>
            <ul
              class="poster-carousel__track"
              {{this.registerTrack}}
              {{this.bindLightbox}}
            >
              {{#each topics key="id" as |topic|}}
                <li class="poster-carousel__item">
                  {{! The size spares core's lightbox from preloading every full
                      image on render to measure it. }}
                  {{#let (posterSize topic) as |size|}}
                    <a
                      class="lightbox poster-carousel__media"
                      href={{topic.image_url}}
                      title={{topic.title}}
                      data-target-width={{size.width}}
                      data-target-height={{size.height}}
                    >
                      <img
                        src={{posterImage topic}}
                        alt={{topic.title}}
                        loading="lazy"
                      />
                    </a>
                  {{/let}}
                  <a class="poster-carousel__caption" href={{topic.url}}>
                    {{trustHTML topic.fancy_title}}
                  </a>
                </li>
              {{/each}}
            </ul>
          </section>
        </:content>
      </DAsyncContent>
    {{/if}}
  </template>
}

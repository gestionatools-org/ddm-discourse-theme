import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { youtubeThumbnail } from "../lib/highlights";

// The 16:9 card. Presentational: the block resolves the topic and the video id
// and hands them down; the only state here is whether the viewer has pressed
// play. With a video id the thumbnail swaps for an embedded player that plays in
// place — on www.youtube.com/embed, the host Discourse's own lazy-video uses, so
// it clears the frame-src allowlist. Without a video id the thumbnail is just a
// link to the topic.
export default class HighlightPodcastCard extends Component {
  @tracked playing = false;

  get thumbnail() {
    return this.args.videoId
      ? youtubeThumbnail(this.args.videoId)
      : this.args.topic.image_url;
  }

  get embedUrl() {
    return `https://www.youtube.com/embed/${this.args.videoId}?autoplay=1`;
  }

  @action
  play() {
    this.playing = true;
  }

  <template>
    <article class="highlight-card highlight-podcast">
      <div class="highlight-podcast__frame">
        {{#if this.playing}}
          <iframe
            class="highlight-podcast__player"
            src={{this.embedUrl}}
            title={{i18n (themePrefix "homepage.highlights.podcast.label")}}
            allow="autoplay; encrypted-media; picture-in-picture"
            allowfullscreen
          ></iframe>
        {{else if @videoId}}
          <button
            type="button"
            class="highlight-podcast__play"
            aria-label={{i18n (themePrefix "homepage.highlights.podcast.play")}}
            {{on "click" this.play}}
          >
            {{#if this.thumbnail}}
              <img src={{this.thumbnail}} alt="" loading="lazy" />
            {{/if}}
            <span class="highlight-podcast__play-icon">{{dIcon "play"}}</span>
          </button>
        {{else}}
          <a href={{@topic.url}} class="highlight-podcast__link">
            {{#if this.thumbnail}}
              <img src={{this.thumbnail}} alt="" loading="lazy" />
            {{else}}
              <span class="highlight-card__placeholder">{{dIcon
                  "podcast"
                }}</span>
            {{/if}}
          </a>
        {{/if}}
      </div>

      <div class="highlight-card__body">
        <div class="highlight-card__label">
          {{dIcon "podcast"}}
          {{i18n (themePrefix "homepage.highlights.podcast.label")}}
        </div>
        <h3 class="highlight-card__title">
          <a href={{@topic.url}}>{{trustHTML @topic.fancy_title}}</a>
        </h3>
        <DButton
          class="btn-flat highlight-card__cta"
          @href={{@topic.url}}
          @translatedLabel={{i18n
            (themePrefix "homepage.highlights.podcast.cta")
          }}
        />
      </div>
    </article>
  </template>
}

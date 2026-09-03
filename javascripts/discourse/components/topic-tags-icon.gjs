import dIcon from "discourse/ui-kit/helpers/d-icon";

// The `tag` glyph that introduces the tag row under a topic title.
//
// It is a component of its own, separate from the tags, because core builds
// that row as an HTML string — `lib/render-tags.js`, reached through the
// `d-discourse-tags` helper — so no template can insert anything into the
// list. This mounts as a sibling of the list inside the same flex row instead,
// and `tagging.scss` reorders the row so the icon lands in front of it. The
// alternative was a connector on `topic-category-wrapper`, which replaces
// core's default block and would have meant re-implementing the category link
// as well.
//
// `tag` needs no `svg_icons` entry: it is in core's default FontAwesome subset
// (`.claude/skills/discourse-theme-authoring/icons.md`). Worth stating,
// because `dIcon` writes its class whether or not the sprite carries the
// symbol, so a missing entry fails silently and no test can catch it.
//
// `aria-hidden`: the `<ul>` core builds already carries an `aria-label` of
// `tagging.tags`, so the icon would only repeat it.
const TopicTagsIcon = <template>
  {{#if @outletArgs.topic.tags.length}}
    <span class="topic-tags-icon" aria-hidden="true">{{dIcon "tag"}}</span>
  {{/if}}
</template>;

export default TopicTagsIcon;

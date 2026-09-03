import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dIcon from "discourse/ui-kit/helpers/d-icon";

// The tag row at the foot of a topic. Core renders tags under the title and
// nowhere else; a member who has read a long thread has to scroll back up to
// see what it is filed under, which is the whole point of repeating them here.
//
// The list itself comes from core's own helper rather than hand-rolled markup,
// so the tag hrefs, the `tag-separator` transformer, per-tag descriptions and
// the private-message case all stay core's business.
//
// No `mode="list"`: that switches the helper to `visibleListTags`, which drops
// tags whose name already appears in the title when
// `suppress_overlapping_tags_in_list` is on. That trim is for *listings*, where
// the title sits inches from the tag. The foot of a topic is not a listing, and
// this row is the one place the full set should be legible.
const TopicFooterTags = <template>
  {{#if @outletArgs.model.tags.length}}
    <div class="topic-footer-tags">
      <span aria-hidden="true">{{dIcon "tag"}}</span>
      {{dDiscourseTags @outletArgs.model}}
    </div>
  {{/if}}
</template>;

export default TopicFooterTags;

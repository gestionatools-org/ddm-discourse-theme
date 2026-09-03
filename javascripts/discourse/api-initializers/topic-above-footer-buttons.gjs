import { apiInitializer } from "discourse/lib/api";
import TopicFooterTags from "../components/topic-footer-tags";

// `topic-above-footer-buttons` sits immediately after the last post and above
// the reply/bookmark/share row (`templates/topic.gjs`), which is what "the foot
// of the topic" means here. Its neighbour `topic-above-suggested` renders below
// those buttons instead, where a tag row would read as a heading for
// "Suggested topics" rather than as metadata belonging to the thread.
//
// Core wraps this outlet in `{{#if loadedAllPosts}}` and `{{#if currentUser}}`.
// The first is what makes it a footer at all; the second costs nothing on an
// instance that is `login_required`, which both of ours are.
//
// Its outlet argument is `model` — the topic — not `topic`, which is what the
// `topic-category` outlet passes. Same object, different name.
export default apiInitializer((api) => {
  api.renderInOutlet("topic-above-footer-buttons", TopicFooterTags);
});

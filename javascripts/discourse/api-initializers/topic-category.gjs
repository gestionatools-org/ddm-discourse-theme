import { apiInitializer } from "discourse/lib/api";
import TopicTagsIcon from "../components/topic-tags-icon";

// `topic-category` is the outlet at the end of core's `TopicCategory`
// component — the metadata row core renders directly under the topic `<h1>`
// (`templates/topic.gjs`, inside `<TopicTitle>`). Its outlet arguments are
// `topic` and `category`, and `topic` is all this needs.
//
// A plugin outlet rather than a block: Blocks are agreed to stay confined to
// the custom homepage, and there is no Blocks outlet on the topic page anyway
// — the five are `hero-blocks`, `homepage-blocks`, `main-outlet-blocks`,
// `sidebar-blocks` and `sidebar-discovery`, and themes cannot register more.
export default apiInitializer((api) => {
  api.renderInOutlet("topic-category", TopicTagsIcon);
});

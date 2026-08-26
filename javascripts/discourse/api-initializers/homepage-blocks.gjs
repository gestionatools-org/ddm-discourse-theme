import BlockGroup from "discourse/blocks/builtin/block-group";
import { apiInitializer } from "discourse/lib/api";
import BlockEvents from "../blocks/block-events";
import BlockForum from "../blocks/block-forum";
import BlockLibrary from "../blocks/block-library";
import BlockNews from "../blocks/block-news";
import BlockShowcase from "../blocks/block-showcase";
import { parseCategoryIds } from "../lib/category-topics";

// The homepage is composed of six lanes. Every lane but the first is keyed by
// category ID because this instance's slugs are legacy and no longer match
// their category; the news lane is site-wide and has no category to lose.
//
// Each lane's shape follows how its category is actually used, measured rather
// than assumed: conversational categories get topic lists with reply counts,
// the poster category gets an image grid, and the reference tree gets directory
// cards with no topic list at all (66 topics, zero replies in its history).
//
// No user or group conditions: every member of this community is a student, so
// the only split is anonymous vs. signed in, which category permissions already
// enforce server-side.
export default apiInitializer((api) => {
  api.renderBlocks("homepage-blocks", [
    {
      block: BlockGroup,
      id: "home-main",
      children: [
        {
          block: BlockNews,
          id: "home-news",
          args: {
            title: "homepage.news.title",
            linkText: "homepage.news.link_text",
            linkUrl: "/latest",
            count: settings.news_count,
          },
        },
        {
          block: BlockForum,
          id: "home-forum",
          args: {
            title: "homepage.forum.title",
            linkText: "homepage.forum.link_text",
            linkUrl: `/c/${settings.forum_category_id}`,
            categoryId: settings.forum_category_id,
            count: settings.forum_count,
          },
        },
        {
          // The same block again, not a new one: BlockForum is fully
          // parameterised and its shape — a topic list with the reply count
          // promoted — is what a category at 3.6 replies/topic wants. Only the
          // icon had to be lifted out of the template to tell the two apart.
          block: BlockForum,
          id: "home-ideas",
          args: {
            title: "homepage.ideas.title",
            linkText: "homepage.ideas.link_text",
            linkUrl: `/c/${settings.ideas_category_id}`,
            icon: "lightbulb",
            emptyText: "homepage.ideas.empty",
            categoryId: settings.ideas_category_id,
            count: settings.ideas_count,
          },
        },
      ],
    },
    {
      block: BlockGroup,
      id: "home-side",
      children: [
        {
          block: BlockEvents,
          id: "home-events",
          args: {
            title: "homepage.events.title",
            linkText: "homepage.events.link_text",
            linkUrl: `/c/${settings.events_category_id}`,
            categoryId: settings.events_category_id,
            count: settings.events_count,
          },
        },
      ],
    },
    {
      block: BlockShowcase,
      id: "home-showcase",
      args: {
        title: "homepage.showcase.title",
        linkText: "homepage.showcase.link_text",
        linkUrl: `/c/${settings.showcase_category_id}`,
        categoryId: settings.showcase_category_id,
        count: settings.showcase_count,
      },
    },
    {
      block: BlockLibrary,
      id: "home-library",
      args: {
        title: "homepage.library.title",
        categoryIds: parseCategoryIds(settings.library_category_ids),
      },
    },
  ]);
});

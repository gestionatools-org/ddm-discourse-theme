import BlockGroup from "discourse/blocks/builtin/block-group";
import { apiInitializer } from "discourse/lib/api";
import BlockForum from "../blocks/block-forum";
import BlockHero from "../blocks/block-hero";
import BlockLatest from "../blocks/block-latest";
import BlockLibrary from "../blocks/block-library";
import BlockShortcuts from "../blocks/block-shortcuts";
import BlockShowcase from "../blocks/block-showcase";
import { parseCategoryIds } from "../lib/category-topics";

// The homepage is a heading band and then a stack of **sections**, each of which
// may split into two columns of its own. That is the shape the reference runs —
// community.hubspot.com, measured on 2026-08-28: three full-width sections in a
// flex column, with the two-column split happening *inside* the first two.
//
// It replaced a global two-column grid that never worked. `layouts/homepage.scss`
// has always carried `@container homepage-blocks (width > 60rem)`, but nothing
// declared that container — not the theme, not core — so the query never
// matched and the homepage was a single column for its whole life. The events
// lane was not "in the right-hand column"; it was fifth in a stack.
//
// Every lane but the first is keyed by category ID because this instance's slugs
// are legacy and no longer match their category; the latest lane is site-wide
// and has no category to lose.
//
// No user or group conditions: every member of this community is a student, so
// the only split is anonymous vs. signed in, which category permissions already
// enforce server-side.
export default apiInitializer((api) => {
  api.renderBlocks("homepage-blocks", [
    // The band, ahead of every section. It takes no args of its own — the same
    // component and resolver the category pages use, called with no context so
    // it renders the community copy.
    {
      block: BlockHero,
      id: "home-hero",
    },

    // Section 1. The reading column and its panel.
    {
      block: BlockGroup,
      id: "home-latest",
      children: [
        {
          block: BlockLatest,
          id: "latest-list",
          args: {
            title: "homepage.latest.title",
            linkText: "homepage.latest.link_text",
            linkUrl: "/latest",
            count: settings.latest_count,
          },
        },
        {
          // A group inside a group, which the Blocks API supports explicitly.
          // It exists so the panel's own two cards stack against each other
          // rather than becoming two more cells of the section's grid.
          block: BlockGroup,
          id: "latest-panel",
          children: [
            {
              block: BlockShortcuts,
              id: "panel-shortcuts",
              args: {
                title: "homepage.shortcuts.title",
                newTopicText: "homepage.shortcuts.new_topic",
              },
            },
            {
              // The ideas lane, moved out of the stack and into the panel.
              // Category 18 is the largest on the site (441 topics, 3.6
              // replies/topic) and its listing answers even on a dormant
              // instance, so this is the one panel slot that is never empty.
              block: BlockForum,
              id: "panel-ideas",
              args: {
                title: "homepage.ideas.title",
                linkText: "homepage.ideas.link_text",
                linkUrl: `/c/${settings.ideas_category_id}`,
                icon: "lightbulb",
                emptyText: "homepage.ideas.empty",
                categoryId: settings.ideas_category_id,
                count: settings.panel_ideas_count,
                compact: true,
              },
            },
          ],
        },
      ],
    },

    // Sections 2 and 3 are not decided yet. Until they are, these three lanes
    // keep rendering full width, one below the other, exactly as they did
    // before — the section frame above needs no change to absorb them later.
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
      block: BlockShowcase,
      id: "home-showcase",
      args: {
        title: "homepage.showcase.title",
        linkText: "homepage.showcase.link_text",
        linkUrl: `/c/${settings.showcase_category_id}`,
        categoryId: settings.showcase_category_id,
        count: settings.showcase_count,
        tag: settings.showcase_tag,
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

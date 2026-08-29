import BlockGroup from "discourse/blocks/builtin/block-group";
import { apiInitializer } from "discourse/lib/api";
import BlockEvents from "../blocks/block-events";
import BlockForum from "../blocks/block-forum";
import BlockHero from "../blocks/block-hero";
import BlockHighlights from "../blocks/block-highlights";
import BlockLatest from "../blocks/block-latest";

// The homepage is a heading band and then section 1: a reading column and a
// panel beside it. The panel holds two cards — the events lane ("Agenda del
// certificado") and the ideas lane ("Tengo una idea") — stacked against the
// site-wide latest list.
//
// The section frame is a container query in `layouts/homepage.scss`. It
// replaced a page-level two-column grid that never worked: the file carried
// `@container homepage-blocks (...)` since the homepage was written, but
// nothing declared that container — not the theme, not core — so the query
// never matched and the page was a single stacked column for its whole life.
//
// The events and ideas lanes are keyed by category ID because this instance's
// slugs are legacy and no longer match their category; the latest list is
// site-wide and has no category to lose.
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
              // The events lane, in the slot the "Empieza aquí" shortcuts card
              // used to hold. Its own SCSS already makes it a card on
              // `--ga-muted`, so it drops into the panel without a change.
              // `event_starts_at` reaches the topic list only while
              // discourse-calendar's `display_post_event_date_on_topic_title`
              // is on — it is, on this instance — otherwise every row falls
              // back to the topic's own date.
              block: BlockEvents,
              id: "panel-events",
              args: {
                title: "homepage.events.title",
                linkText: "homepage.events.link_text",
                linkUrl: `/c/${settings.events_category_id}`,
                categoryId: settings.events_category_id,
                count: settings.events_count,
              },
            },
            {
              // The ideas lane. Category 18 is the largest on the site (441
              // topics, 3.6 replies/topic) and its listing answers even on a
              // dormant instance, so this is the one panel slot that is never
              // empty.
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

    // Section 2. The community highlights bento — see
    // docs/superpowers/specs/2026-08-29-community-highlights-design.md. Its own
    // SCSS carries the grid; here it is just one more section of the stack.
    {
      block: BlockHighlights,
      id: "home-highlights",
      args: {
        title: "homepage.highlights.title",
        podcastTag: settings.highlights_podcast_tag,
        newsletterTag: settings.highlights_newsletter_tag,
        newsTag: settings.highlights_news_tag,
        memberPeriod: settings.highlights_member_period,
      },
    },
  ]);
});

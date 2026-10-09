import BlockGroup from "discourse/blocks/builtin/block-group";
import { apiInitializer } from "discourse/lib/api";
import BlockCertified from "../blocks/block-certified";
import BlockEvents from "../blocks/block-events";
import BlockHero from "../blocks/block-hero";
import BlockHighlights from "../blocks/block-highlights";
import BlockLatest from "../blocks/block-latest";

// The homepage is a heading band, then section 1 — a reading column and a panel
// beside it — then section 2, the community-highlights bento. The panel holds
// two cards, the events lane ("Agenda del certificado") and the certified-users
// lane ("Recursos compartidos"), stacked against the site-wide latest list;
// section 2 is a four-card grid (podcast · newsletter · novedad · member of
// the month) that renders only when at least one of its content tags is set.
//
// The section frame is a container query in `layouts/homepage.scss`. It
// replaced a page-level two-column grid that never worked: the file carried
// `@container homepage-blocks (...)` since the homepage was written, but
// nothing declared that container — not the theme, not core — so the query
// never matched and the page was a single stacked column for its whole life.
//
// The events and certified-users lanes are keyed by category ID because this instance's
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
          // No `linkUrl`, so the heading is a heading and nothing else — the
          // same call as the events lane above. Core's own list already ends
          // in its navigation, and every row is a way into the site.
          // `BlockLatest` keeps the arg, so restoring the button is two lines
          // here rather than a change to the block.
          block: BlockLatest,
          id: "latest-list",
          args: {
            title: "homepage.latest.title",
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
              //
              // No `linkUrl`, so no "Ver agenda" footer: the lane is a glance
              // at what is coming, and a reader who wants the category can
              // click any row to land in it. `BlockEvents` keeps the arg — the
              // latest lane still passes one — so restoring the button is two
              // lines here rather than a change to the block.
              block: BlockEvents,
              id: "panel-events",
              args: {
                title: "homepage.events.title",
                categoryId: settings.events_category_id,
                count: settings.events_count,
              },
            },
            {
              // The certified-users lane, in the slot the ideas lane held until
              // 2026-10-09: the newest certification posters across Comparte
              // and its subcategories. The tag is the carousel's, so one
              // setting says what a poster is. Each subcategory is restricted
              // to its programme's group, so a member sees the posters of the
              // programmes they belong to — permissions are enforced by the
              // listing, not here.
              block: BlockCertified,
              id: "panel-certified",
              args: {
                title: "homepage.certified.title",
                linkText: "homepage.certified.link_text",
                emptyText: "homepage.certified.empty",
                categoryId: settings.certified_category_id,
                count: settings.certified_count,
                tag: settings.poster_carousel_tag,
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
        entityFieldId: settings.highlights_member_entity_field_id,
        roleFieldId: settings.highlights_member_role_field_id,
      },
    },
  ]);
});

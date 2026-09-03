import { definitionTopicIds } from "./category-topics";

// Only decides WHO wins the member card — the card shows raw figures, never
// this score. A one-line edit changes the emphasis; deliberately not four
// theme settings. `days_visited` stands in for "time on the platform" because
// this Discourse version's directory serializer omits `time_read`.
export const WEIGHTS = { posts: 0.5, likes: 0.35, days: 0.15 };

/**
 * The most recent non-definition topic carrying `tag`, or null.
 *
 * An empty `tag` returns null without touching the network — the guard that
 * stops an unset setting becoming the filter `tag//l/latest`. Definition topics
 * are dropped for the same reason `loadCategoryTopics` drops them: they are
 * pinned "Acerca de la categoría …" boilerplate.
 *
 * @param {Object} store - the injected store service
 * @param {String} tag - tag slug, exactly as in /tag/<slug>
 * @returns {Promise<Object|null>}
 */
export async function loadLatestTaggedTopic(store, tag) {
  if (!tag) {
    return null;
  }

  const topicList = await store.findFiltered("topicList", {
    filter: `tag/${tag}/l/latest`,
  });

  const definitions = definitionTopicIds();
  const topic = topicList?.topics?.find((t) => !definitions.has(t.id));

  return topic ?? null;
}

/**
 * The first YouTube video id in a cooked post, or null.
 *
 * `data-video-id` is Discourse's own lazy-video container and the reliable
 * signal; the bare-URL patterns are fallbacks for a link core did not onebox.
 * A YouTube id is always exactly 11 characters of [A-Za-z0-9_-].
 *
 * @param {String} cooked - post HTML
 * @returns {String|null}
 */
export function extractVideoId(cooked) {
  if (!cooked) {
    return null;
  }

  const patterns = [
    /data-video-id="([\w-]{11})"/,
    /youtube(?:-nocookie)?\.com\/embed\/([\w-]{11})/,
    /youtu\.be\/([\w-]{11})/,
    /[?&]v=([\w-]{11})/,
  ];

  for (const pattern of patterns) {
    const match = cooked.match(pattern);
    if (match) {
      return match[1];
    }
  }

  return null;
}

/**
 * The hqdefault thumbnail URL for a YouTube id. hqdefault (480×360) always
 * exists; maxresdefault does not for every video, so it is not used.
 *
 * @param {String} id
 * @returns {String}
 */
export function youtubeThumbnail(id) {
  return `https://i.ytimg.com/vi/${id}/hqdefault.jpg`;
}

/**
 * The directory item with the highest weighted-composite activity, or null for
 * an empty list.
 *
 * Each of post_count, likes_received and days_visited is normalised against the
 * maximum in `items` (a field whose max is 0 contributes 0), then combined by
 * `weights`. Ties keep the earlier item.
 *
 * @param {Array<Object>} items - directory_items entries
 * @param {{posts:Number,likes:Number,days:Number}} weights
 * @returns {Object|null}
 */
export function rankTopMember(items, weights) {
  if (!items?.length) {
    return null;
  }

  const ceiling = (key) => Math.max(0, ...items.map((it) => it[key] || 0));
  const maxPosts = ceiling("post_count");
  const maxLikes = ceiling("likes_received");
  const maxDays = ceiling("days_visited");

  const norm = (value, max) => (max > 0 ? (value || 0) / max : 0);

  const score = (it) =>
    weights.posts * norm(it.post_count, maxPosts) +
    weights.likes * norm(it.likes_received, maxLikes) +
    weights.days * norm(it.days_visited, maxDays);

  return items.reduce((best, it) => (score(it) > score(best) ? it : best));
}

/**
 * Whether a directory item represents real participation this period. The
 * guard for a quiet instance, where the ranking would otherwise crown someone
 * with no posts and no likes (PRE's 30-day directory is all zeros today).
 *
 * @param {Object|null} item
 * @returns {Boolean}
 */
export function memberHasActivity(item) {
  return Boolean(item && (item.post_count > 0 || item.likes_received > 0));
}

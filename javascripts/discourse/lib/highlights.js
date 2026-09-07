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
 * Parse cooked post HTML into a detached document, or null for nothing.
 *
 * `DOMParser` fetches nothing — no image, stylesheet or script in the parsed
 * markup is loaded — so this is a cheap, inert read of someone else's HTML. The
 * three extractors below share it; `extractVideoId` stays on regexes because it
 * reads an attribute value rather than the tree.
 *
 * @param {String} cooked - post HTML
 * @returns {Document|null}
 */
function parseCooked(cooked) {
  if (!cooked) {
    return null;
  }

  return new DOMParser().parseFromString(cooked, "text/html");
}

/**
 * The src of the first non-emoji image in a cooked post, or null.
 *
 * Position is no signal: the newsletter's cover is the *last* image in the
 * post, wrapped in the anchor that points at the PDF. So the discriminator is
 * "not an emoji" — checked both by `class="emoji"`, which is what core writes
 * on the tag, and by the `/images/emoji/` path it serves them from.
 *
 * The src is returned exactly as written, which for an upload is
 * protocol-relative (`//cdck-file-uploads-…`). That is a valid `src`; resolving
 * it would only risk rewriting it against the wrong origin.
 *
 * @param {String} cooked - post HTML
 * @returns {String|null}
 */
export function extractCoverImage(cooked) {
  const doc = parseCooked(cooked);
  if (!doc) {
    return null;
  }

  for (const img of doc.querySelectorAll("img")) {
    const src = img.getAttribute("src");
    if (
      src &&
      !img.classList.contains("emoji") &&
      !src.includes("/images/emoji/")
    ) {
      return src;
    }
  }

  return null;
}

/**
 * The URL of the first PDF linked from a cooked post, or null.
 *
 * `/uploads/short-url/…` is preferred over the raw storage URL: it is the link
 * core rewrites when an upload moves, and it is same-origin. It is matched by
 * href pattern rather than by `class="attachment"` — measured across three
 * newsletters on PRE, two carried the class and one did not.
 *
 * `getAttribute` rather than `.href`, so a relative href stays relative instead
 * of being resolved against whatever page did the parsing.
 *
 * @param {String} cooked - post HTML
 * @returns {String|null}
 */
export function extractPdfUrl(cooked) {
  const doc = parseCooked(cooked);
  if (!doc) {
    return null;
  }

  const isPdf = (href) => href.split(/[?#]/)[0].toLowerCase().endsWith(".pdf");

  const hrefs = Array.from(doc.querySelectorAll("a[href]"), (a) =>
    a.getAttribute("href")
  ).filter((href) => href && isPdf(href));

  return (
    hrefs.find((href) => href.includes("/uploads/short-url/")) ??
    hrefs[0] ??
    null
  );
}

/**
 * A plain-text summary of a cooked post, at most `maxLength` characters, or
 * null when the post has no text.
 *
 * This exists because `topic.excerpt` is capped at `topic_excerpt_maxlength`
 * (220 on this instance) — a site setting, so raising it would move every
 * listing on the forum to make one card longer. Reading the post gives the
 * theme its own dial.
 *
 * Only the body's top-level blocks are read: `querySelectorAll("p")` would
 * repeat the text of a paragraph nested in a quote or an aside. Emoji images
 * contribute no text and so drop out on their own.
 *
 * @param {String} cooked - post HTML
 * @param {Number} maxLength - character budget, ellipsis excluded
 * @returns {String|null}
 */
export function excerptFromCooked(cooked, maxLength) {
  const doc = parseCooked(cooked);
  if (!doc) {
    return null;
  }

  const blocks = Array.from(doc.body.children, (el) =>
    el.textContent.trim()
  ).filter(Boolean);

  const text = (blocks.length ? blocks.join(" ") : doc.body.textContent)
    .replace(/\s+/g, " ")
    .trim();

  if (!text) {
    return null;
  }

  if (text.length <= maxLength) {
    return text;
  }

  // Cut on a word boundary, then strip the punctuation the cut can leave
  // stranded before the ellipsis. One character past the budget is read so that
  // a word ending exactly on it survives instead of being thrown away; a text
  // with no space in reach falls back to a hard cut.
  const cut = text.slice(0, maxLength + 1);
  const lastSpace = cut.lastIndexOf(" ");
  const kept =
    lastSpace > 0 ? cut.slice(0, lastSpace) : text.slice(0, maxLength);

  return `${kept.replace(/[\s.,;:¡¿—–-]+$/, "")}…`;
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

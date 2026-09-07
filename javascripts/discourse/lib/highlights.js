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
 * The href of the first PDF linked from a cooked post, or null.
 *
 * An absolute URL is preferred over a `/uploads/short-url/…` path, and that
 * order is the opposite of what it first looked like it should be. **On this
 * instance no same-origin `/uploads/**` route serves anything**: measured on
 * PRE 2026-09-07, the short-url of the PDF, the same short-url without the
 * extension and with `?dl=1`, the long `/uploads/<site>/original/…` form, and
 * even the short-url of the cover image that renders perfectly on the homepage
 * all answer 404, while the storage URL answers 200 `application/pdf`. Uploads
 * are served from the external store only, which is also why cooked `<img>`
 * tags carry the absolute URL — the same anchor that renders the cover keeps
 * the short form only because core never resolves an attachment href it did
 * not tag with `data-orig-href`.
 *
 * A short-url still has to be handled rather than dropped: 9 of the 14
 * newsletters carry no absolute PDF link at all. `uploadRefFromShortUrl` turns
 * it into the reference core's own `/uploads/lookup-urls` resolves.
 *
 * Matched by href pattern rather than by `class="attachment"` — measured across
 * three newsletters, two carried the class and one did not. `getAttribute`
 * rather than `.href`, so a relative href stays relative instead of being
 * resolved against whatever page did the parsing.
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
  const isAbsolute = (href) => /^(?:https?:)?\/\//.test(href);

  const hrefs = Array.from(doc.querySelectorAll("a[href]"), (a) =>
    a.getAttribute("href")
  ).filter((href) => href && isPdf(href));

  return hrefs.find(isAbsolute) ?? hrefs[0] ?? null;
}

/**
 * The `upload://…` reference behind a `/uploads/short-url/…` href, or null for
 * any other href (including null).
 *
 * This is the form `/uploads/lookup-urls` takes — the endpoint core's own
 * client posts to when it resolves the short-url placeholders in a post. The
 * extension is part of the reference and is kept.
 *
 * @param {String|null} href
 * @returns {String|null}
 */
export function uploadRefFromShortUrl(href) {
  const match = href?.match(
    /\/uploads\/short-url\/([a-zA-Z0-9]+)(\.[a-zA-Z0-9]+)?/
  );

  return match ? `upload://${match[1]}${match[2] ?? ""}` : null;
}

// Below this, a truncated tail is a stranded fragment rather than a sentence,
// so the budget is spent and the paragraph is dropped instead.
const MIN_TAIL = 40;

/**
 * Cut `text` to `maxLength` on a word boundary, with an ellipsis.
 *
 * One character past the budget is read so that a word ending exactly on it
 * survives instead of being thrown away; a text with no space in reach falls
 * back to a hard cut. The trailing punctuation the cut can strand is stripped.
 *
 * @param {String} text
 * @param {Number} maxLength - ellipsis excluded
 * @returns {String}
 */
function truncateOnWord(text, maxLength) {
  const cut = text.slice(0, maxLength + 1);
  const lastSpace = cut.lastIndexOf(" ");
  const kept =
    lastSpace > 0 ? cut.slice(0, lastSpace) : text.slice(0, maxLength);

  return `${kept.replace(/[\s.,;:¡¿—–-]+$/, "")}…`;
}

/**
 * A cooked post's own text as an array of paragraphs, spending at most
 * `maxLength` characters across all of them, or null when the post has no text.
 *
 * Paragraphs rather than one joined string: run together, a newsletter's copy
 * reads as a wall, and the breaks are the only structure the plain text keeps.
 *
 * The budget exists because `topic.excerpt` is capped at
 * `topic_excerpt_maxlength` (220 on this instance) — a site setting, so raising
 * it would lengthen every listing on the forum to fill one card. It is set
 * deliberately larger than any card is tall: the card clips what does not fit
 * (see `block-highlights.scss`), so the text always reaches the bottom and
 * there is no gap left above the CTA.
 *
 * Only the body's top-level blocks are read: `querySelectorAll("p")` would
 * repeat the text of a paragraph nested in a quote or an aside. Emoji images
 * contribute no text and so drop out on their own.
 *
 * @param {String} cooked - post HTML
 * @param {Number} maxLength - character budget across all paragraphs
 * @returns {Array<String>|null}
 */
export function paragraphsFromCooked(cooked, maxLength) {
  const doc = parseCooked(cooked);
  if (!doc) {
    return null;
  }

  const blocks = Array.from(doc.body.children, (el) =>
    el.textContent.replace(/\s+/g, " ").trim()
  ).filter(Boolean);

  const kept = [];
  let budget = maxLength;

  for (const block of blocks) {
    if (block.length <= budget) {
      kept.push(block);
      budget -= block.length;
      continue;
    }
    if (budget >= MIN_TAIL) {
      kept.push(truncateOnWord(block, budget));
    }
    break;
  }

  return kept.length ? kept : null;
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
 * Whether a directory item represents any participation in the window.
 *
 * Turning up counts, not just posting. It used to require a post or a like,
 * which on this instance meant nobody ever qualified: measured 2026-09-07, the
 * 30-day directory returns 50 people and **not one has a post or a like**,
 * only visits. That left the card permanently on its take-part nudge. Counting
 * `days_visited` keeps the card on the month — the window whose figures it
 * shows — instead of reaching into a wider one to find somebody.
 *
 * It still refuses a genuinely absent member, which is what stops the ranking
 * crowning row zero of an all-zero directory.
 *
 * @param {Object|null} item
 * @returns {Boolean}
 */
export function memberHasActivity(item) {
  return Boolean(
    item &&
    (item.post_count > 0 || item.likes_received > 0 || item.days_visited > 0)
  );
}

/**
 * The handful of profile details the member card shows, or null.
 *
 * **Only the two configured field ids are read, never `user_fields` as a
 * whole.** On PRE, fields 1 and 3 are a NIF and a CIF carrying
 * `show_on_profile: false` — a member's own session does not receive them, but
 * an administrator's does, so a generic loop over the object would put a
 * national ID on the homepage for exactly the people most likely to be looking
 * at it. Naming the ids is what prevents that, and it is the reason they are
 * settings rather than a spread.
 *
 * A field id of 0 (the setting's "off") reads as absent, and every value is
 * normalised to null so the template can test one way.
 *
 * @param {Object|null} user - the payload of /u/<username>.json
 * @param {{entityFieldId:Number, roleFieldId:Number}} fields
 * @returns {Object|null}
 */
export function profileDetails(user, { entityFieldId, roleFieldId } = {}) {
  if (!user) {
    return null;
  }

  const field = (id) => (id ? user.user_fields?.[String(id)] || null : null);

  return {
    location: user.location || null,
    websiteName: user.website_name || null,
    websiteUrl: user.website || null,
    entity: field(entityFieldId),
    role: field(roleFieldId),
    memberSince: user.created_at || null,
  };
}

/**
 * An ISO timestamp as a month and year in `locale`, or null for anything
 * unparseable — a missing `created_at`, or a string Date rejects.
 *
 * @param {String|null} iso
 * @param {String} [locale] - falls back to the runtime's own default
 * @returns {String|null}
 */
export function monthAndYear(iso, locale) {
  if (!iso) {
    return null;
  }

  const date = new Date(iso);
  if (Number.isNaN(date.valueOf())) {
    return null;
  }

  return new Intl.DateTimeFormat(locale || undefined, {
    month: "long",
    year: "numeric",
  }).format(date);
}

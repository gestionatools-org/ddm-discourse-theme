// The carousel's slide is ~180px wide at its narrowest column count, so 360px
// covers a 2× display. On PROD (2026-10-09) that picks the 424×600 rendition of
// a portrait poster rather than the 723×1024 one `image_url` points at.
export const POSTER_THUMBNAIL_MIN_WIDTH = 360;

// 5 × 30 topics. On PROD 2026-10-09 the first page already held 12 posters with
// an image in categories 85, 94 and 83; the cap only matters where images are
// scarce, and bounds the requests a sparse category can cost.
export const POSTER_MAX_PAGES = 5;

/**
 * The image a carousel slide shows: the narrowest generated thumbnail that is
 * still sharp at the slide's size, else the topic's own image.
 *
 * @param {Object|null} topic
 * @param {Number} [minWidth]
 * @returns {String|null}
 */
export function posterImage(topic, minWidth = POSTER_THUMBNAIL_MIN_WIDTH) {
  const fit = (topic?.thumbnails ?? [])
    .filter((thumbnail) => thumbnail.url && thumbnail.width >= minWidth)
    .sort((a, b) => a.width - b.width)[0];

  return fit?.url ?? topic?.image_url ?? null;
}

/**
 * Topics that can be shown as a poster: they carry an image and are not
 * excluded (category definition topics). Order is preserved.
 *
 * Only 39 of Comparte's 176 `poster-evf` topics had an `image_url` on PROD on
 * 2026-10-09 — the rest attach the poster as a PDF, which Discourse does not
 * thumbnail — so this filter is what the carousel is mostly doing.
 *
 * @param {Array|null|undefined} topics
 * @param {Object} options
 * @param {Number} options.limit
 * @param {Set<Number>} [options.excludeIds]
 * @returns {Array}
 */
export function pickPosters(topics, { limit, excludeIds = new Set() }) {
  return (topics ?? [])
    .filter((topic) => topic.image_url && !excludeIds.has(topic.id))
    .slice(0, limit);
}

/**
 * Load up to `count` posters from a category's listing (subcategories
 * included), newest first, paging until there are enough, the listing ends, or
 * the page cap is reached.
 *
 * `order: "created"` sorts by when the topic was written, not by last activity
 * — a reply to an old poster must not move it to the front. Verified on PROD
 * 2026-10-09: `c/<id>/l/latest.json?order=created&tags[]=poster-evf` returns
 * only tagged topics, sorted by `created_at` descending.
 *
 * @param {Object} store - the injected `store` service
 * @param {Number|null} categoryId
 * @param {Object} options
 * @param {String} options.tag
 * @param {Number} options.count
 * @param {Set<Number>} [options.excludeIds]
 * @param {Number} [options.maxPages]
 * @returns {Promise<Array>}
 */
export async function loadPosters(
  store,
  categoryId,
  { tag, count, excludeIds = new Set(), maxPages = POSTER_MAX_PAGES }
) {
  if (!categoryId || !tag || !(count > 0)) {
    return [];
  }

  const posters = [];
  const seen = new Set(excludeIds);

  for (let page = 0; page < maxPages && posters.length < count; page++) {
    const params = { order: "created", tags: [tag] };
    if (page > 0) {
      params.page = page;
    }

    const list = await store.findFiltered("topicList", {
      filter: `c/${categoryId}/l/latest`,
      params,
    });

    // `seen` doubles as the exclusion set, so a topic that slid onto the next
    // page between two requests is not shown twice.
    for (const topic of pickPosters(list?.topics, {
      limit: count - posters.length,
      excludeIds: seen,
    })) {
      seen.add(topic.id);
      posters.push(topic);
    }

    if (!list?.more_topics_url) {
      break;
    }
  }

  return posters;
}

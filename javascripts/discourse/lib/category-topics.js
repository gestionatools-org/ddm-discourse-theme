import Category from "discourse/models/category";

/**
 * Load the most recent topics of a category, subcategories included.
 *
 * Returns `null` rather than an empty array when there is nothing to show, so
 * that `AsyncContent` routes to its `<:empty>` block instead of rendering an
 * empty list.
 *
 * @param {Object} store - the injected `store` service
 * @param {Number} categoryId - 0 or undefined disables the lane
 * @param {Number} count - maximum topics to return
 * @returns {Promise<Array|null>}
 */
export async function loadCategoryTopics(store, categoryId, count) {
  if (!categoryId) {
    return null;
  }

  const topicList = await store.findFiltered("topicList", {
    filter: `c/${categoryId}/l/latest`,
  });

  const topics = topicList?.topics;
  if (!topics?.length) {
    return null;
  }

  return topics.slice(0, count);
}

/**
 * Parse a `type: list` theme setting into category IDs.
 *
 * Discourse hands list settings to JavaScript as a pipe-separated **string**,
 * not an array — `"73|85|14"`. An unset setting is `""`, which splits to `[""]`,
 * so the non-finite entries have to be dropped rather than passed on as NaN.
 *
 * @param {String} value - raw setting value
 * @returns {Array<Number>}
 */
export function parseCategoryIds(value) {
  if (!value) {
    return [];
  }

  return value
    .split("|")
    .map((id) => parseInt(id, 10))
    .filter((id) => Number.isFinite(id));
}

/**
 * Resolve category IDs against the preloaded category list.
 *
 * IDs that no longer resolve are dropped rather than rendered as blanks, so a
 * category deleted in admin degrades to one missing card.
 *
 * @param {Array<Number>} ids
 * @returns {Array<Category>}
 */
export function resolveCategories(ids) {
  return (ids || []).map((id) => Category.findById(id)).filter(Boolean);
}

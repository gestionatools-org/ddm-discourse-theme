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
 * Resolve category IDs against the preloaded category list.
 *
 * `library_category_ids` is a pipe-separated list setting, which Discourse
 * hands over as an array of strings; `Category.findById` needs numbers. IDs
 * that no longer resolve are dropped rather than rendered as blanks, so a
 * category deleted in admin degrades to one missing card.
 *
 * @param {Array<String|Number>} ids
 * @returns {Array<Category>}
 */
export function resolveCategories(ids) {
  return (ids || [])
    .map((id) => Category.findById(parseInt(id, 10)))
    .filter(Boolean);
}

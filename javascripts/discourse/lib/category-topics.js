import Category from "discourse/models/category";

/**
 * The topic id of a category's "About the category" definition topic.
 *
 * `topic_id` is **not** serialized onto the preloaded site categories — it is
 * simply absent — but `topic_url` is, and it ends in the id:
 * `/t/acerca-de-la-categoria-nuevos-usuarios-certificados-posters/2246`.
 *
 * @param {Category} category
 * @returns {Number|null}
 */
export function definitionTopicId(category) {
  const match = category?.topic_url?.match(/\/(\d+)(?:[?#]|$)/);
  return match ? parseInt(match[1], 10) : null;
}

/**
 * Every category definition topic on the site, as a Set of topic ids.
 *
 * Built from the whole list rather than the lane's own category because a lane
 * pulls subcategory topics too, so a child's definition topic can surface in a
 * parent's listing.
 *
 * @returns {Set<Number>}
 */
export function definitionTopicIds() {
  return new Set(Category.list().map(definitionTopicId).filter(Boolean));
}

/**
 * Section and document counts for a directory card, summed over the subtree.
 *
 * `topic_count` counts a category's **direct** topics only, and
 * `subcategory_count` is serialized as `null` on the preloaded site categories
 * — it is only populated by the category-list serializer. Reading either alone
 * reports "0 documents" for exactly the categories this lane exists to
 * advertise: id 73 keeps all 66 of its topics in seven subcategories, id 85 all
 * 8 in one. The children are present in `Category.list()` with
 * `parent_category_id`, so both numbers are computable client-side.
 *
 * Only one level down. These are two-level trees, and a general recursion would
 * imply a depth the taxonomy does not have.
 *
 * @param {Category} category
 * @returns {{sections: Number, documents: Number}}
 */
export function categoryStats(category) {
  const children = Category.list().filter(
    (child) => child.parent_category_id === category.id
  );

  return {
    sections: children.length,
    documents:
      (category.topic_count || 0) +
      children.reduce((total, child) => total + (child.topic_count || 0), 0),
  };
}

/**
 * Load the most recent topics of a category, subcategories included.
 *
 * Category definition topics are dropped: they are auto-generated
 * "Acerca de la categoría …" boilerplate, they are pinned so they sort to the
 * top, and they never carry a cover image — which put one at the head of the
 * showcase grid as an empty grey card. Filtering before the slice keeps the
 * lane at its configured length.
 *
 * Returns `null` rather than an empty array when there is nothing to show, so
 * that `AsyncContent` routes to its `<:empty>` block instead of rendering an
 * empty list.
 *
 * @param {Object} store - the injected `store` service
 * @param {Number} categoryId - 0 or undefined disables the lane
 * @param {Number} count - maximum topics to return
 * @param {Object} [options]
 * @param {Boolean} [options.requireImage] - drop topics with no cover image
 * @param {String} [options.tag] - restrict to topics carrying this tag
 * @returns {Promise<Array|null>}
 */
export async function loadCategoryTopics(
  store,
  categoryId,
  count,
  { requireImage = false, tag = "" } = {}
) {
  if (!categoryId) {
    return null;
  }

  const options = { filter: `c/${categoryId}/l/latest` };

  // Server-side, unlike requireImage below: the tag has to select across the
  // whole category, not across the one page that was fetched. Verified against
  // the live API — c/62/l/latest.json?tags[]=markdown returns 6 of 16.
  //
  // The empty-string guard is what keeps an unset setting from becoming
  // `tags: [""]`, which matches nothing and would empty the lane in silence.
  if (tag) {
    options.params = { tags: [tag] };
  }

  const topicList = await store.findFiltered("topicList", options);

  const definitions = definitionTopicIds();
  let topics = topicList?.topics?.filter((topic) => !definitions.has(topic.id));

  // Both filters run before the slice, so a lane still fills its configured
  // length as long as the first page holds enough qualifying topics.
  if (requireImage) {
    topics = topics?.filter((topic) => topic.image_url);
  }

  if (!topics?.length) {
    return null;
  }

  return topics.slice(0, count);
}

/**
 * Load the most recent topics on the site, from every category the reader can
 * see.
 *
 * Separate from `loadCategoryTopics` rather than a mode of it, because a
 * falsy category id there means *the lane is switched off* and must return
 * null without touching the network.
 *
 * Definition topics are dropped here too, and it matters more than it did for a
 * category lane: that one only ever met the definition topic of its own
 * subtree, while `latest` meets every one on the site, surfacing them as
 * ordinary recent topics each time a category is created or edited.
 *
 * @param {Object} store - the injected `store` service
 * @param {Number} count - maximum topics to return
 * @returns {Promise<Array|null>}
 */
export async function loadLatestTopics(store, count) {
  const topicList = await store.findFiltered("topicList", { filter: "latest" });

  const definitions = definitionTopicIds();
  const topics = topicList?.topics?.filter(
    (topic) => !definitions.has(topic.id)
  );

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

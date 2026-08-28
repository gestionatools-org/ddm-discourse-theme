/**
 * What the page hero says, and which category its button preselects.
 *
 * Text arrives two ways and the shape keeps them apart: `title`/`subtitle` are
 * literal strings taken from data, `titleKey`/`subtitleKey` are i18n keys the
 * component resolves through `themePrefix`. A caller never has to ask where a
 * string came from — exactly one of each pair is set.
 *
 * @typedef {Object} HeroContent
 * @property {String|null} title
 * @property {String|null} titleKey
 * @property {Object|null} titleArgs
 * @property {String|null} subtitle
 * @property {String|null} subtitleKey
 * @property {Object|null} category
 */

const HOME = {
  title: null,
  titleKey: "hero.home.title",
  titleArgs: null,
  subtitle: null,
  subtitleKey: "hero.home.subtitle",
  category: null,
};

/**
 * @param {Object} [context]
 * @param {Object} [context.category] the category in scope, if any
 * @param {String} [context.tag] the tag in scope, if any
 * @returns {HeroContent}
 */
export function heroContentFor({ category, tag } = {}) {
  // A category wins over a tag: `/c/5?tag=x` is a category page that happens
  // to be filtered, and the band names the place rather than the filter.
  if (category) {
    // Measured on PRE 2026-08-28: 5 of 17 categories carry no description, and
    // they are the busiest ones. Title-only is the correct rendering there —
    // the band never invents filler and never repeats the name as its own
    // subtitle.
    const description = category.description_text?.trim();

    return {
      title: category.name,
      titleKey: null,
      titleArgs: null,
      subtitle: description || null,
      subtitleKey: null,
      category,
    };
  }

  if (tag) {
    // A raw tag name is a slug — "poster-evf" is a poor headline — so it is
    // interpolated into a locale string instead of printed on its own.
    return {
      title: null,
      titleKey: "hero.tag.title",
      titleArgs: { tag },
      subtitle: null,
      subtitleKey: "hero.tag.subtitle",
      category: null,
    };
  }

  // The homepage and every generic listing (/latest, /top, /unread). A generic
  // listing has no identity of its own, and inventing one would be filler.
  //
  // Ruling 2 (2026-08-28): return a fresh copy rather than the module-level
  // HOME constant by reference, so a caller mutating the result cannot
  // corrupt every later call.
  return { ...HOME };
}

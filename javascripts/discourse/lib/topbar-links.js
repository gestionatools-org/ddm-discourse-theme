// The three destination links in the topbar.
//
// Labels are i18n keys and live in locales/*.yml; only the URLs are settings.
// That split is the theme's rule — settings.yml is functional configuration,
// every user-visible string is a translation.
//
// This lives in lib/ rather than inside the component because two callers need
// the same answer: topbar-links.gjs renders the links, and topbar.gjs has to
// know whether any exist to decide whether the band renders at all. Reading the
// same three settings in two places is how the two drift apart.
const LINKS = [
  { key: "topbar.links.academy", url: () => settings.academy_url },
  { key: "topbar.links.demo", url: () => settings.demo_url },
  { key: "topbar.links.first_steps", url: () => settings.first_steps_url },
];

/**
 * The links that have a URL configured, in display order.
 *
 * A link with no URL renders nothing rather than pointing at "#". All three
 * destinations are still being decided, so the empty result is the expected
 * one for now, not a fault.
 *
 * @returns {Array<{key: String, url: String}>}
 */
export function configuredLinks() {
  return LINKS.map(({ key, url }) => ({ key, url: url()?.trim() })).filter(
    (link) => link.url
  );
}

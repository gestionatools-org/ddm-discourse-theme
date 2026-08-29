// The three configured destinations — Academy, Demo Gestiona, Primeros pasos —
// shared by the site header and the homepage's shortcuts card.
//
// Extracted when the second consumer arrived rather than copied: the list, the
// trim and the drop-if-empty rule are one behaviour, and two copies of it would
// drift the moment a fourth destination is added.
//
// Labels are **not** here. They are i18n keys under `header.links.*` in
// locales/*.yml, and only the URLs are settings — the theme's standing split
// between functional configuration and user-visible strings. The keys are named
// after the header because that is where they were first shown; the card reuses
// them deliberately, since a destination that changed its name in one place and
// not the other is exactly the confusion this community has already had.
//
// The URL reaches `href` after nothing but a trim, so an absolute destination
// typed without its scheme resolves as a path on this forum and 404s. There is
// no validation to lean on: `validations: { url: true }` exists only for
// properties inside a `type: objects` schema, and converting these three would
// discard what admins have already stored. The setting descriptions say so.
const DESTINATIONS = [
  { key: "header.links.academy", url: () => settings.academy_url },
  { key: "header.links.demo", url: () => settings.demo_url },
  { key: "header.links.first_steps", url: () => settings.first_steps_url },
];

/**
 * The configured destinations, in order, with the unset ones dropped.
 *
 * Read at call time rather than at module load: a theme setting changed in
 * admin takes effect without a reload, and the tests set them per case.
 *
 * @returns {Array<{key: String, url: String}>}
 */
export function destinationLinks() {
  return DESTINATIONS.map(({ key, url }) => ({
    key,
    url: url()?.trim(),
  })).filter((link) => link.url);
}

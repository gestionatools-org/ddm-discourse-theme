# Topbar — an information band above the site header

Design date: 2026-08-15. Target version: `theme_version` 0.11.0.

A full-width band rendered above the site header carrying two things: the
theme's destination links, and three live figures about the community. The
reference the maintainer asked for is `community.zapier.com`, whose band shows
Topics / Replies / Members.

## Why above the header rather than inside it

The three destination links landed in v0.10.0 inside the header itself, in the
`before-header-panel` outlet. That header now carries a logo, a search field,
three links and the user icons, which is why `.header-links` is hidden below
`lg` — there is no room. Moving the links up to a band of their own frees the
header and gives the figures somewhere to live that is not the homepage.

## Placement

Core renders `above-site-header` in `frontend/discourse/app/templates/application.gjs`,
immediately before `<GlimmerSiteHeader>` and outside it:

```gjs
<PluginOutlet
  @name="above-site-header"
  @connectorTagName="div"
  @outletArgs={{lazyHash currentPath=@controller.router._router.currentPath}}
/>

{{#if @controller.showSiteHeader}}
  <GlimmerSiteHeader ... />
{{/if}}
```

This is the outlet Discourse's own `discourse-brand-header` component uses, and
it is a plugin outlet rather than a block because the Blocks API has no header
outlet and themes cannot register new ones. It is also the split this theme
already agreed: Blocks for the custom homepage only, outlets and SCSS
everywhere else.

Two consequences follow from sitting in normal flow above a sticky header:

- The band scrolls away and the header sticks to the top on its own. No
  `--header-offset` arithmetic, no `position: fixed`, no JavaScript measuring
  anything.
- The outlet renders on every route, including `/admin`, where the band is
  noise. The component opts out by reading the `router` service:
  `router.currentRouteName?.startsWith("admin")`, the same test core's
  `isCurrentAdminRoute` uses.

Inside the band, content sits in a `div.wrap`. `.wrap` is a core global —
`max-width: var(--d-max-width)`, auto margins, `padding: 0 var(--d-wrap-padding-x)`,
and `body.has-sidebar-page .wrap` widens it by the sidebar width. Reusing it is
what aligns the band's left edge with the header logo on every page shape.

## Components

```
javascripts/discourse/
├── api-initializers/
│   └── above-site-header.gjs      renders Topbar into the outlet
├── components/
│   ├── topbar.gjs                 container; route gate; layout
│   ├── topbar-links.gjs           destination links (moved from header-links.gjs)
│   └── topbar-stats.gjs           the three figures; owns the async state
└── lib/
    └── site-stats.js              the fetch and its cache
```

One outlet per initializer file, named after the outlet — the theme's existing
rule. One BEM block per component: `.topbar`, `.topbar-links`, `.topbar-stats`.

`topbar-links.gjs` is `header-links.gjs` moved and renamed, with no change to
its logic: it still maps three i18n keys to three URL settings and filters out
the ones whose URL is empty. Only the i18n key prefix changes, from
`header.links.*` to `topbar.links.*`.

## Data

`GET /about.json` returns `about.stats`, verified against a live instance:

```
topics_count      topics_last_day   topics_7_days   topics_30_days
posts_count       posts_last_day    posts_7_days    posts_30_days
users_count       users_last_day    users_7_days    users_30_days
likes_count       likes_last_day    likes_7_days    likes_30_days
active_users_last_day  active_users_7_days  active_users_30_days
participating_users_*  visitors_*  eu_visitors_*  chat_*
```

This is the same call core's own `/about` route makes — `ajax("/about.json")`
in `frontend/discourse/app/routes/about.js`. There is no client-side `About`
model to go through; the old `models/about.js` no longer exists. Visibility is
not gated: `Guardian#can_see_about_stats?` returns `true` unconditionally.

`lib/site-stats.js` memoises the promise at module scope:

```js
import { ajax } from "discourse/lib/ajax";

let cached;

export function loadSiteStats() {
  cached ||= ajax("/about.json")
    .then((result) => result?.about?.stats ?? null)
    .catch(() => null);

  return cached;
}
```

One request per page load and none on route transitions. Caching the rejection
too is deliberate: on a login-required site an anonymous or 403 response must
not turn into a retry on every navigation. Figures go stale only within a single
browsing session, which is irrelevant for 30-day windows.

### Which three figures

| Slot | Key | Rationale |
|---|---|---|
| Members | `users_count` | The one size figure that grows with every CAAG intake |
| Topics this month | `topics_30_days` | Pulse, not size |
| People active | `active_users_30_days` | Pulse, not size |

Lifetime totals were rejected. Zapier can show them because they are in the tens
of thousands; Gestiona Avanza is a closed community around a certification
programme, and the totals visible in the category data (category 5: 1,055 posts;
category 73's whole tree: 66 topics and zero replies) are three or four figures.
A small lifetime total displayed prominently reads as an empty community. Recent
activity reads as a live one.

Numbers are formatted with `I18n.toNumber(value, { precision: 0 })` from
`discourse-i18n`, which applies the locale's thousands separator — `1.240` under
`es`, `1,240` under `en`.

Not core's `number()` from `discourse/lib/formatter`, despite it being the
formatter core uses for counts elsewhere. Its source abbreviates everything past
999: `val > 999` renders `I18n.toNumber(val / 1000, { precision: 1 })` through
`number.short.thousands`, so a `users_count` of 1,240 displays as "1,2k". Core
wants that in topic-list columns where a count has to fit a narrow cell. Here
the figure is the headline of a full-width band, there is room, and abbreviating
the one lifetime total we chose to show throws away precision to save four
characters.

Number and label render as separate `<span>`s so they can carry different
weight; the label is the pluralised i18n string and the number is interpolated
by the template, not by i18n.

## Rendering and failure

- **While loading:** nothing renders in the figures slot. No spinner. The band's
  height comes from its own padding, so the figures fading in a few hundred
  milliseconds later causes no layout shift — only the right-hand cluster
  changes. `topbar-stats.gjs` therefore does *not* use `<AsyncContent>`, unlike
  the homepage lanes: `AsyncContent` exists to give a `<:loading>` and an
  `<:empty>` block somewhere to go, and here both of those states are "render
  nothing". A tracked property set from the resolved promise is the whole
  requirement.
- **Stats unavailable** (network failure, 403, plugin-shaped surprise): the
  figures slot renders nothing and the band still shows its links.
- **No links configured:** the links slot renders nothing. This is the state on
  merge — `academy_url`, `demo_url` and `first_steps_url` are all still empty
  while the destinations are being decided, so the band ships showing figures
  only. That is expected, not a fault.
- **Neither links nor stats:** the band does not render at all. An empty grey
  strip above the header is worse than no band.
- **Links configured but stats unavailable, below `lg`:** also nothing. This
  case needs its own handling because the links are hidden by CSS, not by the
  component, so the JS-level "render nothing" test above does not catch it and
  the band would collapse to an empty strip on mobile. `Topbar` therefore
  carries a standalone `--no-stats` modifier class when the figures resolve to
  nothing, and `topbar.scss` hides the whole band on that class below `lg`.
  Standalone `--modifier`, not `topbar--no-stats`, per the theme's BEM rule.

## Responsive behaviour

| Viewport | Links | Figures |
|---|---|---|
| ≥ `lg` (1024px) | left, inline | right, inline |
| < `lg` | hidden | centred |

Below `lg` the whole band does not fit, and the maintainer chose to keep the
figures and drop the links, so the band stays recognisable as the data band at
every width. Media queries go through the viewport library —
`viewport.until(lg)` — never a raw media query.

Known consequence, accepted: below `lg` the three destination links are reachable
from nowhere. They are not reachable there today either, since `.header-links`
is already hidden below `lg`. If that becomes a problem the fix is custom
sidebar links configured in admin, which needs no theme change.

## Appearance

A quiet utility strip, not a saturated brand band:

| Property | Token | Resolves to |
|---|---|---|
| Background | `var(--ga-muted)` | `#f1f5f7` light / `#1d2e35` dark |
| Text and links | `var(--ga-muted-fg)` | `#58686e` / `#99a7ad` |
| Link hover/focus | `var(--tertiary)` | petrol light / brand cyan dark |
| Figures | `var(--primary)`, weight 600 | the only emphasis in the band |
| Bottom rule | `1px solid var(--ga-border)` | — |

The header is white and carries the logotype. A petrol band above it would
outweigh the logo and invert the page's hierarchy; the band is context, not
primary navigation, so it sits below the header visually as well as
structurally. A flat surface separated by a rule rather than a shadow is what
`app/elevation.scss` already asks for.

No 3px cyan edge. That gesture means "active, focused or leading" in the
identity system, not "topmost", and spending it here would devalue it.

All colour comes from existing `--ga-*` tokens and core variables. No new
tokens, no new hex values.

## Accessibility

- Links stay in a `<nav>` with `aria-label` from `topbar.links.aria_label`,
  as today.
- Figures render as a `<ul>` inside a container labelled by
  `topbar.stats.aria_label`. Number and label are both text, so a screen reader
  reads "640 members" rather than an orphaned number.
- Contrast, computed against the resolved hex values rather than inferred from
  the tokens being used elsewhere. Every pair clears AA for normal text (4.5:1):

  | Pair | Light | Dark |
  |---|---|---|
  | Label text — `--ga-muted-fg` on `--ga-muted` | 5.29:1 | 5.68:1 |
  | Figures — `--primary` on `--ga-muted` | 15.07:1 | 12.34:1 |
  | Link hover — `--tertiary` on `--ga-muted` | 5.41:1 | 5.67:1 |

  The dark column is where `--tertiary` is brand cyan `#00b4d3` at full
  strength. It passes there because `--ga-muted` resolves to `#1d2e35` in the
  dark scheme, which is the inversion the identity system already declares in
  `about.json`. Brand cyan is never used as text on the light surface, per the
  standing constraint that it scores 2.48:1 on white.

## Localisation

`locales/en.yml` and `locales/es.yml` gain a `topbar` section. The existing
`header.links.*` keys are renamed to `topbar.links.*` in the same change, with
their values unchanged.

```yml
topbar:
  links:
    aria_label: "Featured links"
    academy: "Academy"
    demo: "Demo Gestiona"
    first_steps: "First steps"
  stats:
    aria_label: "Community activity"
    members:
      one: "member"
      other: "members"
    topics:
      one: "topic this month"
      other: "topics this month"
    active:
      one: "person active"
      other: "people active"
```

Labels carry no `%{count}`: the number is a separate element in the template,
and the string is pluralised on the count without interpolating it.

No new entries under `theme_metadata.settings` because there are no new
settings.

## Files

| Action | Path |
|---|---|
| new | `javascripts/discourse/api-initializers/above-site-header.gjs` |
| new | `javascripts/discourse/components/topbar.gjs` |
| new | `javascripts/discourse/components/topbar-stats.gjs` |
| new | `javascripts/discourse/lib/site-stats.js` |
| new | `stylesheets/app/topbar.scss` |
| moved | `components/header-links.gjs` → `components/topbar-links.gjs` |
| deleted | `javascripts/discourse/api-initializers/before-header-panel.gjs` |
| edited | `stylesheets/app/header.scss` — remove the `.header-links` block |
| edited | `stylesheets/app/_index.scss` — `@import "topbar";` |
| edited | `locales/en.yml`, `locales/es.yml` |
| edited | `about.json` — `theme_version` 0.10.0 → 0.11.0 |

`settings.yml` is not touched. The band reuses `academy_url`, `demo_url` and
`first_steps_url` exactly as they are.

## Out of scope

- A setting to toggle the figures on and off. If the numbers read badly on PRE
  the answer is to change which numbers, not to add a switch.
- A setting to choose the metrics. Three fixed keys until there is evidence
  another set is wanted.
- Making the band sticky, dismissible, or animated.
- Restoring the destination links on narrow viewports. Deliberately deferred to
  admin-side sidebar links.

## Verification

- `npx pnpm@10.28.0 lint` — stylelint, eslint, prettier and `ember-tsc`. The
  only local gate, and exactly what CI runs.
- `spec/system/core_features_spec.rb` is expected to need no new
  `skip_examples`: the band adds no interaction and removes no control. CI
  decides; if an example does break, narrow it rather than deleting it.
- Neither of those looks at the result. The band must be checked by eye on PRE
  at `https://discourse.gestiona4dev.tech/?preview_theme_id=14`, in both colour
  schemes and at a viewport above and below 1024px, before the PR is merged.
  This is the same visual check the homepage has been owing since v0.1.0.

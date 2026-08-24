# Topbar — an information band above the site header

Design date: 2026-08-15. Shipped as `theme_version` 0.11.0.
Revised 2026-08-16 for 0.12.0 — see *Which figures*.

> **Partly superseded 2026-08-16, noted 2026-08-24.** The destination links
> moved back into the site header later the same day (`8b7ce12`), so the band
> now carries the figures and nothing else. Everything this spec says about
> links in the band, about `lib/topbar-links.js`, and about the `--no-stats`
> modifier describes code that no longer exists — the module and the modifier
> were both deleted with the move. The figures half of the spec is current.
> Kept as written so the reasoning behind the original placement survives.

A full-width band rendered above the site header carrying two things: the
theme's destination links, and four live figures about the community. The
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
│   ├── topbar.gjs                 container; route gate; render/collapse rules
│   ├── topbar-links.gjs           destination links (moved from header-links.gjs)
│   └── topbar-stats.gjs           the four figures
├── lib/
│   └── topbar-links.js            configuredLinks(), shared by both of the above
└── services/
    └── site-stats.js              the fetch, its cache and its state
```

`lib/topbar-links.js` exists because two components need the same answer:
`topbar-links.gjs` renders the links, and `topbar.gjs` has to know whether any
exist to decide whether the band renders at all. One `configuredLinks()` used
by both, rather than the same three settings read and trimmed in two places.

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

`services/site-stats.js` memoises the request on the service instance and
exposes three states:

```js
export default class SiteStats extends Service {
  @tracked stats = null;   // the stats object once it arrives, else null
  @tracked loaded = false; // true once the request has settled, either way

  #request;

  load() {
    this.#request ||= ajax("/about.json")
      .then((result) => (this.stats = result?.about?.stats ?? null))
      .catch(() => (this.stats = null))
      .finally(() => (this.loaded = true));

    return this.#request;
  }
}
```

One request per application instance and none on route transitions. Caching the
rejection too is deliberate: on a login-required site an anonymous or 403
response must not turn into a retry on every navigation. Figures go stale only
within a single browsing session, which is irrelevant for 30-day windows.

**A service rather than a module-level `let cached`.** The memo has to live
exactly as long as the application instance. A module-scope cache lives as long
as the *module*, which in a QUnit run is the whole suite: the first test to
resolve `/about.json` would pin its response for every test after it, and the
failure cases — the ones actually worth testing — would be unreachable. Ember
tears services down between acceptance tests, so the same caching behaviour
comes for free and stays testable. Themes may declare services;
`discourse-discover-theme`, `discourse-kanban-theme` and
`discourse-category-banners` all do.

`loaded` exists to separate "still loading" from "failed", which the collapse
rules below depend on.

### Which figures

Four, since v0.12.0. Three shipped in v0.11.0 and the middle one did not
survive contact with the real numbers.

| Slot | Key | Below `lg` | Rationale |
|---|---|---|---|
| Members | `users_count` | kept | The one size figure that grows with every CAAG intake |
| Messages this month | `posts_30_days` | hidden | Conversation volume — the thing this community actually does |
| Likes this month | `likes_30_days` | hidden | Appreciation; says people read each other |
| People active | `active_users_30_days` | kept | Reach |

Lifetime totals were rejected. Zapier can show them because they are in the tens
of thousands; Gestiona Avanza is a closed community around a certification
programme, and the totals visible in the category data (category 5: 1,055 posts;
category 73's whole tree: 66 topics and zero replies) are three or four figures.
A small lifetime total displayed prominently reads as an empty community. Recent
activity reads as a live one.

**Why `topics_30_days` was dropped.** On PROD it read **9**, next to 374 members
and 114 people active — a 30.5% monthly active rate, which is strong, sitting
beside a number that invites the reader to divide and conclude nobody writes.
Partly an artefact: the window was 17 July to 16 August, the deadest stretch of
the Spanish year, and category 4 alone averages ~15 topics a month across the
year. But mostly the wrong measure. This community lives in replies, not in new
threads — category 5 averages 1.7 and 4.5 replies per topic, category 78 reaches
5.7, category 73's whole tree has never received one. Topics count initiative;
posts count participation, and participation is what is actually happening here.

The two are **not filtered alike**, and the difference is not cosmetic:

```ruby
def self.topics
  topics = Topic.listable_topics      # excludes PMs and unlisted
def self.posts
  Post.where("created_at > ?", 30.days.ago).count   # no equivalent filter
```

`posts_30_days` therefore counts private messages and restricted categories.
That is defensible on a login-required community where every category is "the
community", but it is why the label is **messages** and never *replies* —
"replies" would be a specific claim the number cannot support.

Four figures need roughly 396px at `--font-down-2`; a 375px phone leaves about
343px of line, and below `lg` the figures are the only thing the band still
carries. So the two 30-day content figures carry a standalone `--secondary`
modifier and stand down there, leaving size and reach. Which two stand down is
decided in `topbar-stats.gjs`, not in the stylesheet — the SCSS only honours the
class.

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

Two inputs drive everything: whether any link URL is configured, and which of
the service's three states the figures are in.

| Stats state | Test |
|---|---|
| `loading` | `!loaded` |
| `ready` | `stats` is truthy |
| `unavailable` | `loaded && !stats` |

Rules:

1. The figures slot renders only in `ready`. In `loading` and `unavailable` it
   renders nothing — no spinner, no placeholder.
2. `Topbar` renders nothing at all when there are no links **and** the state is
   `unavailable`. An empty grey strip above the header is worse than no band.
3. `Topbar` carries a standalone `--no-stats` modifier class in the
   `unavailable` state, and `topbar.scss` hides the whole band on that class
   below `lg`. Standalone `--modifier`, not `topbar--no-stats`, per the theme's
   BEM rule.

Rule 3 is not redundant with rule 2. Below `lg` the links are hidden by CSS, not
by the component, so a band with links configured and stats unavailable passes
rule 2 and would still collapse to an empty strip on mobile. Rule 3 is the case
rule 2 cannot see.

The `unavailable` test is `loaded && !stats`, never just `!stats` — that
distinction is what keeps the happy path free of layout shift. During `loading`
the band renders with its normal padding and reserves its height, then the
figures appear inside it. If `--no-stats` also applied while loading, the band
would be absent on mobile and then push the page down when the request landed.
The only remaining shift is in the failure case, where the band collapses once,
early, and rarely.

**This is a trade, and rule 2 is not absolute.** Reserving the height means the
band *is* briefly the empty strip rule 2 forbids: on every cold load, for the
length of the `/about.json` round trip, and on desktop with no links configured
that strip is the entire band. Rule 2 governs the settled state; the loading
state deliberately violates it because a stable layout is worth more than a
blank 32px for 200ms. Anyone reading rule 2 as absolute will "fix" this by
gating on a bare `!stats` and reintroduce the shift — which is why the trade is
written down here rather than left to be re-derived.

`topbar-stats.gjs` does *not* use `<AsyncContent>`, unlike the homepage lanes.
`AsyncContent` earns its place when `<:loading>` and `<:empty>` have something
to render; here both are "render nothing", and a tracked property read off the
service is the whole requirement.

**No links configured** is the state on merge: `academy_url`, `demo_url` and
`first_steps_url` are all still empty while the destinations are being decided,
so the band ships showing figures only. That is expected, not a fault.

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
| Figures | `var(--primary)`, weight 700 | the only emphasis in the band |
| Bottom rule | `1px solid var(--ga-border)` | — |

**Amended 2026-08-24.** This table said weight 600 and the implementation
followed it. The identity system loads 400, 500 and 700 and forbids everything
else (`docs/03-tipografia.md`), so 600 should never have been specified — Phase 1
of the brand audit had already stripped the four occurrences that existed
elsewhere. Corrected to 700, which is also what the browser was painting: core
serves Roboto 400 and 700 only, and CSS font matching resolves a requested 600
upward. 500 is the closer reading of "emphasis", but it has no file on the site
and would match *downward* to 400; revisit once `Roboto-Medium.woff2` is
vendored.

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
| new | `javascripts/discourse/lib/topbar-links.js` |
| new | `javascripts/discourse/services/site-stats.js` |
| new | `stylesheets/app/topbar.scss` |
| new | `test/acceptance/topbar-test.js` |
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

- `npx pnpm@10.28.0 lint` — stylelint, eslint, prettier, ember-template-lint and
  `ember-tsc`. The only gate that runs locally, and exactly what CI's `linting`
  job runs.
- `test/acceptance/topbar-test.js` — QUnit acceptance tests, written against
  the pattern in `.reference/discourse-versatile-banner/test/acceptance/` and
  `.reference/discourse-right-sidebar-blocks/test/acceptance/`: `acceptance()`
  from `discourse/tests/helpers/qunit-helpers`, `needs.pretender()` to stub
  `/about.json`, theme settings assigned through the global `settings`.

  **This switches on a CI job the repository has never run.** The shared
  workflow's `check_for_tests` builds its matrix from
  `Dir.glob("test/**/*.{js,gjs}").any?`, and `test/acceptance/` currently holds
  nothing but `.gitkeep`, so the `frontend` job has never been part of any run
  here. The first PR carrying these tests is also the first exercise of
  `rake themes:qunit` against this theme; budget for the job itself needing a
  fix, separately from whether the tests pass.

  They cannot be run locally. `package.json` has no `test` script and the suite
  needs a Discourse checkout with Postgres, Redis and an Ember build. The red
  and green halves of the cycle both happen in CI, one push per turn.
- `spec/system/core_features_spec.rb` is expected to need no new
  `skip_examples`: the band adds no interaction and removes no control. CI
  decides; if an example does break, narrow it rather than deleting it.
- **The admin-route gate is covered by an acceptance test.** This spec
  originally routed it to manual verification, on the grounds that
  `visit("/admin")` drags in the admin bundle and its own fixtures for a
  one-line getter. The maintainer overruled that on 2026-08-15: it is the only
  behavioural branch that would otherwise ship unverified, and Task 2 builds on
  `visible`, which composes it. The added unknown on the first-ever `frontend`
  CI run was accepted explicitly.

  The test configures a link URL before visiting `/admin`. Without one the band
  would be absent there regardless of the gate — `hasLinks` would be false —
  and the assertion would pass for the wrong reason.
- None of the above looks at the result. Before the PR is merged the band must
  be checked by eye on PRE at
  `https://discourse.gestiona4dev.tech/?preview_theme_id=14`:
  1. Light scheme and dark scheme.
  2. Viewport above and below 1024px.
  3. `/admin` — the band must be absent.
  4. Scroll down — the band leaves, the header stays.
  5. **A sidebar page at ≥ `lg`** — `/latest` with the sidebar open. The band's
     left edge must still land on the header logo. That alignment rests on
     core's `body.has-sidebar-page .wrap` rule widening our `.wrap` the same
     way it widens the header's, which is the one claim in this design that no
     test can see and that could not be verified from the checkout.
  6. **Where the figures sit with no links configured** — the merge-day state.
     They must hold the right edge, which is what the auto inline-start margin
     on `.topbar-stats` exists for: `TopbarLinks` renders no element at all
     when every URL is empty, so `justify-content: space-between` alone would
     put the figures on the left.

  This is the same visual check the homepage has been owing since v0.1.0.

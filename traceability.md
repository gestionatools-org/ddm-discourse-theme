# Traceability

## 2026-08-10 — Project bootstrap

**Goal.** Stand up a new Discourse theme for an es|public Discourse Cloud instance. No design guidelines provided yet; scope limited to research, tooling and structure.

**Research.** `discourse/all-the-themes` turned out to be an index (229 official + 246 third-party repo slugs), not code. Cloned a curated 19-theme corpus into `.reference/` for grepping real implementations.

**Key finding.** `discourse/discourse-theme-skills` ships `.claude/skills/` — Discourse's own Claude Code authoring skills (~1.7k lines covering SCSS architecture, BEM, settings schema, modifiers, transformers, CSS variables, and the Blocks API). Vendored into `.claude/skills/`, re-syncable via `bin/sync-skills`.

**Architecture decisions.**
- Full theme (`"component": false`), scaffolded from `discourse-theme-skeleton` rather than hand-rolled, to inherit upstream lint configs, CI workflows and the core-features system spec.
- SCSS split into `brand/` `app/` `blocks/` `layouts/` with `common.scss` as a rules-free import manifest, per Discourse's documented architecture.
- Blocks API (`api.renderBlocks`) preferred over plugin outlets for layout work. Discourse runs it in production on Meta and states it is the direction of travel, but it is still flagged experimental — noted as a version-pinning risk.
- Display strings live in `locales/`, functional config in `settings.yml`. Enforced by convention, not tooling.

**Environment friction.** Corporate Fortinet TLS proxy breaks corepack's npm registry fetch, so pnpm cannot be installed via `corepack enable`/`corepack install`. Working invocation is `npx pnpm@10.28.0`. macOS system Ruby 2.6 is too old for `discourse_theme`; installed Homebrew Ruby 4.0.6.

**Verification.** `pnpm lint` green across stylelint, eslint, prettier and `ember-tsc`. System specs not runnable locally (require a Discourse dev checkout); CI covers them.

**Open.** Target instance URL for `discourse_theme watch` not configured. Brand assets and category taxonomy pending.

## 2026-08-11 — Direction agreed

- **Community model:** mixed — support for public-administration customers alongside open knowledge categories.
- **Architecture:** hybrid. Blocks confined to the custom homepage; all other surfaces via SCSS + transformers over native layouts. Rationale: the Blocks API is still experimental, so the blast radius of an API change stays limited to one page that can fall back to a stock homepage.
- **Theme name:** `Espublico Theme`, block namespace `theme:espublico:*`.

## 2026-08-11 — Brand foundation

**Target.** `gestionaavanza.espublico.com` — community for esPublico's *Administración Avanzada de Gestiona* certification programme. Login-required is on, so the site cannot be inspected anonymously (403 on `/categories.json`); no visual baseline captured and category slugs unknown.

**Palette derived, not invented.** Taken from `presentaciones/assets/css/corporate.css`, `[data-brand="gestiona-avanza"]`. The cyan ramp there was sampled from the official logotype and is explicitly marked as not-to-be-adjusted.

**Accessibility finding that shaped the design.** The brand cyan `#00b4d3` scores **2.48:1 on white** — far below the 4.5:1 that WCAG 2.1 AA requires, and this forum serves public administration under RD 1112/2018. Even the darker `#00839e` misses at 4.43:1. Resolution: cyan is demoted to a fill/border/large-mark colour on light surfaces, and interactive text uses the parent Gestiona petrol `#006d85` (5.96:1). This is brand-coherent rather than a compromise — the isotype is petrol arcs wrapped around a cyan arrow, so both colours are already the mark. On the dark `#003040` surface the cyan clears AA (5.66:1) and does carry interactive text, so the brand signal is strongest exactly where it is legible.

`success` and `love` were darkened the minimum amount needed to reach 4.5:1 while preserving hue (`#00bb88`→`#008762`, `#ee0055`→`#e90053`). Every colour in both schemes is contrast-checked.

**Open.** API key or staging site — without one nothing can be verified visually and `discourse_theme watch` cannot run.

## 2026-08-11 — CI

Pushed to `gestionatools-org/discourse-theme`. Linting green; the two test jobs fail upstream.

**Template lint (fixed).** Correction to the commit message on `3e312c2`: the trigger was not a skeleton gap. `discourse/.github` #216 (2026-05-15) makes the shared workflow *skip* the template-lint step when no config is present — the skeleton passes CI precisely because it ships no `.template-lintrc.cjs`. Copying that file over from `discourse-theme-skills` is what turned the step on, and the skeleton has no `ember-template-lint` binary to run it. Deleting the file would also have fixed it; declaring the dependency was chosen instead because the homepage blocks will be `.gjs` and template lint catches accessibility defects that matter here — it rejected an alt-less `<img>` in a smoke test. Note `discourse-theme-skills` pins `@discourse/lint-configs` 2.43.0, which still exported `./template-lint`; 3.2.0 does not, so the config is self-contained.

**Redis (upstream, resolved 2026-08-11).** `backend_tests` and `system_tests` both failed at "Create and migrate database" with `Redis::CannotConnectError`, caused by `*** FATAL CONFIG FILE ERROR (Redis 8.0.2) *** Can't open the log file` during the Start redis step. Reproducible across three runs, not flaky, and nothing in this theme could influence it. It cleared on its own upstream — both jobs pass now — so the earlier "treat linting as the effective gate" conclusion no longer applies. All four checks are live.

## 2026-08-11 — Instance reconnaissance

**Access.** A Global-scope API key against PRE unblocked the taxonomy work. Note the gem stores credentials in `~/.discourse_theme`, keyed by project path — *not* in `.discourse-site`; the skeleton's `.gitignore` entry is vestigial and offered no protection. During this session the key was leaked into the chat transcript by a redaction filter that matched on hash key names, and under `api_keys` the key name is the site URL, so the value passed through. Key must be rotated.

**Taxonomy.** 35 categories, 13 top-level. Three findings reshaped the homepage design:

1. **Slugs are legacy and no longer describe their category** — id 4 "Te contamos…" is `comunidad-expertos`, id 5 "El foro del Certificado" is `grupos-de-trabajo`, id 50 "Analiza" is `analitica-datos`, id 53 "Moderadores" is `vota-tu-gestiona`. Everything is therefore keyed by numeric ID; a slug rename would silently empty a lane.
2. **Category 73's whole tree is a repository, not a forum.** 66 topics with `post_count == topic_count` exactly — not one reply in its history. Presenting it with a topic list would advertise a conversation that does not exist.
3. **Category 78 "Pósters" is the most conversational surface on the site** (5.7 replies/topic, the highest anywhere) and one of only four publicly readable categories, yet it sits buried as a subcategory of an announcements channel.

Only cat 4 and children 66, 78, 87 are public; everything else is `read_restricted`. 59 groups exist, including 33 `CAAG*` cohorts — deliberately unused, see below.

## 2026-08-11 — Custom homepage

**Scope decision.** Ricardo confirmed the five lanes, `custom_homepage`, and promoting cat 78. He also ruled out differentiating by cohort or certification status: *every member is a student*. That collapses the conditions to nothing — the only split is anonymous vs. signed in, which category permissions already enforce server-side. No `user` or `group` conditions anywhere.

**Lane shapes derive from measured use, not tree position.** News (177 topics/year) gets excerpts; forum (1.7 and 4.5 replies/topic) gets the reply count promoted as proof of life; showcase gets an image grid; library gets directory cards and *no topic list at all*.

**Layout** keys off a container query rather than the viewport, since the homepage narrows when the sidebar opens and should answer to the space it has.

**Two bugs CI caught that local lint could not.**
- `type: list` settings arrive in JavaScript as a pipe-separated **string**, not an array. The block's arg validation rejected it at registration, and that error aborted the theme's JS — which is why *seven* core-feature examples failed rather than just the homepage ones. Fixed by splitting in the initializer, where the setting enters.
- The remaining failures were `custom_homepage` working as intended: seven examples start at `/` and expect core's topic list or `#create-topic`. Narrowed with `skip_examples`, not deleted.

**Coverage gap, recorded deliberately.** `topics:read` also skips "lists topics for a category", which would pass on its own — Discourse exposes no narrower key. 19 examples drop to 10. Category listings are now unguarded by CI and need manual checking when topic-list styling changes.

**Not visually verified.** The instance is login-required and this session had no browser session; only compilation (27 theme fields, 0 errors) and CI are confirmed.

## 2026-08-12 — Real event dates in the events lane

`discourse-calendar` was installed but disabled on PRE. Enabled it, plus `sort_categories_by_event_start_date_enabled`; the other two switches (`discourse_post_event_enabled`, `display_post_event_date_on_topic_title`) were already on.

**The lane now shows a real start time where one exists.** `event_starts_at` reaches `topic_list_item` for topics carrying an `[event]` block, so the same lane renders both kinds without a second request: event date where serialized, topic date otherwise, distinguished by a `--scheduled` modifier.

**Core's date helpers cannot render future dates and this is not obvious.** `relativeAgeMedium` computes `now - date` and treats anything under one minute as "now" — a negative distance clears that threshold, so `format="medium"` renders *every* future date as "now". `format="tiny"` is better but discards the sign, making an event three days out read exactly like a topic bumped three days ago. Event dates are therefore formatted absolutely with `Intl.DateTimeFormat`, locale taken from `<html lang>` so it tracks the Discourse UI rather than the browser. `moment` was rejected despite being the plugin's own idiom: it is an allowed eslint global but carries no type declaration, so `lint:types` would break.

**Two verification mistakes worth remembering.** `discourse-calendar` was read from its standalone repo, which is stale — the plugin now lives in `discourse/discourse` under `plugins/`, where the category-settings connector has been rewritten for the form-based editor. And `sort_topics_by_event_start_date` was reported unset three times running because `/c/<slug>/<id>/show.json` errors while `/c/<id>/show.json` works, and a `jq // "unset"` default dressed the error up as an answer. The flag was set all along. Both facts underpinning the block itself were re-checked against the in-core copy and hold.

**`[event]` fails silently when malformed.** It is a *block* bbcode, so the tag must open its own line; an emoji glued in front makes it cook as plain text. `EventValidator` returns early when zero events are extracted, without adding an error, so the post saves looking fine. Both events created during this session hit exactly this. Verify against the cooked HTML (`div.discourse-post-event`), never against a successful save.

**Reference corpus is stale relative to the pinned lint config.** `@discourse/lint-configs` 3.2.0 requires the `discourse/ui-kit/*` imports and `trustHTML`; every theme in `.reference/` still uses the old `discourse/components/*`, `discourse/helpers/*` and `htmlSafe`. Copy patterns from the corpus, but let the linter arbitrate imports.

## 2026-08-15 — Topbar above the site header

**Goal.** A full-width band above the header carrying the destination links and live community figures, on the model of `community.zapier.com`.

**Placement.** Core's `above-site-header` outlet, rendered in `application.gjs` outside `<GlimmerSiteHeader>`. Normal flow above a sticky header means the band scrolls away with no offset arithmetic. Same outlet `discourse-brand-header` uses.

**Decisions.**
- The three destination links moved out of the header, where they had been hidden below `lg` since v0.10.0 for lack of room. Below `lg` the band shows figures and drops the links — the maintainer's call, against the recommendation, so the band stays recognisable as the data band at every width. Consequence accepted: the links are reachable from nowhere on a phone, fixable from admin with sidebar links if it bites.
- Members plus two 30-day windows rather than lifetime totals, which on a closed community read as an empty forum.
- `I18n.toNumber` rather than core's `number()`, which abbreviates past 999 and would render a 1,240-member community as "1.2k".
- The `/about.json` memo lives on a service, not at module scope. A module-level cache outlives every acceptance test and would pin the first response for the whole suite.

**Test cycle.** `test/acceptance/topbar-test.js` is the repository's first frontend test, which switches on a CI job that has never run here: the shared workflow builds its matrix from `Dir.glob("test/**/*.{js,gjs}")`, and `test/acceptance/` held nothing but `.gitkeep`. The suite cannot run locally — no `test` script, and it needs a Discourse checkout with Postgres, Redis and an Ember build.

**Admin-route gate.** Originally routed to manual verification, on the grounds that `visit("/admin")` drags in the admin bundle for a one-line getter. Overruled by the maintainer: it is the only behavioural branch that would otherwise ship unverified, and the figures task builds on `visible`, which composes it. The test configures a link URL first, or the band would be absent on `/admin` through `hasLinks` and the assertion would pass for the wrong reason.

## 2026-08-16 — The band settles, and main gets a gate

**Which figures.** `topics_30_days` read 9 on PROD, next to 374 members and 114 people active. A 30.5 % monthly active rate with a 9 beside it invites the reader to divide and conclude nobody writes. Partly a window artefact, mostly the wrong measure: this community lives in replies, not new threads — category 5 averages 1.7 and 4.5 replies per topic, 78 reaches 5.7, 73's whole tree has never received one. Topics count initiative; posts count participation. Swapped for messages and likes. The label says "messages", never "replies": `topics` counted `Topic.listable_topics` while `posts` is a bare `Post.where(created_at > …)`, so it includes PMs and restricted categories.

**One period lead-in.** The band mixed a lifetime total with three 30-day windows and only said so on two of them, which made active users read as an all-time figure sitting between two monthly ones — the opposite of what it measures. Now the total stands alone, a rule separates it, and "Este mes:" introduces the three windows. Active users leads the group so that when the two secondary figures stand down below `lg` the survivor renders as one contiguous run instead of stranding the lead-in.

**The links went back to the header.** Reverts the placement half of `992f280`, two days after the maintainer's call to move them out. The band keeps the figures and loses everything else, which simplified it rather than shrinking it: `lib/topbar-links.js` disappeared (it existed so two files could share one answer; with one consumer left it was indirection, not DRY), and the `--no-stats` modifier and its CSS went with it.

**Three homepage lanes were displaying wrong data, all green in CI.**
- *Library counts reported zero for the two largest trees.* `topic_count` counts direct topics only and `subcategory_count` is `null` on the preloaded site categories — it is populated by the category-list serializer, which the homepage never calls. The lane whose whole purpose is to advertise the library announced it was empty. `categoryStats()` now sums the subtree client-side from `Category.list()`, no extra request.
- *Titles double-encoded any fancy character* — "La Seu d'Urgell" rendered as "La Seu d&rsquo;Urgell". `fancy_title` arrives already cooked, and `dReplaceEmoji` escapes before substituting. Core renders `fancy_title` raw for exactly this reason; the four topic blocks now do too.
- *The category definition topic led the showcase grid* — pinned, so it sorted first, and imageless, so it opened the grid as an empty grey card. `loadCategoryTopics` drops every definition topic, filtering before the slice so lanes keep their length.

**Branch protection.** Recorded as a convention in `CLAUDE.md` and enforced nowhere, which is how PR #14 landed on main with four jobs still running. `main` now requires `linting`, `backend_tests`, `frontend_tests` and `system_tests`. Required reviews stay off (a sole maintainer cannot approve their own PR) and `enforce_admins` stays false as an escape hatch for the shared workflow this repo does not control. The trap worth remembering: `check_for_tests` builds the CI matrix from `Dir.glob`, so deleting the test files would stop a required context from ever reporting and would block every PR forever.

**Settings documentation.** The three link settings take a URL straight to `href` after a trim, so an absolute destination typed without its scheme resolves against the current page — `demo-a.example.com` becomes a 404 on this host. It had already happened once on `demo_url`. Documentation only: `validations: { url: true }` exists only inside a `type: objects` schema, and converting the three would discard the values admins have stored.

## 2026-08-17 — Homepage data, second pass

**The showcase now requires a cover image.** The lane exists so members can exhibit certification work; a card with no image exhibits nothing, and those topics were still taking a cell filled with a grey box and a picture glyph — three of six on the live instance, so half the grid read as broken. `loadCategoryTopics` gained `requireImage`, applied before the slice. Measured on category 78: 30 topics in the first page, 29 after the definition topic, 12 with a cover image — six cells against twelve candidates.

**Events split into upcoming and past.** Category 59 carries `sort_topics_by_event_start_date`, but the listing it serves is *exactly* `bumped_at` descending — verified by comparing the served order against a `bumped_at` sort. The one upcoming event led the lane only because it happened to be the most recently bumped topic; four write-ups later it would have dropped off a four-row lane entirely. The split is therefore client-side: "Próximamente" soonest-first, then "Celebrados" in recency order, each rendering nothing when empty. `fetchTopics` now loads the page unsliced, because slicing first would discard an upcoming event below the cut before it could be promoted — the exact bug the change exists to prevent.

**Emoji in excerpts.** One news excerpt in four printed `:automobile:` as words: `ExcerptParser` strips cooked HTML to text and turns emoji images back into shortcodes. Fixed with `emojiUnescape`, not the `dReplaceEmoji` used for category names — that one escapes its input first, which is right for plain text but would re-encode an excerpt that is already HTML-encoded (30 of 30 sampled carry entities) and reproduce the `&rsquo;` bug fixed the day before.

**Instance state.** PRE upgraded to 2026.8.0-latest.1. This theme became the **only** theme on the instance and therefore the default — Air Theme (id 2), the legacy `Gestiona avanza` (id 1) and the earlier id 14 install were deleted, so every push to `main` now lands on every PRE user immediately, and there is no fallback theme to switch to. That is what the green-CI-before-merge rule is protecting. The 2026-08-11 API key was revoked, which leaves `discourse_theme watch` needing a `--reset` before it can run again.

**A stray `[event]` removed.** Topic 2592, a July newsletter, carried a mistyped 2026-11-06 reference to the November congress — which has its own event in topic 2600. Two symptoms worth recognising: `display_post_event_date_on_topic_title` decorated the newsletter with an "en 3 meses" future badge in its category listing, and `/discourse-post-event/events.json` reported two site-wide events when there was one. The site-wide feed is only as clean as the `[event]` blocks in ordinary posts.

**What the six bugs have in common.** Every one of them passed CI green, because none of them broke anything — the lanes rendered fine and stated falsehoods. `javascripts/discourse/blocks/` has no test coverage at all; the acceptance tests cover the topbar and the header links only.

## 2026-08-24 — Hygiene sweep

Shipped as `theme_version` 0.16.2. Documentation and one weight, no behaviour —
the version moves so the installed theme can be told apart from 0.16.1, not
because anything on screen changed.

**`settings.yml` described a plugin state that changed twelve days earlier.** The events lane's comment said `calendar_enabled` is off and the lane is sorted by topic recency. The calendar was enabled on 2026-08-12 and the lane has read `event_starts_at` ever since — the setting's own comment contradicted the block it configures.

**Weight 600 was back.** Phase 1 of the brand audit stripped the four occurrences the theme had; the topbar reintroduced one on 2026-08-15, and `docs/superpowers/specs/2026-08-15-topbar-design.md` is where it came from — the spec's appearance table specified it. Corrected in both, or the next implementer reads the spec and puts it back.

Set to 700 rather than the 500 the design arguably means. Core serves Roboto 400 and 700 only; CSS font matching resolves a requested 600 *upward*, so the figures have been painting in the real Bold face all along and 700 changes the declaration without changing a pixel. 500 would match *downward* to 400 and flatten the figures into their labels — it is the right value only after `Roboto-Medium.woff2` is vendored, which is open decision 3.

**`docs/brand-audit.md` was still writing as of v0.5.0** with the subject pinned at `theme_version` 0.2.0, ten versions behind. Finding 5 ("every core surface outside the homepage is still stock") had stopped being true: header, nav, sidebar and topic-list are all styled now, and what remains of the finding is the topic view alone. Phase 3 gained a per-surface status table, and open decisions 1, 2 and 3b were folded into a resolved line — they were settled on 2026-08-12 and never struck off.

## 2026-08-24 — Test coverage, then the last stock surface

**Two test layers, split by what each needs.** The homepage blocks had no coverage at all, and the six data bugs of 2026-08-16/17 had all passed CI green because none of them broke anything — they rendered fine and stated falsehoods.

`test/unit/` and `test/acceptance/category-topics-test.js` (25 tests) cover the data pipeline at the function boundary. `loadCategoryTopics` takes the store as an argument rather than reaching for the service, so the whole fetch path is testable with a fake store and no network stub. The four Category-dependent functions need an application booted for `Category.list()`, so they use `acceptance` + `needs.site` — but no test there visits a route.

`test/integration/homepage-lanes-test.gjs` (7 tests) covers what only the DOM reaches: the two encoding bugs, the events split, the showcase's image requirement.

**Three harness facts, none guessable, all now written into the files.**

1. **Theme modules import from `test/` without the `javascripts/` segment.** The bundle uses `javascripts/` as the source root, so `javascripts/discourse/lib/x` compiles to `<theme>/discourse/lib/x` while `test/` sits directly under the theme root. Relative, never absolute — a bare `discourse/lib/...` collides with core's namespace, and the theme id in the root (`theme-1` in CI, 15 on PRE) is not stable.
2. **`visit("/")` does not render the theme's blocks in tests.** `custom_homepage` is applied server-side and does not reach the JS test environment; `/` is core's discovery route there. `topbar-test.js` carried a comment asserting the opposite, never verified because those tests visit `/latest` — corrected. Blocks render through `<BlockOutlet>` with `setupRenderingTest` + `withPluginApi(api.renderBlocks(...))`, core's own pattern. The vendored block skill's testing snippet is not sufficient: it shows `registerBlock` outside `withTestBlockRegistration` and never shows a render.
3. **`setupRenderingTest` runs `autoLoadModules`**, which executes the theme's own initializer, so `homepage-blocks` already has a layout before any test body runs. The tests use `main-outlet-blocks` instead. Outlet layouts *do* reset between rendering tests — core reuses one outlet fifteen times in a file.

**The lesson that cost the most.** Fixture topic ids must avoid core's category definition topics; the site fixture puts one at **11**, three times over. `loadCategoryTopics` drops those silently, the lane falls through to its empty state, and the assertion fails on a missing element that reads exactly like a rendering bug. One digit separated a passing test from five CI runs spent on emoji settings and helper contexts that were working correctly all along. Ids now sit at 900000+.

Method note, recorded because it generalises: after the first "obvious" fix failed, the next move should have been to instrument the DOM and *look*, not to try the next plausible hypothesis. Doing that at the end produced the answer in one read. `CLAUDE.md` already says it — "si el primer fix falla, detente, re-analiza el flujo completo" — and it was not applied.

**The topic view, v0.17.0.** The last stock surface of a member's session, and the close of Finding 5 and Phase 3. Deliberately small: core keeps the post stream's mechanics, the theme adds the brand layer. The topic title takes Roboto Slab at the system's 28px step — page titles are the one place the system spends Slab, so the two brand moments a member meets are the homepage and the top of a thread. Quotes go flat with a neutral hairline, *not* the cyan filo: that gesture means "active, focused or leading" and a quote is none of the three.

Two variables left unset on purpose. `--content-border-color` already resolves to `--ga-border` from `topic-list.scss` and reaches post separators too; `--d-content-background` is global, so setting it would repaint categories, search and the list at the same time.

**Confirmed on PRE by the maintainer the same day** — the only verification this surface can get, since `core_features_spec.rb` skips `topics:read` and `topics:reply` and `discourse_theme watch` is still unauthorised.

**Weight 500 turned out not to be a vendoring job.** `google/fonts` now ships only the variable `Roboto[wdth,wght].ttf`; the CSS API serves Roboto v51 sliced into ~9 `unicode-range` subsets, where the 400 and 500 URLs are the same file. `discourse-fonts` ships static Regular and Bold from an older cut that can no longer be reproduced. Mixing them would put the mismatch on precisely the weight meant to signal emphasis. Open decision 3 in the audit now states the four real options; none is taken.

**Versioning convention, made explicit:** features take the minor, fixes and chores the patch. Every release from 0.10.0 follows it except 0.16.3, which was a `feat:` given a patch — left as is, since it had already been pulled.

## 2026-08-25 — PROD parity deferred behind the category reorganisation

The standing "verify PROD category IDs" task was **not** done, by decision. A
category reorganisation is the next block of work, so diffing IDs now would
measure a map about to be redrawn. The maintainer confirms the two taxonomies
match today by eye — enough to plan against, not enough to ship ID-keyed config
on. The diff moves to where it belongs: the gate immediately before the theme
installs on PROD.

**What a reorg does and does not cost.** Discourse category IDs survive rename,
slug change and reparenting, so the long-agreed promotion of category 78 to top
level is free — it stays 78. Only create, delete + recreate and merge issue or
retire IDs.

**The exposure is PRE, not PROD.** All five homepage lanes are keyed by numeric
ID, so a reorg that touches IDs breaks the live instance's own settings, and the
theme is the only one installed there. Three failure modes, and only the first
announces itself:

| Change | Symptom |
|---|---|
| category deleted or merged | `c/<id>/l/latest` 404s, the lane shows an error |
| topics moved out, ID kept | lane renders its `<:empty>` state, silently |
| category repurposed | lane renders the wrong topics, silently |

The two silent modes are indistinguishable from a genuinely quiet category, so
neither the theme nor CI can report them. `settings.yml` now carries this table
in its header, because that is the file someone opens when a lane goes blank.
Retuning the lane settings after the reorg is unavoidable work, and PROD parity
is a by-product of that pass rather than a separate task.

Agreed order: reorganise PRE → retune the lane settings → check the five lanes
render → replicate on PROD → parity diff + PROD settings.

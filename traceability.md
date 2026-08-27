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

## 2026-08-25 — The category reorganisation, designed

Full design in `docs/superpowers/specs/2026-08-25-category-reorganisation-design.md`
(#30). **34 categories → 17 active, 10 visible top-level → 9, no new IDs.** Sixteen
categories dissolve into tags or into their parent, 71 is archived, and only 73
keeps children — kept as the deliberate exception after collapsing it was offered
twice and declined twice.

The axis moves from subcategory to tag. Three findings justify it: the three
programmes may see each other, so per-category permissions buy nothing against 59
groups; a tag crosses categories, which a póster topic needs because it is both an
arrival announcement and a library resource; and a tag survives a reorganisation
where a category-keyed lane empties in silence.

**Most of the dissolved categories already carry their tag** — `trucazo` on 13 of
62's 16 topics, `seminarios` on 46 of 67's 50, `newsletter` on 20 of 65's 28. They
were duplicating a classification the topics already had, which is the clearest
argument in the design that they are tags wearing category clothing.

**One permission widens and it does not undo cheaply.** 65 Newsletter is
read-restricted, 4 is not, so dissolving it makes 27 topics readable by everyone
who can read Noticias. Accepted by the maintainer. Deleting 65 retires its ID, so
restoring the restriction would need a new category and a second move — the exact
create-and-move the rest of the plan avoids.

**A measurement trap, recorded because it produced four wrong readings.** A
category's `latest` listing includes its subcategories' topics and pins the
definition topic first, so reading activity from the first row reports the
definition topic's age: 78 read as 4 months idle when it was 5 days, 62 as 17
months dead when it was 19 days alive. Take `topic_count` from `categories.json`,
never from a listing.

PRE goes first and PROD follows, decided after the two documents disagreed about
it. PRE is a faithful rehearsal — the taxonomies match ID for ID — and rehearsal
is what phases 3 and 4 need, since bulk tagging and topic moves cannot be undone
once the source category is deleted.

## 2026-08-26 — Phase 5: the homepage catches up with the new taxonomy

Theme code only (#31, #32). Five lanes become six; **57 tests, all green**;
`theme_version` 0.17.0 → 0.18.1.

| Change | Why |
|---|---|
| news lane → site-wide `latest` | keyed on category 4 it was 57% arrival announcements, because 4's listing carried 78's 164 topics |
| a sixth lane for "Tengo una idea" | 318 topics at 3.6 replies, the largest category on the site, and it had no heading of its own |
| `loadCategoryTopics` takes a `tag` | the showcase lane needs the póster subset of 78 once that category also holds welcome content |

`news_category_id` is deleted; `ideas_category_id` and `ideas_count` are added.
Nothing else moves, because every category anchoring a lane is renamed or
reparented rather than recreated.

**The news lane is now the one a reorganisation cannot empty**, since it no longer
names a category.

**The tag filter goes to the server, unlike `requireImage`.** That one filters the
page already fetched, which is right for it and wrong here: the póster subset is a
growing minority of 164 topics, so a page filter would show a handful of cards and
call the rest absent. The endpoint was verified against the live API before the
test was written — `c/62/l/latest.json?tags[]=markdown` returns 6 of 16. An
empty-string guard keeps an unset setting from becoming `tags: [""]`, which matches
nothing and would empty a lane silently.

**"Tengo una idea" is a second `BlockForum`, not a new component.** It was already
parameterised and its shape is what a category at 3.6 replies/topic wants. The icon
and the empty string were the two things its template hardcoded; both became args.
The forum lane deliberately does *not* also point at 18 — with a lane each, that
would print the same 318 topics twice on one page.

`loadLatestTopics` is a separate function rather than a mode of `loadCategoryTopics`,
because a falsy category id there means *the lane is switched off* and must not
touch the network. It drops definition topics too, and that matters more: a category
lane only ever met its own subtree's, while `latest` meets every one on the site
whenever a category is created or edited.

### Two Blocks API behaviours, measured here and absent from the vendored skill

Both were found the expensive way, each costing a CI run, and both are now in code
comments where they will be met again:

- **An undeclared arg aborts the entire QUnit run** with an uncaught `BlockError`,
  taking down tests that have nothing to do with blocks — 25 of 56 never ran.
  Declare a new arg inert first, then honour it.
- **Rollup hard-fails the whole theme bundle** on an import of a missing export and
  reports a compile error rather than a test failure; all 56 tests died as one
  global error. Export an empty stub before writing the implementation.

### CI is the test runner, including for the red step

There is no Discourse checkout on this machine, so QUnit only runs in
`frontend_tests` on a PR — roughly four minutes per red-green cycle, which is the
reason to batch a red push rather than go test by test. The full cycle for #31 ran
four times: compile error, global abort, a clean red of exactly 7, then green.

### Unguarded, and worth knowing

`lightbulb` was added to `svg_icons`, and **no test can guard it**: `dIcon` writes
the `d-icon-<name>` class whether or not the SVG sprite carries the symbol, so a
missing entry renders an empty box with the suite green. It joins category listings
and the topic view on the list of surfaces only the maintainer's eyes cover.

**Not done, deliberately:** the showcase lane is not wired to a tag. The capability
ships and is tested; pointing the lane at the póster tag is phase 6, once that tag
exists.

## 2026-08-26 — Phases 1 to 3 execute, and a missing icon turns out to be a frozen instance

Thirteen PRs, #30 to #42. The taxonomy work moved from design to execution on PRE:
renames and slugs, the tag vocabulary, and 800 topics tagged. Phase 4 — moving topics
and deleting categories — is where it stops, deliberately, because it is the first
step that cannot be undone.

### The bulb that was never there

The day's longest thread began as "the lightbulb icon does not render" and ended
somewhere else entirely. `svg_icons` was declared correctly, the arg was wired
correctly, the tests were green. The lane itself was absent — and so was the setting
behind it, and the entry in `svg_icons`.

**PRE was not running `main`.** A `d-compat/2026.8` branch had been cut automatically
at 01:08 UTC that morning, the first this repo ever had, and Discourse moved the
instance onto it by itself: `branch: None`, `remote_compat_ref: d-compat/2026.8`,
`commits_behind: 0`, `theme_version 0.17.0`. Perfectly up to date with a branch nobody
chose, while six PRs sat unreachable on `main`.

Three corrections came out of chasing it, each replacing something asserted too
early:

- The nightly run did not *decline to advance* the branch, it **created** it. The
  evidence for "it never advances" is the shared workflow's own source
  (`Branch #{branch} already exists on origin. Skipping.`), not the observation that
  first suggested it.
- The branch is cut for the **current** core version, not the previous one. Discourse's
  latest tag was `v2026.8.0` and PRE ran `2026.8.0-latest.1`, so there was no core
  upgrade to escape through — a fix that had been written into `CLAUDE.md` and had to
  come back out.
- Deleting the branch alone would not have held, because the next run recreates it.
  The workflow had to go with it.

`d-compat-branch.yml` is deleted. What this theme gives up is implicit protection for
an instance on older core; the explicit tool for that is `.discourse-compatibility`,
still in the repo and still empty by choice.

The lesson worth keeping is not "check which branch the instance follows". It is that
**the day a compat branch first appears, there was nothing to check the day before**.
`main` is what the instances run, right up until it silently is not.

### What measuring changed about the plan

Three things the design had asserted without evidence, checked with a Global-scope key
that was created for the purpose and revoked the same day.

**Permissions are neutral.** All fifteen dissolutions move topics between categories
with the same effective audience. `read_restricted` here does not mean what it looks
like: category 65 was limited to `Certificación`, which has **375 members against 373
registered users**. The group is the community. So the plan's headline irreversible
risk — widening read access on the 27 newsletters, "not cheaply undone" — was never a
widening at all. This also turns the case for tags over subcategories from a
reasonable assumption into a measurement: there is no confidentiality boundary between
the programmes for a subcategory to express.

**PRE and PROD are not the same data.** Category IDs match exactly, 34 against 34.
Tag counts and topic counts do not, in both directions: `caag` 40 against 15,
`analiza` 62 against 69, and category 5 holding **196 topics on PRE against 252 on
PROD**. Every other count matches, so it is one category out of step rather than a
stale copy. Phase 3 needed its own worksheet.

**The instance was configured as if tags were marginal**, and the reorganisation makes
them the primary structure. `max_tags_per_topic` was **3** — topics already carry 2–3,
so a bulk append would have exceeded the cap on roughly a hundred topics, failing
partway rather than cleanly. `max_tag_length` was 20, which truncated
`administracion-avanzada` on entry and briefly renamed it. Raised to 7 and 30.
`max_tag_search_results` is still 3, and is the likeliest reason the vocabulary had
grown to 226 tags: three suggestions while typing is how you fail to find the tag that
exists and invent another.

### Traps that only appear when you execute

**Bulk selection follows subcategories.** Category 5 still has three children, so
*select all* there reaches 307 topics rather than 199 — `administracion-avanzada`
would have landed on 102 February-campaign topics, five from Recursos compartidos and
one V9 topic. `?no_subcategories=true` is the fix. Category 5 was the only source with
children.

**The bulk dialog cannot mint a tag.** It only offers tags that already exist, and
there is no standalone "create tag" button anywhere in the admin. A tag is born by
being applied to a topic or typed into a tag group. This cost a false start on
`campana-2024`, which the dialog accepted and silently did not apply.

**`topic_count` excludes unlisted topics as well as the definition topic**, and
category 3 holds nine unlisted `expertos-espublico` talks that *select all* will not
see in phase 4. It is the only category affected; the other seventeen return exactly
`topic_count` + 1.

**Three tag variants were invisible to a plan written from canonical names** —
`app-móvil`, `seminario`, `póster` — and the maintainer found all three by reading the
live vocabulary rather than the document. A normalised sweep then turned up 11
families of near-duplicates. `búsquedas-avanzadas` is the shape of it: three spellings,
16 uses between them, and the correctly formed one has a single use.

### The constraint earning its place on day one

Category 5 finished phase 3 at **196 of 198** tagged, which is correct. The two
holdouts already carried `developers`, and `max 1 per topic` refused them a second
programme tag. In a bulk operation over 198 topics the partition held itself — 196, 2,
no overlaps — with nobody reading a row. That is the whole argument for the tag group,
demonstrated the first time it was used, and it answers the question that had been
asked that morning about what the group was for.

### Naming, and one decision reversed

Category 5 went through three names in a day: *Expertos* from the design, *Usuarios
certificados* during phase 1, and back to **Foro del certificado**. The one that
survived is the only one of the three that names the place rather than the people in
it, and the category is the general forum rather than a roster. The homepage lane
title was aligned with it, retiring one of the six placeholder strings.

The tag group was renamed too, from `Certificaciones` to **`programa-certificacion`**.
There is a *user* group called `Certificación` with 375 members; the two things in this
project that had nothing to do with each other were one letter apart. Three different
things here answer to "group" — user groups, tag groups and categories — and the
ambiguity cost real confusion twice in one day.

**`posters` is kept and cleaned rather than retired.** The design retired it into
`alumno-certificado` and minted a fresh tag for genuine pósters, arguing that stripping
leaves no way to tell a missed póster from a correctly-cleaned non-póster. The
maintainer's objection was that pósters and arrival announcements are becoming two
different kinds of post and deserve two tags — which the design wanted too, it only
declined to reuse the name. The auditability argument does not survive a *full* sweep:
removing the tag from all 158 topics in one operation and reapplying it deliberately to
the ~17 genuine ones gives the same guarantee while keeping a word the community has
used 158 times.

**Subcategories are settled as a standing rule**, and it outlives this reorganisation:
conversational surfaces stay flat, documentation categories may keep children. The test
is measurable rather than aesthetic — category 73's seven children hold 66 topics and
have never received a single reply, so there is no conversation to fragment. That
retires the residual about 73: it is not an exception to a flat tree, it is the rule
applied to a documentation category.

## 2026-08-27 — Phase 4: the tree comes down, and nothing is lost

**34 categories → 17.** The irreversible phase ran end to end on PRE and, in the event,
**deleted no topic at all**: the two candidates for the bin were archived instead. 284
topics moved in 16 operations, 17 categories deleted, six deliberate departures from the
plan.

The method that made it safe was cheap and worth reusing. **Every move was verified by
topic ID, not by count.** The source category's listing was captured before the move and
each topic located in the destination afterwards, so "nothing was lost" is a measurement
rather than an inference from arithmetic that happens to balance. It also caught the two
faults below, which no per-category count could have surfaced.

### The trap the plan did not have

Every source category's listing carries its own definition topic, and **only 4 of the 15
were pinned** — the rest sort by activity, mixed into real content. A *select all → change
category* takes it along.

That is not cosmetic, and the reason is in the theme. `definitionTopicIds()` builds its
exclusion set from `Category.list()` via each category's `topic_url`; **delete the source
category and the entry disappears, so the orphan stops being filtered** and surfaces in the
lanes as an ordinary recent topic — most visibly in the site-wide news lane. An
`Acerca de la categoría Newsletter` would have appeared in Noticias, and only after the
deletion that made it irreversible.

Reading each definition topic's id off the API and handing it over per category was cheaper
than hunting a title in a 103-row list. All 15 stayed put.

### Two Phase 3 errors that only a full sweep would find

Walking all 441 topics of category 18 after the moves turned up two faults in the bulk
tagging. `campana-2024` had been applied to category 58's 102 topics as well as category
57's 20 — 122 uses conflating two campaigns, and the tag is the *only* thing that survives
those categories being deleted. And the 20 topics arriving from 57 carried no
`administracion-avanzada`, because Phase 3 swept category 18 while they were still outside
it.

Both fixed in two operations, and **the order made them exact**: strip `campana-2024` from
everything carrying `campana-febrero-2025` and precisely the 20 remain, so the second
filter returning 20 is itself the proof that the first worked.

The generalisable lesson: *bulk-tag a destination after its inbound moves, not before.*

With the categories gone the tag became the classification, so the three were renamed to
`ideas-2024` / `ideas-2025` / `ideas-v9`, sitting alongside plain `ideas` (319 live ones).

### What the plan got right, and the one thing it missed

The headline risk never materialised. Five lanes are keyed by numeric category ID and the
fear was that a reorganisation would leave one pointing at a dead ID, rendering empty and
silently. **No theme setting was retuned and no theme code changed**, because the deletion
set and the lane set are disjoint — exactly as the *Lane safety* check had predicted the day
before.

What it missed was an access question. The permissions analysis measured the 15 dissolution
pairs and found every one neutral, but **category 3 → 14 was never in that table**. Both are
`read_restricted` to different audiences: 3 is staff, 14 is member groups. Moving nine
unlisted staff topics there would have widened who could reach them by direct link. The
maintainer's call — archive them in place, they are disused — made the question moot, and
cost the library card ten documents it was projected to gain.

### Two facts corrected

**Category listings answer 301, not an empty body.** The 2026-08-26 note claiming
`/c/<id>/l/latest.json` returns nothing was `curl` without `-L` reporting a redirect it had
not been told to follow. With `-L` the ID-only form works for top-level categories *and*
subcategories — which is the shape to use, because the slug form needs the full parent path
for a child and is itself another 301.

**The homepage is a two-column grid, not a stack of six lanes.** Above 60rem of container
width `home-main` (news, forum, ideas) and `home-side` (events) sit side by side, with
showcase and library full-width beneath. Reading the main column top to bottom yields five
lanes and looks like events has vanished. It has not; it is to the right. Worth knowing
before diagnosing the next missing lane — the last one turned out to be a frozen instance.

## 2026-08-27 — Phase 6: the poster tag becomes true, and a write costs nine thumbnails

**Goal.** Close the category reorganisation: clean the `posters` tag so it means something,
wire the showcase lane to it, and pull the stray arrival announcements into the category
that owns them.

**Measured before touching anything.** All 1,249 topics of the 17 categories over the API,
then the **full post stream** of every topic in category 78. Three of the plan's assumptions
did not survive it:

- **78 holds no poster topics.** All 149 are arrival announcements; the poster is an artifact
  *inside* them. So `posters` cannot mean "this is a poster" — it means *this announcement
  carries one*.
- **The poster comes in two formats.** Embedded as a portrait image in 17 topics, attached as
  a PDF in 36, absent in 98. The grid needs `image_url`, so **the 34 PDF-only ones can never
  appear in it**, tagged or not.
- **The `alumno-certificado` prerequisite was void.** Five topics, not three, and none would
  have been left unclassified; three were Eventos topics about the poster *contest*, where
  the tag would have been false.

**The check that made the sweep safe.** The first-post scan cannot see a poster posted in a
reply, and stripping the tag off such a topic would be a silent, unrecoverable loss of
signal. The full-thread scan answered it: **51 posters in first posts, 0 only in replies.**

**Executed.** 115 topics — 103 tag removals, 6 additions, 5 `alumno-certificado` fixes,
11 moves into 78 — each read fresh immediately before its write and re-read after. **0
failures.** `posters` went from **158 uses to 61**; category 78 from 149 topics to 160.

**The finding that will repeat on PROD.** A topic updated through `PUT /t/-/<id>.json`
**loses its `image_url` in every topic listing.** All nine topics that had a thumbnail and
received a write lost it — six of them tag-only edits — while the 49 that needed no change
kept theirs. That contrast isolates the cause: the write, not the move. The post is intact;
only the topic-level thumbnail is gone, and that is exactly what `requireImage` filters on,
so three poster-bearing topics fell out of a grid pool that is 22 instead of 25.

**A rebake does not bring it back** — tried on all three, pool unchanged. The discriminator is
in the cooked HTML: the topics that kept a thumbnail have a first image resolving to an
`optimized/` derivative on the CDN, the ones that lost it resolve to the raw S3 original. They
were being served the upload itself, and once the write invalidated that there is no
derivative to fall back on. Narrower than it looked for PROD, and still silent.

**Two keys, not one.** A granular key scoped to `topics: update` cannot read: `GET
/t/<id>.json` answers 403. The first executor run failed all 115 topics at the read stage
before attempting a single write — no damage, but the run looked complete until the log was
counted rather than skimmed.

**What the posters are.** Certification deliverables, on four independent signals: 50 of 51
titles name a cohort; nobody announces themselves; the attachments say *"Evaluación final
certificación"*; and seven of the eight posters exhibited at the III Encuentro match a
certification announcement word for word by project title. The exceptions are one
self-presented poster (Estrella Fadrique, who has no announcement anywhere) and the Hackathon
deliverables, which turn out to carry no posters at all — seven of the eight have neither
image nor attachment.

**Theme.** `showcase_tag` (default `poster-evf`) narrows the grid on top of the category, sent
to the server as a `tags` param. Two integration tests: the tag reaches the request, and an
empty setting means *no filter* rather than `tags: [""]`, which would empty the lane in
silence. `theme_version` 0.19.0, merged in #45 with all five checks green.

**The tag was renamed the same afternoon.** `posters` → **`poster-evf`**, once the sweep had
shown what it marks: the certification's *evaluación final* poster, which is not the same
thing as a poster an event exhibits. The III Encuentro compilation `/t/1959` takes
`poster-congreso-2025` instead. `showcase_tag` moved with it — **a tag rename empties a
tag-filtered lane in silence**, because the request just stops matching, so the setting and
the rename have to ship together. `theme_version` 0.19.1.

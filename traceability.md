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

**A rebake does not bring it back** — tried on all three, pool unchanged. It is not inert: the
post is re-cooked and its HTML now points at an `optimized/` derivative where it pointed at
the raw S3 upload. The topic-level thumbnail stays gone.

**Two explanations of why have already been wrong** — that a rebake would fix it, and that the
casualties were topics whose image lacked an optimized derivative. The second came from
reading one topic before its rebake and comparing it against one that had never been written;
all nine casualties now show optimized derivatives and still have no thumbnail. What is
measured is the price, not the mechanism: **a write costs a topic its place in any lane that
filters on `image_url`**, and nothing tried gives it back.

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

**Both write routes clear the thumbnail.** The admin bulk dialog uses `PUT /topics/bulk.json`
with `append_tags`, a different endpoint from the whole-topic update, and the hope was that it
only touched tags. Tested on one pool topic with the thumbnail measured either side: the tag
landed and the thumbnail went. There is no cheap route — the cost belongs to tagging a topic,
not to the tool.

So the price was paid on purpose: `poster-congreso-2025` on the eight III Encuentro topics
took the showcase pool from **22 to 17**, five of the seven announcements having been in it.
And "pool" flatters the lane: it fetches one page, the 30 most recently active topics of the
filtered listing, so only **10 of the 17** are reachable at all. The margin over six cells is
four.
**`poster-congreso-2025` ends on one topic**, `/t/1959`, and `poster-evf` on 60, all inside
category 78. Getting there took a round trip worth keeping.

Seven announcements were tagged as congress posters first, on a title match: the eight posters
exhibited at the III Encuentro name their exhibitor and project, and seven matched an
announcement word for word. The match was real; the conclusion was wrong. It proved that *the
poster* was exhibited, not that *the topic* is a congress topic — the topic is an arrival
announcement whose poster is the evaluation deliverable, and the tag describes the topic. All
seven were reverted.

**What did not revert is the cost.** Five of the seven were in the showcase grid, every write
clears a thumbnail, and the pool went 22 → 17 and stayed there after an operation undone in
full. A tag edit is logically reversible and physically is not, so the scope of a tagging pass
has to be settled before the first write: "we can always untag it" buys back the tag, not the
card.

Still unresolved is whether a lost thumbnail returns after a day; nothing recovered within the
session.

**The lane went empty, and the instance was the reason.** Renaming the tag on PRE broke the
showcase lane even though the theme fix had merged 40 minutes earlier: **a remote theme does
not pull on merge.** PRE was still on #45, filtering by `posters`, and its theme record said
`commits_behind: 0` — true of its last check, which ran at 10:46, before the fix merged at
11:20. Zero results, no error, an empty lane, and a record claiming everything was current.

Fixed twice over: the setting written directly onto the instance
(`PUT /admin/themes/15/setting.json`), which fixes it in seconds, and then a forced pull
(`PUT /admin/themes/15.json` with `theme[remote_update]`) to bring the instance to main.
`POST /admin/themes/<id>/update.json` is a 404. Read `updated_at` next to `commits_behind`,
because the reassuring number is the one that lies.

## 2026-08-28 — The interface reaches the window edges, and the probe answered the wrong question

Ricardo asked for a full-width interface "como en esta otra comunidad",
`community.hubspot.com`. Measuring the reference first turned the task around.

**HubSpot is Discourse, and its content column is narrower than ours** — 1200px against
our 1240. Nothing about the request was really about content width. What reads as full
width there is the *chrome*: `.d-header .wrap` at `max-width: none` and the sidebar flush
to the window edge. Ours sat in a 1512px island (`--d-max-width` + `--d-sidebar-width`,
core's `calc()` on `body.has-sidebar-page .wrap`) with 204px of dead margin either side at
1920. Asked which he wanted, Ricardo picked the faithful copy — chrome to the edges,
content keeping its measure — and then asked for the three-column grid as well.

**The reference's grid needs no breakpoints.** Measuring it at three widths gave
1920 → `328/1200/328`, 1600 → `272/1200/64`, 1280 → `272/944/0`, which is
`minmax(var(--d-sidebar-width), 1fr) minmax(0, <measure>) 1fr`: the left gutter is never
allowed below the sidebar's own width, so the right gutter gives way first and the content
column narrows only after it has reached zero. It also leaves `grid-template-areas` alone —
core names two areas and the third column stays unnamed — so nothing takes ownership of
core's `below-content` row or its `sidebar-animate` transition.

**The cap is released by inheritance, not by overriding `max-width`.** `--d-max-width` is
widened to `100vw` over the chrome's subtree and restored to the measure on `#main-outlet`.
A custom property redefined on a descendant wins for that subtree outright — it is a
different element from the `:root` that declares it, so specificity never gets an opinion.
`100vw` rather than `none` because core builds the sidebar case as
`calc(var(--d-sidebar-width) + var(--d-max-width))`, and `none` inside a `calc()`
invalidates the declaration. The measure moved to its own token, `--ga-measure`, because
consumers that are not the content column keep needing a real length: the composer's
hide-preview offset, large badge cards, and `.more-topics__container`, which divides it and
held at 1079px throughout.

Verified live on PRE at 1920 / 1600 / 1280 / 390 on a listing, the homepage and a topic:
`308/1240/308`, sidebar at `left: 0`, content centred with 340px either side, six homepage
lanes and two columns intact, no horizontal overflow anywhere, and a post's reading measure
unchanged at **714px** at every width. Centring survives a sidebar toggle only from 1848px
up — measure, both gaps and two sidebar widths; below that the content sits beside the
sidebar rather than centred, which is the trade the reference makes too.

### The probe answered a different question than the one asked

Every cascade check behind #54 was run by appending a `<style>` to `<head>` from the
console. Measured that way, an equal-specificity override loses to core: `.wrap
{ max-width: none }` does not win, and neither does `body.has-sidebar-page
#main-outlet-wrapper`, which ties core's own rule at (1,1,1). That went into the design, the
comments and the commit message as a property of the instance.

It is not one. Inserting the same tie into the theme's **compiled stylesheet** with
`CSSStyleSheet.insertRule` shows it winning: `body.has-sidebar-page .wrap
{ max-width: 555px }` takes effect over core at the same (0,2,1). The theme sheet is
unlayered and is the last `<link>` on the page, which is exactly what should happen. What
loses is the injected `<style>` — later in document order still, with no `@layer` anywhere
on the page. **That mechanism is unexplained and stays unexplained**; what it cost is the
point.

So console injection is fine for prototyping geometry — the whole three-column grid was
designed that way and the compiled result matched it to the pixel — and unsafe for anything
whose outcome turns on the cascade. Corrected in #55, with the rule recorded in `CLAUDE.md`.
The extra `.wrap` on the selector stays: it was never required, but it makes the rule
independent of a load order the theme does not control.

`theme_version` 0.20.0 (#54), docs correction #55. PRE pulled and verified against the
compiled theme, not against injected CSS.

## 2026-08-28 — The category background photos come off, and the theme was never the culprit

**Goal.** Ricardo asked for a clean background on every topic in every category — no custom
background images. The first job was finding out where they came from, because the theme
does not paint one.

**It is admin data, not theme code.** The only `url()` background in this repo is the
isotype at 4 % behind an empty homepage lane (`app/mixins.scss:64`). The photos are
`uploaded_background`, set per category in admin. Core injects them at runtime from
`frontend/discourse/app/components/d-styles.gjs` as
`body.category-<fullSlug> { background-image: url(...) }` into a `<style id="d-styles">`,
and core's base serves the body background `fixed` and `cover`
(`common/base/discourse.scss:228`).

**They reach the topic view, not just the listing.** The `category` / `category-<fullSlug>`
classes come from `add-category-tag-classes.gjs`, which is rendered by discovery's
navigation **and** by `frontend/discourse/app/templates/topic.gjs:72`. With `#main-outlet`
transparent — `--d-content-background` is deliberately unset, see `app/topic.scss:20-24` —
the photo sat behind the posts themselves, not only in the margins. #54 had just widened
those margins to ~308px a side at 1920, which is why it had become conspicuous.

**Census, measured over the API before touching anything.** PRE **6 of 17** (4, 5, 14, 18,
59, 78); PROD **18 of 34**, one of them (87) carrying an `uploaded_background_dark` as well.
The six on PRE are the categories behind five of the six homepage lanes, so this was the
main path through the site rather than an edge case. On PRE the background and the logo
happened to be the *same upload id* on all six — separate fields, so clearing one leaves the
other, and the theme depends on neither: the library lane paints its swatch from
`category.color`.

**One rule rather than 24 admin edits.** `html body.category { background-image: none; }` in
`app/layout.scss`, (0,1,2) against core's (0,1,1) — it outranks rather than ties, which is
the policy #55 established after the console-injection episode and means nothing here rests
on a load order the theme does not control. A media query adds no specificity, so the dark
variant is covered by the same rule. Deleting the uploads instead would have been 6 edits on
PRE and 18 on PROD, reversible by any admin, and no protection against the next category
that acquires one.

**`commits_behind: 0` lied again, exactly as documented.** After #57 merged at 08:15:03 the
theme record still read `local_version 6a15af5` with `commits_behind: 0` — two commits
stale — because `updated_at` was 07:51. Forced `remote_update`, then verified the compiled
sheet PRE actually serves rather than the commit: `common_theme_15_463309ff….css` contains
`html body.category{background-image:none}`.

Ricardo then cleared the uploads in admin and confirmed both schemes by eye. Re-measured:
**PRE 0 of 17**. PROD still carries all 18 and will until its own pass — the rule already
neutralises them there, so the cleanup is about the record, not the render.

`theme_version` 0.20.1 (#57).

## 2026-08-28 — Page hero band: title, subtitle and a compose button above every listing

**What shipped.** A hero band — title, subtitle, and a "Hacer una pregunta" button that
opens the composer — at the top of the custom homepage and above every discovery listing:
categories, tags, `/latest`, `/top`, `/unread`. Topic pages and full-page search are
deliberately out of scope.

**Architecture.** One pure resolver, `lib/hero-content.js`, decides what the band says from
route context (category wins over tag; a bare listing falls back to generic homepage copy);
one presentational component, `components/page-hero.gjs`, renders whatever the resolver
returns. That single component is mounted twice — as a Block (`block-hero.gjs`) for the
custom homepage, which never runs the discovery route, and through the
`discovery-list-controls-above` plugin outlet (`discovery-hero.gjs`) for every listing. This
keeps the agreed split intact: Blocks confined to the homepage, outlets and SCSS everywhere
else.

**Why `discovery-list-controls-above`, and why it was `discovery-list-container-top` first.**
The outlet was the design's one declared unknown. It was first resolved to
`discovery-list-container-top` from indirect evidence — Discourse's theme-developer tutorial
documents that outlet used with `@outletArgs.category`, and `discourse-featured-tiles` renders
a tile grid into it. Both facts are true and the conclusion was still wrong: read against
`frontend/discourse/app/components/discovery/layout.gjs`, that outlet sits at line 124 **inside
`#list-area`**, below the nav tabs and below core's own New Topic button — so the band landed
mid-page with its own button duplicating an affordance a few pixels above it, and the spec asks
for a band at the *top*. `discovery-list-controls-above` (layout.gjs:56-64) sits above the whole
navigation block and carries `category`, `tag` and `toggleTagInfo`. It had been rejected earlier
for having "no evidence of carrying `category`" — which was absence of evidence read as evidence
of absence. It also drops a nesting bug for free: the old outlet declares
`@connectorTagName="span"`, so `<section>`/`<h1>`/`<p>` were nesting inside a `<span>`.

**The permission guard was got wrong, then right, and the wrong version is the lesson.**
The spec's guard was `category.permission === 1`. Hand-tracing the tests showed a fixture with
no `permission` field failing on `undefined === 1`, and that was read as a site-wide silent
failure: absence was taken to mean "the serializer didn't tell us", so the guard was changed to
defer to the global `can_create_topic` check whenever `permission` was missing. **That inverted
Discourse's own semantics and made the whole category check a no-op** — it returned true for
precisely the categories that must return false, and a test was written pinning the defect as
intended behaviour.

Core settles it, and settled it the whole time: `app/models/site.rb` writes
`category[:permission] = permission_types[:full] if allowed_topic_create&.include?(...)` with
**no `else`**, so the key is absent exactly when the user may not post there; and
`frontend/discourse/app/models/category.js` defines
`get canCreateTopic() { return this.permission === PermissionType.FULL; }`. The guard now
imports `PermissionType` from `discourse/models/permission-type` and compares strictly, with the
reasoning written into the file because the line has now been got wrong twice.

**The process lesson is the durable part: Discourse core's source is one `gh api` call away, and
"context7 has no documentation on it" is not the same as unanswerable.** Two decisions on this
branch were deferred to a manual check on PRE on exactly that reasoning, and both were wrong.
Note the frontend now lives under `frontend/discourse/app/` — the old
`app/assets/javascripts/` path 404s, which is probably what defeated earlier attempts to read it.

What genuinely cannot be read over the API stays true: `/categories.json` answers with the key's
own (admin) permissions, so **what a non-admin sees still has to be checked in a browser** — see
the outstanding checks below.

**Three checks remain outstanding, and none is covered by a test.** They need a browser
against the live instance, and this session did not open one:

1. ~~Exactly one `.page-hero` renders on the homepage.~~ **Closed by reading core, not by a
   browser:** `frontend/discourse/app/templates/discovery/custom.gjs` renders only
   `<BlockOutlet @name="homepage-blocks">` and the `custom-homepage` outlet — it never renders
   `Discovery::Layout`, so no discovery outlet can fire at `/`. The two mounts cannot collide.
2. The button is genuinely absent in a read-only category, checked with a **non-admin**
   account — the API keys can't make this check, they answer with admin permissions. Category
   3 (*Administradores*) and one of the *Recursos Analítica* tree are the candidates.
3. Legibility at 390px: title, subtitle and button, no horizontal overflow, subtitle clamped
   at two lines. Category 85 *Comparte* (414 characters of description) is the worst case.

**An admin task for the maintainer.** Four categories have no description and so render
title-only until one is written: 4 *Noticias*, 5 *Foro del Certificado*, 14 *Aula de
formación*, 59 *Eventos*. Category 3 is staff-only and 75 already has a short description.
Title-only is correct behaviour, not a bug — the band never invents filler — and writing the
text also improves the native categories page.

`theme_version` 0.25.0. Committed on `feat/page-hero-band`; not pushed, no PR opened, no
instance touched — releasing this is a separate, explicit decision for the maintainer.

## 2026-08-29 — The latest section's tests go green, three commits after the same wound

**The branch.** `feat/homepage-latest-section` / PR #71 — first increment of the homepage
redesign: a section frame, and section 1 (a site-wide *latest* list rendered with core's own
`topic-list/list`, beside a panel holding a shortcuts card and the ideas lane in compact
form). The events lane came out. `BlockNews` became `BlockLatest`; `news`/`ideas_count`
became `latest`/`panel_ideas_count`. Design and implementation landed in a prior session
(`8b42edb`); this session only closed CI.

**The symptom.** `frontend_tests` failed on three successive commits (`da9fea5`, `8b42edb`,
`a6b713b`, `6c4efba`) with an *escalating* error, each fix exposing the next:

1. `topic?.get is not a function` — the POJO fixtures the other lanes use.
2. `Cannot override the computed property url` — once real models were used, `url` is
   `@computed` on `models/topic.js` and cannot be passed to `createRecord`.
3. `Cannot read properties of undefined (reading 'length')` — a **global** error that
   aborted the run after 21 of 75 tests without naming one.

**Root cause of #3, read from core rather than guessed.** The render stack in the CI log
(`BlockLatest → TopicList → Item → PluginOutlet → posters column`) pointed at
`Topic#featuredUsers` (`models/topic.js:466`): `const posterCount = this.posters.length` —
**no null guard**, unlike its `creator` and `lastPoster` siblings a dozen lines up, which use
`this.posters?.`. The latest lane renders `<TopicList @showPosters={{true}} />`, which is the
only thing that mounts the posters column and evaluates that getter. Core's own
`topic-list-test.gjs` never passes `@showPosters`, so core never hits it and the fixture gap
is invisible upstream.

**Production was never exposed — verified, not assumed.** `GET /latest.json` on PRE
serializes `posters` as a non-empty array on all 30 topics; the topic-list serializer always
includes it. The hole was the hand-built model fixtures only.

**The fix.** `posters: []` on the shared `topic()` factory (`9f9d02d`). `featuredUsers` then
returns `[]`, the column renders empty, and the component tree is identical to the one core's
own passing tests render. CI green: **75/75 frontend**, all five checks CLEAN.

**The lesson.** The jump from POJO to "a real model" (#1) is only done when the model is
complete *for what the consumer renders*, not merely non-throwing for the last error seen —
otherwise it is the same wound in a new place, three commits running. What ended it was one
`gh api` call to read the throwing line in core; three commits of black-box iteration before
that did not. Same note as 2026-08-28: `frontend/discourse/app/` is the path, and core source
is always one call away.

`theme_version` 0.29.0. **PR #71 squash-merged itself as `a265f01`** the moment the required
checks went green — auto-merge had been armed on 2026-08-28T14:30 and CI was the only gate
left. The latest section is on `main` and bound for every PRE user on the next theme pull.
This traceability entry missed that merge by minutes and rode in on its own PR.

## 2026-08-29 — The homepage drops to the band and section 1

**The branch.** `refactor/remove-deferred-homepage-lanes`. Ricardo asked for the three
full-width lanes below section 1 to come off the homepage: **foro del certificado** (forum,
cat 5), **lo que hacen los certificados** (showcase, cat 78, tag `poster-evf`) and
**biblioteca** (library, cats 73/85/14). After #71 these were the "deferred" lanes still
rendering while sections 2 and 3 were undesigned; the redesign now says they are out.

**Scope chosen — "quitar carriles, conservar helpers".** Ricardo picked the middle option of
three: remove everything lane-specific, keep the shared plumbing.

- **Gone:** the three `renderBlocks` entries; `blocks/block-showcase.gjs` +
  `blocks/block-library.gjs` and their SCSS (+ the two `@import`s in `blocks/_index.scss`);
  settings `forum_category_id`, `forum_count`, `showcase_category_id`, `showcase_count`,
  `showcase_tag`, `library_category_ids` and their locale descriptions; strings
  `homepage.forum.title` / `.link_text`, `homepage.showcase.*`, `homepage.library.*`; the
  `showcase lane` integration module (3 tests) and the standalone `forum lane` module.
- **Kept:** `blocks/block-forum.gjs` + `block-forum.scss` — the panel's "Tengo una idea" lane
  is a `BlockForum` (compact variant, which layers on the same base rules). `lib/category-topics.js`
  untouched: `categoryStats`, `resolveCategories`, `parseCategoryIds`, and the
  `requireImage` / `tag` options of `loadCategoryTopics` stay, with their acceptance and unit
  tests, ready if a lane returns. `homepage.forum.empty` (BlockForum's `emptyText` arg
  default) and `homepage.forum.replies` (read straight from the template) stay — they are
  component contract, not lane copy, so they moved under an explaining comment.
- **about.json untouched** per the chosen option — only `theme_version` 0.29.0 → 0.30.0. But
  the `serialize_topic_excerpts` modifier is now provably dead (nothing in the theme reads a
  topic excerpt since #71 moved the latest lane to core's `TopicList`; the showcase lane it
  was long attributed to never read excerpts at all). `topic_thumbnail_sizes` likewise only
  fed the showcase grid's `image_url`. Both flagged in `block-latest.gjs` and *Pending* for a
  separate about.json pass.
- The one folded test: `forum lane`'s reply-count assertion moved into `ideas lane`, because
  the panel lane promotes reply counts too (3.6 replies/topic). Integration suite 13 → 10.

**Stale comments swept in the same commit** — they now named deleted things: `block-latest.gjs`
(the `serialize_topic_excerpts` rationale), `page-hero.gjs` (an example pointing at
`block-library`), `block-forum.gjs` (both arg comments said the component "is instantiated
twice"), `settings.yml`'s header (was "every homepage lane is keyed by category ID"; now one
lane is).

**Verification.** `npx pnpm@10.28.0 lint` green on all five (stylelint, eslint, ember-template-lint,
prettier, ember-tsc). YAML re-parsed with Homebrew Ruby. System/QUnit specs run in CI only.
No instance touched — `refactor/…` branch, PR, CI-green-before-merge as always.

`theme_version` 0.30.0.

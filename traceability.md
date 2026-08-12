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

**Reference corpus is stale relative to the pinned lint config.** `@discourse/lint-configs` 3.2.0 requires the `discourse/ui-kit/*` imports and `trustHTML`; every theme in `.reference/` still uses the old `discourse/components/*`, `discourse/helpers/*` and `htmlSafe`. Copy patterns from the corpus, but let the linter arbitrate imports.

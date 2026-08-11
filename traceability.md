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

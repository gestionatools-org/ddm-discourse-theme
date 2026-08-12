# Brand audit — Gestiona Avanza identity system vs. this theme

Audit date: 2026-08-12. Every claim below is traceable to a file and line in one
of the three repositories named under *Sources*.

**Status:** Phase 0 verified, Phase 1 landed in theme v0.3.0. Findings 1, 4 and
the palette half of 2 are resolved in code; Findings 3, 5, 6, 7 are open. The
findings are kept as written so the reasoning survives — see *Proposed order of
work* at the end for what remains.

## Sources

| Role | Path | Status |
|---|---|---|
| **System of record** | `~/Documents/proyectos-espublico/img-gestiona-avanza` | Closed and stable since 2026-08-04. 8 manual documents, one token file, `tokens/audit.py` with 65 checks. |
| What the theme was actually built from | `~/Documents/proyectos-espublico/presentaciones/assets/css/corporate.css` | Derived presentation CSS, multi-brand, not audited. |
| Subject | this repository | `theme_version` 0.2.0 |

`CLAUDE.local.md` names `presentaciones/` as the brand source of truth. That is
the root cause of everything in this document: the identity system was never
consulted, and `presentaciones/` is downstream, drifted material — its own
manual records that `corporate.css` carried a wrong Gestiona Avanza cyan
(`#00a2c4`) until commit `52bf098`
(`img-gestiona-avanza/docs/02-color.md:12`).

---

## Finding 1 — Wrong source of truth, and the values show it

`corporate.css` declares no Gestiona Avanza petrol at all. Its
`[data-brand="gestiona-avanza"]` block (`corporate.css:91-96`) carries only the
cyan ramp. Every petrol, neutral and state colour in this theme was therefore
taken from a neighbouring block of the same file — a different brand, or the
parent brand — rather than from the audited ramp.

| Theme value | Where it lives | Traced to | System value |
|---|---|---|---|
| `#006d85` petrol | `stylesheets/brand/colors.scss:21`, `about.json` `tertiary` | `corporate.css:12,80` — **parent Gestiona**, not the submarca | `--ga-petrol-700` = **`#006d87`** |
| `#1a3a44` body text | `about.json` `primary` | `corporate.css:29` `--color-text-body` | `--foreground` = **`#112127`** (`--ga-neutral-900`) |
| `#ecf0f3` hover | `about.json` `hover`, `--ga-surface-soft` | `corporate.css:24` `--color-bg-light` | `--muted` = **`#f1f5f7`** (`--ga-neutral-100`) |
| `#b3003f` danger | `about.json` `danger` | `corporate.css:121` — `--color-primary-dark` of **`[data-brand="rrhh"]`** | `--destructive` = **`#cb2526`** |
| `#008762` success | `about.json` `success` | eyeballed near the `hacienda-local` green | `--success` = **`#1f7c4b`** |
| `#a94` gold | `stylesheets/brand/colors.scss:29` | esFirma sub-brand | not in the system — Gestiona Avanza is a **single closed identity**, no per-product variants (`docs/01-marca.md:5`) |

The cyan ramp is the one thing that is right: `#00b4d3`, `#4cc4e0`, `#b1e9f8`,
`#00839e` all match steps 500/400/200/700 of the audited ramp exactly.

The reasoning recorded in `colors.scss:8-14` — "interactive text on light uses
the parent Gestiona petrol, brand-coherent since the isotype is petrol arcs" —
is sound but unnecessary. `#006d87` **is** the Gestiona Avanza petrol, sampled
pixel by pixel from `assets/logo/gestiona-avanza.png`, and it clears AA on white
at 5.94:1 (`docs/02-color.md:27`). There was never a need to borrow the parent
brand's.

**Consequence:** `tokens/audit.py` would fail on this theme's palette today.

---

## Finding 2 — Typography: mechanism verified, one real gap

**Checked against PRE on 2026-08-12 — the headline risk did not materialise.**
`base_font` and `heading_font` are both Roboto, and the compiled colour
stylesheet emits real `@font-face` rules for weights 400 and 700 against
`/fonts/Roboto-{Regular,Bold}.woff2?v=0.0.19`. The forum renders Roboto today.

The mechanism is documented anyway, for two reasons: the theme's own comment
gives a reason that is not the true one and would mislead the next reader, and
the setting is admin-side, so nothing in this repository keeps it that way.

`stylesheets/brand/fonts.scss:1-3` states that "Roboto ships with Discourse
core, so no external font request … is needed". The font *file* ships. The
`@font-face` rule does not — it is conditional on a site setting the theme
cannot set.

Discourse emits `@font-face` for exactly three fonts
(`discourse/lib/stylesheet/importer.rb:42-77`):

1. the font selected in the `base_font` **site setting**,
2. the font selected in the `heading_font` **site setting**,
3. JetBrains Mono, unconditionally.

Every other bundled family gets an `@font-face` only in the *wizard* stylesheet,
for the admin preview canvases. A theme cannot set `base_font` — it is a site
setting, admin-side.

Had `base_font` been set to anything else, `--font-family: "Roboto", system-ui,
…` would have resolved to whatever the browser had locally — and macOS has no
Roboto, so the whole forum would have been rendering in `system-ui`. It is not.
But the theme's typography rests on a setting outside the theme, and the comment
in `fonts.scss` should say so.

### What core actually provides

Confirmed against `discourse/discourse-fonts` (`lib/discourse_fonts.rb`,
`vendor/assets/fonts/`):

| System wants | Core ships | Family name in core | Weights |
|---|---|---|---|
| Roboto | yes | `Roboto` | 400, 700 |
| Roboto Slab | **yes** | **`RobotoSlab`** — no space | 400, 700 |
| Roboto Mono | **yes** | **`RobotoMono`** — no space | 400, 700 |

Two traps:

- **The family names have no space.** `font-family: "Roboto Slab"` fails
  silently and falls back. It must be `RobotoSlab`.
- **Core ships no weight 500.** Confirmed empirically on PRE, not only from the
  gem: the served stylesheet contains exactly four Roboto `@font-face` rules —
  400 and 700, declared twice because `base_font` and `heading_font` are the
  same family — plus JetBrains Mono 400/700. Nothing else. The system loads
  exactly 400/500/700 and
  forbids anything else (`docs/03-tipografia.md:31-39`). Weight 500 is required
  by the navigation pattern — the active sidebar item is marked by weight 500
  against 400, not by colour alone (`docs/06-patrones-gestion.md:78`). With core
  fonts only, 500 would be synthesised, which is precisely what the rule exists
  to prevent.

  Two ways out: vendor `Roboto-Medium.woff2` into `assets/` with `@font-face` —
  same origin, so no `csp_extensions` modifier and no external request — or drop
  to 400/700 and mark the active item with 700, which contradicts
  `docs/06-patrones-gestion.md:80`. Vendoring is the correct answer and also
  resolves the pending logo item.

- **Roboto Slab has a cheaper route than vendoring.** `heading_font` is a site
  setting like `base_font`, and `RobotoSlab` is in core's list — setting it makes
  core emit the `@font-face` automatically, no theme asset needed. The catch is
  scope: `heading_font` applies to every `h1`–`h6` on the site, whereas the
  system reserves Slab for page titles and brand moments only and says it "pierde
  su valor si se reparte" (`AGENTS.md:66`). Vendoring keeps the theme in control
  of where it lands. Decision, not a blocker.

### Weight 600 is in the theme today

Forbidden system-wide (`AGENTS.md:65`). Four occurrences:

- `stylesheets/blocks/block-forum.scss:28`
- `stylesheets/blocks/block-events.scss:45`
- `stylesheets/blocks/block-events.scss:50`
- `stylesheets/blocks/block-showcase.scss:56`

### The type scale is Discourse's, not the system's

The system fixes eight sizes and declares them the only ones available:
12 · 13 · 14 · 16 · 18 · 22 · 28 · 36 px. The theme uses Discourse's ratio
scale (`--font-0`, `--font-up-1`, `--font-down-1/2`), which lands on different
numbers — `--font-up-1` is ≈18.3 px where the system's block title is 22 px.

Discourse's steps are overridable CSS variables and map onto the system's scale
one-to-one, with `--font-up-5`/`-6` pinned to the top step so nothing can exceed
it — the same trick the Tailwind layer plays with `--text-*: initial`:

| Discourse var | System token | px |
|---|---|---|
| `--font-down-3` | `--ga-text-xs` | 12 |
| `--font-down-2` | `--ga-text-dense` | 13 |
| `--font-down-1` | `--ga-text-sm` | 14 |
| `--font-0` | `--ga-text-base` | 16 |
| `--font-up-1` | `--ga-text-lg` | 18 |
| `--font-up-2` | `--ga-text-xl` | 22 |
| `--font-up-3` | `--ga-text-2xl` | 28 |
| `--font-up-4` | `--ga-text-3xl` | 36 |
| `--font-up-5`, `--font-up-6` | — | pin to 36 |

**Verify before adopting wholesale:** core declares these steps in `em`, so they
compound in nested contexts. Redeclaring them in `rem` changes that behaviour
across every core surface. Confirm against core's `_variables.scss` first; the
conservative alternative is to declare `--ga-text-*` and use them only in
theme-authored SCSS.

---

## Finding 3 — None of the three signature gestures exist

These are what the manual calls the silent signature. Zero occurrences in
`stylesheets/` or `javascripts/`.

### The filo — cyan 3 px edge

`--ga-edge-width: 3px`, colour decided by the surface it sits on, never by the
element (`docs/04-forma-y-espacio.md:5-19`). It is not a new invention:
`corporate.css` already does it in the decks (`.slide-title` `border-left: 5px`,
`.tile` `border-top: 4px`), so a slide and a forum page would read as the same
house.

Where it belongs in this theme, and the Discourse variable that carries it:

| Surface | Edge | Token | Discourse hook |
|---|---|---|---|
| Lane header on the homepage | left | `--edge` `#009dbc` | replaces the `border-bottom` in `stylesheets/app/mixins.scss:14` |
| Active sidebar item | left | `--sidebar-active` `#00b4d3` | `--d-sidebar-active-*` |
| Active nav pill (latest/top/categories) | bottom | `--edge` | `--d-nav-border-color--active`, `--d-nav-underline-height` |
| Featured / focused card | top | `--edge` | theme SCSS |

Rule that constrains it: **never on every card by default** — an edge on
everything signals nothing (`docs/05-componentes.md:50`). And inside the sidebar
the edge uses `--sidebar-active`, not `--edge`: `--edge` is calibrated to reach
3.09:1 against the *light* background, so using it on the dark sidebar would put
two different cyans side by side — and only in one of the two themes
(`docs/04-forma-y-espacio.md:15-17`).

### The 20° angle

`--ga-angle: 20deg`, measured off the isotype (true half-angle 19.71°). The only
diagonal permitted anywhere in the system. Applies to chevrons, decorative cuts
and empty-state illustrations.

The theme has no diagonal at all today, so there is nothing to correct — this is
an addition, and the natural home is the homepage lane headers and the "see
more" affordances.

### The arc

The isotype's arcs at 4 % opacity, **only** on large empty surfaces: login,
cover pages, empty states (`docs/04-forma-y-espacio.md:29-31`). The custom
homepage is exactly that surface, and the theme's five empty states
(`&__empty` in every block) are the other.

Blocked on an asset: `assets/` contains only `.gitkeep`. The system's own
`assets/logo/` has both PNGs and permits using the whole isotype at 4 % while
only PNG exists — at that opacity the arrow tip is indistinguishable.

---

## Finding 4 — Rules the theme actively contradicts

| Rule | Where the system states it | Where the theme breaks it |
|---|---|---|
| Borders, never decorative shadow, on flat surfaces | `docs/04-forma-y-espacio.md:41-43,62-66`; repeated in `docs/05-componentes.md:43,49` | `stylesheets/app/elevation.scss:5` declares `--ga-shadow-card`, `stylesheets/app/mixins.scss:45` puts it on every library and showcase card |
| Shadow tint: petrol in light, **pure black** in dark | `docs/04-forma-y-espacio.md:55-60` | not implemented either way; the theme sets the dark value to `none` |
| Weight 600 forbidden | `docs/03-tipografia.md:31-39` | 4 occurrences, listed above |
| Three motion durations, one easing curve | `docs/04-forma-y-espacio.md:82-91` | `stylesheets/app/mixins.scss:46` hardcodes `0.15s ease` |
| `prefers-reduced-motion` mandatory, not optional | `docs/04-forma-y-espacio.md:93-104` | absent from the theme |
| Logo out of the main block, centred above it | `docs/01-marca.md:49-61` | no logo anywhere |

### A latent bug found while checking the shadow rule

`stylesheets/app/elevation.scss:8-9` removes the card shadow in dark mode via:

```scss
:root[data-theme="dark"],
:root[data-scheme="dark"] { … }
```

There is no evidence Discourse emits either attribute. Nothing in
`.claude/skills/`, nothing in the 19-theme `.reference/` corpus. Discourse's own
reference theme (`discourse-theme-skills/stylesheets/brand/colors.scss`) handles
light/dark exclusively with `light-dark()` — the mechanism this theme already
uses correctly in `colors.scss:33-40`. The selector is almost certainly dead,
which means the card shadow stays on in dark mode.

The fix is not to repair the selector: the system forbids the shadow on flat
cards in both themes, so `--ga-shadow-card` and the whole block disappear.
`--ga-shadow-overlay` / `--ga-shadow-popover` take its place, wired to
Discourse's `--shadow-modal` / `--shadow-dropdown` / `--shadow-menu-panel`.

---

## Finding 5 — Everything outside the homepage is stock Discourse

`CLAUDE.md` describes `stylesheets/app/` as "variables.scss + one file per core
surface (header, sidebar, topic-list…)". What exists is `variables`, `mixins`,
`elevation` — no core surface is styled at all.

A member's session is: login → sidebar → topic list → topic. The homepage is one
screen out of four, and the other three are untouched Discourse. This weighs more
than any individual token.

Given the instance is **login-required**, the login screen is the single most
seen surface on the site, and it is precisely the one the manual is most
specific about: full logotype, centred *above* the card, never inside its header
(`docs/01-marca.md:53-59`). That is a site-setting job (logo upload), not a theme
one — and it is already on the pending list in `CLAUDE.local.md`.

---

## Finding 6 — What PRE is actually serving is not this theme

Established anonymously on 2026-08-12: `/` returns 200 on a login-required site
because it is the login page, and its `<link rel="stylesheet">` set names the
active theme and colour scheme.

PRE is serving **`color_definitions_gestiona-light_11_2`** — colour scheme
`gestiona-light` (id 11) under theme id **2, Air Theme**. This theme (id 14) is
installed but not default, as recorded in `CLAUDE.local.md`.

`?preview_theme_id=14` does **not** change that anonymously — the same
stylesheets come back. The preview parameter needs a logged-in session, so the
theme cannot be inspected or judged without signing in.

That matters for reading any visual impression of the site. The live scheme is
substantially further from the brand than this theme is:

| Discourse key | Live on PRE | Traced to | System |
|---|---|---|---|
| `primary` | `#000000` | — pure black | `#112127` |
| `tertiary` | `#006d85` | parent Gestiona petrol | `#006d87` |
| `quaternary` | `#00dfb2` | `corporate.css:13` — parent Gestiona **mint** | `#00b4d3` cyan |
| `highlight` | `#5fffdf` | `corporate.css:15` — parent Gestiona aqua | `#b1e9f8` |
| `success` | `#00dfb2` | same mint | `#1f7c4b` |
| `love` | `#ee0055` | `[data-brand="rrhh"]` | no system token |
| `danger` | `#BB1122` | — | `#cb2526` |

A mint-and-aqua accent pair is not in the Gestiona Avanza palette at all: those
are the *parent* Gestiona's light accents. So whatever is being looked at today
carries neither the submarca's cyan nor its petrol.

## Finding 7 — The theme's colour schemes are probably not attached to it

This is the likeliest single explanation for the whole complaint, and it is not
a code defect — it is an install-order accident.

Core assigns a theme's colour scheme **only on first import**
(`discourse/app/models/remote_theme.rb:506-515`):

```ruby
if theme.new_record? && ordered_schemes.present?
  …
  theme.color_scheme = ordered_schemes.first
end
```

On every later `update_from_remote`, the schemes declared in `about.json` are
created and kept in sync as `ColorScheme` records, but `theme.color_scheme` is
never assigned again. The guard is `theme.new_record?`, nothing else.

Now the install order in this repository:

| Commit | `about.json` `color_schemes` |
|---|---|
| `7dcbb9d` Bootstrap from official skeleton | `{}` — **empty** |
| `85f7c07` Add Gestiona Avanza brand foundation | the two schemes added |

If theme 14 was installed on PRE from the bootstrap commit — which the ordering
of the work strongly suggests — then `ordered_schemes` was empty at the moment
`new_record?` was true. `theme.color_scheme` was never set, and no later push
can set it.

**Consequence:** theme 14 renders its layout and SCSS wearing the *site's*
default scheme, `gestiona-light` — black text, parent-brand mint and aqua
accents (Finding 6). Previewing `?preview_theme_id=14` with a session would show
the custom homepage in a palette that belongs to another brand. Neither
`Gestiona Avanza` nor `Gestiona Avanza Oscuro` would be in play, however correct
their hex values are.

**Verify in one place:** Admin → Personalizar → Temas → *Espublico Theme* →
*Esquema de color*. If it reads anything other than `Gestiona Avanza`, this is
confirmed and the fix is to select it — an admin action, not a commit.

**Corollary for Phase 1:** correcting the hex values in `about.json` changes
nothing visible until that dropdown is set. Do the admin action first, or the
palette work will appear to have had no effect.

**To harden it for future installs:** the `only_theme_color_schemes` modifier
makes core bind both a light and a dark scheme instead of just the first
(`remote_theme.rb:507-512`). It still only fires on `new_record?`, so it does not
repair this instance — it protects the next one, and PROD, which has not been
installed yet.

## Token map — system → Discourse

Everything below is a variable override. None of it requires DOM patching, a
plugin outlet or a Block. The sidebar in particular maps one-to-one, including
the weight-500 rule.

### Colour scheme (`about.json` → `color_schemes`)

| System token | Light | Dark | Discourse key | Current |
|---|---|---|---|---|
| `--foreground` | `#112127` | `#ecf1f3` | `primary` | `1a3a44` / `ecf0f3` |
| `--background` | `#f9fbfd` | `#071318` | `secondary` | `ffffff` / `003040` |
| `--primary` | `#006d87` | `#00b4d3` | `tertiary` | `006d85` / `4cc4e0` |
| brand cyan | `#00b4d3` | `#00b4d3` | `quaternary` | correct |
| `--ga-cyan-200` | `#b1e9f8` | `#00b4d3` | `highlight` | correct |
| `--destructive` | `#cb2526` | `#e7534a` | `danger` | `b3003f` / `ff6b8f` |
| `--success` | `#1f7c4b` | `#4ab074` | `success` | `008762` / `4ddbb0` |
| `--muted` | `#f1f5f7` | `#1d2e35` | `hover` | `ecf0f3` / `0a4453` |
| `--accent` | `#effbff` | `#153843` | `selected` | `e3f4f9` / `004d5e` |

The primary **inverts between themes** — petrol with white text in light, brand
cyan at full strength with petrol text in dark. "La marca no se diluye en
oscuro: se enciende" (`docs/02-color.md:50`). The theme already does this by
accident via `--ga-accent`; it should be the declared scheme.

Two gaps with no Discourse equivalent, both needing a decision:

- **`love`** — Discourse's like heart. No system token; the state colours are
  explicitly reserved and must not be repurposed (`docs/02-color.md:227`).
  Currently `e90053`, which is the `rrhh` brand's pink. Nearest defensible
  choice is `--destructive`; otherwise it stays a documented exception.
- **`header_background` / `header_primary`** — the system describes a
  sidebar-driven navigation and says nothing about a top header. Discourse has
  both. Decision needed: neutral header + dark sidebar, or carry the dark
  petrol across both.

### Derived scales and component variables

| System token | Light | Discourse variable |
|---|---|---|
| `--border` | `#e2e8eb` | `--primary-low` |
| `--muted-foreground` | `#58686e` | `--primary-medium` |
| `--card` | `#ffffff` | `--d-content-background` |
| `--ring` | `#009dbc` | `--d-input-focused-color` |
| `--edge` | `#009dbc` | `--d-nav-border-color--active` + `--ga-edge` |
| `--ga-edge-width` | `3px` | `--d-nav-underline-height` |
| `--radius` | `8px` | `--d-border-radius` — already correct |
| `--ga-shadow-overlay` | | `--shadow-modal`, `--shadow-dropdown`, `--shadow-menu-panel` |
| `--ga-shadow-popover` | | `--shadow-composer` |
| — | flat | `--shadow-card: none` |

### Sidebar — a clean one-to-one

| System token | Light | Dark | Discourse variable |
|---|---|---|---|
| `--sidebar` | `#032029` | `#030d11` | `--d-sidebar-background` |
| `--sidebar-foreground` | `#d6e0e4` | `#d6e0e4` | `--d-sidebar-link-color`, `--d-sidebar-link-icon-color` |
| `--sidebar-active` | `#00b4d3` | `#00b4d3` | `--d-sidebar-active-color`, `--d-sidebar-active-icon-color` |
| `--sidebar-border` | `#153843` | `#223036` | `--d-sidebar-border-color` |
| weight 500 on active | | | `--d-sidebar-active-font-weight: 500` |

`--d-sidebar-active-font-weight` exists in core, which means the manual's rule —
active item marked by weight *and* edge, never by the edge alone
(`docs/06-patrones-gestion.md:80`) — is a one-line override. It depends on
Finding 2: a real 500 has to be loaded first.

### Spacing — already correct

Discourse's `--space` base unit is 4px and `--space-1`…`--space-12` step in
4px increments, which is the system's grid exactly
(`docs/04-forma-y-espacio.md:70`). No work needed. The only off-grid step is
`--space-half` (2px), used in three places in the block SCSS.

---

## What of the system does not apply here

Stated so the next reader does not try to force it:

- **Chart palettes** (categorical, sequential, divergent) — no data
  visualisation in a forum theme.
- **Table densities and 36 px control heights** — Discourse owns its controls.
- **shadcn/ui component rules** (`docs/05-componentes.md`) — the entire
  "no custom component code, shadcn reads the tokens" premise has no analogue.
  Discourse's equivalent is: override CSS variables, do not fork core templates
  — same spirit, different mechanism.
- **The Tailwind layer, `next/font`, `@theme inline`** — this is the manual's
  *camino B* (plain CSS, no utility layer). Tokens only.
- **`tokens/audit.py` as a gate** — it parses the system's own CSS file. It can
  validate a copy of the token file, but it cannot read `about.json`. If the
  palette is going to be kept honest automatically, that check has to be
  written here.

Management patterns that *do* transfer: the two distinct empty states (nothing
yet vs. nothing matched), the error-state rule, and `tabular-nums` on every
numeric datum — the theme already does the last one in two of five blocks
(`block-forum.scss:50`, `block-library.scss:71`).

---

## Proposed order of work

Nothing below has been executed. Sizes are rough.

**Phase 0 — verify (no code). Done, 2026-08-12.**
`base_font` and `heading_font` are Roboto and the faces are served (400/700
only). No weight 500 and no `RobotoSlab` anywhere. PRE is running Air Theme with
the `gestiona-light` scheme; this theme is installed but not default, and cannot
be previewed without a session — see Finding 6.

Method, for repeating it later without credentials: `~/.discourse_theme` holds
only `url` and `theme_id` — **no API key is stored**, so the admin JSON endpoints
are unreachable. Instead, fetch `/` anonymously (200, it is the login page),
read the `<link rel="stylesheet">` hrefs, and pull
`color_definitions_<scheme>_<id>_<theme>.css`. It carries the `@font-face`
rules and the whole colour scheme.

**Phase 0b — attach the colour scheme (admin, no code).**
Select `Gestiona Avanza` on theme 14 (Finding 7). Until this is done, Phase 1 is
invisible.

**Phase 1 — correct the palette. Done, theme v0.3.0.**
`stylesheets/brand/colors.scss` rewritten against the audited ramps; the wrong
values in `about.json` corrected; `--ga-gold` and `--ga-shadow-card` deleted
along with the dead `[data-scheme]` selector; `stylesheets/app/motion.scss`
added with the three durations, the single curve and a global
`prefers-reduced-motion`; the four weight-600s removed.

Decisions taken here, per Ricardo on 2026-08-12: light header against the dark
sidebar; `love` mapped to `--destructive`; `only_theme_color_schemes` enabled.

Verified: `pnpm lint` green across all five jobs; every one of the 24
`color_schemes` hexes and all 38 hexes in `brand/colors.scss` exist in the
system token file, and all 33 identically-named tokens carry identical values
(`--ga-neutral-0` differs only as `#fff` vs `#ffffff`, which stylelint's
shorthand rule requires); 16 of 16 contrast pairs meet their WCAG minimum
across both schemes.

Not done in this phase, and still true: weight 500 has no font file on the site,
so `--scheduled` event dates render at 400.

**Phase 2 — the signature gestures.** All four authorised.
Vendor the logo PNGs and the medium-weight woff2 into `assets/`; wire
`RobotoSlab` for page titles and brand moments; the filo on lane headers, nav
pills and the sidebar's active item; the dark petrol sidebar via the
`--d-sidebar-*` block; the arc at 4 % on the homepage and the five empty states.

**Phase 3 — the core surfaces.**
The `stylesheets/app/` files that `CLAUDE.md` already promises: header, sidebar,
topic-list, topic. This is where the largest share of the "despersonalizado"
impression actually lives, and it is plain SCSS over native layouts — the
architecture already agreed in `CLAUDE.md`.

## Decisions still open

1. `header_background` — neutral header against the dark sidebar, or dark petrol
   across both. The manual does not cover a top header.
2. `love` — map to `--destructive`, or keep a documented exception.
3. Weight 500 — vendor the woff2 (correct), or accept 400/700 and break
   `docs/06-patrones-gestion.md:78`.
3b. Roboto Slab — vendor it into `assets/` and control where it lands, or set
   the `heading_font` site setting to `RobotoSlab` and accept that it dresses
   every heading on the site.
4. Type scale — remap Discourse's `--font-*` steps globally (verify the `em`
   compounding first), or declare `--ga-text-*` and confine them to
   theme-authored SCSS.
5. Whether the palette gets an automated check in CI, or stays reviewed by hand.

# PROD Migration — Step-by-Step Roadmap

> **For agentic workers:** this roadmap sequences the three tranches of the silent migration into
> short sessions. It does not repeat task code: **T1's executable steps live in
> `docs/superpowers/plans/2026-09-13-migracion-silenciosa-t1.md`**. T2 and T3 get their own plans
> when they start, from that week's measurements, as the spec requires. Use
> superpowers:executing-plans one session at a time. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Take PROD (`gestionaavanza.espublico.com`) to PRE's state — vocabulary, subject layer,
category map, programme rooms, instance chrome, and finally the theme — without members noticing a
project under way until the launch.

**Architecture:** Three tranches from the agreed spec: **T1 content** (tags, settings, rooms born
closed), **T2 categories** (moves verified by id, nothing deleted), **T3 launch** (theme installed
hidden, verified in preview, then made default). Each session ends at a stable, verified state that
can stay that way for days. Every write re-reads live state first; every session ends with its
verifier green and a line in the spec's *As executed* record.

**Tech Stack:** Discourse admin API, `bin/_discourse.py` with `DISCOURSE_INSTANCE=PROD`, Python 3.9
stdlib, `curl`.

**Spec:** `docs/superpowers/specs/2026-09-13-migracion-silenciosa-design.md` (binding). Recipes and
PROD mechanics from `2026-09-06-migracion-prod-design.md`; target map from
`2026-09-11-reorganizacion-generos-design.md` and `2026-09-11-cabecera-salas-design.md`.

## Global Constraints

- **Protected topics: `/t/2683`, `/t/2690`, `/t/2673`.** No write, move, retag, unpin, close or bulk
  operation that includes them, and no change to their category's existence or parent, **without
  naming them to Ricardo and getting his explicit yes.** Every write loop carries
  `PROTECTED = {2683, 2690, 2673}` and skips them, printing the skip.
- **Ids assigned after the restore (~2026-07-27) are not shared.** Category 89, group 98 and topic
  ids ≥ 2620 mean different things on each instance. Nothing written against PRE after that date is
  valid on PROD until re-read by **name**.
- **This is production, with no maintenance window.** When an outcome differs from the prediction,
  STOP and report; do not improvise.
- **Every topic write costs its list thumbnail, permanently.** Measure `image_url` before any batch.
- **Tags come back as objects.** Normalise with `d.tag_names()`, re-read names after every write.
- **Captures never enter the repo** (public by obligation). Files holding titles or member data are
  born gitignored: `*-capture.json`, `*-prior-state.json`, `*-move-proposals.json`,
  `*-title-proposals.json`.
- **Rate limit ~1 req/s; no background jobs;** credentials only via `source .env.local` in the same
  invocation; never print a key.
- **Nothing is announced** to members before T3.

---

## Status at 2026-09-15

| Item | State |
|---|---|
| T1 Task 1 — `bin/` resolves the instance | **Done**, merged as `6db5986` |
| Global PROD key | **Done**: `PROD_DISCOURSE_GLOBAL_API_KEY`, once in `.env.local`, 200 on admin reads |
| PROD Discourse version | **2026.9.0-latest** — above the `2026.7.0` floor; T3 is not blocked |
| PROD user fields 1–4 | **Measured, identical to PRE** (1 NIF and 3 CIF hidden) — T3's stop-the-line row is cleared, re-read by name on flip day |
| Granular PROD key | 200 on `/t/<id>.json` and category listings, 403 on `/c/<id>/show.json` — enough for `crawl_category` |
| T1 Tasks 2–12, T2, T3 | **Not started** |

### What changed since the spec (measured 2026-09-14/15)

Each row names the step that absorbs it.

| Fact | Consequence | Absorbed in |
|---|---|---|
| PROD has **36** categories, not 35: **89 "Anuncios"** (public, created on PROD, holds `/t/2690`) | **Kept** (D1). Its id collides with PRE's room 89 | S7, S10 |
| PRE carries **92** "Gestiona for developers" and **93** "Administración Avanzada" under 85, plus **83** now under 85 | Part of the target map; T2 must create 92/93 equivalents under 85 and reparent 83 | S8 |
| PRE **94** "Prueba anuncios" is a rehearsal | Never replicated | — |
| PROD group **98 = `Votacion`** (8), PRE 98 = `Developers` | `Developers` gets a new id on PROD; resolve by name | S6 |
| `Developers01`–`04` (16/14/17/15), `AdminDevelopers` (3), `Certificación` (378), `Analiza` (82), `AdminAnaliza` (5), `administradores` (1) all exist on PROD; `Developers` absent | T1 Task 11 Step 1 passes as written | S6 |
| `max_tags_per_topic` **3**, `max_tag_length` **20** | Exactly the values T1 Task 3 raises | S2 |
| `caag` **130**, `posters` **171**; `poster-evf`, `administracion-avanzada`, `idea-registrada`, `nueva-version-gestiona` absent | T1 Task 4 as written | S2 |
| `search_experience` already `search_icon`; `enable_welcome_banner` **true**; `default_navigation_menu_categories` `4\|5\|14\|18\|59` | T3's leak measurement matters for the banner only | S11 |
| `ai_embeddings_semantic_search_enabled` **true** on PROD (false on PRE) | Not in scope; do not change it | — |
| **`/t/2683`** is in **86**, with an open ranked-choice poll until **2026-09-25 13:00Z** | T2 dissolves 86; that move waits until the poll closes **and** Ricardo says yes | S8 |
| **`/t/2673`** is in 59 with a thumbnail and tags `evento`, `congreso`, `sesión-online` | T1 Task 7 merges only by synonym (no topic write — safe). Any per-topic retag must skip it | S3, S5 |

---

## The sessions

Each session is sized for one sitting. **Visible** says what a member could notice.

### T1 — Content (invisible)

- [x] **S1 · Pre-flight capture** — **done 2026-09-15**, record in the spec's *As executed*. — T1 plan **Task 2**, Steps 3–7. Steps 1–2 are already answered
  (table above); run them anyway as a 30-second check.
  Expected counts now: **~219 tags, 36 categories**, topics measured.
  *Gate:* Ricardo hears the numbers and the thumbnail total (he is PROD's tagger, D4 — no one else to warn). *Visible:* nothing. *Rollback:* none needed (read-only).

- [x] **S2 · Ceilings and the two renames** — **done 2026-09-15**. — T1 **Tasks 3 and 4**.
  *Visible:* nothing (`#caag`, `#posters` keep filtering through synonyms).
  *Rollback:* rename back + delete synonym; no topic is written.

- [x] **S3 · Structural bulk tagging** — **done 2026-09-15**: 793 writes, 0 bumped; thumbnails 1 lost / 157 kept (provisional, re-check in S4). — T1 **Task 5**. The first session that writes to topics.
  Categories 59, 86 and 89 are not in its table; the `PROTECTED` guard still applies.
  *Gate:* the revalidated table with its **thumbnail bill**, approved before writing.
  *Visible:* tags on existing topics. *Rollback:* capture file, one write per topic (costs a second
  thumbnail).

- [x] **S4 · Tag group + spelling merges + unaccented synonyms** — **done 2026-09-15 except the tag group** (pending `/t/2582`, `/t/2583`). — T1 **Tasks 6 and 7**.
  **First**: re-check the 157 thumbnails S3 kept. **Add to the families**: `app-movil` ↔ `app-móvil`
  and `cafe-con-certificados` ↔ `cafe-con-certificado`, both created by S3's own mistake.
  *Gate:* canonical form per family. *Visible:* autocomplete offers fewer variants.
  *Rollback:* **none for merges** (`destroy_synonym` does not return topics) — the gate is the
  protection.

- [ ] **S5 · Module groups and verifier** — T1 **Task 8**.
  *Gate:* the mapping (budget several rounds). *Visible:* nothing.

- [ ] **S5b · Coverage pass** — T1 **Task 9**, in as many sittings as the batches need.
  *Gate:* every batch; thumbnail bill before writing. Body pass is **not** run.
  *Visible:* tags on existing topics.

- [ ] **S6 · Settings + additive tail** — T1 **Tasks 10 and 11**.
  Rooms born closed to `administradores`; their PROD ids are recorded in
  `2026-09-13-prod-rooms.json` and **replace 89/90/91 everywhere PROD is concerned**.
  *Visible:* short searches work; posting no longer demands two tags; new topics stop auto-closing.

- [ ] **S6b · Close T1** — T1 **Task 12**: all verifiers green on both instances, *As executed*,
  `CLAUDE.local.md`, PR with CI green before merge.

### T2 — Categories (the one real leak)

Written as its own plan when it starts, from that week's listings. The steps are fixed; the lists
are not.

- [ ] **S7 · Write the T2 plan.** Inputs: post-T1 capture, PRE's current tree (20 categories incl.
  92/93, excluding 94), the rules in `2026-09-11-reorganizacion-generos-design.md`, and decisions
  D1–D4 below (89 "Anuncios" kept). Output: `docs/superpowers/plans/<date>-migracion-silenciosa-t2.md`, with every
  move list derived from PROD rules and **the three protected topics listed by id as excluded or
  pending**. Gitignored proposals under `*-move-proposals.json`.
  *Gate:* Ricardo approves the map and every move list.

- [ ] **S8 · Execute T2**, in this order, one sitting per numbered block:
  1. Category 5 receives the programme groups (read-only rows) before anything hangs under it.
  2. Rooms opened to their groups and reparented under 5 (no topic moves, no id changes).
  3. Consultations moved into the rooms, in batches, verified by id; thumbnails measured per batch.
  4. August's consolidation, per the mapping in `2026-08-25-category-reorganisation-design.md`
     (lines 149–173) plus its recorded departures: 57/58/54 → 18; 34 → 85; 62/67 → 14;
     65/66 → 4; **87 → 59**; 50/49/56/68/69 → 5, whose consultations then follow the genre rules
     into the rooms (block 3); 71 dissolved into 5 (departure, not archived); 18 and 78 promoted.
     Re-derived against PROD's listings, never replayed from PRE's.
     **86 → 85 only after 2026-09-25 13:00Z (D2), naming `/t/2683` to Ricardo when it runs.**
  5. 78's ~165 arrival announcements → 5; then 78 renamed "Primeros pasos" **with slug**
     `primeros-pasos`.
  6. Create 92/93 equivalents under 85 and reparent 83 under 85, matching PRE.
  7. Surplus categories emptied and closed (staff-only, out of the default sidebar) — **never
     deleted**.
     **Category 67's slug `seminarios` shadows the `#seminarios` synonym** — closing it keeps the
     shadow; change its slug when it is emptied.
  8. `default_navigation_menu_categories` with `update_existing_user=true`, **and the
     `default_categories_{tracking,watching,watching_first_post,normal}` family**, which today names
     categories this pass closes (measured in S1).
  *Verifier:* `bin/categories-verify` parameterised with PROD's ids (a T2 task), green.
  *Visible:* topics listed elsewhere, rooms appear for members of each programme. Links do not break.
  *Rollback:* move back (second thumbnail each).

### T3 — Launch

- [ ] **S9 · Measure the `theme_site_settings` leak on PRE** with a throwaway theme (spec §T3).
  Decides whether `enable_welcome_banner: false` must leave `about.json` until the flip.

- [ ] **S10 · Install the theme on PROD hidden** (not default), then set the instance overrides it
  needs, all resolved by name:
  `header_room_category_ids` = PROD's three room ids (**never the default `89|90|91` — PROD 89 is
  "Anuncios"**); `idea-registrada` created, restricted to staff via tag group; `nueva-version-gestiona`
  created (merge `nuevas-versiones`(14) into it); `academy_url`; user fields 2/4 re-read by name.
  Verify the ten settings in `?preview_theme_id=` against real data.

- [ ] **S11 · Chrome that does not travel**: sidebar section "Recursos de apoyo" (icons from the
  default subset, matched literally), the three login site texts, `search_experience` row.
  Check PROD's existing custom sidebar sections against the capture — the theme reorders them.

- [ ] **S12 · One non-admin session on PROD (preview)**: walls, header links by membership,
  "Nueva publicación" lands in 5, plaza lists only announcements, `idea-registrada` visible but not
  applicable. *Gate:* Ricardo signs off.

- [ ] **S13 · Flip**: theme default; Air Theme and `Gestiona avanza` kept installed (not default)
  as the rollback for one week. From here **every merge to `main` reaches PROD**: watch CI green
  before merging, always.

- [ ] **S14 · Close**: revoke `PROD_DISCOURSE_GLOBAL_API_KEY` and delete its line; record *As
  executed*; decide real deletion of the emptied categories.

---

## Decisions (settled by Ricardo 2026-09-15)

| # | Question | Decision | Effect |
|---|---|---|---|
| D1 | PROD **89 "Anuncios"** | **Kept** as a category of the target map | S7 carries it untouched; PRE's 94 stays a rehearsal |
| D2 | `/t/2683` and category 86 | **Moves with 86 once the poll closes** (after 2026-09-25 13:00Z) | S8.4's 86 → 85 is scheduled after that instant; still named to Ricardo when it runs |
| D3 | Slot for T2's visible pass | **No fixed date yet** | S8 waits for a date; T1 proceeds |
| D4 | Who tags PROD | **Ricardo himself** | No one to warn. His tagging runs concurrently with S2–S5b, so every batch re-reads live state immediately before writing, as the constraints already require |

## Self-review against the spec

- T1 items 1–10 → S1–S6 via T1 plan Tasks 2–11. ✔
- T2 items 1–9 → S7–S8 blocks 1–8 (item 1 and 2 in S7, 3–9 in S8). ✔
- T3: leak on PRE (S9), hidden install + ten settings (S10), chrome (S11), non-admin session (S12),
  CI rule after launch (S13), key revoked (S14). ✔
- New since the spec: protected topics (Global Constraints, S3, S8.4), 89/98 collisions (S6, S10,
  D1), 92/93/83 under 85 (S8.6). ✔

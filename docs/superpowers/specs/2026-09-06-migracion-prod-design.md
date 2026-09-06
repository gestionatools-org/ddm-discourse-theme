# Migrating PRE's work to PROD — design

**Date:** 2026-09-06
**Status:** agreed in brainstorming, not executed. Nothing here has been applied to PROD.
**Scope:** `gestionaavanza.espublico.com` (PROD). Instance configuration, tags and categories,
then the theme. Executed during a **staff-writes-only maintenance window** next week.
**Depends on:** `2026-08-25-category-reorganisation-design.md` (its Phase 3 table and instance
settings) and `2026-09-04-capa-materia-etiquetas-design.md` (the module axis and its method).

## Why this is not a replay

PRE was built from a PROD backup roughly a month ago, so the intuition is that PROD is "PRE
minus a month". **Measured, that is false**, and the difference is not the month:

| | PRE (2026-09-04, before any of our work) | PROD (today) |
|---|---|---|
| Categories | 17 | **35** |
| Topics crawled | 1 261 | 1 297 |
| Distinct tags | 221 | **218** |
| `administracion-avanzada` | 700 | **absent** |
| `ideas` | 320 | 73 |
| `caag` | absent | **129** |
| `posters` / `poster-evf` | — / 60 | **170** / — |

**PRE's snapshot already contained the August category reorganisation**, which never touched
PROD: six phases on 2026-08-27 that moved 284 topics, deleted 17 categories, renamed the
campaign tags and bulk-tagged whole categories. `administracion-avanzada`(700) and `ideas`(320)
are its output, not the backup's content.

Two specific consequences that shape everything below:

- **`caag`(129) on PROD is `administracion-avanzada` under its old name.** The August spec
  records `caag` as a *synonym* of it. PROD's structural tag exists; it is simply unmerged and
  un-amplified.
- **`posters`(170) on PROD is `poster-evf`(60) before its rename**, likewise.

The genuinely new content is small: **20 topics** carry an id above PRE's maximum (2624), and
39 exist in PROD but not in PRE's crawl. Three of the 20 carry no tags. They need no special
handling — they are simply part of the corpus every phase measures.

### PROD is not idle — someone has been tagging it

This is the finding that most changes how this plan must be executed. Comparing the August
spec's PROD measurements against today:

| Tag | 2026-08-25 | today | delta | of which on new topics |
|---|---:|---:|---:|---:|
| `caag` | 40 | **129** | +89 | **3** |
| `alumno-certificado` | 163 | 187 | +24 | 8 |
| `analiza` | 62 | 74 | +12 | 2 |
| `developers` | 24 | **17** | **−7** | 1 |

**126 of `caag`'s 129 topics predate PRE's snapshot**, so roughly 86 *existing* topics were
tagged during the month, and `developers` lost tags. That is not community activity — it is
deliberate vocabulary work by someone with admin access.

Three consequences:

- **Every count in every older document is not merely stale but describes a different tagging
  state.** Re-measure immediately before executing each phase, never at planning time.
- The August table's Webinars row assumes `seminarios`, `webinar` and `seminario` were already
  merged into `webinars`. **On PROD they are not**: `seminarios`(53), `webinar`(11) and
  `webinars`(1) are three separate tags today. That row is wrong for PROD.
- **Renaming `caag` to `administracion-avanzada` renames someone's active work.** The synonym
  preserves it and `#caag` keeps filtering, but whoever is doing it should be told before the
  window, not after.

## The maintenance window

**Use `readonly_mode:staff_writes_only`, not full read-only.** Discourse's own comment on the
key is *"Pseudo readonly mode, where staff can still write"*. Under full `readonly_mode` every
non-GET is blocked including ours, so the API work in every phase below would fail and the
window would be spent discovering that.

Phases 0 through 2 run inside the window. **Phase 3 runs after reopening**, by Ricardo's
decision: the theme is the only reversible thing here — it uninstalls — so seeing it against a
live forum is worth more than the small risk.

## Phase 0 — prerequisites, before the window opens

**A Global-scope API key on PROD. This is the blocker.** The current key is granular and
read-only: `/tags.json` answers 403, and `/tag_groups.json` and `/admin/site_settings.json`
answer 404. Every operation below is an admin write. Create the key when the window opens and
**revoke it when the window closes** — PRE's equivalent was revoked for exactly this reason.

**A verified PROD backup with a tested restore.** It is the only real rollback for Phase 2.

**A full capture of the prior state** — vocabulary with counts, category tree, every topic's
tags, and the instance settings. On PRE this capture is what made 57 tag deletions reversible
after the fact; the same file shape is committed at
`docs/superpowers/specs/2026-09-04-tags-deleted-recovery.json`.

**Read `max_tags_per_topic` and `max_tag_length` before anything else.** This is a hard
blocker, not a nicety. On PRE they were **3** and **20**, and they broke the August bulk
tagging partway: topics already carried 2–3 tags, so appending one exceeded the cap on roughly
a hundred topics, and `administracion-avanzada` (23 chars) was truncated to
`administracion-avanz` on entry. PROD is the instance PRE was cloned from, so assume both are
still at the old values until measured. Raise them to **7** and **30** as the first write of
Phase 1a.

## Phase 1a — the structural layer

Additive, and it runs against the **current 35-category tree**. It does not depend on the
reorganisation, because it tags topics by the category they are already in.

**Order matters and this is why it comes first.** The subject layer is built on top of the
structural one: the family derivation in Phase 1b computes co-occurrence with structural tags
excluded, so those tags must exist before it runs. On PRE this happened in the right order by
accident of history — August then September — and replaying it the other way would measure a
corpus that is about to change underneath.

1. Raise `max_tags_per_topic` to 7 and `max_tag_length` to 30.
2. **Rename — not merge — `caag`(129) to `administracion-avanzada` and `posters`(170) to
   `poster-evf`**, then recreate each old name as a synonym so `#caag` and `#posters` keep
   filtering. *Neither target exists on PROD*, so a merge is impossible: `add_or_create_synonyms`
   needs an existing target, and `DiscourseTagging` will not invent one. On PRE these were
   renames too, of tags that already carried the mass.
   **This is why step 1 comes first**: `administracion-avanzada` is 23 characters and
   `max_tag_length` at 20 truncated it to `administracion-avanz` on PRE. Raise the limit before
   the rename or the same truncation happens here.
   Both operations are `topic_tags` rewrites at the database level, so no topic is written and
   no list thumbnail is lost.
3. Bulk-tag by source category. **The August spec already carries a PROD-derived table** — kept
   there explicitly "because PROD's turn comes later" — and it is genuinely useful, but its
   counts are a month old *and* the instance has been tagged since. Revalidate **every** row
   against the listing on the day, and record the deltas. Its Webinars row is known wrong for
   PROD: it assumes a merge that happened only on PRE.
4. **Tell whoever has been tagging PROD what is about to happen**, before touching `caag`.
5. Recreate the `programa-certificacion` tag group: `administracion-avanzada`, `analiza`,
   `developers`, `one_per_topic: true`.

**Do not delete anything in this phase.** It is additive by design so that Phase 1b measures a
settled corpus.

## Phase 1b — vocabulary and the subject layer

The PRE spec is reused as a **method, not as a list of tags**. Its group structure, naming
convention and thresholds carry; its specific tag assignments describe a different corpus and
must be recomputed.

**Measured starting state on PROD:** 218 tags, 2 484 uses, **108 used twice or less** (50% of
the vocabulary, the same proportion PRE started from), 209 topics with no tags at all.

1. **Merge the spelling collisions.** A normalised sweep of PROD's 218 finds **11 families**:

   ```
   posters(170) | póster(2)                    tesauro(68) | tesauros(15)
   seminarios(53) | seminario(2)               evento(30) | eventos(1)
   búsquedasavanzadas(8) | busquedasavanzadas(7) | búsquedas-avanzadas(1)
   tramitesexternos(8) | trámites-externos(5)  webinar(11) | webinars(1)
   integraciones(8) | ìntegración(1)           curso(5) | cursos(1)
   paginasinformativas(3) | páginas-informativas(3)
   temas-y-categorias(2) | temasycategorías(1)
   ```

   Three of these PRE never had (`posters`/`póster`, `seminarios`/`seminario`,
   `webinar`/`webinars`), and PROD's mass sits differently — `webinar`(11) against PRE's
   `webinars`(56). **Choose the canonical form by PROD's own counts, not PRE's.** Convention
   stays: no accent, hyphenated. Every rename must recreate the old name as a synonym.
2. **Derive families from PROD's co-occurrence**, excluding structural tags, exactly as the
   subject-layer spec describes. Do not import PRE's nine families.
3. **Create the eight module groups** — the same eight, mirroring Gestiona's main menu, since
   the product menu is the same. Their membership is recomputed. **Check every group slug for
   shadowing before creating it**: on PRE the group `Configuración` was shadowed by its own
   member tag and returned a subset in silence for two review rounds.
4. **Raise coverage** with the title rule, validated batch by batch, then an assisted body pass.
   **Do not run a body pass unattended**: on PRE it produced 10 false positives in 43 proposals
   and only human review caught them.
5. Set `min_search_term_length` to **3** and `max_tag_search_results` to **5**.

**Expected starting coverage is lower than PRE's.** Of PRE's 57 subject tags, 48 exist on PROD
and cover 38.9% of its topics, against the 47.3% PRE started from. The nine absent ones are
those PRE created (`circuitos-resolucion`, `circuitos-tramitacion`, `integracion-pid`,
`serie-documental`, `busquedas-avanzadas`, `tramites-externos`, `paginas-informativas`, plus
`app-movil` and `dietas`). Some will be created here by the same merges that created them there.

## Phase 2 — categories

The visible, irreversible half, deliberately last inside the window. Follows
`2026-08-25-category-reorganisation-design.md`, **without its Phase 3**: the bulk tagging that
phase performed has already happened in Phase 1a above.

Two things that outlived the PRE execution and apply here unchanged:

- **Verify moves by topic id, not by count.** Capture the source listing first and locate each
  topic in the destination afterwards. It is what caught two tagging faults on PRE.
- **Definition topics ride along in a bulk move**, and once the source category is deleted the
  theme stops filtering the orphan, so it surfaces in the latest lane. Untick that row; read
  its id from the API rather than hunting the title.

PRE's execution departed from its own plan in six recorded ways. Expect the same here and
record each departure rather than smoothing it.

## Phase 3 — the theme, after reopening

The theme is a remote theme; PROD pulls it from
`git@github.com:gestionatools-org/ddm-discourse-theme.git`. Measured against PROD today, its
dependencies are nearly satisfied already:

| Setting | Value | State on PROD |
|---|---|---|
| `events_category_id` | 59 | exists, 41 topics |
| `ideas_category_id` | 18 | exists, 319 topics |
| `highlights_podcast_tag` | `podcast` | 6 uses |
| `highlights_newsletter_tag` | `newsletter` | 22 uses |
| `highlights_news_tag` | `nueva-version-gestiona` | **absent — card shows "coming soon"** |

**The theme does not depend on the content work.** Two of the three highlight cards work the
moment it installs. The third needs the tag created — there is no tag-creation endpoint, so use
a throwaway tag group with `name` + `tag_names[]` and **no `permissions` parameter**, which
returns 500 — and the release announcements tagged.

Note the category ids Phase 2 may move. **Re-read `events_category_id` and `ideas_category_id`
after Phase 2**: category ids survive rename and reparenting, but not delete-and-recreate.

`academy_url` is an instance override on PRE (`https://espublico.gestiona.academy`); PROD's is
unread because the current key cannot reach settings.

## Success criteria

1. `max_tags_per_topic` ≥ 7 and `max_tag_length` ≥ 30 **before** any bulk tagging runs.
2. `caag` and `posters` resolve as synonyms — `#caag` and `#posters` still filter.
3. Eight module groups exist on PROD, none shadowed, each `#<slug>` returning its union.
4. No tag below 3 uses, excluding a `pendiente-etiquetar` queue if one is opened.
5. Subject coverage measured by a fresh crawl, not derived, and recorded with its percentage.
6. Every category move verified by topic id.
7. The theme installs and all three highlight cards render with content.
8. The Global PROD key is revoked when the window closes.

## Rollback

**Phase 1a and 1b are reversible in practice, not in principle.** Merges cannot be undone —
`destroy_synonym` unlinks the tag but does not return its topics — so the capture from Phase 0
is what makes them recoverable, at one write per topic. Deletions likewise.

**Phase 2 is the one that needs the backup.** Category deletion is not recoverable from a tag
capture, and a bad move is only reversible while the source category still exists.

**Phase 3 uninstalls.** That is why it is last and outside the window.

## Out of scope

- **The funcionalidad axis.** It was never built on PRE either — Approach C, chosen
  deliberately — so `#tramitacion-administrativa` will return a large undifferentiated set on
  PROD too. Coverage improves; the shape does not.
- **Restoring PROD from PRE.** Considered and rejected: it is the only option that guarantees
  exact parity, and the only one that can lose a month of activity.
- **PRE.** It stays as it is and remains the development target.

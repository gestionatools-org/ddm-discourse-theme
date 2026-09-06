# Subject layer for the tag vocabulary — design

**Date:** 2026-09-04
**Status:** agreed in brainstorming, not executed. Nothing in this document has been applied.
**Scope:** the Gestiona Avanza tag vocabulary on PRE. Instance configuration and topic tags
only — **no theme change**. PROD has had none of it.
**Depends on:** the depuration executed earlier the same day (221 → 106 tags, nothing below
3 uses). Every figure here was measured against PRE after that work.

## Why

The vocabulary was cleaned but not reshaped. Measured over 1 261 topics in 17 categories:

| | Tags | Uses | Share |
|---|---:|---:|---:|
| Structural — *who wrote it, what kind of post* | 49 | 2 342 | 73% |
| Subject — *what it is about* | 57 | 874 | 27% |

The five most-used tags are all structural: `administracion-avanzada`(700), `ideas`(320),
`alumno-certificado`(230), `mejoras`(189), `ideas-2025`(102). The first subject tag,
`tramitación-reglada`(87), is sixth. **The vocabulary classifies the author, not the
content**, which is why it does not find classified information.

*(An earlier count in this session put the subject layer at 63 tags / 914 uses. The narrower
figure above is the authoritative one: it excludes the three tags this design deletes and
`hackathon-eivissa`(12), `retodelmes`(11) and `curso`(6), which name activities rather than
subjects and belong to the structural layer.)*

Coverage is the second half of the problem. **53% of topics — 664 of 1 261 — carry no subject
tag at all.** Grouping organises what exists; it does not create coverage. Both have to be
addressed or the goal is not met.

**Purpose agreed: retrieval.** A member searching for how a resolution circuit is configured
should reach the right topics. Not tagging-time enforcement, not theme navigation.

## The module axis

Eight tag groups mirroring Gestiona's main menu — the seven sections plus Configuración,
added because it is a significant area of the product. The 57 surviving subject tags are
distributed across them. **No new tags are created.**

| Group | Tags | Uses | Members |
|---|---:|---:|---|
| **Tramitación administrativa** | 16 | 414 | `tramitación-reglada`(87) · `tesauro`(81) · `expedientes`(50) · `circuitos-resolucion`(48) · `markdown`(35) · `tramitación`(26) · `gestiona-code`(21) · `procedimientos`(15) · `circuitos-tramitacion`(12) · `órganos-colegiados`(10) · `integracion-pid`(9) · `plantillas`(5) · `expedientes-apertura`(4) · `subprocesos`(4) · `gestiona-envia`(4) · `relacionados`(3) |
| **Configuración Gestiona** | 6 | 175 | `tesauro`(81) · `configuración`(37) · `markdown`(35) · `usuario-perfil`(11) · `integraciones`(8) · `serie-documental`(3) |
| **Atención a la ciudadanía** | 11 | 118 | `sede-electrónica`(58) · `terceros`(24) · `paginas-informativas`(6) · `representante`(5) · `cita-previa`(5) · `carpeta-ciudadana`(4) · `transparencia`(4) · `canal-denuncias`(3) · `tablón-anuncios`(3) · `interesados`(3) · `temas-y-categorias`(3) |
| **Registro electrónico** | 3 | 80 | `registro`(63) · `tramites-externos`(14) · `ventanilla-única`(3) |
| **Inicio** | 9 | 72 | `tareas`(22) · `firma`(17) · `tareas-regladas`(6) · `asignaciones`(6) · `app-movil`(6) · `fechas`(5) · `tareas-personal`(4) · `asignado-a`(3) · `plazos`(3) |
| **Gestión económica** | 7 | 68 | `tasas`(34) · `contratación`(9) · `subvenciones`(8) · `ayudas`(5) · `ayudas-personal`(5) · `dietas`(4) · `menor`(3) |
| **Analítica de datos** | 3 | 37 | `analítica`(17) · `busquedas-avanzadas`(16) · `auditoria`(4) |
| **Aplicaciones y servicios** | 4 | 26 | `padrón`(17) · `urbanismo`(3) · `facturas`(3) · `sello-de-organo`(3) |

**57 distinct tags · 874 distinct uses.** `tesauro`(81) and `markdown`(35) each belong to two
groups, so the per-group column sums to 990, not 874 — **the axis is not a partition**, and
`#tramitacion-administrativa` and `#configuracion` share 116 uses. That is deliberate: the
tesauro is defined once in Configuración and used throughout Tramitación, and Gestiona's
Markdown is both.

Three properties worth stating because they are not obvious:

- **Submenus are not tags.** Approach A was chosen precisely to avoid creating tags that start
  at zero, immediately after a day spent deleting 115 for having fewer than three uses. Six of
  Gestiona's 24 submenus (Videoconferencias, Registro de salida, Impresión y ensobrado, Libros
  oficiales, Contabilidad, Avisos y alertas) carry no forum activity at all. Adding a tag to an
  existing group later breaks nothing already tagged, so waiting costs no rework.
- **The group is a filter in its own right.** `#configuracion`, `#registro-electronico` etc.
  return the union of their tags — verified against `#programa-certificacion`, which resolves
  through `TagGroup.find_id_by_slug` in `lib/search.rb`.
- **The group name is not applicable to a topic.** A tag group is a container; there is no way
  to tag a topic "Configuración" unless a tag of that name exists, which here it does.

### Also in this stage

| Action | Tags |
|---|---|
| Delete | `interoperabilidad`(4) · `desarrollo-software`(3) · `debate-técnico`(4) |
| Rename | `pid` → `integracion-pid` · `seriesdocumentales` → `serie-documental` |

Both renames **must be followed by recreating the old name as a synonym**. Renaming a tag does
not preserve its old name, and the `#` filter then silently degrades to full-text search. This
was paid for during the depuration: `#circuitosresolucion` — 34 uses, an established name —
stopped filtering for several minutes after its target was renamed.

`debate-técnico` is deleted because it marks the *kind of thread*, not the subject: its four
topics are Tramitación and Configuración material.

## Coverage stage 1 — the title rule

**Scope:** the 664 topics carrying no subject tag. The 597 that already carry one are not
touched.

**Rule:** every token of the tag name must appear as a **whole word in the topic title**,
accent-insensitive, with a crude Spanish plural stem. Tag synonyms count, so the 16 unaccented
synonyms created during the depuration contribute for free.

**Titles only, never bodies, at this stage.** This is the decision that sets precision. A first
post mentions half a dozen concepts in passing; a title names the actual subject.

**Measured yield:**

| | Topics |
|---|---:|
| Without a subject tag | 664 |
| Receive at least one proposal | 233 (35%) |
| Coverage, before → after | 597 → 830 of 1 261 (**47% → 66%**) |

Sample of what it produces, unedited:

```
Notificación en circuitos de resolución plural        → circuitos-resolucion
Problema al condicionar documentación a un tesauro…   → tesauro
Expedientes: evolución de la búsqueda avanzada        → expedientes, busquedas-avanzadas
Páginas informativas y páginas de información en sede → sede-electrónica, paginas-informativas
Tareas de sistema sin intervención humana con fecha…  → tareas, fechas
```

**The risk is concentrated in common words.** The six highest-volume proposers are
`tesauro`(52), `configuración`(52), `tramitación`(44), `expedientes`(39), `registro`(30) and
`fechas`(23). *"Reasignación de registros de forma rápida"* proposes `registro`, where
"registros" means database rows, not Registro Electrónico. These need line-by-line review;
specific tags like `circuitos-resolucion` and `paginas-informativas` can be approved at a
glance.

## Coverage stage 2 — the residual

431 topics have no subject tag and no title match. A body pass was prototyped over a
302-topic sample of them and **it fails**, which is why this stage is not simply "search the
content".

Measured at a threshold of two mentions in the first post, the body pass proposes a tag for 138
of those 302 — and the proposals are wrong:

```
Nueva alumna Certificada CAAG 29 - Anna de la Torre Tur   → tramitación (×5)
Nuevo Alumno Certificado: GFD 01 - Mariano Quesada        → registro (×5)
Política de privacidad                                    → terceros (×7)
Novedades v 9.1.3.221.11                                  → markdown (×2)
```

`procedimientos` alone proposes itself for 67 of that sample. The cause is visible in the
titles: **most of the residual has no subject because it is not about a subject.** These are
genre posts that mention administrative vocabulary while describing something else.

Classifying all 431 by title:

| Genre | Topics |
|---|---:|
| Certification announcements (*"Nuevo compañero certificado…"*) | 128 |
| Events, encounters, seminars | 76 |
| Release notes | 26 |
| Legal and forum documents | 16 |
| Newsletters | 14 |
| Idea campaigns, podcast | 5 |
| **No genre identified** | **166** |

So the residual splits in two and each half is handled differently:

- **The 265 genre topics get nothing.** They are correctly without a subject tag. Marking them
  `pendiente-etiquetar` would manufacture a queue of 265 items that never need action.
- **The 166 remaining are the real candidates.** The body pass runs over these only, with human
  validation, since precision matters more than recall at this size.
- **Whatever survives unclassified gets `pendiente-etiquetar`.** That is a working queue, not a
  classification: it is expected to be emptied, and its size is the metric for the next pass.

`pendiente-etiquetar` is structural, not subject: it belongs in no module group.

## Validation workflow

**Batches are organised by tag, never by topic.** Reviewing *"these 49 topics all receive
`tesauro`"* is far faster than 203 separate decisions, because a false positive stands out by
contrast against its neighbours. Expect roughly 30-40 batches for stage 1.

Each batch is presented as tag → list of (topic id, title), and returns an approve-all, an
approve-with-exclusions, or a reject. Nothing is written until a batch is approved.

**Application costs one topic write per topic.** The thumbnail loss documented in August
(`PUT /t/-/<id>.json` clears a topic's `image_url`) still happens, but has had no visible
consequence since #73 removed the showcase grid — nothing renders `image_url` any more.

## Recovery asset

The depuration deleted 57 tags. **All 77 (tag, topic) pairs were captured before deletion** and
are complete — no tag is missing. This makes the deletions reversible in practice at the cost of
one write per topic.

It matters here because the new taxonomy has a home for some of what was deleted: `cies`(2) was
the *Impresión y ensobrado* submenu, and its two topics (`/t/1498`, `/t/1458`) are to be
re-tagged as part of this work. `bug` and `incidencia` are recoverable the same way if a later
pass wants them back.

The capture currently lives only in a session scratchpad. **Committing it alongside this spec is
part of stage 1**, or it is lost.

## Mechanics that constrain execution

All measured on PRE on 2026-09-04. Each cost an attempt.

- **Synonyms do not chain.** Merging a tag that already has a synonym fails with *"no está
  permitido mientras existan sinónimos"*. Move the child to the final target first.
- **A tag group creates the tags it names.** `TagGroup#tag_names=` calls
  `DiscourseTagging.add_or_create_tags_by_name`, so `POST /tag_groups.json` with
  `name` + `tag_names[]` creates any tag that does not yet exist — no topic write needed.
  Deleting the group afterwards destroys the memberships, not the tags, so a throwaway group
  is a clean vehicle for creating a tag ahead of use. Verified on 2026-09-04 by creating
  `nueva-version-gestiona`(id 289). Send **no `permissions` parameter**: supplying one returns
  500, while omitting it defaults to `{"0": 1}` (everyone).
  *(An earlier draft of this spec said there is no way to create a tag and prescribed a
  merge-rename-resynonym dance. That was wrong.)*
- **The `#` filter needs the exact accent.** `Tag.where_name` compares `lower(name)` with no
  `unaccent`. Any new accented tag needs an unaccented synonym or it is unreachable without the
  accent — and the failure is silent, returning a larger full-text result set.
- **Tag edits do not reindex.** Adding, removing or renaming a tag leaves the old name in
  weight C of `post_search_data` until the post is rebaked. The `#` filter is live either way;
  only text ranking lags.
- **A tag group needs non-empty permissions**; `ensure_permissions_not_empty` validates on
  update. The existing group uses `{"0": 1}` (everyone).

## Success criteria

1. Eight tag groups exist, holding the 57 subject tags as tabled above, and `#<group-slug>`
   returns the union of each group's tags.
2. Subject coverage rises from 47% to **at least 830 of the 1 261 topics (65.82%)**, before
   the body pass on the 166 adds anything. *(Met: Task 7's writes brought coverage to
   832/1,261 — 65.98% — past this 830-topic target, though one topic short of a strict
   66.00%.)*
3. No tag has fewer than 3 uses, the state reached by the depuration.
4. Every old tag name still filters — no rename leaves a dead `#name`.
5. `pendiente-etiquetar` holds only genuinely unclassified topics, and its count is recorded as
   the starting point for the next pass.

## Explicitly out of scope

- **The funcionalidad axis.** Approach C was chosen: eight module groups and nothing else.
  `#tramitacion-administrativa` will therefore keep returning 414 topics — the module axis does
  not narrow, and the *"how do I configure a resolution circuit"* case that opened the work is
  improved only by better coverage, not by a second dimension. This is a known and accepted
  limit, not an oversight.
- **Any theme change.** The theme reads three tags by name (`highlights_podcast_tag`,
  `highlights_newsletter_tag`, `highlights_news_tag`); `podcast`(3) and `newsletter`(14) both
  survive and are untouched by this design. `nueva-version-gestiona` was created during this
  work (see *Mechanics*, id 289) and now holds 39 uses feeding `highlights_news_tag` — the
  setting itself was not touched by this design, only the tag content it already pointed at.
- **The structural layer.** `alumno-certificado`(230) absorbed `certificados` during the
  depuration and can no longer be split without re-tagging 230 topics by hand.
- **PROD.** It has neither the depuration, nor `min_search_term_length: 3`, nor
  `max_tag_search_results: 5`, and its tag vocabulary is unmeasured.

## As executed (Task 2, 2026-09-06)

Five operations on PRE, split across two sessions with no overlap in what each one touched.

| # | Operation | Result |
|---|---|---|
| 1 | Delete `interoperabilidad` | done — HTTP 200 |
| 2 | Delete `desarrollo-software` | done — HTTP 200 |
| 3 | Delete `debate-técnico` | done — HTTP 200 |
| 4 | Rename `pid` → `integracion-pid` | done — HTTP 200 |
| 5 | Rename `seriesdocumentales` → `serie-documental` | done — HTTP 200 |
| 6 | Recreate `pid` as a synonym of `integracion-pid` | done — HTTP 200, `{"success":"OK"}` |
| 7 | Recreate `seriesdocumentales` as a synonym of `serie-documental` | done — HTTP 200, `{"success":"OK"}` |

**Operations 1–5 had already executed before this session opened them.** What is established,
and no more than this: this session's first read (`/tags.json`) already showed the three tags
deleted and both renames done, with `synonyms: []` on both renamed tags — so the mutation
predates this session's own calls. The staff action log shows the five operations at
2026-09-06T07:48:11Z–07:49:35Z, actor `RicardoPG` — but that attribution is **not diagnostic**:
`RicardoPG` is this project's own API-key username, so every call made with that key is logged
under it regardless of who or what session issued it. It does not distinguish an earlier agent
run from a human acting in admin from anything else holding the key. The log entries are also
**8–38 seconds apart**, while the brief's Step 3 script sleeps 1.3s between calls — a pacing that
does not match that script, which argues against "an earlier run of this exact script" as the
specific mechanism, whatever the actual source was. No stronger claim than "already mutated,
by something other than this session's own calls" is supported. This session verified the
resulting state (read-only), recognised the missing synonym-recreation as the exact,
already-authorised remainder of Step 3 — not new scope — and completed it, since leaving it
half-done meant `#pid` and `#seriesdocumentales` were silently degraded to full-text search in
production.

Step 5 filter check, before (prior session's Step 1, itself already affected by the unfinished
rename) vs. after this session's fix:

| Tag | Before (this session's Step 1) | After (Step 5) | Expected |
|---|---|---|---|
| `#pid` | 50 (synonym missing → fell through to full text) | 7 | 9 |
| `#seriesdocumentales` | 3 | 3 | 3 |

The `7` for `#pid` is not the failure signature (`0` or `50`) the brief warns about: all 7
`search.json` hits carry the `integracion-pid` tag with zero full-text false positives, and the
direct listing endpoint `/tag/integracion-pid.json` returns the full **9**, matching the tag's
own `topic_count`. **Verified cause of the 9-vs-7 gap:** the two topics missing from the search
result, `/t/176` and `/t/177` (both "Integraciones - PID Consulta de inexistencia…"), are
`visible: false` (unlisted) — confirmed directly against `/t/176.json` and `/t/177.json`. `#tag`
search excludes unlisted topics; a tag's `topic_count` and its `/tag/<name>/l/latest.json`
listing both include them. `#integracion-pid` itself also returns 7, so the gap has nothing to do
with the synonym — it is the documented asymmetry already recorded above under *"A tag's
`topic_count` counts unlisted topics; `#tag` search does not"* (measured there on
`nueva-version-gestiona`/`/t/176`), now reproduced on a second tag.

The three deletion candidates, captured at this session's Step 1 (after the prior session had
already deleted them, so these are post-deletion full-text noise, not tag-filtered counts):
`interoperabilidad` 15, `desarrollo-software` 3, `debate-técnico` 4 — all three tags absent from
`/tags.json`, confirmed deleted.

Verifier, before this session's fix (10 assertions — 8 `group missing:` + the 2 synonym gaps) →
after (8 assertions, all `group missing:`, matching the plan's expected post-Task-2 state):

```
FAIL — 10 assertion(s)
  ✗ group missing: Tramitación administrativa
  ✗ group missing: Configuración
  ✗ group missing: Atención a la ciudadanía
  ✗ group missing: Registro electrónico
  ✗ group missing: Inicio
  ✗ group missing: Gestión económica
  ✗ group missing: Analítica de datos
  ✗ group missing: Aplicaciones y servicios
  ✗ integracion-pid does not carry 'pid' as a synonym — #pid no longer filters
  ✗ serie-documental does not carry 'seriesdocumentales' as a synonym — #seriesdocumentales no longer filters
```
```
FAIL — 8 assertion(s)
  ✗ group missing: Tramitación administrativa
  ✗ group missing: Configuración
  ✗ group missing: Atención a la ciudadanía
  ✗ group missing: Registro electrónico
  ✗ group missing: Inicio
  ✗ group missing: Gestión económica
  ✗ group missing: Analítica de datos
  ✗ group missing: Aplicaciones y servicios
```

## As executed (Task 3, 2026-09-06)

Step 1 reproduced the expected red state exactly: 8 assertions, all `group missing:`, no more
and no fewer.

Step 2 created all eight groups in one pass, `POST /tag_groups.json` with no `permissions`
parameter (confirmed: that field 500s). Every group came back `200` with the tag count matching
the request exactly — no group reported extra or missing tags, so no tag was invented:

| # | Group | Requested | Returned | Status |
|---|---|---|---|---|
| 1 | Tramitación administrativa | 16 | 16 | OK — 200 |
| 2 | Configuración | 6 | 6 | OK — 200 |
| 3 | Atención a la ciudadanía | 11 | 11 | OK — 200 |
| 4 | Registro electrónico | 3 | 3 | OK — 200 |
| 5 | Inicio | 9 | 9 | OK — 200 |
| 6 | Gestión económica | 7 | 7 | OK — 200 |
| 7 | Analítica de datos | 3 | 3 | OK — 200 |
| 8 | Aplicaciones y servicios | 4 | 4 | OK — 200 |

`tesauro` and `markdown` each landed in both Tramitación administrativa and Configuración, as
the mapping intends — the axis is deliberately not a partition.

Step 3 verifier: `PASS — 8 groups, 3 deletions, 2 renames`, exit 0.

Step 4 — **`/tag_groups.json` carries no `slug` field for a tag group at all** (checked the raw
response: a group object is only `id`, `name`, `tags`, `parent_tag`, `one_per_topic`,
`permissions`). So there is no stored "real slug" to read back and correct the brief's guesses
against. What was verified instead: the brief's own guessed slugs — the group name, accents
stripped, lowercased, spaces to hyphens — are exactly what `#<slug>` resolves against, computed
on the fly by the search parser rather than persisted.

**Every one of the 8 groups was checked topic-by-topic, not sampled.** For each group, every
topic `search.json` returned for `#<slug>` was checked against that group's own tag list from
the mapping; the first pass counted a group as verified whenever 100% of its returned topics
carried at least one of its tags. Seven of the eight did, cleanly. The eighth — Configuración —
also showed 100%, but that number is a false pass: see the correction below before reading this
table as eight confirmed group filters.

| Group | Slug | Returned | Carrying a group tag | At 50-cap | What `#<slug>` actually resolved to |
|---|---|---|---|---|---|
| Tramitación administrativa | `tramitacion-administrativa` | 50 | 50 (100%) | yes — cap, not true size | the tag group ✅ |
| Configuración | `configuracion` | 37 | 37 (100%) | no | **the tag `configuración`, not the group — see below** ⚠️ |
| Atención a la ciudadanía | `atencion-a-la-ciudadania` | 50 | 50 (100%) | yes — cap, not true size | the tag group ✅ |
| Registro electrónico | `registro-electronico` | 50 | 50 (100%) | yes — cap, not true size | the tag group ✅ |
| Inicio | `inicio` | 50 | 50 (100%) | yes — cap, not true size | the tag group ✅ |
| Gestión económica | `gestion-economica` | 50 | 50 (100%) | yes — cap, not true size | the tag group ✅ |
| Analítica de datos | `analitica-de-datos` | 36 | 36 (100%) | no | the tag group ✅ |
| Aplicaciones y servicios | `aplicaciones-y-servicios` | 26 | 26 (100%) | no | the tag group ✅ |

Zero non-matching topics in any group — no plain full-text-fallback false positive anywhere
across all 219 returned topics. But "100% of returned topics carry a group tag" cannot by itself
distinguish "the group resolved" from "a single member tag resolved, and every result
necessarily carries that one tag" — which is exactly what happened to Configuración.

**Correction — Configuración's `#configuracion` filters the tag, not the group (round-2 review
finding).** Discourse's `#foo` search resolves in a fixed order: **category slug → exact tag
name → tag-group slug → full text.** The tag `configuración` (id 107) already carried an
unaccented synonym `configuracion` (id 275, 0 uses of its own) — created before this task, not
by it — so `#configuracion` matches at the *exact tag name* step and never reaches the
tag-group step at all. Three independent checks confirm it:

1. **The count is exact, not approximate.** `#configuracion` returns 37 topics; the tag
   `configuración` itself has `topic_count: 37`. If the group (6 tags, including `tesauro` at 81
   uses on its own) had resolved instead, the union would run far higher than 37.
2. **Zero overlap with a fellow group member's own listing.** `#tesauro` returns 50 (capped);
   `#configuracion` returns 37; the two result sets share **zero** topic ids. A genuine
   group-level OR would surface at least some of `tesauro`'s topics under `#configuracion`.
3. **The corrected stronger test (below) finds no topic missing the shadow tag.** All 37 topics
   carry `configuración` itself — none is present only because of a *different* group member.
   That is precisely what a single-tag match produces and a group-level OR would not.

**Bounding — only Configuración is affected.** Re-ran the collision check properly this time:
against not just the 103 primary tag names but **every synonym of every one of those 103 tags**
(the first pass, in the initial cut of this section, checked primary names only and had
dismissed this exact coincidence as harmless — it was the collision that mattered). Across all
103 primary tags and their synonyms, exactly one pair collides with any of the 8 group slugs:
the primary tag `configuración` (transliterates to `configuracion`) and its own synonym
`configuracion` (a literal match). No other tag or synonym, anywhere in the vocabulary, matches
any of the other 7 group slugs. Combined with the resolution order above, that is not merely
"unfalsified" for those seven — since neither a category slug nor an exact tag/synonym name
exists for any of them, `#<slug>` for those seven is *structurally forced* to fall through to
the tag-group step. Category slugs were also re-checked (all 17 of PRE's current categories,
walking `subcategory_list`): no collision with any of the 8 group slugs there either.

**A stronger test for future readers, and the trap in its naive reading.** The intended test:
*a group filter is only proven if `#<slug>` returns at least one topic that carries a group tag
while **not** carrying whichever tag's own name equals the group slug.* Read carelessly as "at
least one returned topic carries some other group tag too" it gives a **false pass even for
Configuración**: 9 of its 37 results happen to also carry `tesauro`, `markdown` or
`usuario-perfil` — ordinary co-tagging, since these subject tags are often applied together on
the same topic — which would look like a pass under the sloppy reading. The test only works
read as written: does any returned topic carry a group tag **instead of, not in addition to**,
the shadowing tag? For Configuración the answer is zero out of 37 — every single result carries
`configuración` — which is exactly what a tag-only match produces and a group-level OR could
not, since nothing constrains a genuine OR to always include one particular member.

**Net result of Step 4, corrected: 7 of the 8 group filters are verified genuine; Configuración
is shadowed by its own member tag and its `#configuracion` search never reaches the group.** The
group itself was created correctly with the right 6 members (Step 2's table stands unchanged —
this is a search-filter finding, not a membership defect), and nothing on the instance was
changed to produce or fix this: it is a pre-existing exact-match precedence in Discourse's
search resolution, surfaced only by checking the filter, not by anything this task wrote. Whether
to rename the tag or the group to remove the shadow is Ricardo's call, tracked separately —
untouched here.

**Resolved — Ricardo chose to rename the group, not the tag.** Its name changed to
`Configuración Gestiona`; the resulting slug `configuracion-gestiona` was checked against all
103 tags, every one of their synonyms, every category slug (walking `subcategory_list`) and
every other tag group before applying, so the rename introduces no new shadow. Proof this fixes
the resolution rather than merely renaming the group: of the 30 topics that carry `tesauro` but
not `configuración`, **23 appear in `#configuracion-gestiona` and 0 in `#configuracion`** —
topics the shadowed tag-only match could never have surfaced. **All eight group filters now
resolve to their tag group, so success criterion 1 is met.** The mapping key (the module-axis
data and the verifier) was updated in the same commit, so `./bin/tags-verify` kept passing.

Verifier, before this task vs. after:

```
FAIL — 8 assertion(s)
  ✗ group missing: Tramitación administrativa
  ✗ group missing: Configuración
  ✗ group missing: Atención a la ciudadanía
  ✗ group missing: Registro electrónico
  ✗ group missing: Inicio
  ✗ group missing: Gestión económica
  ✗ group missing: Analítica de datos
  ✗ group missing: Aplicaciones y servicios
```
```
PASS — 8 groups, 3 deletions, 2 renames
```

## As executed (Task 4, 2026-09-06)

Step 1 confirmed the two `cies` topic ids from the committed capture, exactly as expected — no
divergence, so no BLOCKED path was needed:

```
1498 SEMINARIO: Los servicios de impresión, ensobrado y envío de SMS
1458 Nuevo curso en la Academia: Servicios de impresión, ensobrado y envío de SMS
```

Step 2 read each topic's current tags before writing anything:

| Topic | Tags before | `image_url` before |
|---|---|---|
| `/t/1498` | `webinars` | `None` (already no list thumbnail) |
| `/t/1458` | `academia` | `None` (already no list thumbnail) |

Neither was near the 7-tag cap, so no skip was needed.

Step 3 resent each topic's existing tag together with `registro`, via `PUT /t/-/<id>.json`:

| Topic | Sent | HTTP status |
|---|---|---|
| `/t/1498` | `webinars`, `registro` | 200 |
| `/t/1458` | `academia`, `registro` | 200 |

Step 4 re-read both topics and confirmed nothing was lost:

| Topic | Tags after | Has `registro` | `image_url` after |
|---|---|---|---|
| `/t/1498` | `registro`, `webinars` | yes | `None` (unchanged — was already `None` before this write) |
| `/t/1458` | `academia`, `registro` | yes | `None` (unchanged — was already `None` before this write) |

Both topics' `image_url` was already `None` before this task touched them, so the known
"a write clears the list thumbnail" effect had nothing left to clear here — neither topic had
one to lose.

Verifier, run once before the writes and once after, byte-identical output both times, exit 0
both times:

```
PASS — 8 groups, 3 deletions, 2 renames
```

No tags, groups, deletions or renames were touched by this task — only the two topics' tag
assignments.

## As executed (Task 6, 2026-09-06)

Step 1 (batch validation) had already been done before this task started: Ricardo validated
all 42 batches and the controller recorded the decisions in
`docs/superpowers/plans/data/2026-09-04-batch-decisions.json` — 29 batches `approve` (6 of
them carrying the 14 individual exclusion ids: `configuración` 1, `tramitación` 1,
`registro` 5, `sede-electrónica` 1, `terceros` 5, `integraciones` 1), 13 batches `reject`
outright (`fechas`, `interesados`,
`auditoria`, `tablón-anuncios`, `subvenciones`, `relacionados`, `ayudas`, `ventanilla-única`,
`contratación`, `sello-de-organo`, `carpeta-ciudadana`, `plantillas`, `expedientes-apertura`).
Of 455 proposed (tag, topic) pairs, 60 were excluded (46 from the rejected batches wholesale,
14 from individual exclusions inside approved batches), leaving **395 pairs across 208 distinct
topics** to write.

Step 2 grouped the 395 pairs by topic (per the brief's script) and, for each of the 208 topics,
read its current tags before resending the union with `PUT /t/-/<id>.json`:

```
topics to write: 208
  /t/1361 SKIPPED: 2 tags + 6 exceeds max 7
  /t/1363 SKIPPED: 2 tags + 6 exceeds max 7
applied=206 skipped=2 failed=0
```

- **206 applied**, 0 non-200 responses on any read or write.
- **2 skipped at the 7-tag ceiling**, neither truncated:
  - `/t/1361` — existing `administracion-avanzada`, `ideas-2025`; would-add `expedientes`,
    `tareas`, `tareas-regladas`, `tesauro`, `tramitación`, `tramitación-reglada` (6 tags, 8
    total).
  - `/t/1363` — existing `administracion-avanzada`, `ideas-2025`; would-add
    `circuitos-tramitacion`, `configuración`, `tareas`, `tareas-regladas`, `tramitación`,
    `tramitación-reglada` (6 tags, 8 total).
- **0 topics** were already fully tagged going in (no `skip-already-tagged` case fired).
- **0 failed** reads or writes.

Step 3 (coverage re-measurement) did **not complete**. The full paginated crawl (17
categories) hit `HTTP 429` partway on the first attempt; a second attempt with backoff added
was still in flight when Ricardo reported hitting `429` himself probing the same instance, and
was stopped rather than risk a second partial crawl competing for the same rate-limit budget.
**Post-write subject coverage is therefore unmeasured as of this commit.** The pre-write
baseline, from Task 5's Step 1, was **48.5%** (612/1261). Ricardo (or a later, uncontended run
of the brief's Step 3 script) can measure the actual post-write figure once the rate limit
clears; expected, per the brief, is roughly 65% — a little under the design's 66% target
because 60 of the 455 proposed pairs were excluded.

`./bin/tags-verify` was **not** re-run after the writes, for the same rate-limit reason. No
tags, groups, deletions or renames were touched by this task — only topic tag assignments —
so there is no structural reason to expect it to fail; it stands unverified rather than
verified-and-passing as of this commit.

## As executed (Task 7, 2026-09-06)

Steps 1-2 (regenerate the residual, split it by genre, run the body pass at threshold 3) had
already been done in an earlier, read-only dispatch. Summary: crawl of 1,261 topics;
**818/1,261 (64.9%)** already carried a subject tag; residual
443, of which 255 genre-matched (left untagged on purpose) and 188 had no title genre; the body
pass over those 188 proposed at least one tag for 43 (22.9%), two of them flagged as likely
false positives (a boilerplate template field label, and forum-onboarding help docs colliding
with product vocabulary by homonym).

Ricardo reviewed all 43 proposals individually and recorded the final decision in
`docs/superpowers/plans/data/2026-09-04-body-decisions.json`: **14 topics** to receive a
pruned subject-tag set (the weak/false-positive proposals removed), and the remaining
**174 topics** to receive the structural `pendiente-etiquetar` tag instead
(14 + 174 = 188, exactly the no-genre residual — every row accounted for, no overlap).

Step 4 created `pendiente-etiquetar` through a throwaway tag group, per the brief:

```
[200] temporary group created, id=12
[200] temporary group deleted
verify /tags.json: pendiente-etiquetar present=True count=0
```

Verified present with 0 uses before any topic write, exactly as the brief requires.

Steps 3+4 (writes) then ran as one read-modify-write pass, both using the pattern from Task 6
Step 2 (read a topic's current tags, resend the union, skip rather than truncate at the 7-tag
ceiling):

- **Subject-tag writes (14 topics, exactly `body-decisions.json`'s `apply` map):**
  **14 applied, 0 skipped, 0 failed.** No topic was within reach of the 7-tag ceiling — the
  fullest case (`/t/2422`) went from 4 tags to 6. Full before/after list:

  | Topic | Title | Tags before | Tags applied |
  |---|---|---|---|
  | `/t/165` | 05. Expertos grupo esPublico - Arquitectura de interoperabilidad | `expertos-espublico` | `integraciones` |
  | `/t/168` | 09. Expertos grupo esPublico - Integración contable para el… | `expertos-espublico` | `integraciones` |
  | `/t/398` | Mejorar el Servicio de Avisos, Alertas | `administracion-avanzada`, `ideas` | `tareas` |
  | `/t/473` | Condicionales en selector múltiple | `administracion-avanzada`, `ideas`, `v9`, `soporte` | `tesauro` |
  | `/t/504` | Niveles de usuario | (none) | `usuario-perfil` |
  | `/t/714` | Propuesta sobre nomenclatura de documentos y subcarpetas | `administracion-avanzada`, `ideas`, `mejoras`, `proyectos` | `expedientes` |
  | `/t/1097` | Elegir cargo para validacion de documentos | `administracion-avanzada`, `ideas`, `academia`, `actualidad-gestiona` | `firma` |
  | `/t/1544` | Servicio de impresión y ensobrado y las alertas de publicaci… | `administracion-avanzada`, `ideas`, `mejoras`, `actualizar` | `registro` |
  | `/t/2369` | Enlaces a recursos en Gestiona (URL) | `analiza` | `configuración` |
  | `/t/2409` | Modificación de visibilidad de los documentos. Elección de t… | `administracion-avanzada`, `ideas`, `alumno-certificado`, `mejoras` | `terceros` |
  | `/t/2414` | Distribución horaria y estado de las citas (HOY) | `analiza` | `cita-previa` |
  | `/t/2422` | Problemas de conexión Chrome-Autofirma | `administracion-avanzada`, `ideas`, `mejoras`, `soporte` | `firma`, `sede-electrónica` |
  | `/t/2552` | Error en publicación de notificaciones en el BOE | `administracion-avanzada`, `alumno-certificado`, `mejoras` | `registro`, `terceros` |
  | `/t/2568` | Herramientas de ayuda en la definición de objetivos de análi… | (none) | `analítica` |
- **`pendiente-etiquetar` writes (174 topics, the `queue` list):**
  **174 applied, 0 skipped, 0 failed.** Existing tag counts on these topics ranged 0-5
  (median 1-2), so the ceiling was never approached; no skip to report.

Step 5 verification:

- **Coverage rose from 818/1,261 (64.9%) to 832/1,261 (65.98%)** — computed from the same
  1,261-topic crawl plus the 14 newly subject-tagged topics (none of the 14 carried a subject
  tag before this task, confirmed against the crawl, and the 174 `pendiente-etiquetar` writes
  do not touch subject tags — that tag is in no module group). A fresh full re-crawl was not
  re-run for this figure, since nothing else changed the topic set between the Step 1 crawl and
  these writes.
- **Final `pendiente-etiquetar` count: 174**, read from `/tags.json`'s per-tag `count` field —
  the number the brief's own listing check (`/tag/pendiente-etiquetar/l/latest.json`) cannot
  report past 30, since it paginates there and returned exactly 30 topics, not 174. Use the
  `/tags.json` count field for any tag whose usage exceeds one page.
- **`./bin/tags-verify` → `PASS — 8 groups, 3 deletions, 2 renames`, exit 0.** No tag, group,
  deletion or rename was touched by this task beyond `pendiente-etiquetar` itself, which is
  deliberately outside every module group and therefore outside everything the verifier checks.

**174 is the count that matters for the next pass**: it is the size of the working queue this
task opened, distinct from the 255 genre topics that were left untagged on purpose and are not
meant to be worked.

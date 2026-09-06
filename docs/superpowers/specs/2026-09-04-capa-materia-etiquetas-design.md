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
| **Configuración** | 6 | 175 | `tesauro`(81) · `configuración`(37) · `markdown`(35) · `usuario-perfil`(11) · `integraciones`(8) · `serie-documental`(3) |
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
2. Subject coverage rises from 47% to **at least 66%** of the 1 261 topics — 830 of them —
   before the body pass on the 166 adds anything.
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
  survive and are untouched by this design. `nueva-version-gestiona` has never existed.
- **The structural layer.** `alumno-certificado`(230) absorbed `certificados` during the
  depuration and can no longer be split without re-tagging 230 topics by hand.
- **PROD.** It has neither the depuration, nor `min_search_term_length: 3`, nor
  `max_tag_search_results: 5`, and its tag vocabulary is unmeasured.

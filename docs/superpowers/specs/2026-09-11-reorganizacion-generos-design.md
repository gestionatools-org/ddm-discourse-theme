# Genre reorganisation: one plaza, three rooms — design

**Date:** 2026-09-11
**Status:** agreed in brainstorming, not executed.
**Scope:** PRE (`discourse.gestiona4dev.tech`). Instance state only — categories, group
permissions and two category settings. **No theme code changes.**
**Supersedes:** the category half of `2026-09-06-migracion-prod-design.md`. Its Phase 2
replicated onto PROD the taxonomy this document replaces, so that phase is void and the
whole window is postponed (see *Consequences for the PROD migration*).

## Why

The community diagnosed itself in `/t/2224` ("Reflexiones sobre nuestra Comunidad",
2026-03-24, 21 posts): participation concentrated in three people, and — Susana, in the
thread — *"se complica mucho la búsqueda y manejo de información en la plataforma"*. The
answer given there was *"un cambio estético y de organización"*. The theme is the first
half. This is the second.

The concrete complaint is that genres are mixed. Measured on 2026-09-11, they are — but not
where it was assumed, and the measurement moved the design twice.

### What was measured

**Category 5 "Foro del Certificado" — 366 topics, two genres in one box.**

| Genre | Topics | Share |
|---|---:|---:|
| Arrival announcement (with or without poster) | **160** | 44% |
| Forum: peer consultations, plus ~5 community-life topics | **206** | 56% |

Poster and ceremonial announcement are **the same genre**, not two: 51 of the 60
`poster-evf` topics carry an arrival title. The poster is the deliverable a newly certified
member presents when introducing themselves. The 160 are exactly the announcements moved in
from category 78 on 2026-09-03.

**Category 4 "Noticias" — 120 topics. The author discriminates; the title does not.**
84 topics were opened by staff (`esPublico` ∪ `administradores` ∪ `personal` ∪ `Producto`,
18 people) and are genuine official communication: newsletters, product notes, release
notes, "Reto del mes". **36 were opened by members**, and those are technical consultations
with real traction — *Criterios de nomenclatura y ordenación de tareas* (29 replies),
*Subprocesos reglados y vinculación con circuitos de resolución* (19), *Tesauro 18iN con
valores predefinidos* (11). Three of the 36 are community life, not consultation.

Titles are useless as a discriminator here because Spanish titles are noun phrases, not
questions: *"Registrar oficio de salida"*, *"Responsable del expediente"*. A
question/statement heuristic classified 171 of 206 as "neither". **That opacity is itself
part of the retrieval problem Susana named**, and is noted as out of scope below.

**Category 18 "Tengo una idea" — 528 topics, and almost clean.** 19 release notes
(*Novedades versión 10.0.3.336*, 28 replies), ~20 pattern matches for incidents of which
roughly half are false positives (*"Propuesta: Sistema de Gestión de Incidencias
Ciudadanas"* is a proposal), and **489 legitimate proposals — 93%**.

**This killed a category before it was drawn.** The design opened with an "incidencias"
genre on the strength of four titles seen in `/latest`. At 10–20 real topics it has no mass,
so it is out of scope, and the correction is recorded because the four titles were
genuinely convincing.

### The finding that was not about genres

Three programme spaces exist and **in all three the students cannot write**:

| Category | Group | Permission held | Consequence |
|---|---|---|---|
| 75 Recursos Developers | `Developers01`–`04`, 62 people | **none at all** | 2 topics. They cannot see it. |
| 73 Recursos Analítica | `Analiza`, 82 people | **`ver`** only | 66 topics, **zero replies in its whole history** |
| 85 Comparte | — (`administradores`, 11) | — | 14 topics visible to eleven people |

Analítica's tree has no replies because five administrators are the only accounts that can
post there — not because it is a repository. "Comparte" promises *"material compartido por
otros usuarios de la comunidad"* to an audience of eleven.

These are configuration faults, not cultural ones. Ricardo's decision was to leave all three
untouched in this pass; they are recorded under *Out of scope* so the next pass does not
re-derive them.

### Scale of each programme

| Programme | People | Topics | Boxes today |
|---|---:|---:|---:|
| Administración Avanzada | `Certificación` 374 · `UsuariosCertificados` 234 · 33 CAAG cohorts | ~700 | shares 4, 5, 18 |
| Analítica de datos | `Analiza` 82 | ~112 | **8** |
| Developers | `Developers01`–`04` ≈ 62 | **15** | 1 (holding 2) |

**Eight categories hold 66 topics (5% of the site) while two hold 893 (71%).** The tree is
inversely proportional to the content. Analítica's seven children subdivide by *subject* —
*Biblioteca de expresiones*, *Modelos de datos*, *Técnicas y expresiones básicas* — which is
the axis the module tag groups already own at 66% coverage against these categories' 5%.

## Design

### The organising principle

**Scope first, not genre.** The top-level split is what Ricardo asked for in his own words:
separate *"las cuestiones que afectan a los tres programas de certificación (noticias
comunidad, eventos, formación de novedades, etc.) de aquellas que son exclusivas de los
alumnos de un programa concreto"*. Within each zone, the category names a genre; subject
stays in tags, where the module axis already lives.

Membership overlaps by design — members are certified in one, two or three programmes — so
the zones are not a partition of people, only of content.

### Target map

**Common zone** — open to `Certificación` (374) unless noted:

| ID | Name | What is its own | Change |
|---|---|---|---|
| 4 | Noticias *(public)* | Official communication: newsletters, release notes, product, brand | **+19**, **−36** |
| 5 | Foro del Certificado | **The plaza**: arrival announcements and community life | **−201**, **+3** |
| 14 | Aula de formación | Training and course news (broadcast: members reply only) | — |
| 18 | Tengo una idea | Product improvement proposals | **−19** |
| 59 | Eventos | Meetups, cafés, congresses | — |
| 78 | Primeros pasos *(public)* | How the community works | — |
| 85 | Comparte | Reusable resources | — *(pending)* |
| 3 | Administradores | Staff | — |

**Programme zone** — walled, each closed to its group:

| ID | Name | Permission | Content |
|---|---|---|---|
| *new* | **Administración Avanzada** | `Certificación`: create | **234** consultations (201 from 5, 33 from 4) |
| *new* | **Analítica de datos** | `Analiza`: create | Empty at birth; sibling of 73 |
| 73 + 7 children | Recursos Analítica | *untouched* | Course repository |
| 75 | Recursos Developers | *untouched* | *(pending: 62 locked out)* |

**Two categories created, none deleted, ~256 topics moved.** Comparable to August's phase 4
(284 moves, zero topics lost).

### The decisions, and what they cost

**Category 5 becomes the plaza rather than the Administración Avanzada room.** Ricardo's
call: arrival announcements are of general interest, and the 5 keeps them. The consequence
accepted alongside it is that **all three programme rooms are symmetric and none inherits
the common space** — Administración Avanzada gets a new category like the other two, and the
~201 consultations move out of the 5, leaving the 160 announcements and the handful of
community-life topics behind.

**The name is now wrong and stays wrong for the moment.** "Foro del Certificado" names the
programme, not the common plaza. Renaming was offered and declined for this pass; it is
listed under *Out of scope*.

**The wall is a wall, not a shelf.** A closed category is invisible to search for anyone
outside the group, which is a direct cost against Susana's complaint and was put to Ricardo
in those terms before he chose it.

**Measured, that cost is entirely prospective.** Nobody loses access to anything that exists
today. Categories 73 and 75 are already restricted — to `Analiza` at read level, and to the
eight `AdminAnaliza`/`AdminDevelopers` accounts — so their content is already unreachable
for everyone else; the Analítica room
is born empty; and the 234 consultations move from 4 and 5 into a room walled to
`Certificación`, which at 374 members is effectively the whole census (the site has 374
members). The price is paid later, by whatever gets written in a room the rest of the
community cannot search.

**Administración Avanzada is walled to `Certificación` (374), which is every member.** So in
practice the walls only separate Analítica and Developers; AA's room is separated from the
plaza but open to the whole census. This keeps the status quo — nobody loses access relative
to today — and was preferred over `UsuariosCertificados` (234), which would have shut out
140 people who can read the forum today and are most likely students in progress.

**"Tengo una idea" stays single.** Splitting it per programme would fragment the feedback
loop to Producto at exactly the point where the community complains there is no return, and
would break `ideas_category_id`, which names one category.

**Analítica's tree is untouched, and it gets a new sibling room.** The seven children stay
with their read-only permissions as a course repository; conversation gets a new top-level
category closed to `Analiza`. Collapsing the seven was offered and declined.

**`minimum_required_tags` goes to 0.** Categories 4, 5, 14 and 18 all require two tags
today. In a vocabulary of 104 tags that toll manufactures filler rather than
classification — `administracion-avanzada` 700 uses, `alumno-certificado` 230,
`pendiente-etiquetar` 174 — and it is friction on exactly the person who has never posted.

**`hero_default_category_id` stays at 5.** From the homepage, "Nueva publicación" keeps
opening on the common plaza. The alternative — pointing it at the new AA room — would have
required a different value on each instance, since the new categories get different IDs on
PRE and PROD.

## Execution

All instance state on PRE, over the API with `PRE_DISCOURSE_GLOBAL_API_KEY` — the only key
that reaches `/topics/bulk.json`. Rate limit ~1 req/s; sleep 1.3s and back off on 429.

### Phase 0 — capture

Dump the recoverable state before the first write, in the shape of
`2026-09-04-tags-deleted-recovery.json`: the category tree with group permissions, and for
every topic in 4, 5 and 18 its `id`, `category_id`, `title`, `tags` and original author.
**This is the only real rollback for the moves.**

### Phase 1 — derive the move lists, and have them reviewed

Rules generate the lists; **a human approves them before any write**. This is the lesson of
the subject layer's body pass, which offered 43 proposals of which 10 were false positives
in three patterns, caught only by review.

- **From 5 → AA room.** A topic stays if it carries `poster-evf` **or** matches the
  ceremonial pattern `nuev[oa]s? (alumn|compañer|miembr)` / `certificad[oa]s? [·\-:]` /
  `enhorabuena` / `bienvenid`. Everything else moves: ~201. Review by hand the short list of
  community-life topics the pattern cannot see — *Reflexiones sobre nuestra Comunidad*,
  *Hasta aquí llego*, *Encuesta de experiencia y mejora de la Comunidad*, *Reflexión sobre
  el día a día de los certificados*.
- **From 4 → AA room.** Candidate: every topic whose original author is **not** in
  `esPublico` ∪ `administradores` ∪ `personal` ∪ `Producto`. That is 36, of which **3 go to
  5, not to the room** — *Pequeña reflexión que nos puede pasar a cualquiera*,
  *Felicitaciones a los equipos del Hackathon*, *COMUNICADO OFICIAL (Y Extraoficial) de la
  resistencia*. Thirty-six titles: review all of them.
- **From 18 → 4.** Release-note pattern: `novedades? versión`, `nueva versión`,
  `versión \d`, `próximas mejoras`, `aviso de mantenimiento`. Nineteen topics, reviewed
  whole. **The pattern has a known hole recorded from the subject-layer work**: the product
  name can sit between keyword and version (*"Nueva versión Gestiona 10.0.3.325"*), so do
  not require a digit immediately after the keyword.

Commit the approved lists as versioned data under `docs/superpowers/plans/data/`, as the
module axis did.

### Phase 2 — create the two rooms

`POST /categories.json` for "Administración Avanzada" and "Analítica de datos", each with
group `permissions` at create level (`Certificación` and `Analiza` respectively) and
`minimum_required_tags: 0`. **Record the assigned IDs — they will differ on PROD.**

### Phase 3 — move, in batches, verified by ID

`PUT /topics/bulk.json` with the Global key.

- **Verify by topic id, never by count.** Capture the source listing first and locate each
  id in the destination afterwards. It is what caught the two phase-3 tagging faults in
  August.
- **Definition topics ride along in a bulk move.** Untick that row; read its id from the API
  rather than hunting the title.
- **Each move costs the topic its list thumbnail**, by both routes, and a rebake does not
  bring it back. **Verified harmless here**: the 19 `nueva-version-gestiona` topics already
  have `image_url: null`, and the highlights "novedad" card takes its cover from
  `extractCoverImage(cooked)` over the post, not from the listing
  (`javascripts/discourse/blocks/block-highlights.gjs`). No surface renders the 234
  consultations by image.

### Phase 4 — settings

- `minimum_required_tags: 0` on **4, 5, 14, 18** and both new rooms.
- **Delete category 5's `topic_template`** — 457 characters inherited from "Proyectos
  piloto" (category 49, dissolved in August) about early access to in-development versions.
  Every new topic in the forum starts with the wrong paragraph. This is a defect of the
  August reorganisation, not a decision.

### Phase 5 — record

Amend this file with what was actually executed, including departures from the plan —
August's phase 4 had six and recorded every one. Update `CLAUDE.local.md`'s category map,
and amend `2026-09-06-migracion-prod-design.md` per the next section.

## Verification

1. **Topic counts per category**, before and after, against the target map: 4 → 103,
   5 → 168, 18 → 509, AA room → 234, Analítica room → 0. *(`topic_count` excludes unlisted
   topics and the definition topic, while the listing reveals them. Always say which number
   is meant.)*
2. **Every moved id located in its destination.** A count is not a verification.
3. **`bin/categories-verify`** — a re-runnable assertion in the shape of `bin/tags-verify`:
   the tree, each category's group permissions, `minimum_required_tags`, and the absence of
   a `topic_template` on 5. Run with
   `set -a && source .env.local && set +a && ./bin/categories-verify`.
4. **The walls, from a non-admin account.** This is the half neither CI nor the API can
   measure: `/categories.json` answers with the permissions of the key's own user, who is an
   administrator. Confirm that a `Certificación` member without `Analiza` cannot see the
   Analítica room, and that an `Analiza` member can. Same gap the `canCreateTopic` and
   `hero_default_category_id` guards already carry.
5. **The homepage still renders:** three lanes (18 and 59 untouched) and the four bento
   cards. `hero_default_category_id` still resolves to 5, now the plaza.
6. **`bin/tags-verify` green.** This work touches no tags, so it must stay green.

## Consequences for the PROD migration

`2026-09-06-migracion-prod-design.md` planned a maintenance window whose **Phase 2 replays
PRE's 17-category taxonomy onto PROD** — the taxonomy this document replaces. Executing it
would reorganise PROD twice, the second time against 35 live categories and 1 297 topics.

**The whole window is postponed** by Ricardo's decision, until this map is executed and
proven on PRE. Nothing has been applied to PROD, so PROD can receive the final map directly
and skip the intermediate state entirely.

Phases 0, 1a and 1b of that document — keys, tag limits, spelling merges, the subject
layer — are orthogonal to the map and survive unchanged.

**When PROD's turn comes, this map is re-derived against PROD's own measurements, never by
replaying these lists.** PROD has 35 categories, never received August's reorganisation, and
still holds its arrival announcements in category 78. Method carries; numbers do not.

## Out of scope

Recorded so the next pass does not re-derive them.

- **Automatic closing.** `auto_close_hours: 720` from the last post on 4, 5, 14 and 18, plus
  `solved_topics_auto_close_hours: 1`. Measured: **113/120, 356/366 and 179/180 topics
  closed**. Practically the whole community is closed to replies — someone who finds a
  relevant four-month-old thread cannot answer in it, only open a new one or say nothing.
  That is a participation barrier no amount of dinamización fixes, and it is part of what
  "siempre las mismas tres personas" measures. **Deferred by explicit decision to after the
  migration to production.**
- **Category 5's name.** "Foro del Certificado" names the programme, not the plaza.
- **The three permission faults**: Developers' 62 members locked out of category 75,
  `Analiza` unable to write in its own tree, and "Comparte" invisible to 363 members.
- **An incidents category.** Measured at 10–20 topics; no mass.
- **Visible states for proposals** (*Recibida, En estudio, Planificada, Descartada*),
  requested explicitly in `/t/2224`. Offered and declined for this pass.
- **Opaque titles.** Noun-phrase titles that do not say what is being asked are part of the
  retrieval complaint, and no category move addresses them.
- **The funcionalidad axis** of the subject layer, out of scope there too by the same
  deliberate choice.

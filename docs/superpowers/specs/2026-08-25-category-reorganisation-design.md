# Category reorganisation — design

**Date:** 2026-08-25
**Amended:** 2026-08-26 — three further renames, six slugs instead of two, and four
measurements taken while preparing execution. See *Amendments* at the foot of this document.
**Status:** agreed with the maintainer on 2026-08-25. Phase 5 shipped (PRs #31, #32);
Phases 1–4 and 6 pending, PRE first.
**Scope:** the Gestiona Avanza taxonomy and the theme settings and code that depend on it.
Every figure here was measured against PROD (`gestionaavanza.espublico.com`), which is the
authoritative tree; **execution runs on PRE first** — see *Migration plan*.

## Why

The taxonomy grew one category per initiative. It is organised by *who inside esPublico
created it* rather than by *what a member came to do*, and it has accumulated permanent
structure for time-boxed events. Measured on 2026-08-25 over the read-only API:

| | |
|---|---|
| Categories | 34 (12 top-level, 10 member-visible) |
| Topics / posts | 1 242 / 5 377 |
| Tags in use | 109 distinct, on **97%** of sampled topics |

**Four categories carry 80% of all posts** — 18 (26%), 5 (27%), 78 (17%), 4 (10%). The
other 30 share the remaining 20%.

Three structural faults follow from that:

1. **The two largest conversational surfaces are buried as subcategories.** 18 "Tengo una
   idea" (318 topics, the largest on the site) and 78 (164 topics, 4.7 replies/topic,
   growing) both hang off other categories.
2. **Time-boxed campaigns became permanent categories.** 57, 58 and 54 are dead 18-26
   months and will never revive; the next campaign would create a fourth.
3. **Ten categories hold 178 topics with zero replies in their entire history.** They are
   repositories and submission forms wearing forum clothing.

## Evidence that shaped the design

Findings that were not visible from the taxonomy alone and changed the plan:

- **Category 78 contains no pósters.** All 164 topics, from 2024-06-04 to six days ago,
  announce a newly certified person. "Pósters" in its name describes nothing that exists.
  Growth: 38 (2024) → 55 (2025) → 71 (8 months of 2026).
- **Cover images are recent and rising**: 3% of 2024 topics, 7% of 2025, **41% of 2026**,
  and roughly half over the last five months. The póster is a new practice, not a dead one.
- **"Has an image" is not "has a póster."** Of 34 images, 17 are portrait (poster-shaped)
  and 14 are landscape (group photos, screenshots). The showcase lane's `requireImage`
  filter is currently mixing the two. Only an explicit tag can separate them.
- **The `posters` tag cannot classify anything** — it is on 162 of 164 topics, including
  the 130 with no image at all. It duplicates `alumno-certificado` (163 of 164).
- **Categories 57 and 58 are machine imports**, not discussions: titles of the form
  `4072 # 09 - SEDE ELECTRÓNICA<TAB>09.01 - INICIO<TAB>…`, one message each, zero tags.
  Category 18 is the opposite — human titles, 3.6 replies/topic, well tagged.
- **Two of the three proposed programme tags already exist**: `analiza` (62 uses, on 100%
  of category 73) and `developers` (24). `administracion-avanzada` does not — but `caag`
  (40 uses) already fills that role and matches the `CAAG01`–`CAAG33` groups.
- **Category 3 holds Discourse's own `/tos`, `/privacy` and `/faq` topics.** Deleting or
  over-restricting it breaks the site's legal pages. It stays.
- **The Café con certificados series is split across two categories.** Six instalments
  (1er–6º, January–June 2026) sit in 87, and a seventh topic of the same name sits in 71.
  Archiving 71 as-is would deliver an incomplete series to Eventos.
- **PROD's slugs are not the legacy ones recorded for PRE.** Category 4 is `te-contamos`
  and 5 is `el-foro-del-certificado`, not the `comunidad-expertos` / `grupos-de-trabajo`
  captured on PRE on 2026-08-11. The slug work is therefore *caused by* the renames rather
  than pre-existing: after renaming to Noticias and Expertos, correct slugs go stale.
- **Category 85 owns no topics.** All eight live in its child 86; 85 is a wrapper with a
  definition topic. Structurally it is category 53, which this plan deletes.
- **Three of the four dissolutions decided second already carry their tag.** `trucazo` is
  on 13 of 62's 16 topics, `seminarios` on 46 of 67's 50, `newsletter` on 20 of 65's 28.
  The categories were duplicating a classification the topics already had, which is the
  clearest argument in the whole plan that these are tags wearing category clothing.
- **Webinars has two competing tags**, `seminarios` (46) and `webinar` (10). Adopting
  `webinars` with both as synonyms migrates all 56 taggings and ends the split.
- **Category 14's own topics are already webinars**: "Curso Novedades Febrero 2026",
  "Seminarios de septiembre", "Sesión de formación de las novedades v.10.0.3.325", two of
  them tagged `seminarios`. Dissolving 67 into 14 merges content that never differed.
- **`newsletter` is not exclusive to category 65.** At least one Trucazos topic ("Truco del
  mes newsletter 12") carries it, and keeps it in Aula de formación. The tag marks *the
  newsletter it came from*, not *is a newsletter* — worth knowing before any lane or saved
  search is keyed on it.

### A measurement trap worth recording

A category's `latest` listing **includes its subcategories' topics**, and the category
definition topic is pinned to the top. Reading activity from the first row of that listing
therefore reports the definition topic's age, and reading topic counts from it double-counts
children. This produced four wrong readings before it was caught: 78 read as 4 months idle
when it was 5 days; 62 Trucazos read as 17 months dead when it is 19 days alive; categories
53 and 49 appeared to hold topics that belong to their children. **Measure with the
definition topic excluded and `topic_count` taken from `categories.json`, never from a
listing.**

Three more, found on 2026-08-26 while preparing execution:

- **`topic_count` excludes unlisted topics as well as the definition topic.** Category 3
  reports 8 and its listing returns 18: 18 − 9 unlisted − 1 definition = 8. The two measures
  answer different questions, and the gap is exactly where content hides.
- **For listings, the endpoint that works is the slug form.** `/c/<id>/l/latest.json`
  returns an empty body; `/c/<slug>/<id>/l/latest.json` returns 200. That is the opposite of
  `show.json`, where `/c/<id>/show.json` works and the slug form errors. Both facts are now
  in `CLAUDE.local.md`; neither is guessable.
- **A category's own topics must be filtered by `category_id`** even in its own listing,
  because the listing carries children's topics too. Every count in the *Slugs* and
  *Amendments* sections is filtered that way.

## Target taxonomy

**34 categories → 17 active. 10 visible top-level → 9.** No new category IDs.

Only category 73 keeps children. Everything else is flat.

| Top level | ID | Children |
|---|---|---|
| **Noticias** | 4 *(renamed)* | — *(65 and 66 become tags)* |
| **Primeros pasos** | 78 *(renamed, promoted)* | — |
| **Expertos** | 5 *(renamed)* | — *(34 dissolved into 85)* |
| **Tengo una idea** | 18 *(promoted)* | — |
| **Aula de formación** | 14 | — *(62 and 67 become tags)* |
| **Eventos** | 59 *(renamed)* | — |
| **Recursos Analítica** | 73 *(renamed)* | its 7 existing children |
| **Recursos Developers** | 75 *(renamed)* | — |
| **Comparte** | 85 *(renamed, absorbs 34 and 86)* | — |
| *(staff)* Administradores | 3 | — |

After the renames the word "certificación" appears in **no** category name — it leaves 5,
59, 73 and 78, and 87 dissolves into a tag. That is right rather than lossy: the whole site
is the certification programme, so the word discriminated nothing wherever it appeared. It
survives only where it identifies a person, in the tag `alumno-certificado`.

### Every category, and what happens to it

| ID | Today | Action |
|---|---|---|
| 4 | Te contamos… | rename → **Noticias**; new slug (see *Slugs*) |
| 65 | Newsletter *(child of 4)* | topics → 4, tag `newsletter`; delete — **widens read access**, accepted |
| 66 | Blog Gestiona *(child of 4)* | topics → 4, tag `blog-gestiona`; delete |
| 78 | …· Pósters *(child of 4)* | rename → **Primeros pasos**, promote to top level; new slug |
| 87 | Café con certificados *(child of 4)* | topics → 59, tag `cafe-con-certificados`; delete |
| 5 | El foro del Certificado | rename → **Expertos**; new slug (see *Slugs*) |
| 34 | Recursos compartidos *(child of 5)* | topics → **85**; delete |
| 18 | Tengo una idea *(child of 5)* | promote to top level — **name kept**, it is what members already know |
| 58 | Campaña ideas febrero 2025 | topics → 18, tag `campana-febrero-2025`; delete |
| 54 | Campaña Gestiona V9 | topics → 18, tag `campana-v9`; delete |
| 57 | Campañas de ideas *(child of 53)* | topics → 18, tag `campana-2024`; delete |
| 53 | Moderadores | delete — **zero own topics** |
| 50 | Analiza | topics → 5, tag `analiza`; delete |
| 49 | Proyectos piloto | topics → 5; delete |
| 56 | Tasas e impuestos | topics → 5, tags `administracion-avanzada` + `tasas`; delete |
| 68 | PID | topics → 5, tags `administracion-avanzada` + `pid`; delete |
| 69 | App Móvil | topics → 5, tags `administracion-avanzada` + `app-movil`; delete |
| 14 | Aula de formación | unchanged; absorbs 62, 67 and the 10 `expertos-espublico` topics → 99 topics |
| 62 | Trucazos *(child of 14)* | topics → **14**, tags `trucazo` + `administracion-avanzada`; delete |
| 67 | Webinars *(child of 14)* | topics → **14**, tag `webinars`; delete |
| 59 | Eventos certificación | rename → **Eventos**; stays top level; slug already `eventos` |
| 73 + 7 children | Recursos Certificación Analítica de datos | rename → **Recursos Analítica**; new slug. Children untouched |
| 85 | Recursos y proyectos compartidos | rename → **Comparte**; new slug; **absorbs 34 and 86** → 13 topics, no children |
| 86 | Proyectos 360 · Hackathon *(child of 85)* | topics → **85**, tag `hackathon-eivissa`; delete |
| 75 | DocDevelopers | rename → **Recursos Developers**; new slug. Stays top level at 2 topics |
| 71 | Un nuevo horizonte… | move its "Café con certificados" topic to **59** first, then archive: close, keep readable, remove from navigation |
| 3 | Administradores | **keep** (core `/tos`, `/privacy`, `/faq` live here); move the 10 `expertos-espublico` topics to **14 Aula de formación** — **9 of them are unlisted**, see Phase 4 — and "Ponencias II encuentro" to **59 Eventos**; delete the 2 test topics |

Deleted: 34, 62, 65, 66, 67, 86, 87, 58, 54, 57, 53, 50, 49, 56, 68, 69. Archived: 71.

### Slugs

Seven renames, and **six slugs** follow them. The original plan named two, before 73, 75
and 85 were renamed and before 78's slug was checked against its new name.

| ID | Name after rename | Slug today (PROD) | Slug target |
|---|---|---|---|
| 4 | Noticias | `te-contamos` ⚠️ | `noticias` |
| 5 | Expertos | `el-foro-del-certificado` ⚠️ | `expertos` |
| 78 | Primeros pasos | `nuevos-usuarios-certificados` | `primeros-pasos` |
| 73 | Recursos Analítica | `documentacion-analiza` | `recursos-analitica` |
| 75 | Recursos Developers | `doc-developers` | `recursos-developers` |
| 85 | Comparte | `recursos-y-proyectos-compartidos` | `comparte` |
| 59 | Eventos | `eventos` | *(already correct)* |
| 18 | *(name kept)* | `ideas-gestiona` | `tengo-una-idea` — **optional**, pre-existing debt |

⚠️ **PRE starts from a different slug on exactly these two**: 4 is `comunidad-expertos` and
5 is `grupos-de-trabajo`. Of the 27 slugs that the 2026-08-11 PRE capture records and PROD
also has, **25 are identical and these 2 differ**. The seven children of 73 were never
slug-captured on PRE, so they remain uncompared — they are also untouched by this plan.
Every target in the table above is the same on both instances.

*This is PROD read live on 2026-08-26 against the PRE capture of 2026-08-11, not two live
reads: there is no PRE API key on this machine. Re-check the two ⚠️ rows in the PRE admin
before renaming.*

The seven new targets were checked against the 34 slugs in use: none collides. `comparte` is
free — the near misses are `comparte-conocimiento` (34, deleted here) and
`comparte-tu-conocimiento-analiza` (83, which stays).

Changing a slug does not break existing links: Discourse puts the ID in the path
(`/c/<slug>/<id>`) and redirects a stale slug to the canonical one. Only hand-written links
that omit the ID break.

## Tag model

Three axes, replacing what subcategories were doing badly.

| Group | Constraint | Tags |
|---|---|---|
| **programa** | **required, max 1**, on Expertos | `administracion-avanzada` ← synonym `caag` · `developers` · `analiza` |
| **dominio** | optional, multiple | `pid` · `tasas` ← synonym `gestión-tributaria` · `app-movil` ← synonym `app` · `expedientes` · `registro` · `padrón` · `firma` · `tramitación-reglada` · `tesauro` · `markdown` … |
| **contexto** | per category | `alumno-certificado` ← synonym `posters` · *(new poster-resource tag)* · `campana-2024` / `campana-febrero-2025` / `campana-v9` · `cafe-con-certificados` · `newsletter` · `blog-gestiona` *(Noticias)* · `trucazo` *(Aula de formación)* · `webinars` ← synonyms `seminarios`, `webinar` *(Aula de formación)* · `hackathon-eivissa` *(Comparte)* · `expertos-espublico` · `mejoras` |

**Discourse tag synonyms migrate every existing use automatically**, so adopting
`administracion-avanzada` keeps `caag`'s 40 taggings rather than discarding them.

### Why tags rather than subcategories

The maintainer's decision, and the data supports it three ways:

1. **Permissions are per-category and the three programmes may see each other.** With no
   confidentiality boundary between them, subcategories would buy nothing and cost three
   permission sets to maintain against 59 groups.
2. **A tag crosses categories; a subcategory cannot.** A póster topic has two lives — an
   arrival announcement in Primeros pasos and a reusable resource for the library. One
   category can only place it once. A tag places it in both, without moving it.
3. **A tag survives reorganisation.** A lane keyed on a category empties silently when
   topics move; a lane keyed on a tag does not, because the topic carries the tag with it.

### The poster-resource tag

`posters` is unusable as a classifier and is retired into `alumno-certificado`. A fresh tag
is minted for genuine pósters and applied to the ~17 portrait-image topics. Minting fresh
rather than stripping `posters` from ~130 topics is deliberate: **everything carrying the
new tag is there by decision, and the result is auditable.** Stripping leaves no way to tell
a missed póster from a correctly-cleaned non-póster.

## Impact on the theme

> **Shipped 2026-08-26** in PRs #31 and #32, `theme_version` 0.18.1, 57 tests green. This
> section is a record of what was built, not a plan. The one item deferred is noted under
> *Code* below.

### Settings

| Setting | Change |
|---|---|
| `news_category_id` | **removed** — the lane becomes site-wide `latest` |
| `forum_category_id` | unchanged (5) |
| `ideas_category_id`, `ideas_count` | **added** — the new "Tengo una idea" lane |
| `showcase_category_id` | unchanged (78), but the lane gains a tag filter |
| `events_category_id` | unchanged (59) |
| `library_category_ids` | unchanged (`73\|85\|14`) |

One setting removed, two added, none modified — because every category that anchors a lane
is renamed or reparented, never recreated.

Dissolving 65 and 66 costs the theme nothing: no setting, initializer or block references
either ID, and the news lane stops being category-keyed in the same pass.

### Code

1. **`loadCategoryTopics` learns to filter by tag.** Required so the showcase lane can serve
   only the póster subset of Primeros pasos once that category also holds welcome content.
2. **The news lane switches to `latest`.** `block-news.gjs` drops `categoryId`.
3. **A sixth lane for "Tengo una idea."** No new component: `BlockForum` is fully
   parameterised (`title`, `linkText`, `linkUrl`, `categoryId`, `count`) and its shape — a
   topic list with reply counts promoted — is exactly right for a category at 3.6
   replies/topic. A second instance goes into the `home-main` group after the forum lane,
   with two new settings and four new locale strings. No new SCSS.

   Its icon is the one thing `BlockForum` hardcodes (`far-comments`). Either promote the
   icon to an arg and add `lightbulb` to `svg_icons` in `about.json`, or accept both lanes
   sharing an icon.

All three need tests; the existing 47 stay green or are updated alongside.

**As built:** all three landed, the icon was promoted to an arg and `lightbulb` added to
`svg_icons`, and `BlockForum` also gained `emptyText` so each lane says something different
when empty (#32). Tests went 47 → 57. **The tag filter is implemented but not wired to the
showcase lane** — that is Phase 6, and it waits on the poster-resource tag existing. Nothing
verifies the `lightbulb` glyph: `dIcon` writes the class whether or not the sprite carries
the symbol, so a missing entry renders an empty box with every test green.

### Homepage consequences

- **The forum lane drops from 570 topics to 293** when "Tengo una idea" is promoted out of
  Expertos, and stays pointed at category 5 alone. It does *not* also point at 18: with 18
  carrying its own lane, that would print the same 318 topics twice on one page.
  *(The estimate here read ~297 until 2026-08-26; the measured figure is 252 + 15 + 1 + 20 +
  4 + 1 = 293, the absorbed categories' definition topics having been counted by mistake.)*
- **The news lane stops being 57% Pósters.** Today category 4's listing includes 78's 164
  topics, so most of what "Novedades" shows is arrival announcements. Promoting 78 fixes it.
- **`latest` will repeat topics** that also appear in the Events and Primeros pasos lanes.
  Default taken: **accept the overlap**, on the grounds that a "latest" list which silently
  hides categories is more surprising than one that repeats. Reversible.

## Migration plan

Ordered so that nothing is destroyed before its content is safe, and so the free operations
land first.

**Phase 1 — free, reversible, no content moves.** Seven renames (4, 5, 78, 59, 73, 75, 85),
the six slugs that follow them, and the two promotions (78 and 18 to top level). IDs survive
all of it, so no setting changes, no code changes and no lane can break. Verify the six lanes
still render.

**Phase 2 — tag vocabulary.** Create the `programa` and `dominio` tag groups. Declare the
synonyms (`caag`, `posters`, `gestión-tributaria`, `app`). Set `programa` required with
max 1 on Expertos. No topics move.

**Phase 3 — bulk tagging, per source category, before anything is deleted.** Using the topic
list's *select all → append tags*, so each category is a few operations rather than one per
topic:

| Source | Topics | Tags to append |
|---|---:|---|
| 5 Expertos | 252 | `administracion-avanzada` |
| 18 Tengo una idea | 318 | `administracion-avanzada` |
| 50 Analiza | 15 | `analiza` |
| 56 Tasas | 20 | `administracion-avanzada`, `tasas` |
| 68 PID | 4 | `administracion-avanzada`, `pid` |
| 69 App Móvil | 1 | `administracion-avanzada`, `app-movil` |
| 57 / 58 / 54 | 20 / 102 / 1 | `campana-2024` / `campana-febrero-2025` / `campana-v9` |
| 87 Café | 6 | `cafe-con-certificados` |
| 65 Newsletter | 27 | `newsletter` — **already on 20 of 28**, 8 to append |
| 66 Blog Gestiona | 9 | `blog-gestiona` |
| 62 Trucazos | 15 | `administracion-avanzada` — `trucazo` **already on 13** |
| 67 Webinars | 50 | none: `seminarios` (46) and `webinar` (10) migrate as synonyms of `webinars`; 2 untagged to fix by hand |
| 86 Hackathon | 8 | `hackathon-eivissa` — **none of the 8 carries any tag today** |
| 34 Recursos compartidos | 5 | none: all five are already tagged by subject |

**Phase 4 — move topics**, now that every topic carries the tag that says where it came
from. Then delete the emptied categories: 34, 62, 65, 66, 67, 86, 87, 58, 54, 57, 53, 50, 49, 56, 68, 69.

Three moves out of category 3 need no tagging first, because their tags are already in place:
the 10 `expertos-espublico` topics go to **14 Aula de formación**, "Ponencias II encuentro"
(tagged `evento`) goes to **59 Eventos**, and the two test topics are deleted. The four
Discourse-generated documents stay where they are.

> **Nine of those ten topics are unlisted** — the talks numbered 01 to 09. Only the index
> topic *"Charlas expertos grupo esPublico"* is listed. **The category listing's
> *select all → move* does not see them**, so a bulk move silently leaves nine topics behind
> in a category that keeps existing, which is the quiet failure this whole plan is built to
> avoid. Reach them with a `status:unlisted` search or move them one by one, and confirm
> category 3 is down to its four Discourse documents afterwards.
>
> Measured on 2026-08-26 across all 18 categories that lose topics: **category 3 is the only
> one with unlisted content.** The other 17 return exactly `topic_count` + 1 definition
> topic, so a bulk move is safe everywhere else.

**Phase 5 — theme changes. ✅ Done 2026-08-26**, out of order and deliberately: it depends on
no category ID surviving anything, and Phases 1 and 2 cannot break it. Tag filtering in
`loadCategoryTopics`, news lane to `latest`, `news_category_id` removed, `ideas_*` added,
57 tests, `theme_version` 0.18.1.

**Phase 6 — pósters.** Review the 34 image-bearing topics in Primeros pasos, apply the
poster-resource tag to the genuine ones, and point the showcase lane at that tag.

**PRE goes first, then PROD.** Decided 2026-08-25. Every phase runs end to end on PRE and
is checked there before the same sequence is repeated on PROD.

The two taxonomies were verified identical on 2026-08-25 — 34 IDs matching exactly, the only
difference being category 1 "Sin categoría", which exists on PRE and not on PROD — so PRE is
a faithful rehearsal, which is what Phases 3 and 4 need: bulk tagging and topic moves are
the operations that cannot be undone once the source category is deleted.

The price is accepted. PRE is the only instance with the theme installed and has no fallback
theme, so its homepage lanes break the moment their categories move, and anyone using PRE
sees it. That is a rehearsal cost, not a defect: PROD carries the real members and has no
theme installed yet, so the reorganisation there has no homepage consequence at all until
the theme ships.

## Risks

- **Phases 3 and 4 are not reversible by an undo.** Bulk tagging is cheap to correct; moving
  topics between categories is not, once the source is deleted. Phase 4 deletes nothing until
  its topics are tagged and moved.
- **Category 3 must not be deleted or over-restricted.** `/tos`, `/privacy` and `/faq` read
  from topics inside it.
- **Widening read access on the 27 newsletters is not cheaply undone.** Once 65 is deleted
  its ID is gone; restoring the restriction would mean creating a new category and moving
  the topics back, which is the create-and-move that this whole plan avoids. Confirm the
  newsletters hold nothing group-confidential before Phase 4 runs.
- **Category listings and the topic view are unguarded by CI** (`skip_examples` takes
  `topics:read` and `topics:reply`). The maintainer's eyes on PRE remain the only check on
  the surfaces this touches.
- **The reorganisation invalidates the taxonomy table in `CLAUDE.local.md`.** Re-capture it
  after Phase 4 rather than patching it.
- **Nine unlisted topics in category 3 will be missed by a bulk move.** See Phase 4. It is
  the only category in the plan where the listing does not show everything that must move.
- **The library lane's rationale no longer covers category 85.** The lane renders directory
  cards rather than topic lists because "these categories are repositories, not forums —
  category 73's whole tree has never received a single reply". Measured on 2026-08-26, the
  85 that this plan builds has **20 replies across 13 topics**, 4 of them conversational:
  the five how-tos arriving from 34 carry 5 replies each, the eight Hackathon deliverables
  carry none. Renaming it to the imperative *Comparte* makes the mismatch visible rather
  than causing it. **Deferred to Phase 6 by decision**, not overlooked — reshaping the lane
  is theme work with tests, and Phase 5 is shipped and green.

## Decisions taken

All resolved with the maintainer on 2026-08-25:

1. **Category 18 keeps the name "Tengo una idea."** It is what members already know, and it
   spares a rename. A working title of "Ideation" was dropped — it would have been the only
   English word in the taxonomy of a Spanish public-administration community.
2. **It gets its own homepage lane**, becoming the largest category at 440 topics.
3. **The forum lane therefore stays on category 5 alone**, so nothing is printed twice.
4. **Category 73 keeps its seven subcategories.** Collapsing them was offered at 7→3 and 7→2
   and declined. See the residual note below.
5. **75 stays top-level** at 2 topics: the Developers programme is still being
   built, and the category is there to receive it. *(Renamed on 2026-08-26 — see 12.)*
6. **"Ponencias II encuentro de expertos" goes to Eventos**; the ten `expertos-espublico`
   topics go to Aula de formación.
7. **Newsletter (65) and Blog Gestiona (66) become tags of Noticias**, leaving category 4
   with no children. 66 is already unrestricted, so it moves without consequence. 65 is
   read-restricted and 4 is not, so its 27 topics become readable by everyone who can read
   Noticias — **a deliberate widening, accepted by the maintainer on 2026-08-25.** It is
   the only permission change in the plan; every other dissolution moves restricted topics
   into restricted categories, and 87 moves *from* unrestricted *to* restricted.
8. **Recursos compartidos (34) dissolves into 85**, leaving Expertos with no children. A
   promotion to top level was decided first and reversed: it would have put *Recursos
   compartidos* beside *Recursos y proyectos compartidos*, two top-level names differing by
   two words.
9. **Trucazos (62) becomes a tag on Aula de formación**, staying in the category it already
   hangs off. It keeps `administracion-avanzada` as a programme marker, but *optionally*:
   `programa` is required only on Expertos, so nothing on these 15 topics is forced.
10. **Webinars (67) becomes a tag on Aula de formación**, canonical `webinars`, with
   `seminarios` and `webinar` as synonyms so no tagging is lost.
11. **Hackathon (86) dissolves into 85 too**, tagged `hackathon-eivissa`. 85 stops being an
   empty wrapper and becomes a real category of 13 topics with no children: five
   member-contributed how-tos from 34 and eight Hackathon deliverables. All three
   categories are read-restricted, so nothing changes about who sees what.

Taken on 2026-08-26, while turning the plan into an execution list:

12. **73 and 75 become "Recursos Analítica" and "Recursos Developers."** They are the same
   kind of thing — the resource shelf of one certification programme — and had names from
   two different eras (`DocDevelopers` was never a display name so much as a leftover).
   "Certificación" is dropped from both: see the note under *Target taxonomy*.
13. **85 becomes "Comparte."** Considered and rejected: *Proyectos compartidos* (loses the
   materials that are not projects), *Banco de proyectos* (reads as storage, not
   invitation), *Hecho por la comunidad* (accurate but long). The single imperative was
   chosen for what it asks of the reader. It leaves the "Recursos" family deliberately,
   which is the point — 73 and 75 are what esPublico publishes, 85 is what members
   contribute, and after the 75 rename a third "Recursos …" at top level would have
   recreated exactly the collision decision 8 avoided.
14. **The two member-voice names are the two categories where members write.** "Tengo una
   idea" and "Comparte" are the only imperative or first-person names in the taxonomy, and
   they are precisely the surfaces whose purpose is contribution rather than reading. Not
   designed for; observed afterwards and kept.

**Left open:** *Comparte* (85, top level) echoes *Comparte tu conocimiento: Analiza* (83, a
child of 73). The `: Analiza` suffix and the tree position disambiguate, so this is not
treated as blocking. If it proves confusing, renaming 83 is free in Phase 1 — no ID, no
setting, no code.

### Residual, recorded so it is a decision and not an oversight

**Category 73 holds 66 topics across seven subcategories** of 4, 23, 23, 1, 2, 3 and 10
topics, with zero replies between them in their whole history. Its content is three kinds:
a cookbook (79 + 80, 27 topics), training material (81 + 88 + 84, 36 topics) and member
contributions (82 + 83, 3 topics). Three of the seven hold one, two and three topics.
Collapsing it is independent of everything in this document and can be revisited at any
time without touching a lane, a setting or a line of code. **Re-offered on 2026-08-25 once
every other branch had been flattened, and declined again**, so 73 is a settled decision
and the deliberate exception to a flat tree — not an oversight.

Two residuals recorded earlier are **resolved** by decisions 8 and 11: the three top-level
names starting with "Recursos" (34 no longer becomes one) and category 85 owning no topics
(it now owns 13). The "Recursos" question reopened on 2026-08-26 when 75 was renamed into
the family and closed again by decision 13, which moved 85 out of it: the prefix now marks
exactly one thing, a programme's resource shelf, and there are two of them.

That family covers two of the three `programa` values. The third,
`administracion-avanzada`, has no "Recursos …" of its own — its material lives in **Aula de
formación**, which at 99 topics of webinars, trucazos and course sessions is a good deal
more than a shelf. The asymmetry is deliberate.

What remains is that 85 mixes two kinds of content — how-tos that draw replies and Hackathon
deliverables that draw none — separated only by `hackathon-eivissa`. Now measured: 20 replies
against 0. See the library-lane risk above, which is the same fact seen from the theme.

## Amendments

**2026-08-26.** Everything below was decided or measured after the document was merged in
PR #30, and is folded into the sections above rather than appended:

| # | Change | Where |
|---|---|---|
| 1 | 73 → **Recursos Analítica**, 75 → **Recursos Developers**, 85 → **Comparte** | *Target taxonomy*, decisions 12–13 |
| 2 | **Six slugs**, not two; all checked for collisions | *Slugs* |
| 3 | PRE and PROD differ on **exactly two** slugs (4, 5); the other 25 match | *Slugs* |
| 4 | **9 unlisted topics in category 3** that a bulk move would miss; the only such category | *Phase 4*, *Risks* |
| 5 | `topic_count` excludes unlisted topics; listings need the **slug-form endpoint** | *A measurement trap* |
| 6 | Forum lane lands at **293** topics, not ~297 | *Homepage consequences* |
| 7 | Category 85 has **20 replies over 13 topics**, breaking the library lane's premise | *Risks* |
| 8 | Phase 5 **shipped**; Phase 6 still owns the showcase tag filter and the `lightbulb` check | *Impact on the theme*, *Migration plan* |

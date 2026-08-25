# Category reorganisation — design

**Date:** 2026-08-25
**Status:** proposed, pending maintainer review
**Scope:** the Gestiona Avanza taxonomy on PROD (`gestionaavanza.espublico.com`) and the
theme settings and code that depend on it.

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

### A measurement trap worth recording

A category's `latest` listing **includes its subcategories' topics**, and the category
definition topic is pinned to the top. Reading activity from the first row of that listing
therefore reports the definition topic's age, and reading topic counts from it double-counts
children. This produced four wrong readings before it was caught: 78 read as 4 months idle
when it was 5 days; 62 Trucazos read as 17 months dead when it is 19 days alive; categories
53 and 49 appeared to hold topics that belong to their children. **Measure with the
definition topic excluded and `topic_count` taken from `categories.json`, never from a
listing.**

## Target taxonomy

**34 categories → 23 active. 10 visible top-level → 9.** No new category IDs.

| Top level | ID | Children |
|---|---|---|
| **Noticias** | 4 *(renamed)* | Newsletter (65), Blog Gestiona (66) |
| **Primeros pasos** | 78 *(renamed, promoted)* | — |
| **Expertos** | 5 *(renamed)* | Recursos compartidos (34) |
| **Ideation** | 18 *(renamed, promoted)* | — |
| **Aula de formación** | 14 | Trucazos (62), Webinars (67) |
| **Eventos** | 59 *(renamed)* | — |
| **Recursos Certificación Analítica** | 73 | its 7 existing children |
| **Recursos y proyectos compartidos** | 85 | Hackathon (86) |
| **DocDevelopers** | 75 | — |
| *(staff)* Administradores | 3 | — |

### Every category, and what happens to it

| ID | Today | Action |
|---|---|---|
| 4 | Te contamos… | rename → **Noticias**; repair slug `comunidad-expertos` |
| 65, 66 | Newsletter, Blog Gestiona | unchanged |
| 78 | …· Pósters *(child of 4)* | rename → **Primeros pasos**, promote to top level |
| 87 | Café con certificados *(child of 4)* | topics → 59, tag `cafe-con-certificados`; delete |
| 5 | El foro del Certificado | rename → **Expertos**; repair slug `grupos-de-trabajo` |
| 34 | Recursos compartidos | unchanged |
| 18 | Tengo una idea *(child of 5)* | rename → **Ideation**, promote to top level |
| 58 | Campaña ideas febrero 2025 | topics → 18, tag `campana-febrero-2025`; delete |
| 54 | Campaña Gestiona V9 | topics → 18, tag `campana-v9`; delete |
| 57 | Campañas de ideas *(child of 53)* | topics → 18, tag `campana-2024`; delete |
| 53 | Moderadores | delete — **zero own topics** |
| 50 | Analiza | topics → 5, tag `analiza`; delete |
| 49 | Proyectos piloto | topics → 5; delete |
| 56 | Tasas e impuestos | topics → 5, tags `administracion-avanzada` + `tasas`; delete |
| 68 | PID | topics → 5, tags `administracion-avanzada` + `pid`; delete |
| 69 | App Móvil | topics → 5, tags `administracion-avanzada` + `app-movil`; delete |
| 14, 62, 67 | Aula, Trucazos, Webinars | unchanged — **62 is alive (19 days), not a ghost** |
| 59 | Eventos certificación | rename → **Eventos**; stays top level |
| 73 + 7 children | Recursos Cert. Analítica | unchanged |
| 85, 86 | Recursos y proyectos compartidos | unchanged |
| 75 | DocDevelopers | unchanged |
| 71 | Un nuevo horizonte… | archive: close, keep readable, remove from navigation |
| 3 | Administradores | **keep** (core `/tos`, `/privacy`, `/faq` live here); move the 10 `expertos-espublico` topics to **14 Aula de formación** and "Ponencias II encuentro" to **59 Eventos**; delete the 2 test topics |

Deleted: 87, 58, 54, 57, 53, 50, 49, 56, 68, 69. Archived: 71.

## Tag model

Three axes, replacing what subcategories were doing badly.

| Group | Constraint | Tags |
|---|---|---|
| **programa** | **required, max 1**, on Expertos | `administracion-avanzada` ← synonym `caag` · `developers` · `analiza` |
| **dominio** | optional, multiple | `pid` · `tasas` ← synonym `gestión-tributaria` · `app-movil` ← synonym `app` · `expedientes` · `registro` · `padrón` · `firma` · `tramitación-reglada` · `tesauro` · `markdown` … |
| **contexto** | per category | `alumno-certificado` ← synonym `posters` · *(new poster-resource tag)* · `campana-2024` / `campana-febrero-2025` / `campana-v9` · `cafe-con-certificados` · `expertos-espublico` *(Aula de formación)* · `mejoras` |

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

### Settings

| Setting | Change |
|---|---|
| `news_category_id` | **removed** — the lane becomes site-wide `latest` |
| `forum_category_id` | unchanged (5) |
| `showcase_category_id` | unchanged (78), but the lane gains a tag filter |
| `events_category_id` | unchanged (59) |
| `library_category_ids` | unchanged (`73\|85\|14`) |

One setting removed, none modified — because every category that anchors a lane is renamed
or reparented, never recreated.

### Code

1. **`loadCategoryTopics` learns to filter by tag.** Required so the showcase lane can serve
   only the póster subset of Primeros pasos once that category also holds welcome content.
2. **The news lane switches to `latest`.** `block-news.gjs` drops `categoryId`.

Both changes need tests; the existing 47 stay green or are updated alongside.

### Homepage consequences

- **The forum lane drops from 570 topics to ~297** when Ideation is promoted out of
  Expertos. Still substantial. Whether the lane should also point at 18 is an open decision.
- **The news lane stops being 57% Pósters.** Today category 4's listing includes 78's 164
  topics, so most of what "Novedades" shows is arrival announcements. Promoting 78 fixes it.
- **`latest` will repeat topics** that also appear in the Events and Primeros pasos lanes.
  Default taken: **accept the overlap**, on the grounds that a "latest" list which silently
  hides categories is more surprising than one that repeats. Reversible.

## Migration plan

Ordered so that nothing is destroyed before its content is safe, and so the free operations
land first.

**Phase 1 — free, reversible, no content moves.** Renames, slug repairs, and the two
promotions (78 and 18 to top level). IDs survive all of it, so no setting changes and no
lane can break. Verify the five lanes still render.

**Phase 2 — tag vocabulary.** Create the `programa` and `dominio` tag groups. Declare the
synonyms (`caag`, `posters`, `gestión-tributaria`, `app`). Set `programa` required with
max 1 on Expertos. No topics move.

**Phase 3 — bulk tagging, per source category, before anything is deleted.** Using the topic
list's *select all → append tags*, so each category is a few operations rather than one per
topic:

| Source | Topics | Tags to append |
|---|---:|---|
| 5 Expertos | 252 | `administracion-avanzada` |
| 18 Ideation | 318 | `administracion-avanzada` |
| 50 Analiza | 15 | `analiza` |
| 56 Tasas | 20 | `administracion-avanzada`, `tasas` |
| 68 PID | 4 | `administracion-avanzada`, `pid` |
| 69 App Móvil | 1 | `administracion-avanzada`, `app-movil` |
| 57 / 58 / 54 | 20 / 102 / 1 | `campana-2024` / `campana-febrero-2025` / `campana-v9` |
| 87 Café | 6 | `cafe-con-certificados` |

**Phase 4 — move topics**, now that every topic carries the tag that says where it came
from. Then delete the emptied categories: 87, 58, 54, 57, 53, 50, 49, 56, 68, 69.

Three moves out of category 3 need no tagging first, because their tags are already in place:
the 10 `expertos-espublico` topics go to **14 Aula de formación**, "Ponencias II encuentro"
(tagged `evento`) goes to **59 Eventos**, and the two test topics are deleted. The four
Discourse-generated documents stay where they are.

**Phase 5 — theme changes.** Tag filtering in `loadCategoryTopics`, news lane to `latest`,
remove `news_category_id`, update tests, bump `theme_version` (minor).

**Phase 6 — pósters.** Review the 34 image-bearing topics in Primeros pasos, apply the
poster-resource tag to the genuine ones, and point the showcase lane at that tag.

**PRE mirrors PROD afterwards.** The two taxonomies were verified identical on 2026-08-25 —
34 IDs matching exactly, the only difference being category 1 "Sin categoría", which exists
on PRE and not on PROD.

## Risks

- **Phases 3 and 4 are not reversible by an undo.** Bulk tagging is cheap to correct; moving
  topics between categories is not, once the source is deleted. Phase 4 deletes nothing until
  its topics are tagged and moved.
- **Category 3 must not be deleted or over-restricted.** `/tos`, `/privacy` and `/faq` read
  from topics inside it.
- **Category listings and the topic view are unguarded by CI** (`skip_examples` takes
  `topics:read` and `topics:reply`). The maintainer's eyes on PRE remain the only check on
  the surfaces this touches.
- **The reorganisation invalidates the taxonomy table in `CLAUDE.local.md`.** Re-capture it
  after Phase 4 rather than patching it.

## Open decisions

1. **"Ideation" is the only English word in the taxonomy**, in a Spanish public-administration
   community. *Ideas*, *Ideación* or *Propuestas* would sit better. Cosmetic; changes nothing else.
2. **Should the forum lane also point at Ideation (18)?** It loses 318 topics otherwise.
3. **Should Ideation get its own homepage lane?** It becomes the largest category at 440 topics.
4. **Category 73 keeps 7 subcategories for 66 topics** — of 1, 2, 3, 4, 10, 23 and 23 topics
   each, with zero replies between them. Collapsing them is independent of everything above
   and can be done later.
5. **75 DocDevelopers is a top-level category with 2 topics.**

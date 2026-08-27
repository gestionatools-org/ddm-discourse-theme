# Category reorganisation — design

**Date:** 2026-08-25
**Amended:** 2026-08-26 — renames, slugs, and everything learned while executing Phases 1
and 2. **2026-08-27 — Phase 4 executed.** See *Amendments* at the foot of this document.
**Status:** agreed 2026-08-25. **All six phases done on PRE**, Phase 6 on 2026-08-27:
115 topics written, 0 failures, `posters` from 158 uses down to 61.
Phase 4 ran on 2026-08-27 and took the tree from 34 categories to **17**. It was the phase
that could not be undone, and in the event it **deleted no topic at all** — every candidate
for the bin ended up archived instead. PROD has had nothing applied to it yet.
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
  than pre-existing: after renaming to Noticias and Foro del certificado, correct slugs go stale.
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
- **Listings redirect; `show.json` does not.** `/c/<id>/l/latest.json` answers **301**, not
  an empty body as this document first recorded — the empty body was `curl` without `-L`
  reporting a redirect it had not been told to follow. With `-L` the ID-only form works for
  top-level categories *and* subcategories, which is the shape to use: the slug form needs
  the **full parent path** for a child (`/c/noticias/cafe-con-certificados/87/l/latest.json`),
  and `/c/cafe-con-certificados/87/l/latest.json` is itself just another 301. `show.json`
  stays ID-only and genuinely errors on the slug form. Corrected 2026-08-27 after the
  original reading cost a failed measurement pass.
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
| **Foro del certificado** | 5 *(renamed)* | — *(34 dissolved into 85)* |
| **Tengo una idea** | 18 *(promoted)* | — |
| **Aula de formación** | 14 | — *(62 and 67 become tags)* |
| **Eventos** | 59 *(renamed)* | — |
| **Recursos Analítica** | 73 *(renamed)* | its 7 existing children |
| **Recursos Developers** | 75 *(renamed)* | — |
| **Comparte** | 85 *(renamed, absorbs 34 and 86)* | — |
| *(staff)* Administradores | 3 | — |

The word "certificación" leaves four category names — 59, 73 and 78 are renamed and 87
dissolves into a tag — and stays in exactly one: **5 Foro del certificado**.

That is the rule working, not an exception to it. The original observation was that the whole
site *is* the certification programme, so the word discriminated nothing wherever it appeared.
It appeared in five names, which is precisely why it told a reader nothing. In one name it
does work: category 5 *is* the forum of the certification, and there the word names the
whole rather than distinguishing a part.

*(This note was amended twice on 2026-08-26 while category 5 changed name three times. It is
stated here as the settled version rather than patched again.)*

### Every category, and what happens to it

| ID | Today | Action |
|---|---|---|
| 4 | Te contamos… | rename → **Noticias**; new slug (see *Slugs*) |
| 65 | Newsletter *(child of 4)* | topics → 4, tag `newsletter`; delete — **widens read access**, accepted |
| 66 | Blog Gestiona *(child of 4)* | topics → 4, tag `blog-gestiona`; delete |
| 78 | …· Pósters *(child of 4)* | rename → **Primeros pasos**, promote to top level; new slug |
| 87 | Café con certificados *(child of 4)* | topics → 59, tag `cafe-con-certificados`; delete |
| 5 | El foro del Certificado | rename → **Foro del certificado**; new slug (see *Slugs*) |
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
| 5 | Foro del certificado | `el-foro-del-certificado` ⚠️ | `foro-del-certificado` |
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
| **`programa-certificacion`** | **max 1 per topic**; required on Foro del certificado *(deferred — see Phase 2)* | `administracion-avanzada` ← synonym `caag` · `developers` · `analiza` |
| **dominio** *(not created — optional)* | optional, multiple | `pid` · `tasas` ← synonym `gestión-tributaria` · `app-movil` ← synonyms `app`, `app-móvil` · `expedientes` · `registro` · `padrón` · `firma` · `tramitación-reglada` · `tesauro` ← synonym `tesauros` · `markdown` … |
| **contexto** | per category | `alumno-certificado` · **`posters`** ← synonym `póster` *(kept independent — see below)* · `campana-2024` / `campana-febrero-2025` / `campana-v9` · `cafe-con-certificados` · `newsletter` · `blog-gestiona` *(Noticias)* · `trucazo` *(Aula de formación)* · `webinars` ← synonyms `seminarios`, `webinar`, `seminario` *(Aula de formación)* · `hackathon-eivissa` *(Comparte)* · `expertos-espublico` · `mejoras` |

**Discourse tag synonyms migrate every existing use automatically**, so adopting
`administracion-avanzada` keeps `caag`'s 40 taggings rather than discarding them.

### Instance settings the tag model needs

Discovered on 2026-08-26, mid-Phase 2. **PRE was configured as if tags were a marginal
feature**, and the reorganisation makes them the primary structure. One of the settings was
a hard blocker on Phase 3.

| Setting | Was | Now | Why it mattered |
|---|---|---|---|
| `max_tags_per_topic` | **3** | 7 | **Blocked Phase 3.** Topics already carry 2–3 tags, so appending one more exceeded the cap on 28 of 157 topics scanned in category 5, 60 of 319 in category 18, and 4 of 16 in Trucazos — roughly a hundred topics a bulk *select all → append* could not have touched, failing partway rather than cleanly |
| `max_tag_length` | **20** | 30 | Truncated `administracion-avanzada` (23 chars) to `administracion-avanz` on entry, which is why the tag was briefly named `admin-avanzada`. `cafe-con-certificados` (21) would have been truncated in Phase 3 |
| `max_tags_in_filter_list` | **3** | 30 | A three-item filter list against a 218-tag vocabulary |
| `max_tag_search_results` | **3** | *(still 3)* | Only three suggestions while typing. With 218 tags this actively manufactures duplicates: someone typing "trami" is not shown `tramitación-reglada` and invents a new tag instead |

The last one is unchanged and is the likeliest single cause of the duplicate families below.

### Vocabulary hygiene

A normalised sweep of all 220 tags on 2026-08-26 — accents stripped, hyphens removed, crude
singular/plural folding — found **11 families of near-duplicates**. Four were merged during
Phase 2 (`app-móvil`, `seminario`, `póster`, `tesauros`). The rest are recorded rather than
fixed, because none of them touches a category being dissolved:

| Canonical | Variants still live | Uses adrift |
|---|---|---|
| `certificados` (50) | `certificado` (4) | 4 |
| `evento` (30) | `eventos` (1) | 1 |
| `búsquedas-avanzadas` (1) | `búsquedasavanzadas` (8) · `busquedasavanzadas` (7) | 15 |
| `trámites-externos` (5) | `tramitesexternos` (9) | 9 |
| `integraciones` (7) | `ìntegración` (1) — grave accent, a typo | 1 |
| `páginas-informativas` (3) | `paginasinformativas` (3) | 3 |
| `curso` (5) | `cursos` (1) | 1 |
| `temas-y-categorias` (2) | `temasycategorías` (1) | 1 |
| `contrato-menor` (1) | `contratomenor` (1) | 1 |

`búsquedas-avanzadas` is the shape of the problem: three spellings of one idea, 16 uses
between them, and the correctly formed one has a single use. **Canonical is chosen by the
name worth reading, not by the count** — the same call made for `tasas` (5, absorbing 10) and
`webinars` (1, absorbing 62).

### Permissions are neutral, and `read_restricted` is largely decorative

Measured category by category on 2026-08-26, on PRE, with an admin key. **All fifteen
dissolutions in this plan move topics between categories with the same effective audience.**
Nobody gains or loses access to anything.

| Source → destination | Delta |
|---|---|
| 65 → 4 · 66 → 4 | none — both open |
| 34 → 85 · 86 → 85 · 62 → 14 · 67 → 14 | none — both restricted |
| 58 / 54 / 57 → 18 · 50 / 49 / 56 / 68 / 69 → 5 | none — both restricted |
| 87 → 59 | nominally closes; see below |

The reason is that "restricted" here does not mean what it looks like. Category 65 was
limited to `Certificación`, `esPublico` and `moderadores`; **`Certificación` has 375 members
and the site has 373 registered users.** The group *is* the community. The same holds for the
one apparent narrowing: 87's six Café topics move into 59 Eventos, which is restricted — to
`Certificación` among others, so the same people again.

The site is `login_required` (anonymous `/categories.json` returns 403), so "open" never
meant the public internet either. It means any member with a session.

**This confirms a premise the plan asserted without measuring.** The argument for tags over
subcategories opened with "permissions are per-category and the three programmes may see each
other… with no confidentiality boundary between them, subcategories would buy nothing". That
was a reasonable assumption in August. It is now a measurement.

What survives is narrow: a **future** member not added to `Certificación` would not see
anything restricted to it. That is membership administration, not taxonomy.

**Standing decision, 2026-08-26:** the reorganisation runs **without permission work**.
Group-based restrictions may be configured later, deliberately, on a taxonomy that is already
flat and tagged — not woven into the reorganisation.

### Standing decision: subcategories only in documentation categories

Agreed 2026-08-26, and it outlives this reorganisation.

**Conversational surfaces are flat.** Noticias, Primeros pasos, Foro del certificado, Tengo
una idea, Aula de formación, Eventos, Comparte — none of them takes children, now or later.
Whatever a subcategory would have expressed there is a tag: `programa-certificacion` for the
programme axis, `dominio` for subject, `contexto` for provenance.

**Documentation categories may keep them.** Recursos Analítica (73) and Recursos Developers
(75) are repositories, and subcategories there are a table of contents rather than a
structure competing with tags.

The distinction is measurable rather than aesthetic: **73's seven children hold 66 topics and
have never received a single reply.** There is no conversation for a subcategory to fragment,
and no permission boundary for it to imply — see *Permissions are neutral*. Where topics do
draw replies, splitting them across children buries the two largest surfaces on the site,
which is fault 1 in *Why*.

This retires the residual below. **73 is not an exception to a flat tree; it is the rule
applied to a documentation category.** And 75, which has 2 topics today and exists to receive
the Developers programme, may take children on the same grounds when it has material to
organise.

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

### The poster tag — `posters` is kept and cleaned, not retired

**Reversed on 2026-08-26**, during Phase 2. The original decision retired `posters` into
`alumno-certificado` and minted a fresh tag for genuine pósters, on the grounds that
stripping leaves no way to tell a missed póster from a correctly-cleaned non-póster.

The maintainer's objection: pósters and arrival announcements are becoming two different
kinds of post, so they deserve two tags — and `posters` is the right word for one of them.
That is what the original plan wanted too; it only declined to reuse the name.

The auditability argument does not survive a **full** sweep. Stripping *incrementally* is
what leaves ambiguity. Removing the tag from all 158 topics in one operation and then
applying it deliberately to the ~17 genuine pósters produces exactly the same guarantee as a
fresh tag — everything carrying it is there by decision — while keeping a word the community
has used 158 times.

So `posters` stays independent and Phase 6 cleans it. It absorbed `póster` (2 uses) in
Phase 2 and stands at **158**.

**One prerequisite, measured 2026-08-26 and easy to miss:** of the 156 topics that carried
`posters` before that merge, **153 also carry `alumno-certificado` and 3 do not**. Sweeping
`posters` without adding `alumno-certificado` to those 3 first leaves them with no
classification at all.

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
when empty (#32). Tests went 47 → 57. **The tag filter reached the lane in Phase 6**, as a
`showcase_tag` setting defaulting to `posters` — see the worksheet for why the tag and the
image requirement are not redundant. Nothing
verifies the `lightbulb` glyph: `dIcon` writes the class whether or not the sprite carries
the symbol, so a missing entry renders an empty box with every test green.

### Homepage consequences

- **The forum lane drops from 570 topics to 293** when "Tengo una idea" is promoted out of
  Foro del certificado, and stays pointed at category 5 alone. It does *not* also point at 18: with 18
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

**Phase 2 — tag vocabulary. ✅ Done 2026-08-26.** As executed, which differs from the plan
in four ways worth keeping.

The tag group is **`programa-certificacion`**, holding `administracion-avanzada` (15),
`analiza` (69) and `developers` (15), max 1 per topic, permissions unrestricted, no parent
tag. **`dominio` was not created** — it carries no constraint, so it buys grouping in the tag
picker and nothing else; the decision was to skip it rather than maintain it.

> **The group was first called `Certificaciones` and renamed on 2026-08-26.** There is a
> *user* group called `Certificación` with 375 members, and a *tag* group called
> `Certificaciones` one letter away from it. Three different things in this project answer to
> "group" — user groups (59), tag groups (1) and categories (34) — and the two that shared a
> name were the two that had nothing to do with each other. `programa-certificacion` restores
> the axis name this document used from the start. Renaming a tag group touches no tag and no
> topic.

**`programa` required on Foro del certificado is deliberately deferred to after Phase 3.**
Its 252 topics carry no programme tag yet, so requiring one now blocks anyone editing an
existing topic until they add it, for the whole window between the two phases. After the bulk
tagging the rule is satisfied from the first moment.

Five synonym merges, taking the vocabulary from 226 tags to 218:

| Canonical | Absorbed | Result |
|---|---|---|
| `administracion-avanzada` | `caag` | 15 |
| `tasas` | `gestión-tributaria` | 13 *(2 topics carried both)* |
| `app-movil` | `app`, **`app-móvil`** | 5 |
| `webinars` | `seminarios`, `webinar`, **`seminario`** | 54 |
| `posters` | **`póster`** | 158 |
| `tesauro` | **`tesauros`** | 81 *(1 overlap)* |

**Three of those the plan did not know about** — `app-móvil`, `seminario`, `póster` — because
it named canonical forms and the live vocabulary carries accent and singular/plural variants
of them. A sweep of all 220 tags found **11 such families**; four were merged here, and the
rest are recorded under *Vocabulary hygiene* below.

Merges are unions, not sums: overlapping topics count once. That is why `tasas` lands on 13
rather than 15, and it is the signal that the merge worked rather than that anything was
lost.

**Phase 3 — bulk tagging, per source category, before anything is deleted.** Using the topic
list's *select all → append tags*, so each category is a few operations rather than one per
topic:

> **Two tables follow.** The first is PRE as measured on 2026-08-26 and is what to execute
> against; the second is the original PROD-derived plan, kept because PROD's turn comes later.
>
> Check `max_tags_per_topic` before starting: it was 3 on PRE and had to be raised to 7. See
> *Instance settings*.

#### PRE, measured 2026-08-26

| ID | Category | Topics | Tags to append | Still missing |
|---|---|---:|---|---:|
| 18 | Tengo una idea | 318 | `administracion-avanzada` | 318 |
| 5 | Foro del certificado | **196** | `administracion-avanzada` | 196 |
| 58 | Campaña ideas febrero 2025 | 102 | `campana-febrero-2025` | 102 |
| 57 | Campañas de ideas | 20 | `campana-2024` | 20 |
| 56 | Tasas e impuestos | 20 | `administracion-avanzada` · `tasas` | 20 · 16 |
| 50 | Analiza | 15 | `analiza` | 15 |
| 62 | Trucazos | 15 | `administracion-avanzada` · `trucazo` | 15 · **1** |
| 86 | Hackathon | 8 | `hackathon-eivissa` | 8 |
| 65 | Newsletter | 27 | `newsletter` | **7** |
| 87 | Café con certificados | 6 | `cafe-con-certificados` | 6 |
| 68 | PID | 4 | `administracion-avanzada` · `pid` | 4 · 2 |
| 67 | Webinars | 50 | `webinars` | **2, by hand** |
| 69 | App Móvil | 1 | `administracion-avanzada` · `app-movil` | 1 · 1 |
| 54 | Campaña Gestiona V9 | 1 | `campana-v9` | 1 |
| 66 | Blog Gestiona | 9 | `blog-gestiona` | **0 — already done** |
| 34 | Recursos compartidos | 5 | — | 0 |

Fourteen bulk operations and two hand fixes. The first three rows are 616 of roughly 740
taggings.

Four differences from the PROD plan below, all measured:

- **Category 5 holds 196 topics on PRE, not 252** — a 56-topic divergence. Every other count
  matches exactly, so this is one category out of step rather than a stale copy.
- **Category 78 holds 149 against 163.** It does not affect Phase 3, but it does affect what
  the showcase lane displays.
- **Category 66 needs no work at all**: `blog-gestiona` is already on 9 of 9.
- **Category 67 needs only 2 hand fixes** rather than 50, because Phase 2's synonym merge
  already tagged 48 of them. Exactly as the plan predicted.

#### PROD, as originally planned

The counts that follow are PROD's, from 2026-08-25. Re-measure before executing there:
`caag` was 40 on PROD against 15 on PRE, `developers` 24 against 15, `analiza` 62 against 69,
`alumno-certificado` 163 against 171. The divergences run in both directions, so PRE is not
simply an older copy. **Category IDs are identical on both** — 34 against 34, verified the
same day — but tag and topic data are not.

| Source | Topics | Tags to append |
|---|---:|---|
| 5 Foro del certificado | 252 | `administracion-avanzada` |
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
| 67 Webinars | 50 | none: `seminarios`, `webinar` and `seminario` already migrated into `webinars` in Phase 2 (54 uses); 2 untagged to fix by hand |
| 86 Hackathon | 8 | `hackathon-eivissa` — **none of the 8 carries any tag today** |
| 34 Recursos compartidos | 5 | none: all five are already tagged by subject |

### Lane safety, checked 2026-08-26

Before Phase 4 runs, the six lane settings were checked against the deletion list. **The two
sets are disjoint** — no setting references a category this plan deletes:

```
deleted by Phase 4 : 34 49 50 53 54 56 57 58 62 65 66 67 68 69 86 87
referenced by lanes: 5 14 18 59 73 78 85
```

| Lane | Points at | Projected | **Actual, 2026-08-27** |
|---|---|---|---|
| news | *(none)* | immune by design — site-wide `latest` since #31 | unchanged |
| forum | 5 | 196 → 237 | **239** — category 71 was dissolved here too |
| ideas | 18 | 318 → 441 | **441** ✓ |
| showcase | 78 | 149 → 149 | **149** ✓ |
| events | 59 | 40 → 46 | **47** — the 7th Café was rescued from 71 |
| library | 73 · 85 · 14 | 66 · 13 · 99 | **66 · 13 · 89** — see below |

The three divergences are decisions taken during execution, not measurement error, and each
is recorded under *Phase 4 as executed*. The library figure is the one that moved against
the plan: category 3's `expertos-espublico` topics were archived in place rather than moved
to 14, so 14 holds 89 and not 99.

Every lane survives and every one grows or holds. The library cards for 85 and 14 lose their
children in Phase 4, and `BlockLibrary` handles that on its own: the subcategory count is
inside `{{#if card.sections}}`, so those cards simply drop the line rather than printing
"0 sections". Only 73 keeps showing its seven.

### Phase 3 as executed — ✅ done 2026-08-26

**800 topics across 17 categories, zero `max 1 per topic` conflicts.**

| ID | Category | Topics | Coverage |
|---|---|---:|---|
| 54 | Campaña Gestiona V9 | 1 | `campana-v9` 1/1 |
| 69 | App Móvil | 1 | `administracion-avanzada` · `app-movil` 1/1 |
| 49 | Proyectos piloto | 1 | `administracion-avanzada` 1/1 |
| 68 | PID | 4 | `administracion-avanzada` · `pid` 4/4 |
| 34 | Recursos compartidos | 5 | — none required |
| 87 | Café con certificados | 6 | `cafe-con-certificados` 6/6 |
| 86 | Hackathon | 8 | `hackathon-eivissa` 8/8 |
| 66 | Blog Gestiona | 9 | `blog-gestiona` 9/9 |
| 62 | Trucazos | 15 | `administracion-avanzada` · `trucazo` 15/15 |
| 50 | Analiza | 15 | `analiza` 15/15 |
| 56 | Tasas e impuestos | 20 | `administracion-avanzada` · `tasas` 20/20 |
| 57 | Campañas de ideas | 20 | `campana-2024` 20/20 |
| 65 | Newsletter | 27 | `newsletter` 27/27 |
| 67 | Webinars | 50 | `webinars` 50/50 |
| 58 | Campaña ideas febrero 2025 | 102 | `campana-febrero-2025` 102/102 |
| 5 | Foro del certificado | 198 | `administracion-avanzada` **196/198** — correct, see below |
| 18 | Tengo una idea | 318 | `administracion-avanzada` 318/318 |

#### The two topics that did not take the tag

Category 5 reads 196 of 198, and that is the model working rather than a gap. The two are
`Nuevo Alumno Certificado: GFD 01` and `GFD 03`, and they already carry **`developers`**.
`max 1 per topic` refused them a second programme tag.

**In a bulk operation over 198 topics, the partition held itself** — 196 · 2 · 0 overlaps —
with nobody reading a single row. This is the constraint that Phase 2's group exists for, and
it earned its place on the first day it was used.

*(Both also carry `alumno-certificado` and `posters`, which is the signature of Primeros
pasos. They are arrival announcements filed in the general forum. Content curation, outside
this plan.)*

#### The trap that would have mis-tagged 108 topics

**A category's topic list includes its subcategories', and bulk selection follows the list.**
Category 5 still has three children — 58, 34 and 54 — so *select all* there reaches 307
topics, not 199:

```
listing of 5, unfiltered        : 307 topics → 5:199  58:102  34:5  54:1
listing of 5, no_subcategories  : 199 topics → 5:199
```

Without the filter, `administracion-avanzada` would have landed on the 102 February-campaign
topics, the 5 from Recursos compartidos and the one V9 topic. Use
`?no_subcategories=true`, or the equivalent control on the category page. **Category 5 was
the only source with children** — the other fifteen are safe to select wholesale.

#### Two things the original table got wrong

- **Category 49 was missing from it.** One topic, moving to category 5 in Phase 4, which
  would have arrived as the only topic in the forum with no programme tag.
- **Category 57 is easy to skip**, and did get skipped on the first pass. It hangs off
  53 Moderadores, a staff category — and the naming there is crossed: category **3** is named
  *Administradores* with slug `moderadores`, while category **53** is named *Moderadores*
  with slug `vota-tu-gestiona`. The URL that reads like the moderators' category is the other
  one. Both name and slug point away from where 57 actually lives.

#### A tag cannot be minted from the bulk dialog

It only offers tags that already exist. New tags have to be created first — by applying one
to a single topic by hand, or by typing it into a tag group. There is no standalone "create
tag" button anywhere in Discourse's admin. This cost a false start on `campana-2024`, which
the bulk dialog accepted and silently did not apply.

**Phase 4 — move topics. ✅ Done 2026-08-27** — see *Phase 4 as executed* below for what
actually happened, including six deliberate departures from the plan that follows. Moves come
first, now that every topic carries the tag that says where it came from. Then delete the
emptied categories: 34, 62, 65, 66, 67, 86, 87, 58, 54, 57, 53, 50, 49, 56, 68, 69.

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

**Phase 6 — pósters.** Now a cleanup of `posters` rather than the minting of a new tag —
see *The poster tag* above. In order: add `alumno-certificado` to the **3** topics that carry
`posters` without it; sweep `posters` off all 158 topics in one operation; review the 34
image-bearing topics in Primeros pasos and apply `posters` to the ~17 genuine ones; then
point the showcase lane at that tag with the filter shipped in #31.

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

> **RESOLVED 2026-08-26 (#37). Kept because the failure is silent and worth recognising.**
>
> **PRE was not running what `main` held.** Found 2026-08-26: PRE followed
> `d-compat/2026.8`, a compatibility branch frozen at `760df74` (#29), so it is on
> `theme_version` **0.17.0** and shows **five lanes, not six** — Phase 5's work has never
> been live there. Its news lane is still keyed on category 4, the state #31 replaced.
>
> Two consequences for this plan. **Anything verified on PRE before that branch is corrected
> was verified against 0.17.0**, whatever `main` says. And the news lane there *is* still
> category-keyed, so the protection described under *Settings* — that a reorganisation
> cannot empty it — does not yet apply to PRE.
>
> Fixed by deleting `d-compat-branch.yml` and the branch it had cut; see *Why this repo no
> longer cuts compatibility branches* in `CLAUDE.md`. PRE has followed `main` since, and the
> six lanes were confirmed rendering there again at the close of Phase 4.

### Phase 4 as executed — ✅ done 2026-08-27

**34 categories → 17. 284 topics moved in 16 operations. Zero topics deleted.**

Run as three blocks, verified over the API between each one. Every move was checked by
**topic ID**, not by count: the source's listing was captured before the move and each
topic located in the destination afterwards. That is what makes "nothing was lost" a
measurement rather than an inference.

| | |
|---|---|
| Categories | 34 → **17** (10 top-level, 9 of them member-visible) |
| With children | **only 73**, as designed |
| Topics moved | **284** in block A, plus 4 by hand |
| Categories deleted | **17** — the 16 planned, plus 71 |
| Topics deleted | **0** |

Final census: 18 (441) · 5 (239) · 4 (174) · 78 (149) · 14 (89) · 59 (47) · 85 (13) ·
3 (7) · 75 (2) · 73 (0, with its seven children).

#### The trap the plan did not have: definition topics

Every source category's listing carries its own **"Acerca de la categoría …"** topic, and
**only 4 of the 15 were pinned** — the rest sort by activity, mixed in with real content. A
*select all → change category* therefore takes it along, and the result is an orphaned
definition topic sitting in the destination.

That is not cosmetic. `definitionTopicIds()` in `lib/category-topics.js` builds its exclusion
set from `Category.list()` via each category's `topic_url`. **Once the source category is
deleted its entry disappears from that list, so the orphan is no longer filtered** and
surfaces in the lanes as an ordinary recent topic — most visibly in the site-wide news lane.

The fix is free if you know: untick that one row before each move. Its topic id was read off
the API and handed over per category, which is cheaper than hunting a title in a 103-row
list. **All 15 stayed put**, and each deleted category took its own definition topic with it.

One related detail worth keeping: a definition topic's title does **not** follow a category
rename in general — but on this instance only category 85's had drifted
(*"Recursos y proyectos compartidos"* under a category called *Comparte*). Category 4's is
correctly *"Acerca de la categoría Noticias"*. Nothing in the theme reads those titles, since
`definitionTopicId()` keys on `topic_url`; it is cosmetic debt for Phase 6.

#### Two Phase 3 errors that only a full sweep would find

Walking all 441 topics of category 18 after the moves turned up two faults left by the bulk
tagging, both fixed the same day and both invisible from any per-category count:

1. **`campana-2024` had been applied to category 58's 102 topics as well as category 57's
   20.** It stood at 122 uses, conflating two campaigns — and the tag is the *only* thing
   that survives the deletion of those categories, so the conflation would have been
   permanent.
2. **The 20 topics from category 57 arrived without `administracion-avanzada`.** Phase 3
   tagged category 18 while those topics were still in 57, so the sweep never reached them.
   They were the only 20 of 441 without the programme tag.

Both were fixed in two operations, and **the order made them exact**: removing
`campana-2024` from everything carrying `campana-febrero-2025` leaves precisely the 20, so
the second filter returning 20 is itself the proof that the first operation worked.

The lesson generalises: *bulk-tag a destination category after its inbound moves, not
before*, or run the sweep again afterwards.

#### The campaign tags were renamed

With the categories gone, the tag is the classification, so it was worth naming properly:

| Was | Is | Topics |
|---|---|---|
| `campana-2024` | **`ideas-2024`** | 20 |
| `campana-febrero-2025` | **`ideas-2025`** | 102 |
| `campana-v9` | **`ideas-v9`** | 1 |

That leaves a readable family alongside plain `ideas` (319, the live ones). Renaming a tag
preserves every assignment — verified topic by topic. `ideas-2025` drops the "febrero";
harmless while the campaigns stay closed.

#### Six departures from the plan, all deliberate

| | Planned | Done | Why |
|---|---|---|---|
| Category 71 | archive | **dissolved into 5, deleted** | it had served its purpose; leaves no zombie in the tree |
| Category 3's 10 `expertos-espublico` topics | move to 14 | **archived in place** | disused, and it avoided the one access question the plan never answered |
| `/t/843` "Ponencias II encuentro" | move to 59 | **archived in place** | same call |
| `/t/515` test topic | delete | **archived** | costs nothing to keep |
| 7th Café con certificados | *(not in the plan)* | **rescued from 71 → 59** | the series was split; archiving 71 would have buried the opening instalment |
| Campaign tags | keep `campana-*` | **renamed `ideas-*`** | see above |

The access question is worth stating, because the plan's permissions analysis missed it.
That analysis measured the 15 dissolution pairs and found every one neutral — but **category
3 → 14 was never in that table.** Both are `read_restricted`, to different audiences: 3 is
staff, 14 is member groups. Moving nine unlisted staff topics there would have widened who
could reach them by direct link. Archiving in place made the question moot, and the granular
API key cannot read category permissions to have settled it either way.

#### What Phase 4 did not need

**No theme setting was retuned, and no theme code changed.** The plan's headline risk was
five lanes keyed by numeric category ID pointing at categories that a reorganisation might
delete, rendering empty and silently. It never materialised, for the reason *Lane safety*
predicted: the deletion set and the lane set are disjoint. All six lanes were confirmed
rendering on PRE afterwards.

Worth recording for the next reader of this document: **the homepage is a two-column grid,
not a stack of six lanes.** Above 60rem of container width `home-main` (news, forum, ideas)
and `home-side` (events) sit side by side, with showcase and library full-width beneath —
`stylesheets/layouts/homepage.scss:22`. Reading the main column top to bottom yields five
lanes and looks like events is missing. It is not; it is to the right.

### Phase 6 — the measured worksheet, 2026-08-27

Measured before touching anything: all **1,249 topics** of the 17 categories over the API,
then the **full post stream** of every topic in 78 and of every stray found outside it. Three
of the plan's assumptions did not survive the measurement.

**1. Category 78 holds no poster topics.** All 149 of its topics are arrival announcements —
*"Nuevo compañero certificado · Nombre · CAAG NN"*. The poster is not a topic; it is an
artifact **inside** the announcement. So `posters` cannot mean "this is a poster". It means
**this announcement carries the member's poster**, which is what the sweep applies.

**2. The poster comes in two formats, and only one of them can reach the grid.**

| Evidence in the first post | Topics |
|---|---|
| Poster embedded as a portrait image (`alt` = the project: `VADOS`, `El Contrato Menor`) | **17** |
| Poster attached as a PDF (`Poster_AranNartCuny.pdf`, `PÓSTER PROCEDIMIENTO AYUDA ESTUDIO…`) | **36** |
| Both | 2 |
| **Carries a poster** | **51** |
| Carries neither | **98** |

The showcase grid requires `image_url`, so the **34 PDF-only topics can never appear in it**,
tagged or not. The tag is still worth applying to them: it is a property of the topic, not of
the lane, and the lane's own filter is what decides what it can hang. Recorded here because
"tagged but invisible" would otherwise read as a bug later.

**3. The prerequisite in *The poster tag* is void.** It said three topics carry `posters`
without `alumno-certificado` and must be given it before the sweep, or they end up with no
classification. Measured today it is **five**, and none of them ends up bare — every one
keeps other tags. Three are Eventos topics about the *poster contest* at the Encuentro,
where `alumno-certificado` would be simply false. The step is dropped rather than executed.

**What the sweep would have destroyed, had it been run from the first post alone: nothing.**
The full-thread scan exists to answer one question — whether any poster hides in a reply,
where the first-post scan would not see it and the sweep would strip the tag off a topic that
deserves it. **51 topics carry a poster in the first post; 0 carry one only in a reply.**

**Eleven arrival announcements sit outside 78** — nine in Noticias (4) and two in Foro del
certificado (5), not the two already on file. Nine carry a poster. They move to 78.

#### The operation list — 115 topics

| Operation | Topics |
|---|---|
| Remove `posters` (no poster in the topic) | **103** |
| Add `posters` (poster present, tag missing) | **6** |
| Add `alumno-certificado` (arrival announcement left untagged) | 5 |
| Move to 78 | 11 |

`posters` lands at **61 uses**: 51 in 78, plus the nine strays that move in, plus `/t/1959`
*"Los pósteres del III Encuentro"*, which carries eight posters as images and is the one
topic outside 78 that genuinely holds any.

Four topics lose the tag outside 78 and are worth naming, because each is a different way it
was mis-applied: `/t/2571` is a support question, `/t/2248` is a forum improvement,
`/t/1924` and `/t/1931` announce the poster *contest* without carrying a poster.

#### What this leaves the showcase lane

**22 topics in 78 carry both the tag and a cover image**, plus `/t/2550` and `/t/2611` once
they move in — **24 cards for a 6-cell grid**. Six of the 24 lead with a photo or a dashboard
screenshot rather than the poster itself, since the poster is their PDF; the grid hangs the
image the topic has.

#### Executing it needs a key that can write

The granular PRE key in `.env.local` is read-only: `PUT /t/-/<id>.json` answers
**403 `invalid_access`**. It reads every listing, every topic and every tag this worksheet was
built from, and cannot change one of them. Applying the list therefore needs either the admin
UI — where the 51 keepers have to be picked out of a 149-row list by eye, with only titles to
match against — or a temporary key scoped to `topics: update`, which lets the same list be
applied **by topic ID** and verified by re-reading every one afterwards.

### Phase 6 as executed — ✅ done 2026-08-27

The second route was taken. **115 topics written, 0 failures**, each one read fresh
immediately before its write and re-read afterwards.

| | before | after |
|---|---|---|
| `posters` uses | 158 | **61** |
| Category 78 | 149 | **160** |
| Category 4 | 176 | 167 |
| Category 5 | 242 | 240 |
| Showcase grid pool (tag + cover image) | — | **22** |

The 61 are the 51 poster-bearing announcements of 78, the nine that moved in, and `/t/1959`,
the Encuentro compilation that carries eight posters as images.

#### The write cleared every thumbnail it touched

**Measured, and not predicted by anything in this plan.** A topic updated through
`PUT /t/-/<id>.json` loses `image_url` in every topic listing. All nine topics that had a
thumbnail *and* received a write lost it — six of them tag-only edits, three of them moves —
while the 49 that already carried `posters` and were therefore never written kept theirs.
That contrast is what isolates the cause: **the write, not the move.**

The post itself is untouched: the image and the PDF are still in the cooked HTML. What is
gone is the topic-level thumbnail the listing serializes, which is exactly what
`requireImage` filters on. So the cost is three poster-bearing topics — `/t/2611`, `/t/2574`
and `/t/2550` — sitting outside the grid pool that would otherwise be 25 rather than 22.

**A rebake does not bring it back.** Tried on all three the same afternoon: the pool stayed
at 22 and `thumbnails` stayed null. The rebake is not inert — it re-cooks the post, and the
cooked HTML afterwards points at an `optimized/` derivative on the CDN where it had pointed
at the raw S3 upload — but the topic-level thumbnail stays gone.

**The mechanism is not established, and two guesses at it have already been wrong.** The
first said a rebake would restore it; it does not. The second said the casualties were the
topics whose image had no optimized derivative; that was an artifact of reading `/t/2611`
*before* its rebake and comparing it against a topic that had never been written. **All nine
casualties now show optimized derivatives and still have no thumbnail.**

What is measured, and enough to work from: **a write costs a topic its place in any lane that
filters on `image_url`, and nothing tried has given it back.**

**Both write routes do it.** The admin bulk dialog goes through `PUT /topics/bulk.json` with
`append_tags`, a different endpoint from the whole-topic `PUT /t/-/<id>.json`, and the hope
was that it only touched tags. Tested on one topic that was in the grid pool, with the
thumbnail measured either side: **the tag landed and the thumbnail went.** So there is no
cheap route, and the cost is a property of tagging a topic, not of the tool used.

The price was then paid deliberately. Tagging the seven III Encuentro announcements with
`poster-congreso-2025` took the showcase pool from **22 to 17** — five of the seven were in
it.

**And "pool" flatters the lane.** `loadCategoryTopics` fetches **one page** — the 30 most
recently active topics of the category-and-tag listing — and applies the image test to that
page. Of the 17 topics that satisfy all three filters, only **10 fall inside that page**; the
other seven sit further down the listing and cannot reach the grid until activity brings them
forward. So the real margin over six cells is four, not eleven. Every "pool" figure in this
document is the count that passes the filters, not the count the lane can actually see.

**Unresolved: whether it comes back on its own.** Nothing recovered within the session, and a
rebake does not do it, but no one has looked a day later. Worth checking before the PROD pass
plans around it.

#### Two keys, not one

A granular key scoped to `topics: update` **cannot read**: `GET /t/<id>.json` answers 403.
The first run of the executor therefore failed all 115 topics at the read, before attempting
a single write — visible only because every line said `READ FAILED` rather than `ok`. Reads
go through the read-only key and writes through the write key; the executor holds both.

#### The tag is `poster-evf`, not `posters`

Renamed the same afternoon, once the sweep had shown what the tag actually marks: **the
certification's *evaluación final* poster**. The flat `posters` could not stay, because it
would have to cover two different things — the work the programme evaluates, and the posters
an event exhibits. With the narrow name each gets its own: `poster-evf` for the 60
announcements in 78, and **`poster-congreso-2025`** for `/t/1959`, the III Encuentro
compilation.

`poster-congreso-2025` ends up on **one topic**: `/t/1959`, the compilation. `poster-evf`
stands at **60**, all inside category 78.

It took a round trip to get there, and the round trip is the part worth keeping. Seven
announcements were tagged `poster-congreso-2025` and stripped of `poster-evf` first, on the
strength of a title match: the eight posters exhibited at the III Encuentro carry the exhibitor's
name and project, and seven matched an announcement in 78 word for word. **The match was real
and the conclusion drawn from it was wrong.** It proved that *the poster* was exhibited at the
congress; it said nothing about what *the topic* is. The topic is an arrival announcement whose
poster is the certification's evaluation deliverable, and the tag describes the topic. All seven
were reverted.

**A tag edit is logically reversible and physically is not.** Reverting the tags did not revert
what the writes cost: five of the seven were in the showcase grid, every write clears a topic's
thumbnail, and **the pool went 22 → 17 and stayed there** after an operation that was undone in
full. That is the practical consequence of the thumbnail finding above, and it changes how a
tagging pass should be run: the scope has to be settled *before* the first write, because
"we can always untag it" buys back the tag and not the card.

**The lane reads one tag, not a set.** `showcase_tag` is a single string and
`loadCategoryTopics` passes one value, so the grid shows `poster-evf` and nothing else. Moot
while the only other poster tag sits on a topic outside category 78, but it is what the
homepage redesign would have to change if event posters were ever meant to appear there.

`showcase_tag` was moved to the new name in the same pass. **A tag rename empties a
tag-filtered lane in silence** — the request simply matches nothing — so the setting and the
rename have to travel together. That is the one coupling this design introduced between the
taxonomy and the theme, and it is worth stating plainly since nothing reports it.

#### What the posters turned out to be

Asked directly, and worth recording because it decides what the lane is showing: **the 51 are
certification deliverables**, not shared resources. Four independent signals agree — 50 of the
51 titles name a cohort; nobody announces themselves (11 accounts wrote all 51, zero
self-references); attachment names say *"Evaluación final certificación promoción XVIII"*,
*"EVF-…-ANALIZA"*, *"Poster Developers"*; and seven of the eight posters exhibited at the III
Encuentro match a certification announcement word for word by project title.

The exceptions are real but small. **Estrella Fadrique** presented at the Encuentro on her own
initiative and has no announcement anywhere on the site — her poster exists only inside
`/t/1959`. And the **Hackathon** deliverables in 85 are write-ups: seven of the eight carry
neither an image nor an attachment, and only `/t/2362`, the worked example, holds a poster
(`poster_final_ejemplo_hackathon`, 353×500). Whatever posters that event produced are not on
the forum.


## Risks

- **Phases 3 and 4 are not reversible by an undo.** Bulk tagging is cheap to correct; moving
  topics between categories is not, once the source is deleted. Phase 4 deletes nothing until
  its topics are tagged and moved.
- **Category 3 must not be deleted or over-restricted.** `/tos`, `/privacy` and `/faq` read
  from topics inside it.
- ~~**Widening read access on the 27 newsletters is not cheaply undone.**~~ **Void as of
  2026-08-26**, for two independent reasons. The maintainer removed category 65's restriction
  directly, so it is now open like its destination — the move changes nothing. And even
  before that, the widening was nominal: 65 was restricted to `Certificación`, which has
  **375 members against 373 registered users**. See *Permissions are neutral* below.
  Reviewing the newsletters is still worth doing, but as routine content review rather than
  as an irreversible exposure decision — and the window for re-restricting them closes when
  Phase 4 deletes the category, not before.
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
   with no children. Recorded on 2026-08-25 as the plan's one deliberate widening of read
   access. **Measured on 2026-08-26 and it was never a widening** — see *Permissions are
   neutral*. The maintainer then removed 65's restriction outright, so by the time Phase 4
   runs the two categories match.
8. **Recursos compartidos (34) dissolves into 85**, leaving Foro del certificado with no children. A
   promotion to top level was decided first and reversed: it would have put *Recursos
   compartidos* beside *Recursos y proyectos compartidos*, two top-level names differing by
   two words.
9. **Trucazos (62) becomes a tag on Aula de formación**, staying in the category it already
   hangs off. It keeps `administracion-avanzada` as a programme marker, but *optionally*:
   `programa` is required only on Foro del certificado, so nothing on these 15 topics is forced.
10. **Webinars (67) becomes a tag on Aula de formación**, canonical `webinars`, with
   `seminarios`, `webinar` and `seminario` as synonyms so no tagging is lost.
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
15. **Category 5 keeps its own name: "Foro del certificado".** It went through three names in
   one day and landed back where it started, which is worth recording rather than tidying
   away. The plan carried *Expertos* from 2026-08-25 — a judgement about the members rather
   than a name for the place. During Phase 1 that became *Usuarios certificados*, which named
   the members instead. Then the maintainer restored the original, dropping the article and
   the capital: **Foro del certificado**, `foro-del-certificado`.

   The version that survived is the only one of the three that names **the place** rather
   than the people in it — and the category is the general forum, not a roster. Two loose
   ends closed with it: the coincidence with the existing `UsuariosCertificados` group is
   moot, and the homepage lane title, which had drifted from the category name, was aligned
   to match in `locales/*.yml`.

   **PROD still reads "El foro del Certificado" / `el-foro-del-certificado`**, so category 5
   needs the same rename there — it is not, as briefly assumed, a category PROD can skip.

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
every other branch had been flattened, and declined again.**

**Resolved 2026-08-26.** 73 stops being an exception: subcategories are the agreed shape for
documentation categories, and 73 is one. See *Standing decision: subcategories only in
documentation categories*. Collapsing it is no longer pending — it is declined on principle.

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
| 9 | Category 5 is **Foro del certificado**, not *Expertos*; slug `foro-del-certificado` | throughout, *Slugs*, decision 15 |
| 10 | **PRE runs 0.17.0 from a frozen compat branch** — five lanes, not six | *Migration plan*, `CLAUDE.md` |
| 11 | Phase 1 **done and verified**; Phase 2 **done**, `dominio` skipped | *Migration plan* |
| 12 | **`posters` is kept and cleaned**, not retired into `alumno-certificado` — reverses the 2026-08-25 decision | *The poster tag*, *Phase 6* |
| 13 | Four **instance settings** blocked or distorted the tag model; `max_tags_per_topic` was a hard blocker on Phase 3 | *Instance settings* |
| 14 | **11 families of near-duplicate tags**; three of them were invisible to a plan written from canonical names | *Vocabulary hygiene* |
| 15 | PRE and PROD are **not tag-identical**, so Phase 3's counts must be re-measured per instance | *Phase 3* |
| 16 | **All 15 dissolutions are permission-neutral**; `Certificación` has 375 members against 373 users | *Permissions are neutral* |
| 17 | The newsletter-widening risk is **void**, and was never real | *Risks*, decision 7 |
| 18 | **Subcategories only in documentation categories** — a standing rule; 73 stops being an exception | *Standing decision*, *Residual* |
| 19 | Category 5 is **Foro del certificado** — three names in one day, back to its own | decision 15 |
| 20 | Phase 3 has a **measured PRE worksheet**; category 5 holds 196 topics there, not 252 | *Phase 3* |
| 21 | **No lane setting points at a category Phase 4 deletes**; all six survive | *Lane safety* |
| 22 | **Phase 3 done** — 800 topics, 17 categories, zero max-1 conflicts | *Phase 3 as executed* |
| 23 | The tag group is **`programa-certificacion`**, renamed off a collision with the `Certificación` user group | *Phase 2* |
| 24 | Bulk selection follows subcategories: category 5 would have mis-tagged **108 topics** | *Phase 3 as executed* |

**2026-08-27.** From executing Phase 4:

| # | Change | Where |
|---|---|---|
| 25 | **Phase 4 done** — 34 categories → 17, 284 topics moved, **zero topics deleted** | *Phase 4 as executed* |
| 26 | Listings answer **301**, not an empty body; `curl -L` and the ID-only form work for children too | *A measurement trap* |
| 27 | **Definition topics ride along in a bulk move** and orphan into the destination, where the theme stops filtering them once the source is deleted | *Phase 4 as executed* |
| 28 | Category 3's 10 `expertos-espublico` topics **archived in place**, not moved — 14 holds 89, not 99 | *Lane safety*, *Phase 4 as executed* |
| 29 | Category 71 **dissolved into 5 and deleted**, not archived — 5 lands at **239** | *Phase 4 as executed* |
| 30 | The **7th Café** was rescued from 71 into 59, completing a split series — 59 lands at **47** | *Phase 4 as executed* |
| 31 | Phase 3 had over-applied `campana-2024` to **102 topics** and left **20** without the programme tag; both fixed | *Phase 4 as executed* |
| 32 | Campaign tags renamed **`ideas-2024` / `ideas-2025` / `ideas-v9`** | *Phase 4 as executed* |
| 33 | The permissions analysis never covered **3 → 14**; archiving in place made it moot | *Phase 4 as executed* |
| 34 | The homepage is a **two-column grid**; events sits beside the first three lanes, not below | *Phase 4 as executed* |
| 35 | **Category 78 holds no poster topics** — all 149 are arrival announcements, and the poster is an artifact inside them | *Phase 6 worksheet*, *The poster tag* |
| 36 | The poster is an **image in 17 topics and a PDF in 36**; the PDF-only ones can never reach the grid | *Phase 6 worksheet* |
| 37 | **No poster hides in a reply** — 51 in first posts, 0 in replies, which is what makes the sweep safe | *Phase 6 worksheet* |
| 38 | The **`alumno-certificado` prerequisite is void**: five topics, not three, and none ends up unclassified | *Phase 6 worksheet*, *The poster tag* |
| 39 | **Eleven arrival announcements sit outside 78**, nine of them carrying a poster | *Phase 6 worksheet* |
| 40 | The showcase lane gains **`showcase_tag`**, defaulting to `posters` | *Impact on the theme*, *Code* |
| 41 | **Phase 6 done** — 115 topics written, `posters` 158 → 61, grid pool 22 | *Phase 6 as executed* |
| 42 | **A topic write clears its list thumbnail**; nine lost one, three of them poster-bearing | *Phase 6 as executed* |
| 43 | A `topics: update` key **cannot read** — reads and writes need separate keys | *Phase 6 as executed* |
| 44 | The posters are **certification deliverables**; the Hackathon's are not on the forum at all | *Phase 6 as executed* |

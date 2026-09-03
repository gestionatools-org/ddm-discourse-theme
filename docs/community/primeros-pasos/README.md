# Primeros pasos — the onboarding set

The **content** of the *Primeros pasos* category, kept under version control because the
instance is not a source of truth: a topic can be edited in admin by anyone with the rights,
and PROD still has to receive the same set against a different set of category IDs.

Each file is the **raw markdown as published**, with nothing added — no front matter, no
metadata block. Copy a file's contents into the composer and you get the live post back.
The filename carries the PRE topic ID.

Modelled on Asana's own *Primeros pasos* (`forum.asana.com/c/forum-es/primerospasos/165`),
which was read over its JSON API on 2026-09-03: six topics, of which four were worth
adapting, one needed rewriting from scratch, and one was refused. See *Departures* below.

## Live on PRE

Published 2026-09-03 as **`RicardoPG`** into category **78** (`Primeros pasos`), which had
been emptied first — its 160 arrival announcements had moved to category 5, taking it from
203 to 363 topics.

**Dated as if written when the forum opened.** Published with 2026 timestamps, they landed at
the top of `/latest` and read as news. `PUT /t/<id>/change-timestamp.json` moved each one back
to the days after the instance was created on **2024-01-15** — welcome on the day itself, the
guides over the two following days, in reading order. That endpoint moves `created_at` on both
the topic and its first post, and `bumped_at` with it, which is what `/latest` orders by.
Verified after: none of them on page 1 of `/latest`.

| File | Topic | Date | Notes |
|---|---|---|---|
| `2622-te-damos-la-bienvenida.md` | [2622](https://discourse.gestiona4dev.tech/t/-/2622) | 2024-01-15 | pinned |
| `0004-pautas-y-preguntas-frecuentes.md` | [4](https://discourse.gestiona4dev.tech/t/-/4) | 2024-01-15 | **serves `/guidelines`, and `/faq` redirects to it**; closed, moved out of category 3 |
| `2620-como-buscar-en-la-comunidad.md` | [2620](https://discourse.gestiona4dev.tech/t/-/2620) | 2024-01-16 | |
| `2621-como-seguir-un-tema-y-recibir-avisos.md` | [2621](https://discourse.gestiona4dev.tech/t/-/2621) | 2024-01-16 | |
| `2623-como-reportar-una-publicacion.md` | [2623](https://discourse.gestiona4dev.tech/t/-/2623) | 2024-01-17 | |
| `2624-como-se-construye-un-buen-debate.md` | [2624](https://discourse.gestiona4dev.tech/t/-/2624) | 2024-01-17 | |
| `0063-construir-un-debate-util.md` | [63](https://discourse.gestiona4dev.tech/t/-/63) | 2024-01-25 | **pre-existing, Ricardo's own**; moved in from category 4, closed |

Topic 4 was already dated 2024-01-15 — it is Discourse's own document — so it needed no
backdating.

The guidelines are the hub: they link the other posts by **topic ID**, not by slug. Slugs on
this instance are legacy and do not match the display names — category 4 is `comunidad-expertos`
and shows as *Noticias* — so every internal link here is ID-keyed on purpose, and category
references are plain bold text rather than `/c/<slug>` links.

**No emoji in the titles.** They were published with them, copying Asana's pattern, and then
stripped: topic 63 — the pre-existing post, and the house rule on this instance — advises
against emoji as too informal, and a category cannot carry both conventions. The slugs never
held the emoji, so nothing broke. Bodies still carry a few `:emoji:` shortcodes; that is
unresolved.

## Topic 4 is not a new topic

*Pautas y preguntas frecuentes* is Discourse's own FAQ/guidelines document, rewritten in place
and moved. That was deliberate: it is wired to `/guidelines` and `/faq` by site setting, so
publishing the house rules as a *new* topic would have left the community with two sets of
rules — ours in the category and Discourse's stock "un lugar civilizado para la discusión
pública" still being served at `/faq`.

Discourse sanctions the edit itself: post #2 of that topic reads *"Edita la primera publicación
de este tema para cambiar el contenido de la página Preguntas frecuentes/Directrices."* Post #3
belongs to `RicardoPG` and was left untouched. The title moved from *Preguntas
frecuentes/Directrices* to *Pautas y preguntas frecuentes* so it reads correctly as both a
topic and a page.

## The category already had two of these, and that was found late

Looking up the instance's creation date turned up two topics covering ground the new set had
just covered. **Both were there before any of this**, and neither was noticed while writing:

- **Topic 63, *Construir un debate útil*** — 4.8 KB, ten pieces of advice on writing in a
  forum, **authored by `RicardoPG` in January 2024**, and already linked from the stock welcome
  topic. It is not boilerplate and not redundant: it covers **how to write** (tone, length, not
  repeating, citing sources) where topic 2624 covers **how to disagree** (Graham's hierarchy).
  Resolution: 63 moved into the category and the two now cite each other. Its original text was
  not edited — only a `Ver también` line appended.
- **Topic 5, *¡Te damos la bienvenida a Gestiona Avanza!*** — Discourse's stock welcome topic,
  lightly customised, by `system`, closed, in category 4, 164 views. Nearly the same title as
  2622. **Both were deliberately kept**: 5 stays in *Noticias* as the historical welcome, 2622
  is the category's. Its links already point the right way — `/faq` now serves the new
  guidelines, and its "debate útil" link goes to 63.

The pattern is worth naming, because it caught three times in one session: **Discourse already
ships a place for most of this, and so did the community.** Check for the existing topic before
writing a new one — category 3's listing and a `/search.json` query for the title would have
found both of these in two calls.

## Held

`HELD-terminos-y-privacidad.md` — **not published, and it should not be until someone writes
the terms.**

Asana's sixth topic is 12 KB of legal text. Replicating it was refused: jurisdiction, the
licence over user content and limitation of liability are not a translation exercise. The
replacement was going to be a short post pointing at `/tos` and `/privacy` — until those were
read.

**Topic 8, which serves `/tos`, is Discourse's unedited template and disclaims itself.** It
opens with the word *"Cámbiame"* and then states that these conditions *"no regulan el uso del
foro de Internet en gestionaavanza.espublico.com, pero podrían hacerlo algún día."* Someone
touched it on 2025-01-07 — the company name is filled in — and left the rest. A post directing
members there would be worse than no post.

Topic 9 (`/privacy`) is clean of placeholder markers but is still Discourse's generic template.

## Two instance facts these posts depend on

**`flag_post_allowed_groups` was `1|2|3`** — admins, moderators, staff. Discourse's default is
`1|2|11`, which includes trust level 1, so **no ordinary member could flag anything**. Changed
to `1|2|3|11` on 2026-09-03 so the reporting post describes something that exists.

**Trust level 1 is expensive here**, and the reporting post says so rather than promising the
button:

| | PRE | Discourse default |
|---|---|---|
| `tl1_requires_topics_entered` | **50** | 5 |
| `tl1_requires_read_posts` | **250** | 30 |
| `tl1_requires_time_spent_mins` | **180** | 10 |

Three hours of reading. Opening the permission was necessary but is not sufficient: a new
member waits weeks for the flag. If the flag should be reachable on day one, the lever is those
three thresholds, not the permission.

## Departures from the Asana set

- **Terms of use — refused.** See *Held*.
- **The confidentiality section is longer than the original's.** Asana warns about leaking
  product details; this is a community of public administrations, where the material on screen
  is other people's data. The section names what to strip before pasting a screenshot — names,
  DNI, expediente references — and proposes substituting invented data.
- **Notifications covers categories and tags, which Asana's does not.** Tags carry a lot of
  structure on this instance (`ideas-2025`, `poster-evf`), and following a tag beats following
  a thread.
- **No email paragraph.** `disable_emails` is not among the 1448 settings
  `/admin/site_settings.json` returns, and the login page shows no banner, so it could not be
  verified. Nothing published promises email delivery. The paragraph is drafted and can be
  added once someone confirms mail leaves PRE.
- **No screenshots.** Asana's posts lean on GIFs and screenshots; these are text and links.
- **Two debate posts where Asana has none.** 2624 exists because rewriting topic 4 removed
  Discourse's stock *"Mejorar el debate"* section: Paul Graham's disagreement hierarchy
  (DH0–DH6, *How to Disagree*, 2008) with examples from this community, opened on the fact that
  the forum software is named after Jeff Atwood's *Civilized Discourse Construction Kit* (2013)
  — the company's actual legal name. Both sources were read at origin and are cited with links,
  not copied. Topic 63 is the community's own, and predates all of it.

## Open

- **The welcome post has no personal introduction.** Asana's is signed by the person who runs
  the forum, who presents themselves. That paragraph was cut rather than invented; the post
  works without it. It is the one gap with a real name on it.
- **`:emoji:` shortcodes remain in the bodies** even though the titles were stripped. Same
  tension with topic 63's advice, unresolved.
- **Topics 5 and 2622 have nearly the same title.** Kept on purpose, but a reader browsing
  search results sees two welcomes.
- **PROD has had none of this applied**, and its category IDs do not match: 34 unreorganised
  categories, and its own `/tos`, `/privacy` and `/faq` documents to inspect first. Locate the
  equivalent category and the three document topics before replaying anything, and re-key every
  internal link — the IDs in these files are PRE's. Check for a pre-existing equivalent of
  topics 5 and 63 there too.

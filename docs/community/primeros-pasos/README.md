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

| File | Topic | Notes |
|---|---|---|
| `2622-te-damos-la-bienvenida.md` | [2622](https://discourse.gestiona4dev.tech/t/-/2622) | pinned |
| `0004-pautas-y-preguntas-frecuentes.md` | [4](https://discourse.gestiona4dev.tech/t/-/4) | **serves `/guidelines`, and `/faq` redirects to it**; closed, moved out of category 3 |
| `2620-como-buscar-en-la-comunidad.md` | [2620](https://discourse.gestiona4dev.tech/t/-/2620) | |
| `2621-como-seguir-un-tema-y-recibir-avisos.md` | [2621](https://discourse.gestiona4dev.tech/t/-/2621) | |
| `2623-como-reportar-una-publicacion.md` | [2623](https://discourse.gestiona4dev.tech/t/-/2623) | |
| `2624-como-se-construye-un-buen-debate.md` | [2624](https://discourse.gestiona4dev.tech/t/-/2624) | |

The guidelines are the hub: they link the other four by **topic ID**, not by slug. Slugs on
this instance are legacy and do not match the display names — category 4 is `comunidad-expertos`
and shows as *Noticias* — so every internal link here is ID-keyed on purpose, and category
references are plain bold text rather than `/c/<slug>` links.

## Topic 4 is not a new topic

*Pautas y preguntas frecuentes* is Discourse's own FAQ/guidelines document, rewritten in place
and moved. That was deliberate: it is wired to `/guidelines` and `/faq` by site setting, so
publishing the house rules as a *new* topic would have left the community with two sets of
rules — ours in the category and Discourse's stock "un lugar civilizado para la discusión
pública" still being served at `/faq`.

Discourse sanctions the edit itself: post #2 of that topic reads *"Edita la primera publicación
de este tema para cambiar el contenido de la página Preguntas frecuentes/Directrices."* Post #3
belongs to `RicardoPG` and was left untouched. The title moved from *Preguntas
frecuentes/Directrices* to *✌️ Pautas y preguntas frecuentes* so it reads correctly as both a
topic and a page.

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
- **The debate post has no counterpart** in the Asana set. It exists because rewriting topic 4
  removed Discourse's stock *"Mejorar el debate"* section, and it covers the same ground with
  more depth: Paul Graham's disagreement hierarchy (DH0–DH6, *How to Disagree*, 2008) with
  examples from this community, opened on the fact that the forum software is named after Jeff
  Atwood's *Civilized Discourse Construction Kit* (2013) — the company's actual legal name.
  Both sources were read at origin and are cited with links, not copied.

## Open

- **The welcome post has no personal introduction.** Asana's is signed by the person who runs
  the forum, who presents themselves. That paragraph was cut rather than invented; the post
  works without it. It is the one gap with a real name on it.
- **PROD has had none of this applied**, and its category IDs do not match: 34 unreorganised
  categories, and its own `/tos`, `/privacy` and `/faq` documents to inspect first. Locate the
  equivalent category and the three document topics before replaying anything, and re-key every
  internal link — the IDs in these files are PRE's.

# The silent migration to PROD — design

**Date:** 2026-09-13
**Status:** agreed in brainstorming, not executed. Nothing here has been applied to PROD.
**Scope:** `gestionaavanza.espublico.com` (PROD). Instance configuration, tags, categories,
then the theme — spread over three tranches with no maintenance window.
**Supersedes:** `2026-09-06-migracion-prod-design.md`. That document's PROD measurements, its
tag mechanics and its per-task API recipes stay valid and are referenced rather than repeated;
its *structure* — one staff-writes-only window, Phase 2 replaying August's taxonomy — is
replaced here.
**Depends on:** `2026-09-11-reorganizacion-generos-design.md` (the target map and its method),
`2026-09-11-cabecera-salas-design.md` (the instance state the theme needs), and
`2026-09-04-capa-materia-etiquetas-design.md` (the module axis and its thresholds).
**Plans:** this spec yields **three** implementation plans, one per tranche, each written when
its tranche starts so it is derived from measurements taken that week rather than from these.
T1 and T2 are instance work only; T3 is the only tranche that touches the repository.

## Why replan

The request, in Ricardo's words: *"la migración la quiero hacer silenciosa… que el usuario
pueda convivir con estos cambios sin darse demasiada cuenta y así podamos hacer un cambio de
interfaz visual cuando esté todo hecho."*

The order he asked for — content, then categories, then interface — happens to be the only
order that works, and not for cosmetic reasons: **the structural tagging marks each topic by
the category it is already in**, so reorganising first destroys the signal it reads. His
instinct and the constraint coincide.

Three things the September plan could not account for, all of them later than it:

1. **Its Phase 2 is void.** It replayed PRE's August taxonomy onto PROD; the genre
   reorganisation of 2026-09-11 replaced that taxonomy. PROD receives the final map directly.
2. **The theme now carries far more instance state than it did.** `header_room_category_ids`
   naming rooms that do not exist on PROD, the derived `Developers` group, the sidebar section
   that now holds the Academy and Demo URLs, `default_navigation_menu_categories` with its
   backfill, `search_experience` as a *theme* site setting, the `idea-registrada` tag with its
   permission group, `hero_default_category_id`, and two user-field ids. None of it travels
   with the `git pull`.
3. **The maintenance window is the loudest thing in the plan.** `staff_writes_only` shows a
   read-only notice to every non-staff member. The tranche that was meant to be invisible
   would have been the most visible of the three.

## What "silent" means, operationally

**A member who signs in during T1 or T2 finds no new interface element, no announcement, and
no broken link.** They may notice that something is better ordered. They must not be able to
notice that a project is under way.

| | What a member sees | Leak |
|---|---|---|
| **T1 · Content** | Nothing in the interface. Tag autocomplete offers different names and less noise; `#caag` and `#posters` keep filtering, because every rename leaves the old name as a synonym | Posting stops demanding two tags (`minimum_required_tags` → 0) and new topics stop closing after 30 days. Noticeable, and in their favour |
| **T1 · additive tail** | Nothing. The `Developers` group is derived and the three rooms are created **closed to staff**: absent from the category list and from the composer's picker | None |
| **T2 · Categories** | Several hundred topics change category — the figure is derived from PROD's own listings in T2 and is not known today — and the rooms open to their groups | **The real one.** See below |
| **T3 · Launch** | Everything | That is the milestone, not a leak |

**Moving a topic does not break its link.** A Discourse topic URL is `/t/<slug>/<id>` and
carries no category, so a bookmark, a link pasted into an email and a cross-reference from
another thread all keep resolving. What changes is where it is listed and what breadcrumb it
shows. T2's noise is navigational, not dead links — an order of magnitude less.

**Deleting a category is the exception, and it is why this plan does not delete any.** PROD
has 35 categories against a target map of roughly 20, so there are removals ahead — unlike
PRE, whose genre reorganisation created three and deleted none. A `/c/<slug>/<id>` linked
from an old thread, from the Academy or from an email would 404. **Surplus categories are
emptied and closed instead**: no topics, no write permission outside staff, out of the default
sidebar, URL still resolving. The real deletion is decided after the launch, when there is
nothing left to hide and it can be looked at calmly.

That choice also buys the rollback back. The September plan said *"Phase 2 is the one that
needs the backup, because category deletion is not recoverable from a tag capture"*. With
nothing deleted, T2 is undone by moving topics back.

**What silence costs us:** no window, so every batch re-reads the live state immediately
before writing and verifies by topic id. If somebody posts into a category while we are
emptying it, that topic is left behind — and the id verification catches it, the count does not.

## Decisions taken in conversation, 2026-09-13

Recorded so no later pass re-derives them.

1. **The category reorganisation sits inside the silent stretch**, not bundled with the visual
   launch. The engineering argument decided it: it settles the category ids *before* the theme
   is installed, so the settings that name PROD's own category ids arrive verified instead of being tuned on the
   day. The alternative pattern — last change, no soak, seen by the maintainer the next
   morning — is exactly what produced the iconless Academy link on PRE.
2. **No maintenance window in any tranche.** The real protection was never the window; it is
   the per-batch re-read and the verification by id. `PUT /topics/bulk.json` runs with
   `bypass_bump`, so a mass move does not flood `/latest`.
3. **The full subject layer**, as on PRE, including the coverage pass. It is the long pole and
   the only part that answers Susana's complaint in `/t/2224`. The theme reads none of it, so
   it never blocks the launch.
4. **`auto_close_hours` removed, already-closed topics left closed.** The setting alone; no
   mass reopening.
5. **The theme is installed hidden, after measuring the leak.**
6. **PRE is replicated exactly**: category 78's ~160 arrival announcements move to category 5
   and 78 becomes "Primeros pasos". The alternative — leaving the announcements where they
   already are and saving an entire mass move — was rejected in favour of one shared map
   across both instances. *Consequence:* 78's slug is `nuevos-usuarios-certificados` on PROD,
   and the sidebar's "Primeros pasos" link is the relative path `/c/primeros-pasos/78`, so the
   rename in T2 must change the slug too or that link is born broken.
7. **Nothing is announced** before the launch.

## T1 — Content

The long tranche, and the only one with the maintainer's attention spread over several
sessions.

**Two things no agent can do.** Create a **Global-scope API key on PROD** as
`PROD_DISCOURSE_GLOBAL_API_KEY` — that exact name, once, on its own line: `.env.local` has
twice had a duplicate name silently shadow another on `source`. And **tell whoever is tagging
PROD** before `caag` is touched: 89 new uses in a month across 126 topics that predate the
snapshot is deliberate admin work, not community activity, and the rename changes it underneath
them.

1. **Prior-state capture.** Vocabulary with counts, the tree with group permissions, every
   topic's tags, and the settings read. Out of the repository. It is T1's rollback and, since
   T2 deletes nothing, effectively the plan's.
2. **Read PROD's Discourse version.** `minimum_discourse_version` is pinned at `2026.7.0` and
   PROD is `login_required`, so it is unknown today. Below that the theme does not install and
   the Blocks API does not exist, which would invalidate the whole schedule. **Day one, not the
   eve of the launch.**
3. **The two ceilings, before the first tag write.** `max_tags_per_topic` → 7 and
   `max_tag_length` → 30. PROD is the instance PRE was cloned from, so assume 3 and 20 until
   measured: at 20 characters `administracion-avanzada` was truncated to
   `administracion-avanz`.
4. **Rename `caag`(129) → `administracion-avanzada` and `posters`(170) → `poster-evf`**,
   recreating each old name as a synonym. Not merges — neither target exists on PROD — and
   both are `topic_tags` rewrites at the database level, so no topic is written and no
   thumbnail is lost.
5. **Structural tagging by source category**, revalidating the August table row by row against
   the day's listing. Its Webinars row is known wrong for PROD: it assumes a merge that only
   happened on PRE. The `programa-certificacion` tag group is recreated in the same pass, over
   `administracion-avanzada`, `analiza` and `developers`, with `one_per_topic: true`.
6. **Spelling depuration.** Eleven families measured on PROD, with the canonical form chosen
   by **PROD's counts, not PRE's** — `webinar`(11) there against `webinars`(56) here. Plus one
   unaccented synonym per accented tag: `#padron` without the accent does not return zero, it
   returns fifty plausible and wrong results, which is worse.
7. **The subject layer.** Families derived from **PROD's** co-occurrence, the eight module
   groups each checked for slug shadowing before creation, and coverage raised by the title
   rule batch by batch. The body pass never runs unattended.
8. **`min_search_term_length` → 3 and `max_tag_search_results` → 5.** The cheapest and most
   effective change in the tranche: on PRE the floor was 6 and `tasas` or `v10` answered
   **HTTP 400**. It costs no write to any topic.
9. **`auto_close_hours` removed from 4, 5, 14 and 18; `minimum_required_tags` → 0.**
10. **Additive tail:** `Developers` derived from the four cohorts, and the three rooms created
    **closed to staff**, with their `foro-` slugs checked against PROD's vocabulary first.

**The rule governing every mass write**, which the September plan predates by four days: the
tags `/t/<id>.json` returns are **objects**, not strings. Re-sending them unnormalised created
13 junk tags and stripped nine topics of their real ones, with **HTTP 200 on all nine**. So:
capture prior state topic by topic before writing, normalise to names, and **re-read the names
afterwards** — the 200 says nothing, and the per-topic tag *count* was even correct. To subtract
one named tag use `manage_tags` with `remove_tag_ids`; the `remove_tags` operation removes
**every** tag.

**Gates where T1 waits for Ricardo:** the canonical form of each spelling family, every tagging
batch, and the body pass proposals.

## T2 — Categories

**The map is re-derived, not replayed.** And PROD must absorb **both** reorganisations at once:
August's, which it never received (dissolve the campaign categories, promote 18 and 78 to top
level, consolidate the resource trees), and September's genre split (plaza plus three rooms).
35 categories to roughly 20, in one pass.

Order, with the constraints where they are:

1. **Derive the move lists from the rules, never from PRE's lists.** The ceremonial pattern,
   the non-staff author test on category 4, and the release-note pattern on 18 with its known
   hole — the product name sits between keyword and version (*"Nueva versión Gestiona
   10.0.3.325"*), so do not require a digit immediately after the keyword.
2. **Gate: Ricardo approves every list.** The lesson of the body pass — 10 false positives in
   43 proposals, caught only by review.
3. **Category 5 receives the programme groups before any room hangs under it.** Core refuses a
   child whose groups are absent from its parent, and the refusal arrives as a 422 mid-sequence
   if the order is reversed.
4. **Open the rooms to their groups and reparent them under 5.** Reparenting moves no topics
   and changes no ids.
5. **Move, in batches, verified by id.** Never by count: counts hide unlisted topics and the
   definition topic. And the id list `PUT /topics/bulk.json` returns **is not proof the change
   happened** — a category's definition topic cannot be moved and Discourse reports it among
   the changed ids anyway.
6. **Measure thumbnails before each batch.** On PRE the 205 plaza topics had none and the real
   cost was 5, not 259. On PROD it is measured again, never inherited.
7. **Rename 78 to "Primeros pasos", slug included**, after its announcements have left.
8. **Empty and close the surplus categories** instead of deleting them.
9. **`default_navigation_menu_categories` with `update_existing_user=true`.** Without the
   backfill it reaches no current member: core seeds each user's sidebar links once, at signup.

**Where T2 stops being invisible, said plainly.** When the rooms open and the topics move, a
member sees a new section for their programme in the sidebar and finds the consultations
inside. There is no way around it: moving topics into a room nobody can see is making content
disappear, which is the loudest thing available. What can be chosen is that it reads as
community life rather than as a project — one pass, in a quiet slot, the rooms explaining
themselves by their names. **Nothing is announced.** The other two rooms are born empty and
walled to 82 and 49 people, so for everyone else they do not exist.

## T3 — The launch

**Measure the leak first, and measure it on PRE, where it is free.** Install a throwaway theme
there declaring a `theme_site_settings` row and read whether that row acts while the theme is
not active. If it does not — the expected answer, since those rows are per-theme — the path is
clear. If it does, `enable_welcome_banner: false` and `search_experience: search_icon` would
reach all of PROD on installation day, and the declaration comes out of `about.json` until the
launch.

**Then the theme enters PROD hidden**, not default, and is verified with `?preview_theme_id=`
against real data. What is being verified is not the look; it is that **ten settings resolve**:

| Setting | State on PROD |
|---|---|
| `events_category_id` 59, `ideas_category_id` 18, `hero_default_category_id` 5 | all exist; ids survive rename, promotion and reparenting, so T2 does not touch them |
| `header_room_category_ids` `89\|90\|91` | **PRE's ids.** PROD assigns its own → an instance override is mandatory |
| `ideas_tag` `idea-registrada` | **absent on PROD.** Without creating it, applying it and restricting it to staff through a tag group, the ideas lane renders empty, silently and with no error |
| `highlights_news_tag` `nueva-version-gestiona` | **absent on PROD.** The card shows its "coming soon" placeholder |
| `highlights_podcast_tag`, `highlights_newsletter_tag` | 6 and 22 topics; both work from minute one |
| `highlights_member_entity_field_id` 2, `..._role_field_id` 4 | **unverified on PROD**, and the one that matters most |

**That last row stops the line.** Fields 1 and 3 on PRE are a NIF and a CIF with
`show_on_profile: false`, and **an administrator's session receives them anyway**. They are
expected to match on PROD because PRE is a restored copy of it — but "expected" is not enough
when the failure is publishing a national ID on the community's front page. Read them by name
with the Global key before the flip.

**The chrome that does not travel**, applied in this tranche: the sidebar section holding
Academy, Demo Gestiona and Primeros pasos — those URLs stopped being theme settings in #129 and
now live in the links — plus the two renames of existing links. And one check against T1's
capture: since 0.40.0 the theme moves every custom section below Categorías and Etiquetas, so
**the order of PROD's sidebar changes on flip day whether anyone asked for it or not**. If a
public custom section turns out to link to `read_restricted` categories, that is Ricardo's call
before the flip, not a discovery after it.

**The verification no API can perform**, and on PROD it stops being tolerable debt: **one
session with a non-admin account.** It covers, at once, the three walls; that `idea-registrada`
is visible but not applicable; that "Nueva publicación" lands in category 5; the header links
by membership; and that the plaza lists only announcements. `/c/<id>/show.json` answers with the
permissions of the reading key, which is an administrator, so without that session all of it is
faith.

**A consequence of the launch that changes the repository's rules:** today `main` reaches PRE
only. Once the theme is installed on PROD, **every merge to `main` lands on both instances**.
`gh pr merge --auto` does not gate CI from this account, so watching the four required checks go
green before merging stops being hygiene and becomes the only thing between a red lint and 374
people.

T3's rollback is uninstalling. It is the only reversible thing in the plan, which is why it is
last.

## Tooling

**The choke point is three functions.** `bin/_discourse.py` reads `PRE_DISCOURSE_URL`,
`PRE_DISCOURSE_API_USERNAME`, `PRE_DISCOURSE_API_KEY` and `PRE_DISCOURSE_GLOBAL_API_KEY` in
`_url()`, `_user()` and `_key()`, and everything else in `bin/` goes through it. A
`DISCOURSE_INSTANCE` variable (`PRE`|`PROD`) composes the prefix, **with no default: undefined
means the script dies on its first call.** A default is the textbook silent failure — a script
meant for PRE writing to production. Every script prints its instance and URL on its first line
of output, so no log is ambiguous about what it ran against.

| | |
|---|---|
| **Unchanged** | `categories-reparent`, `categories-settings`, `tags-remove-from-topics`, `groups-sync-developers` — the last one derives from the names `Developers01`–`04`, whose existence on PROD is confirmed before it is assumed |
| **One parameter** | `categories-create-rooms` creates rooms already open to their groups; T1's additive tail needs them born closed to staff |
| **Their own PROD data** | `categories-propose`, `categories-move`, `forum-rooms-apply`. The logic is reused whole; the ids are not (`PLAZA=5`, `SECTION=3`, links 16 and 19, the `2026-09-11-*.json` files) |
| **Parameterised, not duplicated** | `tags-verify` and `categories-verify`, each reading the mapping file for its instance. The September plan created a separate `bin/prod-verify`; a duplicated verifier is a verifier that falls behind |

## Safety

`.gitignore` covers `*-prior-state.json` and `*-move-proposals.json` **by suffix, not by
folder**, so PROD's files must be born with those exact suffixes or they fall outside the net.
The repository is public by obligation: the theme is cloned over anonymous HTTPS, and making it
private takes it offline from every instance at once, which was measured the hard way.

**A debt that already exists, recorded without drama:**
`docs/superpowers/plans/data/2026-09-04-title-proposals.json` is tracked, and it is 92 KB of
topic titles with their ids from a `login_required` community. No names, no usernames, so it is
not September's incident, but it is the same family. The history is already public and
rewriting it is not an option — `main` blocks force-pushes and is what the theme pulls — so the
only thing that helps going forward: add the pattern to `.gitignore`, untrack the file, and let
PROD's equivalents be born unversioned.

The Global PROD key exists for this migration and is revoked when T3 closes, its line deleted
from `.env.local`. No key value is ever printed, not even redacted: August's leak was exactly
that, a dump "with secrets masked" whose key name was the site URL.

## Success criteria

**T1** — the ceilings raised before the first tag write; `#caag` and `#posters` still filtering
through synonyms; eight module groups, none shadowed by a category or by a tag, each `#slug`
returning its union; no tag below 3 uses except the `pendiente-etiquetar` queue; subject
coverage **measured by a fresh crawl, not derived**, and stated with its topic count and its
percentage separately; a three-letter term no longer answering 400; and **zero junk tags**,
confirmed by re-reading each written topic's tag *names* — not by the 200 and not by the count.

**T2** — every moved id located in its destination, never a verification by count; **no
category deleted**, the surplus ones empty, closed and out of the default sidebar; the three
category-keyed theme settings re-read and alive; and the thumbnail bill measured before each
batch and counted after.

**T3** — the `theme_site_settings` leak measured on PRE before anything is installed on PROD;
the ten settings resolving in preview against real data; user fields 2 and 4 verified **by
name**; one non-admin session signing off the five things the API cannot see; and the Global key
revoked.

## Rollback

**T1** is reversible in practice, not in principle. A merge cannot be undone —
`destroy_synonym` unlinks the tag but does not return its topics — so the Phase 0 capture is
what makes it recoverable, at one write per topic.

**T2** is undone by moving topics back, at the cost of a second thumbnail each. A verified
backup with a tested restore is still wanted, and must be **asked for explicitly rather than
inferred from a backup listing** — it is simply no longer the only thing standing between us
and a loss.

**T3** uninstalls.

**What has no rollback of any kind, and belongs on the first page: every write to a topic costs
it its list thumbnail, permanently.** By both routes, and a rebake does not bring it back —
tested on three PRE topics and checked again a week later. That is why every batch measures
before it writes, and why reverting a move costs a second thumbnail rather than none.

## Out of scope

Recorded so the next pass does not re-derive them.

- **The funcionalidad axis.** Never built on PRE either — Approach C, chosen deliberately — so
  `#tramitacion-administrativa` will return a large undifferentiated set on PROD too.
- **Reopening the topics the timer already closed.** Offered and declined: the setting alone,
  for future topics. *(PRE measured 113/120, 356/366 and 179/180 closed in categories 4, 5
  and 18 — a sum of 648 for three categories, on the other instance. PROD's own figure is
  unmeasured, and category 14 was never counted anywhere.)*
- **The real deletion of the emptied categories.** Decided after the launch.
- **The three permission faults** — the developers holding nothing on category 75, `Analiza`
  on 73, and "Comparte" (85) visible to eleven administrators while promising material shared
  by the community.
- **Restoring PROD from PRE.** The only option that guarantees exact parity, and the only one
  that can lose a month of activity.
- **PRE.** It remains the development target and is untouched, except for the
  `theme_site_settings` leak measurement in T3.

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

## As executed

### S1 · Pre-flight (T1 Task 2) — 2026-09-15, read-only

Capture `docs/superpowers/plans/data/2026-09-13-prod-capture.json`, gitignored, 425 KB. Nothing
written to PROD.

| Check | Measured |
|---|---|
| Keys | Global 200 on `/tags.json`, granular 403; the Global name appears once in `.env.local` |
| Version | **2026.9.0-latest**, above the `2026.7.0` floor |
| Ceilings | `max_tags_per_topic` **3**, `max_tag_length` **20** — Task 3 raises both |
| Search | `min_search_term_length` **6**, `max_tag_search_results` **3**, `max_tags_in_filter_list` 3 |
| Tagging rights | `tag_topic_allowed_groups` `1\|2\|10` (trust level 0 may tag), `create_tag_allowed_groups` `1\|3` |
| Edit notifications | `disable_tags_edit_notifications` **true**, `disable_category_edit_notifications` **true** — tag writes and moves notify no author |
| Vocabulary | **219** tags, **0** tag groups |
| Topics crawled | **1 306** in **36** categories; **309** with a thumbnail; **202** untagged |
| Thumbnails by category | 18→79, 5→47, 78→35, 4→32, 80→23, 81→22, 65→15, 62→13, 50→8, 59→8, 86→7, 67→5, 66→3, 84→3, 83→2, 87→2, and 1 each in 3, 14, 34, 56, 79 |
| Closed topics | 4→79, 5→241, 14→23, 18→314 (**657** in the four categories whose timer T1 clears; stay closed by decision) |
| Protected | `/t/2673` cat 59, **has thumbnail**; `/t/2683` cat 86, none; `/t/2690` cat 89, none |

**Departures from the plan's expectations.** 219 tags / 1 306 topics / 36 categories against the
spec's 218 / 1 297 / 35: the delta is ordinary activity plus category **89 "Anuncios"**, kept by
decision D1. Every crawl count exceeds `topic_count` by exactly one (the definition topic), except
category 3 (17 against 7, unlisted documents).

**What the staff log shows since the restore** (2026-07-28 → 2026-09-15, actions only):

- `deleted_unused_tags` ×50 is Discourse's **daily automatic job**, not a person.
- 2026-08-21: slugs of 4 and 5 changed (now `te-contamos`, `el-foro-del-certificado`),
  `default_composer_category` → 5, and the whole `default_categories_*` family.
- 2026-09-14: permissions changed on **59, 1, 86, 85**; category types unconfigured on 86, 85, 3;
  `Category Banners` and `discourse-gifs` components disabled.

**Two findings for later tranches, not T1.**

- `default_categories_tracking` `18|49|59|85|73|75|65`, `..._watching_first_post` `4|5|87|62|67`
  and `..._normal` `66|78|56|68|69` name categories T2 empties and closes. T2 must retune them with
  `default_navigation_menu_categories`, or new members inherit notification levels for dead
  categories.
- The public sidebar section "Community" links **Wiki → `/c/documentacion-analiza/74`**, a category
  that does not exist on PROD. Already broken today; T3 settles it with the chrome.

### S2 · Ceilings and renames (T1 Tasks 3–4) — 2026-09-15

First writes to PROD. No topic written, so no thumbnail spent.

- **Write probe departed from the plan**: it re-sent `max_tags_in_filter_list` at its current **3**
  instead of setting 30, because 30 would have changed the tag filter members see. 204.
- `max_tags_per_topic` 3 → **7**, `max_tag_length` 20 → **30**; both read back.
- `caag` (id 259, 130) → **`administracion-avanzada`**, `posters` (id 217, 171) → **`poster-evf`**,
  each with its old name recreated as a synonym; neither had synonyms before. Read back: same id,
  same count, old name absent as a base tag and present as a synonym, slug equal to the new name,
  no truncated `administracion-avanz*` variant.
- `#caag`/`#administracion-avanzada` and `#posters`/`#poster-evf` return the same topics as `#caag`
  and `#posters` did before. **That comparison covers the first search page only (50, the cap)**;
  the unchanged tag id and count are what show the `topic_tags` rows were not touched.

### S3 · Structural bulk tagging (T1 Task 5) — 2026-09-15, done

**Revalidated table** (read-only, before any write): 15 rows — the plan's 13 plus **49**
(`administracion-avanzada`) and **86** (`hackathon-eivissa`), both applied on PRE in August's
Phase 3. **793 writes, 158 thumbnails, 0 over the 7-tag ceiling**, `/t/2683` excluded.
Approved by Ricardo with three decisions: campaign tags take PRE's final names **`ideas-2024`,
`ideas-2025`, `ideas-v9`** (the plan said `campana-*`); 5 and 18 approved despite carrying 126 of the
158 thumbnails; `hackathon-eivissa` as on PRE rather than PROD's existing `hackathon`(12).

**Two measurements taken before approving the bill:**

- **A tag-only write does not bump.** Over PRE's 1 268 topics, the 115 topics written on 2026-08-27
  show no bump at all; the 220 written on 2026-09-06/07 show 12 (possibly the junk-tag incident's
  nine, not proven).
- **The thumbnails are not rendered anywhere once the theme ships.** Core's topic list does not show
  them; the theme reads `image_url` only in the highlights cards, and the one newsletter at risk
  (`/t/2575`) is not the newest one the card shows.

**Executor**: a throwaway (not in `bin/`) that re-reads each topic live, normalises tag names, saves
its prior tags to `2026-09-15-prod-s3-prior-state.json` (gitignored) **before** writing, skips
`PROTECTED`, re-reads names after the write and stops on the first mismatch. After each run it
compares `bumped_at` before/after and checks `/latest` page 1. Record by category, ids and counts
only: `docs/superpowers/plans/data/2026-09-13-prod-bulk-tagging.json`.

| Batch | Categories | Writes | Thumbnails lost | Bumped |
|---|---|---:|---:|---:|
| Pilot | 66, 54, 69, 49 | 7 | 0 | 0 |
| 2 | 68, 56, 50, 57, 87, 65 | 78 | 12 | 0 |
| 3 | 58 | 103 | 0 | 0 |
| 4 | 62, 86 (`/t/2683` skipped) | 24 | 20 | 0 |
| 5 | 5, in four chunks (75/60/60/65) | 260 | 47 | 0 |
| 6 | 18, in five chunks (60×4, 81) | 321 | 79 | 0 |
| **Total** | 15 categories | **793** | **158 predicted** | **0** |

Counts reconciled after batch 2: `administracion-avanzada` 130 → 160, `tasas` 5 → 24, `pid` 7 → 10,
`analiza` 74 → 90, `newsletter` 22 → 30; no junk names.

**Verified after the last batch, by re-crawl, not by the executor's own counts:**

- Every topic in the 15 categories carries its planned tags, **except `/t/2683`** (protected). None
  exceeds 7 tags. 793 topics in the prior-state file.
- Tag deltas against the S1 capture match the prior-state prediction exactly, with one exception:
  `administracion-avanzada` **130 → 758, +628 against +627**. The extra use is `/t/2696`, created in
  category 18 at 10:19 that day already carrying the tag; it is not in the prior state, so it was not
  written by the executor.
- **Thumbnails: 1 lost, 157 kept** of the 158 written topics that had one. This **contradicts the
  PRE rule** ("every topic write costs its thumbnail", measured on 2026.8.0 in August) — PROD runs
  2026.9.0, which may be the difference. **Provisional**: measured minutes after the writes, so it
  is re-checked at the start of S4 in case a deferred job clears them. The one loss is `/t/2063`
  (category 87). Until the re-check, keep budgeting thumbnails as spent.

**A mistake, and the rule it broke.** Two of the six tags the rows created **duplicate a spelling
PROD already had**: `app-movil`(2) beside `app-móvil`(3), and `cafe-con-certificados`(7) beside
`cafe-con-certificado`(8) — `/t/2063` now carries both. The rule was already written ("search the
vocabulary before creating", from `nueva-version-gestiona` on PRE) and the revalidated table printed
`ABSENT` for exact names only. Both pairs join S4's spelling merges; a synonym merge writes no topic.
The other four new tags (`hackathon-eivissa`, `ideas-2024`, `ideas-2025`, `ideas-v9`) collide with
nothing: `hackathon`(12), `ideas`(73) and `v9`(37) are distinct tags, not variants.

**A false alarm worth recognising.** After batch 4, six Hackathon topics (2484–2489) sat on `/latest`
page 1. Their `bumped_at` was **2026-09-13 18:37–23:33**, identical in the prior-state capture and
after the write, with last posts from June: someone edited them two days earlier. The check
"written ∩ /latest" cannot tell the two apart, so the executor now snapshots `/latest` before
writing and reports only topics *new* to page 1.

### S4 · Spelling merges, unaccented synonyms, tag group (T1 Tasks 6–7) — 2026-09-15

**Thumbnail re-check first**, over an hour after S3: of the 158 written topics that had a thumbnail,
**157 still have it**; `/t/2063` remains the only loss. On PROD (2026.9.0) a tag-only topic write
no longer clears the list thumbnail — **the PRE rule from August no longer holds here**. Keep
measuring before each batch rather than generalising either way.

**Families, canonical forms approved by Ricardo** (no accent, hyphenated; `webinars` chosen over
PROD's more used `seminarios` for parity with PRE). Every absorbed or renamed name kept as a
synonym; no topic written.

| Canonical | Absorbed | Count after |
|---|---|---:|
| `evento` | `eventos` | 32 |
| `tesauro` | `tesauros` | 82 |
| `webinars` | `seminarios`, `seminario`, `webinar` | 55 |
| `busquedas-avanzadas` (renamed) | `búsquedas-avanzadas`, `búsquedasavanzadas`, `busquedasavanzadas` | 16 |
| `cafe-con-certificados` | `cafe-con-certificado` (S3's duplicate) | 9 |
| `tramites-externos` (renamed) | `trámites-externos`, `tramitesexternos` | 13 |
| `integraciones` | `ìntegración` | 9 |
| `curso` | `cursos` | 7 |
| `paginas-informativas` (renamed) | `páginas-informativas`, `paginasinformativas` | 6 |
| `app-movil` | `app-móvil` (S3's duplicate) | 5 |
| `temas-y-categorias` | `temasycategorías` | 3 |
| `poster-evf` | `póster` (not caught by the root detector; added by hand) | 173 |
| `transformacion-digital` (renamed) | `transformación-digit` (truncated by the old 20-char limit) | 2 |

The first merge (`eventos` → `evento`) was verified before any other ran: `tags[][name]` with an
**existing** name does merge. Every count landed between the largest member and the sum.
**46 unaccented synonyms** added, 0 failed. Vocabulary **225 → 210** base tags.
`/t/2673` (protected) carries `evento`, the target of a merge; its tags did not change and no topic
was written.

**Search checks.** `#padron` 15, `#cafe-con-certificado` 9, `#transformación-digit` 2,
`#tramitacion-reglada` 50 = identical first page to `#tramitación-reglada` (88 uses, so the cap is
real). **`#seminarios` returns category 67, not the tag**: all 50 results are in 67, whose slug is
`seminarios` — category slug wins over tag name. Pre-existing, not caused by the merge. **For T2:**
closing 67 does not remove the shadow, the category must stop existing or change slug.

**`programa-certificacion` was not created.** `one_per_topic` would conflict with `/t/2582` and
`/t/2583` (category 5, Developers arrival announcements), which carry both `developers` and
`administracion-avanzada` — **the second added by S3's category-5 row**. On PRE the same two topics
carry only `developers`, and PRE's group is `one_per_topic: true`.

**Resolved the same day on Ricardo's yes.** `administracion-avanzada` removed from `/t/2582` and
`/t/2583` (prior tags saved to `2026-09-15-prod-s4-prior-state.json`, gitignored; neither had a
thumbnail; names read back). Full listings then showed **no topic carrying two programme tags**, and
`programa-certificacion` was created with `one_per_topic: true` over `administracion-avanzada` (756),
`analiza` (90) and `developers` (17) — all three non-empty, so none was invented.

### S5 · Module groups and verifier (T1 Task 8) — 2026-09-15

**Proposal derived from PRE's mapping resolved onto PROD**, not from PRE's lists: with PRE's groups
as they stood, coverage was 548 of 1 309 (41.86%) and three members were absent
(`circuitos-resolucion`, `circuitos-tramitacion`, `dietas`). Approved by Ricardo in two parts.

**Six more merges first**, the same calls he made on PRE, no topic written:
`circuitos`(16) + `circuitosresolucion`(36) → **`circuitos-resolucion`** (50);
`circuitosdetramitaci`(10) + `circuitostramitacion`(3) → **`circuitos-tramitacion`** (13);
`padrondehabitantes` → `padrón` (18); `órganos` → `órganos-colegiados` (10);
`pid` → **`integracion-pid`** (10); `seriesdocumentales` → **`serie-documental`** (4).
Every old name kept as a synonym.

**A mechanic that cost one attempt.** `órganos` carried S4's unaccented synonym `organos`, and a tag
with synonyms cannot be merged. `DELETE /tag/<id>/synonyms/<synonym>` looks the synonym up **by
numeric id** (`Tag.find_by(id: params[:synonym_id])` in `tags_controller.rb`), so the first attempt,
by name, answered 404 and the script stopped before any merge. Detached by id, `organos` became a
0-topic base tag and was absorbed with the rest.

**Eight groups created**, PRE's membership minus `dietas` (absent), plus four PROD additions:
`gestión-tributaria` → Gestión económica; `usuarios` and `delegación-funciones` → Configuración
Gestiona; `analítica` → Analítica de datos (on PRE it was deleted when room 90 absorbed its topics;
here that room does not exist until T2). Left outside by decision: generic (`documentación`,
`comunicación`), deleted on PRE (`interoperabilidad`, `desarrollo-software`, `debate-técnico`) and
genre/event tags (`actualizar`, `actualidad-gestiona`, `novedades`, `soporte` and others). Each group
returned exactly the requested members; none was invented. Mapping:
`docs/superpowers/plans/data/2026-09-13-prod-module-axis.json`.

**Shadowing** checked against PROD's tag and category slugs before creation: all eight clear.
**Filters**: every `#<group>` result carries a member tag — `#tramitacion-administrativa`,
`#configuracion-gestiona`, `#atencion-a-la-ciudadania`, `#registro-electronico` and `#inicio` hit the
50-result page cap with 50 of 50 member-tagged; `#gestion-economica` 44, `#analitica-de-datos` 37,
`#aplicaciones-y-servicios` 25.

**Coverage, by fresh crawl: 598 of 1 309 topics = 45.68%.** (PRE started its title pass from 47.3%.)

**`bin/tags-verify` now serves PROD.** Its use floor comes from the mapping (`"min_uses": null` on
PROD, 3 by default): PROD keeps ~100 tags below 3 uses because T1 deletes no tags, so the floor would
fail on a decision, not a typo. The empty-tag case the floor used to catch is now asserted directly:
a group member at 0 uses fails. The rename block carries all ten PROD renames with their synonyms.
Proven both ways on PROD — **red** with `Inicio` altered (`missing=['tasas'] extra=['firma']`), mapping
restored byte-identical, **green**: `8 groups, 0 deletions, 10 renames, 206 tags (no use floor), no
shadowed slug`. PRE still green after the change.

### S5b · Subject coverage by the title rule (T1 Task 9) — 2026-09-16

**Two batches, both reviewed by Ricardo before any write.**

- **A — menu path (110 topics, 173 tags).** Campaign-idea titles in categories 57 and 58 start with
  Gestiona's own menu path (`# 08 - CONFIGURACIÓN · 08.09 - TESAURO · …`). Tagging by **section and
  subsection**, ignoring the free-text description, replaced the plan's word rule for these: the word
  rule gave one topic `usuarios`, `tesauro` and `tramitación` at once. 13 topics keep no tag because
  their path has no equivalent (oficina de asistencia 5, avisos y alertas 4, chat 2, mi área 2).
- **B — title words (116 topics, 155 tags),** with 48 matches excluded up front: 27 `usuarios` that
  mean *certified users* (arrival announcements, encuentros), the 17 archived topics of category 3,
  and 4 homonyms (tooltip *de ayuda*, *asignación de un valor*, *registro de ideas*). Ricardo then
  cut three more on review: `fechas` kept only on `/t/374` and `/t/777` (11 were Analiza date
  formulas, not the Inicio feature), `analítica` only on `/t/908`, and `circuitos-tramitacion`
  dropped from `/t/389`. Those cuts left 11 topics with nothing to add, so the plan was **215**.

**Result: 215 topics written, 0 failures, 0 over the ceiling, all planned tags present on re-read.**
Coverage **598 → 814 of 1 310 = 62.14%** (measured by a fresh crawl, not derived). `bin/tags-verify`
green. **Thumbnails: 59 of 59 kept**, confirming S4's re-check.

**Four topics were bumped to the top of `/latest`, and that is a real leak.** `/t/2359`, `/t/2364`,
`/t/2365`, `/t/2366` — category 81, last posted in May — now carry `bumped_at` of the write minute
and sat at positions 0–3 of `/latest`. Nothing else on PROD bumped that day except two genuinely new
topics.

**The mechanism is only half explained, and the half that is known is worth keeping.** Core's
`PostRevisor#should_bump?` returns true when the edited post `is_first_post? && wiki? &&
post_changes.any?` — so **a tag write can bump a wiki first post**, which an ordinary post never does.
All four are wiki posts. But **wiki is not sufficient**: 13 other wiki topics in the same category,
written in the same minute, did not bump, and the revision diffs of a bumped and a non-bumped one are
indistinguishable (same version, same changed fields, same tags-only change). Not resolved; recorded
as a price rather than a theory.

**Practical rule for T2 and any later tagging: check `wiki` before writing.** A wiki first post can
surface a year-old topic at the top of the forum, which is exactly what this tranche must not do.

**Repair available and pending Ricardo's yes:** `PUT /t/<id>/reset-bump-date` (staff-only,
`topics#reset_bump_date`) resets `bumped_at` to the last post's date, returning the four to May.

**Decisions recorded 2026-09-15 (D1–D4):** keep PROD 89; move 86 with `/t/2683` after the poll closes
(2026-09-25 13:00Z); no date yet for T2; Ricardo is PROD's tagger, so no one else needs warning.


### The order of "Primeros pasos" is instance state, held by dates and closure

Category **78** (the sidebar's "Primeros pasos" link, `getting_started_category_id`) lists
six numbered guides, `0.` to `5.`, then "Acerca de la categoría", then the closed 2024
topics. Core cannot sort a category by title, so on PROD that order is held by two things
no file in this repo records, set on 2026-10-02:

- **Backdated timestamps.** Each guide's date was set with `PUT /t/<id>/change-timestamp`
  (`timestamp` = epoch seconds, past only) to 2026-06-01, seconds apart, newest first:
  `0.` 07:04:00 → `5.` 06:59:00. The category sorts by activity, so that is the order shown.
  It also keeps a new guide out of `/latest` and `/new`, which both key on recency — the
  visible post date says 1 June, and the change is in the staff action log.
- **Closure.** All six are closed, so no reply can bump one to the top. Closing does not
  bump (`TopicStatusUpdater` passes `bump: status.opening_topic?`). The definition topic is
  unpinned, so it sorts by its own date, between the guides and the 2024 topics.

**Adding or renumbering a guide means repeating both steps**, or it lands at the top of the
category and on page 1 of `/latest`. The guides were also edited not to invite replies —
a closed topic answers "Responde a este tema" with nothing.


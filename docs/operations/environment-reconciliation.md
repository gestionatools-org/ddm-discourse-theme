# PROD → PRE reconciliation before a theme change

Since 2026-10-05 administrators change PROD (interface, content, site configuration) directly from the admin panel, and PRE is the test bench. Before any theme design change, bring PRE up to PROD so the change is developed against the configuration it will meet in production.

## Order

1. **Diff, read-only on both instances.** List every difference, PROD value vs PRE value.
2. **Show the list to Ricardo** and agree what to copy. Some differences are intentional (environment-specific IDs, PRE-only test content).
3. **Write to PRE only**, capturing prior state first (scratchpad, never the repo).
4. **Re-read PRE** and confirm each value now matches.
5. Only then start the theme change; record the reconciliation in `traceability.md`.

PROD is never written during reconciliation. If something on PROD looks wrong, report it — do not "fix" it from here.

## Surfaces to diff

| Surface | Endpoint | Notes |
|---|---|---|
| Site settings | `GET /admin/site_settings.json` | Diff the full `{setting: value}` map, not a guessed subset. Copy with `PUT /admin/site_settings/<name>`; add `update_existing_user=true` for `default_*` user-preference settings when PROD applied them to existing users. |
| Theme settings | `GET /admin/themes/<id>.json` → `.settings` | PROD theme 14, PRE theme 15. `header_room_category_ids` differs by design (PROD 90/91/92, PRE 89/90/91). |
| Sidebar sections | `GET /sidebar_sections.json` | Public custom sections and the Community section's links. |
| Admin's personal sidebar | `GET /u/<username>.json` → `sidebar_tags`, `sidebar_category_ids` | Only if Ricardo changed his own menu. |
| Categories | `GET /categories.json`, `GET /c/<id>/show.json` | Map by name/slug, not by ID — PRE is a restored copy and later IDs collide. |
| Tags and tag groups | `GET /tags.json`, `GET /tag_groups.json` | Tags referenced by settings must exist on PRE. |
| Color schemes | `GET /admin/color_schemes.json` | |
| Theme version | `GET /admin/themes/<id>.json` → `remote_theme` | Both should be on the same `main` commit; check `remote_version` and `updated_at`, not `commits_behind`. |

## Cautions

- Protected PROD topics and member data rules in `prod-safety.md` still apply; reconciliation copies configuration, not member data.
- Content (topics, pinned posts, banners) is copied only when the theme change depends on it; ask first.
- Credentials: PROD `PROD_DISCOURSE_API_KEY`; PRE admin reads need `PRE_DISCOURSE_GLOBAL_API_KEY` (`PRE_DISCOURSE_API_KEY` returns 404 on admin routes, observed 2026-10-05).

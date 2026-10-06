# Email style

The outgoing email design is **site configuration, not theme**: Discourse does not read it from the theme repo. `email/template.html` and `email/style.css` are the source of truth and are pushed by hand to each instance (Admin → Personalizar → Estilo de email, or the API below). It wraps every email: digest, notifications and system messages.

## How core applies it (`lib/email/styles.rb`, `app/helpers/email_helper.rb`)

- **HTML** replaces the wrapper; it must keep `%{email_content}`, and keeps `%{html_lang}`, `%{email_preview}`, `%{dark_mode_meta_tags}`, `%{dark_mode_styles}`. `<style>` blocks survive into the sent email.
- **CSS** is parsed and **inlined, prepended** to each element's style. Consequences, all encoded in the file header:
  - Without `!important` it loses to the digest's own inline styles.
  - Between two of our `!important` rules, the **first** in the file wins.
  - `@media` would be flattened — responsive and dark rules go in the template.
  - An inline `!important` cannot be overridden by dark mode, so **colours live in the template's `<style>`** (light and dark side by side); the CSS field holds shape and type only.
- `apply_custom_styles_to_digest` must stay `true` (it is on both instances, 2026-10-05).

## Companion site settings

| Setting | Value | Was (both, 2026-10-05) |
|---|---|---|
| `email_accent_bg_color` | `#006D87` (petrol) | `#2F70AC` |
| `email_accent_fg_color` | `#FFFFFF` | `#FFFFFF` |
| `email_link_color` | `#006D87` | `#006699` |

## Hardcoded values

- Logo URLs point at PROD's `logo` / `logo_dark` uploads on S3 (absolute; PRE's `/uploads/**` 404s). If PROD replaces its logo, update both `src`.
- Links are relative (`/?`, `/my/preferences/emails`); core makes them absolute per instance. Only paths matching `\A/[^/]` qualify (`UrlHelper.absolute`): a bare `/` stays relative and Outlook prints it as a literal `[/]` before the logo and "Ir al foro" (seen 2026-10-06). The root is therefore written `/?`.

## Push and preview

```bash
set -a; source .env.local; set +a
U="${PRE_DISCOURSE_URL%/}"   # PROD only with Ricardo's go-ahead
curl -X PUT -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" \
  "$U/admin/customize/email_style.json" \
  --data-urlencode "email_style[html]@email/template.html" \
  --data-urlencode "email_style[css]@email/style.css"
# Rendered digest, styles applied:
curl -H … "$U/admin/email/preview-digest.json?last_seen_at=2026-08-01&username=<user>" | jq -r .html_content
```

The preview contains member names and avatars — keep it in the scratchpad, never in the repo. There is no preview endpoint for notifications; check one with a real email on PROD (PRE has outgoing email disabled).

## When the digest goes out

There is no send day or hour. `Jobs::EnqueueDigestEmails` runs every 30 minutes and picks each user whose digest is on, whose last digest attempt and last visit are both at least their frequency ago (PROD default `default_email_digest_frequency` = 10080, weekly), and who visited within `suppress_digest_email_after_days` (365). Nothing new since the last visit means no email. So it is a "you missed this" mail per user, never a weekly newsletter to everyone; a fixed-day send to all would need something outside core. `default_*` settings only reach new users unless the admin applies them to existing ones when saving.

PROD on 2026-10-05 (aggregate, Data Explorer, temporary queries deleted): 336 weekly, 11 daily, 41 off; ~204 eligible that day by absence. The first digests in the 90-day email log went out that day, 66 of them between 14:00 and 15:00 UTC, right after this template was applied.

## State (2026-10-05)

Applied on PRE and PROD (same files, same three settings). PROD's prior state was core default (empty CSS, default HTML), so rollback is resetting both fields to default and the two colours to `#2F70AC` / `#006699`. Digest verified on a real PROD preview (popular topics, popular posts, "Nuevo para ti"), light, dark and 390px. Notifications not yet seen rendered.

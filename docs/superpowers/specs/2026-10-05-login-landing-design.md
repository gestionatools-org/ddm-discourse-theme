# Login landing and a matching /login — design

**Date:** 2026-10-05 · **Status:** approved in conversation, pending spec review
**Scope:** theme only (components, SCSS, locales, settings). Instance changes are listed
under *Outside the theme* and are not made without Ricardo's explicit go-ahead.

## Why

`login_required` is on, so the splash at `/` is the only page an anonymous visitor ever
reaches. Today it is core's stock card: a small grey box with the logo off-centre, a
heading that wraps one word onto its own line, and a single button. It says nothing about
what the community is, that access is restricted, or what to do without an account —
and registration is closed, so that last question has no answer anywhere.

`/login` does not match it: the header logo sits left of centre, a large empty gap
separates it from the form, "Bienvenid@" heads the form, and "Email me a one-time login
code" is still in English.

## Decisions, each taken in conversation

1. **The splash becomes a landing** (option 3 of three: polish / split screen / landing).
   It serves both audiences — members who want in, and certified users arriving for the
   first time — with access first and the explanation below it.
2. **Layout A: centred hero, sections below** (chosen over a split screen and a fixed
   top bar with a dark hero).
3. **It must state that access is restricted** to people who belong to the community of
   Gestiona certified users.
4. **Two exits for whoever cannot get in:** a certified person without an account writes
   to `certificaciongestiona@espublico.com`; someone interested in certifying goes to
   `https://www.espublicogestiona.com/es/certificaciones-espublico/`.
5. **Heading: "La comunidad online de usuarios certificados de Gestiona".** The site's name,
   "Gestiona Avanza Forum", goes in the logo, not in text. The site `title` setting is
   not changed.
6. **`/login` drops "Bienvenid@"** visually; the heading stays for screen readers.
7. **Approach A of three:** replace the splash through the `login-required` wrapper outlet,
   rather than appending to core's card (`below-login`) or rewriting the site text.

## How core renders the two pages (read from `main`, 2026-10-05)

`frontend/discourse/app/templates/discovery/login-required.gjs` wraps its whole content in
`<PluginOutlet @name="login-required">`. Rendering into a wrapper outlet **replaces**
everything inside it, including four helpers the replacement must call itself:

```handlebars
{{hideApplicationHeaderButtons "search" "login" "signup" "menu"}}
{{hideApplicationSidebar}}
{{bodyClass "login-page"}}
{{bodyClass "static-login"}}
```

and the button, `<DButton class="btn-primary login-button" @action={{routeAction "showLogin"}}>`.

`frontend/discourse/app/templates/login.gjs` has no wrapper outlet; its structure is
fixed. Its outlets: `login-before-modal-body`, `login-header-bottom`, `login-wrapper`,
`login-after-modal-footer` (inside `LoginPageCta`), `below-login-page`.
`LoginPageCta` is **not rendered while the email-code form is open**, so anything placed
in `login-after-modal-footer` disappears exactly when a user is struggling to get in.
`below-login-page` renders unconditionally, desktop and mobile.

## Design

### Files

| File | Responsibility |
|---|---|
| `javascripts/discourse/api-initializers/login-required.gjs` | `api.renderInOutlet("login-required", LoginLanding)` and nothing else |
| `javascripts/discourse/api-initializers/below-login-page.gjs` | `api.renderInOutlet("below-login-page", LoginHelp)` |
| `javascripts/discourse/components/login-landing.gjs` | The landing. BEM block `login-landing` |
| `javascripts/discourse/components/login-help.gjs` | The two exits, shared by both pages. BEM block `login-help` |
| `stylesheets/layouts/login-landing.scss` | Page composition of the landing; added to `layouts/_index.scss` |
| `stylesheets/app/login.scss` | `/login` restyle, next to the existing rules |
| `locales/es.yml`, `locales/en.yml` | All strings, under `login_landing.*` and `login_help.*`, plus setting descriptions |
| `settings.yml` | `access_contact_email`, `certification_url` |
| `about.json` | `theme_version` 1.2.1 → 1.3.0 |

### Landing (`login-landing`)

- Calls the four core helpers above, so the header buttons and sidebar stay hidden and the
  body classes match core's.
- **Hero:** site logo, heading, subtitle, access button, restricted-access notice.
  - Logo from the `logo` site setting, so the upcoming "Forum" logo is swapped from the
    admin panel and updates header and landing at once. With no logo set, the site title
    renders as text.
  - Button keeps core's classes `btn-primary login-button` and action
    `routeAction "showLogin"` — the auth flow is untouched, and `core_features_spec.rb`'s
    `login` example, which clicks `.login-button`, keeps passing.
- **"Qué encontrarás dentro":** three fixed tiles describing sections that exist today —
  the programme rooms, the events agenda, ideas and resources (podcast, newsletter).
- **"¿No puedes entrar?":** `<LoginHelp />`.
- No API calls: an anonymous visitor cannot read the forum under `login_required`.
- Tiles take the system's 3px cyan top edge; heading in Roboto Slab; mobile stacks to one
  column below `sm`, using the viewport mixins only.

### `/login`

- Form in a white centred card with the 3px cyan edge, reusing the existing edge token.
- The vertical gap between logo and form removed.
- Header logo centred on `body.login-page`.
- The `WelcomeHeader` title visually hidden with the visually-hidden pattern, kept in the
  DOM for assistive technology. The site text `js.login.header_title` is not touched.
- `<LoginHelp />` below the card via `below-login-page`.
- **Every `/login` rule is scoped under `.login-fullpage`.** The landing also carries
  `body.login-page`, so an unscoped rule would leak into it.
- The provisional passkeys block in `login.scss` stays as is.
- Mobile uses a different core arrangement (header on top, CTA at the end); verified
  below `sm`, not assumed.

### `login-help`

Reads two theme settings:

| Setting | Type | Default | Empty means |
|---|---|---|---|
| `access_contact_email` | string | `certificaciongestiona@espublico.com` | the "certified, no account" exit is hidden |
| `certification_url` | string | `https://www.espublicogestiona.com/es/certificaciones-espublico/` | the "want to certify" exit is hidden |

Both empty hides the whole component. The email renders as a `mailto:` link; the URL opens
in a new tab with `rel="noopener noreferrer"`.

### Copy (`es`)

| Key | Text |
|---|---|
| `login_landing.title` | La comunidad online de usuarios certificados de Gestiona |
| `login_landing.subtitle` | Comparte experiencia, resuelve dudas y sigue aprendiendo con otros profesionales y con el equipo de Gestiona. |
| `login_landing.cta` | Accede a la comunidad |
| `login_landing.restricted` | Acceso exclusivo para personas certificadas en los programas de Gestiona. |
| `login_landing.inside.title` | Qué encontrarás dentro |
| `login_landing.inside.rooms.title` / `.body` | Foros de tu certificación / Un espacio por programa para compartir con quienes lo cursaron contigo. |
| `login_landing.inside.events.title` / `.body` | Agenda y eventos / Sesiones, congresos y encuentros de la comunidad. |
| `login_landing.inside.ideas.title` / `.body` | Ideas y recursos / Propuestas de mejora, podcast y newsletter. |
| `login_help.title` | ¿No puedes entrar? |
| `login_help.no_account.title` / `.body` | ¿Tienes la certificación y no tu cuenta? / Escríbenos a %{email} |
| `login_help.certify.title` / `.link` | ¿Quieres certificarte? / Conoce las certificaciones de Gestiona |

Neutral wording ("personas certificadas") avoids choosing between "certificado/a" and "@".
`en.yml` carries the English equivalents.

## Outside the theme

Recorded for the PROD → PRE reconciliation; none is made without Ricardo's go-ahead.

- "Email me a one-time login code" is a core string without a Spanish site text on these
  instances; a theme cannot override core translations. Fix: a site text per instance.
- `login_required.welcome_message` and `js.log_in` stop rendering on the splash. They are
  harmless and remain the fallback if the initializer is removed; cleaning them up is a
  later, separate decision.

## Rollout

1. **Reconcile PROD → PRE first**, per `docs/operations/environment-reconciliation.md`:
   read-only diff of every listed surface, agreed list, PRE-only writes with prior state in
   the scratchpad, re-read. Of most interest here: `login_required`, `logo`, `title`, the
   login method settings and the login site texts.
2. Branch `feat/login-landing`; `npx pnpm@10.28.0 lint` clean; PR; **watch the four
   required checks go green before merging** — `--auto` does not wait from this account.
3. **Verify before merging.** A merge reaches PRE and PROD at once, so the branch is
   verified on PRE through a second remote theme tracking `feat/login-landing`, made PRE's
   default only for the verification and reverted to theme 15 afterwards, then deleted.
   Needs Ricardo's go-ahead at that moment.
4. **Checklist**, on PRE with the branch and on PROD after the merge:
   anonymous landing on desktop and below 640px, light and dark schemes; the button opens
   `/login`; on `/login` the logo is centred, "Bienvenid@" is not visible, and the help is
   visible with the email-code form open too; `mailto:` and the external link work; no
   console errors; AA contrast and visible keyboard focus. **Ricardo performs the actual
   sign-in** — no credentials are typed and no populated form is captured.
5. After the merge: confirm PROD pulled the commit from `remote_theme.remote_version` and
   `updated_at`, not `commits_behind`; check PROD's anonymous landing; update
   `docs/operations/login.md` and `traceability.md`.

## Tests

- `test/integration/login-help-test.gjs` — both exits render with their links; each hides
  when its setting is empty; the component renders nothing when both are empty.
- `test/acceptance/login-landing-test.js` — with `login_required` and no user, `/` renders
  `.login-landing`, and its `.login-button` takes the visitor to `/login`.

## Reversibility

Deleting `api-initializers/login-required.gjs` restores core's splash with the instance's
existing site texts; deleting `api-initializers/below-login-page.gjs` removes the help from
`/login`. The SCSS is inert without them except for the `/login` card styling.

# Login landing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace core's login-required splash with a theme landing (layout A) and restyle `/login` to match, both carrying the same "¿No puedes entrar?" exits.

**Architecture:** `api.renderInOutlet` into core's `login-required` *wrapper* outlet replaces the splash with `LoginLanding`; `below-login-page` mounts `LoginHelp` under the `/login` form. All copy in theme locales, the two contact targets in theme settings, `/login` restyled in SCSS only.

**Tech Stack:** Discourse theme (Glimmer `.gjs`, SCSS with `lib/viewport`, `settings.yml`, YAML locales), QUnit integration/acceptance tests run by CI, `npx pnpm@10.28.0 lint`.

**Spec:** `docs/superpowers/specs/2026-10-05-login-landing-design.md`

## Global Constraints

- Branch `feat/login-landing`. Code, comments, identifiers and commits in English; every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Every user-visible string in `locales/es.yml` **and** `locales/en.yml`; every setting described under `theme_metadata.settings.<name>` in both.
- BEM blocks `login-landing` and `login-help`; standalone `--modifier` classes; no raw media queries — `viewport.until(sm)` etc.
- Colours from existing tokens only (`--ga-*`, core variables). The 3px edge is `var(--ga-edge-width) solid var(--ga-edge)`. Cyan `--ga-cyan-500` is never text on a light surface.
- The landing button keeps core's classes `btn-primary login-button` and action `routeAction "showLogin"`.
- Every `/login` rule is scoped under `.login-fullpage` — the landing also carries `body.login-page`.
- `theme_version` → `1.3.0`.
- **Tests do not run locally** — they need a Discourse checkout. They run in CI (`ci / frontend_tests`). Locally the gate is `npx pnpm@10.28.0 lint`. "Watch it fail" therefore means a CI run, and is done once for the whole branch (Task 4), not per step.
- PROD is read-only throughout except the merge itself. No credentials printed; no screenshots of a populated login form; never read `~/.discourse_theme`.
- Protected PROD topics 2683, 2690, 2673 are not touched by anything here; any step that would touch them stops and asks.

## Review Focus

1. **Email-code form open on `/login`** — the help must stay visible (why `below-login-page` and not `login-after-modal-footer`). Pinned by an acceptance test in Task 3.
2. **One or both settings empty** — the corresponding exit disappears; both empty removes the section, including its heading. Pinned in Task 1.
3. **No site logo configured** (fresh instance, or the logo cleared while swapping in the "Forum" version) — the landing shows the site title as text, not a broken image. Pinned in Task 2.
4. **Mobile below 640px** — core switches `/login` to a different arrangement; the card and help must not overflow. Verified by measurement in Task 5 (no automated test is possible: QUnit runs one viewport).
5. **Dark scheme** — petrol logo on a dark floor, cyan edge, link contrast. Verified in Task 5; the logo falls back to `site_logo_dark_url` when set.

---

### Task 0: Reconcile PROD → PRE (operational, no repo code)

Required first by `CLAUDE.md` for any theme design change. Procedure: `docs/operations/environment-reconciliation.md`.

**Files:**
- Create (scratchpad only, never the repo): `$SCRATCH/reconcile/diff.py`, `$SCRATCH/reconcile/prod-*.json`, `$SCRATCH/reconcile/pre-*.json`, `$SCRATCH/reconcile/pre-prior-state.json`

`$SCRATCH` = the session scratchpad directory.

- [ ] **Step 1: Write the read-only diff script**

```python
#!/usr/bin/env python3
"""Read-only PROD vs PRE diff for the reconciliation. Writes nothing to either instance."""
import json, os, pathlib, re, sys
sys.path.insert(0, str(pathlib.Path.cwd() / "bin"))
import _discourse as d

OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)

# PROD's admin-capable key is PROD_DISCOURSE_API_KEY (no GLOBAL key exists on PROD);
# PRE's admin reads need PRE_DISCOURSE_GLOBAL_API_KEY. `elevated` picks between them.
ELEVATED = {"PROD": False, "PRE": True}
THEME = {"PROD": 14, "PRE": 15}

SURFACES = {
    "site_settings": lambda: {s["setting"]: s["value"] for s in d.get("/admin/site_settings.json", ELEVATED[I])["site_settings"]},
    "theme_settings": lambda: {s["setting"]: s["value"] for s in d.get(f"/admin/themes/{THEME[I]}.json", ELEVATED[I])["theme"]["settings"]},
    "theme_remote": lambda: {k: d.get(f"/admin/themes/{THEME[I]}.json", ELEVATED[I])["theme"]["remote_theme"].get(k) for k in ("remote_version", "updated_at", "branch")},
    "site_texts": lambda: {t["id"]: t["value"] for t in d.get("/admin/customize/site_texts.json?overridden=true", ELEVATED[I])["site_texts"]},
    "sidebar_sections": lambda: d.get("/sidebar_sections.json", ELEVATED[I]),
    "categories": lambda: {c["slug"]: {k: c.get(k) for k in ("name", "position", "color", "read_restricted")} for c in d.get("/categories.json?include_subcategories=true", ELEVATED[I])["category_list"]["categories"]},
    "tags": lambda: sorted(t["id"] for t in d.get("/tags.json", ELEVATED[I])["tags"]),
    "color_schemes": lambda: {c["name"]: c["colors"] for c in d.get("/admin/color_schemes.json", ELEVATED[I])},
}

snap = {}
for I in ("PROD", "PRE"):
    os.environ["DISCOURSE_INSTANCE"] = I
    snap[I] = {name: fn() for name, fn in SURFACES.items()}
    (OUT / f"{I.lower()}-snapshot.json").write_text(json.dumps(snap[I], indent=1, ensure_ascii=False))

def diff(a, b, path=""):
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            yield from diff(a.get(k), b.get(k), f"{path}.{k}" if path else k)
    elif a != b:
        yield path, a, b

# Secret-valued settings differ by design and must never reach stdout: report that
# they differ, never what they hold.
SECRET = re.compile(r"secret|key|password|token", re.I)

for path, prod, pre in diff(snap["PROD"], snap["PRE"]):
    if SECRET.search(path):
        prod = pre = "<redacted, differs>"
    print(json.dumps({"path": path, "prod": prod, "pre": pre}, ensure_ascii=False)[:400])
```

The snapshot files hold secret values too; they stay in the scratchpad and are never printed or copied into the repo.

- [ ] **Step 2: Run it**

```bash
set -a && source .env.local && set +a
python3 "$SCRATCH/reconcile/diff.py" "$SCRATCH/reconcile" > "$SCRATCH/reconcile/diff.jsonl"
wc -l "$SCRATCH/reconcile/diff.jsonl"
```

Expected: a line count and two snapshot files. If a call answers 403/404, record which surface and key, do not retry with another key without asking.

- [ ] **Step 3: Summarise for Ricardo and stop**

Group the differences into: *copy to PRE*, *intentional (environment-specific IDs, e.g. `header_room_category_ids` 90/91/92 vs 89/90/91; PRE-only test content)*, *ask*. Call out specifically: `login_required`, `site_logo_url`/`site_logo_dark_url`, `title`, `enable_local_logins`, `enable_local_logins_via_email`, login site texts, `theme_remote`. **Wait for explicit approval of the list.**

- [ ] **Step 4: Capture PRE prior state, then write PRE only**

Write the approved keys' current PRE values to `$SCRATCH/reconcile/pre-prior-state.json` first. Then, per site setting: `PUT /admin/site_settings/<name>` with `{"<name>": value}` (elevated, `DISCOURSE_INSTANCE=PRE`); per site text: `PUT /admin/customize/site_texts/<id>` with `{"site_text": {"value": v, "locale": "es"}}` and `Accept: application/json` (no `.json` suffix — ids contain dots). Assert `os.environ["DISCOURSE_INSTANCE"] == "PRE"` before every write.

- [ ] **Step 5: Re-read PRE and confirm**

Re-run Step 2; every approved path must be gone from `diff.jsonl`. Record the reconciliation (surfaces, count copied, count intentional — no values) in `traceability.md`.

---

### Task 1: Settings, locales and `LoginHelp`

**Files:**
- Modify: `settings.yml` (append)
- Modify: `locales/es.yml`, `locales/en.yml`
- Create: `javascripts/discourse/components/login-help.gjs`
- Create: `stylesheets/blocks/login-help.scss`; Modify: `stylesheets/blocks/_index.scss`
- Test: `test/integration/login-help-test.gjs`

**Interfaces:**
- Produces: `LoginHelp` (default export, no args). Root `section.login-help`; items `li.login-help__item.--no-account` / `.--certify`; links `a.login-help__link`. Renders nothing when both settings are blank.
- Produces settings `access_contact_email: string`, `certification_url: string`.

- [ ] **Step 1: Write the failing test**

```gjs
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LoginHelp from "../../discourse/components/login-help";

const EMAIL = "certificaciongestiona@espublico.com";
const URL = "https://www.espublicogestiona.com/es/certificaciones-espublico/";

module("Espublico Theme | Integration | login help", function (hooks) {
  setupRenderingTest(hooks);

  // `settings` is a shared global across the whole QUnit run: every test
  // starts from the shipped defaults, whatever the previous one left.
  hooks.beforeEach(function () {
    settings.access_contact_email = EMAIL;
    settings.certification_url = URL;
  });

  test("both exits render with their links", async function (assert) {
    await render(<template><LoginHelp /></template>);

    assert.dom(".login-help__title").exists();
    assert
      .dom(".login-help__item.--no-account .login-help__link")
      .hasAttribute("href", `mailto:${EMAIL}`)
      .hasText(EMAIL);
    assert
      .dom(".login-help__item.--certify .login-help__link")
      .hasAttribute("href", URL)
      .hasAttribute("target", "_blank")
      .hasAttribute("rel", "noopener noreferrer");
  });

  test("a blank email hides only its exit", async function (assert) {
    settings.access_contact_email = "  ";
    await render(<template><LoginHelp /></template>);

    assert.dom(".login-help__item.--no-account").doesNotExist();
    assert.dom(".login-help__item.--certify").exists();
  });

  test("a blank URL hides only its exit", async function (assert) {
    settings.certification_url = "";
    await render(<template><LoginHelp /></template>);

    assert.dom(".login-help__item.--certify").doesNotExist();
    assert.dom(".login-help__item.--no-account").exists();
  });

  test("both blank renders nothing, heading included", async function (assert) {
    settings.access_contact_email = "";
    settings.certification_url = "";
    await render(<template><LoginHelp /></template>);

    assert.dom(".login-help").doesNotExist();
  });
});
```

- [ ] **Step 2: Add the settings** (append to `settings.yml`)

```yaml
# The two ways out for a visitor who cannot sign in, shown on the login landing
# and under the /login form. Registration is closed, so these are the only
# answers the site gives to "how do I get in?". Blank hides that exit; both
# blank hides the whole "¿No puedes entrar?" section.
access_contact_email:
  type: string
  default: "certificaciongestiona@espublico.com"

certification_url:
  type: string
  default: "https://www.espublicogestiona.com/es/certificaciones-espublico/"
```

- [ ] **Step 3: Add the locale keys**

`locales/es.yml` — under `theme_metadata.settings`:

```yaml
      access_contact_email: "Correo al que escribe quien tiene la certificación pero no puede entrar. Se muestra en la portada de acceso y bajo el formulario de /login. Vacío oculta esa salida."
      certification_url: "Página con la información de las certificaciones de Gestiona, para quien todavía no la tiene. Se abre en una pestaña nueva. Vacío oculta esa salida."
```

and at top level:

```yaml
  # La portada que ve quien llega sin sesión (login_required está activo) y la
  # ayuda bajo el formulario de /login. El registro está cerrado: estos textos
  # son lo único que explica qué es la comunidad y cómo se entra.
  login_landing:
    title: "La comunidad online de usuarios certificados de Gestiona"
    subtitle: "Comparte experiencia, resuelve dudas y sigue aprendiendo con otros profesionales y con el equipo de Gestiona."
    cta: "Accede a la comunidad"
    restricted: "Acceso exclusivo para personas certificadas en los programas de Gestiona."
    inside:
      title: "Qué encontrarás dentro"
      rooms:
        title: "Foros de tu certificación"
        body: "Un espacio por programa para compartir con quienes lo cursaron contigo."
      events:
        title: "Agenda y eventos"
        body: "Sesiones, congresos y encuentros de la comunidad."
      ideas:
        title: "Ideas y recursos"
        body: "Propuestas de mejora, podcast y newsletter."
  login_help:
    title: "¿No puedes entrar?"
    no_account:
      title: "¿Tienes la certificación y no tu cuenta?"
      body: "Escríbenos a"
    certify:
      title: "¿Quieres certificarte?"
      link: "Conoce las certificaciones de Gestiona"
```

`locales/en.yml` — same keys:

```yaml
      access_contact_email: "Address for certified users who cannot sign in. Shown on the login landing and under the /login form. Blank hides that exit."
      certification_url: "Page about Gestiona certifications, for visitors who do not hold one yet. Opens in a new tab. Blank hides that exit."
```

```yaml
  login_landing:
    title: "The online community of Gestiona certified users"
    subtitle: "Share experience, solve doubts and keep learning with other professionals and with the Gestiona team."
    cta: "Enter the community"
    restricted: "Access is restricted to people certified in Gestiona programmes."
    inside:
      title: "What you will find inside"
      rooms:
        title: "Your certification's forums"
        body: "One space per programme, shared with those who took it with you."
      events:
        title: "Agenda and events"
        body: "Sessions, conferences and community meetings."
      ideas:
        title: "Ideas and resources"
        body: "Improvement proposals, podcast and newsletter."
  login_help:
    title: "Can't get in?"
    no_account:
      title: "Certified but without an account?"
      body: "Write to us at"
    certify:
      title: "Want to get certified?"
      link: "Discover Gestiona certifications"
```

- [ ] **Step 4: Write the component**

`javascripts/discourse/components/login-help.gjs`:

```gjs
import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

// The two ways out for a visitor who cannot sign in. Registration is closed,
// so this is the only place the site answers "how do I get in?".
//
// Shared by the login landing and /login. On /login it is mounted through
// `below-login-page` rather than `login-after-modal-footer`: the latter lives
// inside core's LoginPageCta, which is not rendered while the email-code form
// is open — exactly when someone is struggling to get in.
export default class LoginHelp extends Component {
  get email() {
    return settings.access_contact_email?.trim();
  }

  get certificationUrl() {
    return settings.certification_url?.trim();
  }

  get mailto() {
    return `mailto:${this.email}`;
  }

  get visible() {
    return Boolean(this.email || this.certificationUrl);
  }

  <template>
    {{#if this.visible}}
      <section class="login-help">
        <h2 class="login-help__title">
          {{i18n (themePrefix "login_help.title")}}
        </h2>
        <ul class="login-help__list">
          {{#if this.email}}
            <li class="login-help__item --no-account">
              <h3 class="login-help__item-title">
                {{i18n (themePrefix "login_help.no_account.title")}}
              </h3>
              <p class="login-help__item-body">
                {{i18n (themePrefix "login_help.no_account.body")}}
                <a class="login-help__link" href={{this.mailto}}>
                  {{this.email}}
                </a>
              </p>
            </li>
          {{/if}}
          {{#if this.certificationUrl}}
            <li class="login-help__item --certify">
              <h3 class="login-help__item-title">
                {{i18n (themePrefix "login_help.certify.title")}}
              </h3>
              <p class="login-help__item-body">
                <a
                  class="login-help__link"
                  href={{this.certificationUrl}}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {{i18n (themePrefix "login_help.certify.link")}}
                </a>
              </p>
            </li>
          {{/if}}
        </ul>
      </section>
    {{/if}}
  </template>
}
```

- [ ] **Step 5: Style it**

`stylesheets/blocks/login-help.scss`:

```scss
// "¿No puedes entrar?" — the two exits, shared by the login landing and
// /login. Where it sits on each page is the page's business (layouts/
// login-landing.scss, app/login.scss); this file is only its own look.
.login-help {
  &__title {
    margin: 0 0 0.75rem;
    font-size: var(--font-up-1);
  }

  &__list {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(14rem, 1fr));
    gap: 0.75rem;
    margin: 0;
    padding: 0;
    list-style: none;
  }

  &__item {
    padding: 0.875rem 1rem;
    background: var(--ga-muted);
    border-radius: var(--d-border-radius);
  }

  &__item-title {
    margin: 0 0 0.25rem;
    font-size: var(--font-0);
  }

  &__item-body {
    margin: 0;
    color: var(--ga-muted-fg);
  }

  // Petrol on light, brand cyan on dark: core's --tertiary already carries
  // that inversion (see brand/colors.scss).
  &__link {
    color: var(--tertiary);
    font-weight: 500;
    overflow-wrap: anywhere;
  }
}
```

Append `@import "login-help";` to `stylesheets/blocks/_index.scss`.

- [ ] **Step 6: Lint**

Run: `npx pnpm@10.28.0 lint`
Expected: exit 0. Fix with `npx pnpm@10.28.0 lint:fix` and re-run if prettier complains.

- [ ] **Step 7: Commit**

```bash
git add settings.yml locales/es.yml locales/en.yml javascripts/discourse/components/login-help.gjs stylesheets/blocks/login-help.scss stylesheets/blocks/_index.scss test/integration/login-help-test.gjs
git commit -m "feat(login): add the shared 'can't get in?' help

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: The landing (`LoginLanding` into `login-required`)

**Files:**
- Create: `javascripts/discourse/api-initializers/login-required.gjs`
- Create: `javascripts/discourse/components/login-landing.gjs`
- Create: `stylesheets/layouts/login-landing.scss`; Modify: `stylesheets/layouts/_index.scss`
- Test: `test/acceptance/login-landing-test.js`

**Interfaces:**
- Consumes: `LoginHelp` from Task 1.
- Produces: root `.login-landing`; button `.login-landing__cta.btn-primary.login-button`; logo `img.login-landing__logo` or text `.login-landing__site-title`.

- [ ] **Step 1: Write the failing test**

`test/acceptance/login-landing-test.js`:

```js
import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

// The topbar above the header asks for /about.json on every route. Under
// login_required an anonymous visitor gets a 403, which hides the band — the
// same thing production does.
function stubAbout(server, helper) {
  server.get("/about.json", () => helper.response(403, {}));
}

acceptance("Login landing", function (needs) {
  needs.settings({
    login_required: true,
    site_logo_url: "/images/logo.png",
    title: "Gestiona Avanza",
  });
  needs.pretender(stubAbout);

  test("replaces core's splash", async function (assert) {
    await visit("/");

    assert.dom(".login-landing").exists();
    assert.dom(".login-landing__logo").hasAttribute("src", "/images/logo.png");
    assert.dom(".login-landing__restricted").exists();
    assert.dom(".login-landing__inside-item").exists({ count: 3 });
    assert.dom(".login-landing .login-help").exists();
    assert
      .dom(".login-welcome .login-content")
      .doesNotExist("core's server-composed block is gone");
  });

  test("the button opens /login", async function (assert) {
    await visit("/");
    await click(".login-landing .login-button");

    assert.strictEqual(currentURL(), "/login");
    assert.dom(".login-fullpage").exists();
  });
});

acceptance("Login landing | no site logo", function (needs) {
  needs.settings({
    login_required: true,
    site_logo_url: "",
    title: "Gestiona Avanza",
  });
  needs.pretender(stubAbout);

  test("falls back to the site title as text", async function (assert) {
    await visit("/");

    assert.dom(".login-landing__logo").doesNotExist();
    assert.dom(".login-landing__site-title").hasText("Gestiona Avanza");
  });
});
```

- [ ] **Step 2: Write the initializer**

`javascripts/discourse/api-initializers/login-required.gjs`:

```gjs
import { apiInitializer } from "discourse/lib/api";
import LoginLanding from "../components/login-landing";

// The page an anonymous visitor reaches, since `login_required` is on.
//
// `login-required` is a *wrapper* outlet: core's
// templates/discovery/login-required.gjs wraps its whole content in it, so
// rendering here replaces the stock splash — including the helpers that hide
// the header buttons and sidebar, which LoginLanding therefore calls itself.
// Deleting this file restores core's splash and its site texts.
export default apiInitializer((api) => {
  api.renderInOutlet("login-required", LoginLanding);
});
```

- [ ] **Step 3: Write the component**

`javascripts/discourse/components/login-landing.gjs`:

```gjs
import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import LoginHelp from "./login-help";

// What the community holds, in the order the landing lists it. Each entry
// describes a section that exists today: the programme rooms in the header,
// the events lane, and the ideas lane plus the podcast/newsletter highlights.
const INSIDE = [
  { key: "rooms", icon: "users" },
  { key: "events", icon: "calendar-days" },
  { key: "ideas", icon: "lightbulb" },
];

// The login-required landing. Static by necessity: under `login_required` an
// anonymous visitor cannot read anything from the forum, so every word comes
// from the theme's locales and the two exits from its settings.
export default class LoginLanding extends Component {
  @service siteSettings;

  // Read from the site's own logo rather than a theme asset, so the "Forum"
  // logo is swapped from the admin panel and updates header and landing at once.
  get logoUrl() {
    return this.siteSettings.site_logo_url;
  }

  get logoDarkUrl() {
    return this.siteSettings.site_logo_dark_url;
  }

  get siteTitle() {
    return this.siteSettings.title;
  }

  get insideItems() {
    return INSIDE.map(({ key, icon }) => ({
      key,
      icon,
      title: i18n(themePrefix(`login_landing.inside.${key}.title`)),
      body: i18n(themePrefix(`login_landing.inside.${key}.body`)),
    }));
  }

  <template>
    {{hideApplicationHeaderButtons "search" "login" "signup" "menu"}}
    {{hideApplicationSidebar}}
    {{bodyClass "login-page"}}
    {{bodyClass "static-login"}}

    <div class="login-landing">
      <section class="login-landing__hero">
        {{#if this.logoUrl}}
          <picture>
            {{#if this.logoDarkUrl}}
              <source
                srcset={{this.logoDarkUrl}}
                media="(prefers-color-scheme: dark)"
              />
            {{/if}}
            <img
              class="login-landing__logo"
              src={{this.logoUrl}}
              alt={{this.siteTitle}}
            />
          </picture>
        {{else}}
          <p class="login-landing__site-title">{{this.siteTitle}}</p>
        {{/if}}

        <h1 class="login-landing__title">
          {{i18n (themePrefix "login_landing.title")}}
        </h1>
        <p class="login-landing__subtitle">
          {{i18n (themePrefix "login_landing.subtitle")}}
        </p>

        <DButton
          class="btn-primary login-button login-landing__cta"
          @action={{routeAction "showLogin"}}
          @translatedLabel={{i18n (themePrefix "login_landing.cta")}}
        />

        <p class="login-landing__restricted">
          {{dIcon "lock"}}
          <span>{{i18n (themePrefix "login_landing.restricted")}}</span>
        </p>
      </section>

      <section class="login-landing__inside">
        <h2 class="login-landing__section-title">
          {{i18n (themePrefix "login_landing.inside.title")}}
        </h2>
        <ul class="login-landing__inside-list">
          {{#each this.insideItems as |item|}}
            <li class="login-landing__inside-item">
              {{dIcon item.icon}}
              <h3 class="login-landing__inside-title">{{item.title}}</h3>
              <p class="login-landing__inside-body">{{item.body}}</p>
            </li>
          {{/each}}
        </ul>
      </section>

      <div class="login-landing__help">
        <LoginHelp />
      </div>
    </div>
  </template>
}
```

- [ ] **Step 4: Style the page**

`stylesheets/layouts/login-landing.scss`:

```scss
// The login-required landing — the only page an anonymous visitor reaches.
// Layout A: a centred hero with the access first, then what the community
// holds, then the exits for whoever cannot get in. LoginHelp's own look lives
// in blocks/login-help.scss; this file only places it.
.login-landing {
  --login-landing-width: 56rem;

  display: flex;
  flex-direction: column;
  gap: 2.5rem;
  max-width: var(--login-landing-width);
  margin: 0 auto;
  padding: 3rem 0 4rem;

  &__hero {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
    padding: 2.5rem 2rem;
    text-align: center;
    background: var(--ga-card);
    border: 1px solid var(--ga-border);
    border-top: var(--ga-edge-width) solid var(--ga-edge);
    border-radius: var(--d-border-radius-large);
  }

  &__logo {
    display: block;
    height: 3.5rem;
    width: auto;
  }

  &__site-title {
    margin: 0;
    font-family: var(--heading-font-family);
    font-size: var(--font-up-3);
    font-weight: bold;
  }

  &__title {
    max-width: 36rem;
    margin: 0;
    font-family: RobotoSlab, var(--heading-font-family);
    font-size: var(--font-up-5);
    line-height: var(--line-height-medium);
    text-wrap: balance;
  }

  &__subtitle {
    max-width: 36rem;
    margin: 0;
    color: var(--ga-muted-fg);
    font-size: var(--font-up-1);
  }

  &__restricted {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    margin: 0;
    padding: 0.5rem 0.875rem;
    color: var(--primary-high);
    background: var(--ga-accent-surface);
    border-inline-start: var(--ga-edge-width) solid var(--ga-edge);
    border-radius: var(--d-border-radius);
    font-size: var(--font-down-1);
  }

  &__section-title {
    margin: 0 0 1rem;
    font-size: var(--font-up-2);
  }

  &__inside-list {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
    margin: 0;
    padding: 0;
    list-style: none;
  }

  &__inside-item {
    padding: 1.25rem;
    background: var(--ga-card);
    border: 1px solid var(--ga-border);
    border-top: var(--ga-edge-width) solid var(--ga-edge);
    border-radius: var(--d-border-radius);

    .d-icon {
      color: var(--tertiary);
      font-size: var(--font-up-2);
    }
  }

  &__inside-title {
    margin: 0.5rem 0 0.25rem;
    font-size: var(--font-0);
  }

  &__inside-body {
    margin: 0;
    color: var(--ga-muted-fg);
  }

  @include viewport.until(md) {
    &__inside-list {
      grid-template-columns: 1fr;
    }
  }

  @include viewport.until(sm) {
    gap: 1.5rem;
    padding: 1.5rem 0 2.5rem;

    &__hero {
      padding: 1.75rem 1.25rem;
    }

    &__title {
      font-size: var(--font-up-3);
    }
  }
}
```

Add `@import "login-landing";` to `stylesheets/layouts/_index.scss`.

- [ ] **Step 5: Lint**

Run: `npx pnpm@10.28.0 lint` — Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add javascripts/discourse/api-initializers/login-required.gjs javascripts/discourse/components/login-landing.gjs stylesheets/layouts/login-landing.scss stylesheets/layouts/_index.scss test/acceptance/login-landing-test.js
git commit -m "feat(login): replace the login-required splash with a landing

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `/login` restyle and help

**Files:**
- Create: `javascripts/discourse/api-initializers/below-login-page.gjs`
- Modify: `stylesheets/app/login.scss` (append; the existing `.login-welcome__description` and passkeys blocks stay)
- Test: `test/acceptance/login-landing-test.js` (append a module)

**Interfaces:**
- Consumes: `LoginHelp` from Task 1.

- [ ] **Step 1: Write the failing test** (append to `test/acceptance/login-landing-test.js`)

```js
acceptance("Login page | help", function (needs) {
  needs.settings({ login_required: true, enable_local_logins_via_email: true });
  needs.pretender(stubAbout);

  test("is under the form", async function (assert) {
    await visit("/login");

    assert.dom(".login-fullpage .login-help").exists();
  });

  // Review focus 1: LoginPageCta disappears with the email-code form; the help
  // must not go with it.
  test("stays with the email-code form open", async function (assert) {
    await visit("/login");
    await click("#email-login-link");

    assert.dom(".login-page-cta").doesNotExist();
    assert.dom(".login-fullpage .login-help").exists();
  });
});
```

`#email-login-link` is core's id for "Email me a one-time login code" in `local-login-form.gjs`; confirm it against core `main` before relying on it (`curl -sS https://raw.githubusercontent.com/discourse/discourse/main/frontend/discourse/app/components/local-login-form.gjs | grep -n "email-login\|onShowCodeLogin"`) and use the selector that file actually renders.

- [ ] **Step 2: Write the initializer**

`javascripts/discourse/api-initializers/below-login-page.gjs`:

```gjs
import { apiInitializer } from "discourse/lib/api";
import LoginHelp from "../components/login-help";

// The "can't get in?" exits under the /login form. `below-login-page` and not
// `login-after-modal-footer`: the latter is inside core's LoginPageCta, which
// is not rendered while the email-code form is open.
export default apiInitializer((api) => {
  api.renderInOutlet("below-login-page", LoginHelp);
});
```

- [ ] **Step 3: Style `/login`** (append to `stylesheets/app/login.scss`)

```scss
// ---------------------------------------------------------------------------
// /login, matched to the landing: the form in a centred white card with the
// system's 3px edge, the help under it, the header logo centred.
//
// Everything but the header rule is scoped under `.login-fullpage`: the
// landing carries `body.login-page` too, so an unscoped rule would leak into
// it. The header rule may — a centred logo is right on both pages.
.login-page .d-header .contents {
  justify-content: center;
}

.login-fullpage {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.25rem;
  padding: 2rem 1rem 3rem;

  .login-body {
    width: 100%;
    max-width: 28rem;
    margin: 0;
    padding: 2rem;
    background: var(--ga-card);
    border: 1px solid var(--ga-border);
    border-top: var(--ga-edge-width) solid var(--ga-edge);
    border-radius: var(--d-border-radius-large);
  }

  // "Bienvenid@" is dropped from sight but kept as the form's heading for
  // assistive technology. The site text js.login.header_title is untouched.
  .login-title {
    position: absolute;
    width: 1px;
    height: 1px;
    margin: -1px;
    padding: 0;
    overflow: hidden;
    clip-path: inset(50%);
    white-space: nowrap;
    border: 0;
  }

  .login-help {
    width: 100%;
    max-width: 28rem;
  }

  @include viewport.until(sm) {
    padding-top: 1rem;

    .login-body {
      padding: 1.25rem;
    }
  }
}
```

Core's own `/login` stylesheet sets margins and min-heights on `.login-fullpage` and `.login-body` that may outrank these. Do not guess: in Task 5, measure the rendered gap and card width with `getComputedStyle` and adjust specificity using the cascade notes in `docs/operations/css-cascade-notes.md`.

- [ ] **Step 4: Lint** — `npx pnpm@10.28.0 lint`, expected exit 0.

- [ ] **Step 5: Commit**

```bash
git add javascripts/discourse/api-initializers/below-login-page.gjs stylesheets/app/login.scss test/acceptance/login-landing-test.js
git commit -m "feat(login): restyle /login to match the landing and add the help

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Version, PR and CI

**Files:**
- Modify: `about.json` (`theme_version`)
- Modify: `stylesheets/app/login.scss` header comment (lines 1–11): it says the heading and subtitle are site texts; now they are theme locales and the site texts only apply if the landing initializer is removed.

- [ ] **Step 1:** `about.json` → `"theme_version": "1.3.0"`; rewrite the `login.scss` header comment to match the new ownership. Lint. Commit `chore: bump theme_version to 1.3.0`.
- [ ] **Step 2:** `git push -u origin feat/login-landing`; `gh pr create` with a body summarising the spec, the test list and the verification still pending, ending with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- [ ] **Step 3: Watch CI.** `gh pr checks --watch`. Expected: `ci / linting`, `ci / backend_tests`, `ci / frontend_tests`, `ci / system_tests` green. A red `frontend_tests` is debugged from its log (`gh run view --log-failed`), max two fix attempts before asking Ricardo. **Do not merge yet.**

---

### Task 5: Verify the branch on PRE before merging

Needs Ricardo's explicit go-ahead at this moment: it changes PRE's default theme temporarily.

- [ ] **Step 1:** Ask. On yes: record PRE's current default theme id (expected 15) in the scratchpad.
- [ ] **Step 2:** Install a second remote theme on PRE tracking the branch: `POST /admin/themes/import.json` with `remote=https://github.com/gestionatools-org/ddm-discourse-theme.git`, `branch=feat/login-landing` (elevated, `DISCOURSE_INSTANCE=PRE`). Copy theme 15's non-default theme settings onto it (`PUT /admin/themes/<new>/setting`). Make it default: `PUT /admin/themes/<new>.json` with `{"theme":{"default":true}}`.
- [ ] **Step 3: Checklist, anonymous, Playwright** (measure; capture only empty forms, move captures to the scratchpad):
  - landing at 1440×900 and 390×844, light and `prefers-color-scheme: dark`;
  - logo centred (`getBoundingClientRect` centre within 2px of the viewport centre), no horizontal scroll (`scrollWidth <= innerWidth`);
  - `.login-button` → `/login`; on `/login`: header logo centred, `.login-title` not visible but in the DOM, gap between header bottom and card top < 48px, `.login-help` visible; open the email-code form and confirm `.login-help` is still visible;
  - `mailto:` href and the external link's `target`/`rel`;
  - no console errors;
  - contrast of `.login-help__link`, `.login-landing__restricted` and subtitle ≥ 4.5:1 in both schemes; visible focus ring when tabbing to the button and links.
- [ ] **Step 4:** Ask Ricardo to perform a real sign-in on PRE. Fix anything found on the branch (CI again), re-verify.
- [ ] **Step 5:** Restore theme 15 as PRE's default and delete the temporary theme. Confirm with `GET /admin/themes.json` that 15 is default.

---

### Task 6: Merge, confirm PROD, document

- [ ] **Step 1:** Confirm with Ricardo, then `gh pr merge --squash` only with the four checks green.
- [ ] **Step 2:** Force the pull on both instances if `remote_version` has not moved within a few minutes: `PUT /admin/themes/<id>.json` with `{"theme":{"remote_update":true}}` — PRE 15 (elevated) and, with Ricardo's OK, PROD 14. Confirm `remote_theme.remote_version` equals the merge commit and `updated_at` is fresh. Do not trust `commits_behind`.
- [ ] **Step 3:** Repeat the Task 5 Step 3 checklist on PROD, anonymous only, read-only.
- [ ] **Step 4:** Update `docs/operations/login.md`: the landing now owns the copy; the site texts `login_required.welcome_message` / `js.log_in` are the fallback only; the email-code string still needs a Spanish site text per instance (pending Ricardo's decision). Add a concise, non-sensitive entry to `traceability.md`. Commit on a docs branch, PR, CI, merge.

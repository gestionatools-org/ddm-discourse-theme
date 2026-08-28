# Page Hero Band Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a heading band — title, subtitle, and a "Hacer una pregunta" button that opens the composer — to the top of the homepage and every listing page, reading its text from the category when there is one.

**Architecture:** One presentational component (`PageHero`) driven by one pure function (`heroContentFor`), mounted twice: a plugin outlet serves the listings, and a thin Block wrapper reaches the custom homepage, which has no other way in. The pure function holds every decision that can be wrong and is unit-tested without a DOM.

**Tech Stack:** Discourse theme — Glimmer `.gjs` components, SCSS with the repo's `viewport` mixins, QUnit tests run only in CI.

**Spec:** `docs/superpowers/specs/2026-08-28-page-hero-band-design.md`

## Global Constraints

- **Language split:** code, comments, commits and identifiers in **English**; user-visible strings live in `locales/en.yml` and `locales/es.yml` and are referenced by i18n key. Never hardcode a display string in a template or a setting.
- **Locale namespace for this feature:** `hero.*` — `hero.home.title`, `hero.home.subtitle`, `hero.tag.title`, `hero.tag.subtitle`, `hero.button`. Not `homepage.hero.*`: the band is site-wide.
- **Spanish copy, verbatim from the maintainer:** title *Seguimos aprendiendo juntos*; subtitle *Comparte tus ideas o recibe consejos de otros usuarios certificados*; button *Hacer una pregunta*.
- **No raw media queries.** Use `viewport.until(sm)` etc. Breakpoints: `sm` 640px, `md` 768px, `lg` 1024px, `xl` 1280px, `2xl` 1536px.
- **BEM with standalone modifiers** (`.page-hero__title.--compact`), one BEM block per component.
- **Colors come from `stylesheets/brand/colors.scss` only.** Never introduce a hex value.
- **Blocks stay confined to the homepage.** The only Block added here is `block-hero.gjs`.
- **`theme_version` in `about.json` goes to `0.25.0`** — once, in the final task.
- **The only local gate is `npx pnpm@10.28.0 lint`.** QUnit runs exclusively in CI (~4 min a cycle), so batch the red step rather than pushing test by test.
- **Two Blocks API traps, both already paid for in this repo:** an undeclared Block arg aborts the *entire* QUnit run with an uncaught `BlockError`; an import of a missing export hard-fails the Rollup bundle and kills all tests as one global error. Declare args before honouring them; export before importing.

---

### Task 1: The content resolver

The pure function that decides what the band says. No framework, no DOM, no network — mirroring `lib/category-topics.js`, whose pure half is unit-tested the same way.

It returns i18n **keys** where the text comes from locales and **literal strings** where it comes from data. That split is what lets the component stay dumb.

**Files:**
- Create: `javascripts/discourse/lib/hero-content.js`
- Test: `test/unit/hero-content-test.js`

**Interfaces:**
- Consumes: nothing.
- Produces: `heroContentFor({ category, tag })` → `HeroContent`, an object with exactly these six properties:
  - `title: String|null` — literal, set only in the category case
  - `titleKey: String|null` — i18n key, set in every other case
  - `titleArgs: Object|null` — interpolation args for `titleKey` (the tag case only)
  - `subtitle: String|null` — literal, set only in the category case and only when the category has a description
  - `subtitleKey: String|null` — i18n key, set in every other case
  - `category: Object|null` — the category the composer should preselect

- [ ] **Step 1: Write the failing tests**

Create `test/unit/hero-content-test.js`:

```javascript
import { module, test } from "qunit";
import { heroContentFor } from "../../discourse/lib/hero-content";

// Pure — no Category, no store, no app — so it is tested without booting one,
// the same way the pure half of category-topics.js is.

module("Espublico Theme | Unit | hero-content", function () {
  test("a category supplies its own name and description", function (assert) {
    const category = {
      id: 5,
      name: "Foro del Certificado",
      description_text: "Donde se resuelven las dudas del certificado.",
    };

    const content = heroContentFor({ category });

    assert.strictEqual(content.title, "Foro del Certificado", "title");
    assert.strictEqual(
      content.subtitle,
      "Donde se resuelven las dudas del certificado.",
      "subtitle"
    );
    assert.strictEqual(content.titleKey, null, "no key when data supplies it");
    assert.strictEqual(content.category, category, "composer preselects it");
  });

  // Measured on PRE 2026-08-28: 5 of 17 categories have no description, and
  // they are the highest-traffic ones. The band must render title-only rather
  // than invent filler or repeat the name.
  test("a category with no description has no subtitle", function (assert) {
    const content = heroContentFor({
      category: { id: 4, name: "Noticias", description_text: "" },
    });

    assert.strictEqual(content.title, "Noticias");
    assert.strictEqual(content.subtitle, null, "empty string is not a subtitle");
    assert.strictEqual(content.subtitleKey, null, "and no fallback copy either");
  });

  test("a missing description_text is treated as no description", function (assert) {
    const content = heroContentFor({ category: { id: 4, name: "Noticias" } });

    assert.strictEqual(content.subtitle, null);
  });

  // A raw tag name is a slug and reads badly as a headline — "poster-evf".
  test("a tag is announced through a locale string, not printed raw", function (assert) {
    const content = heroContentFor({ tag: "poster-evf" });

    assert.strictEqual(content.titleKey, "hero.tag.title");
    assert.deepEqual(content.titleArgs, { tag: "poster-evf" });
    assert.strictEqual(content.subtitleKey, "hero.tag.subtitle");
    assert.strictEqual(content.category, null, "a tag preselects nothing");
  });

  test("no category and no tag falls back to the community copy", function (assert) {
    const content = heroContentFor({});

    assert.strictEqual(content.titleKey, "hero.home.title");
    assert.strictEqual(content.subtitleKey, "hero.home.subtitle");
    assert.strictEqual(content.category, null);
  });

  // The discovery outlet passes its args straight through, and on /latest both
  // are simply absent. Called with nothing at all it must still answer.
  test("called with no argument at all it still answers", function (assert) {
    const content = heroContentFor();

    assert.strictEqual(content.titleKey, "hero.home.title");
  });

  // A category always wins: /c/5?tag=x is a category page that happens to be
  // filtered, and the band names the place, not the filter.
  test("a category outranks a tag when both are present", function (assert) {
    const content = heroContentFor({
      category: { id: 5, name: "Foro del Certificado" },
      tag: "poster-evf",
    });

    assert.strictEqual(content.title, "Foro del Certificado");
  });
});
```

- [ ] **Step 2: Export a stub so the import resolves**

An import of a missing export hard-fails the whole Rollup bundle and reports a compile error rather than a test failure — all 56 tests died that way once in this repo. The stub makes the red step actually report.

Create `javascripts/discourse/lib/hero-content.js`:

```javascript
export function heroContentFor() {
  return null;
}
```

- [ ] **Step 3: Push the red step and confirm it fails for the right reason**

```bash
git add javascripts/discourse/lib/hero-content.js test/unit/hero-content-test.js
git commit -m "test: describe the hero content resolver"
git push -u origin feat/page-hero-band
```

Expected in CI `frontend_tests`: the 7 new tests FAIL on reading properties of `null`. Every other test in the suite still passes — if the run reports a global error instead, the bundle is broken and no assertion ran.

- [ ] **Step 4: Implement**

Replace `javascripts/discourse/lib/hero-content.js` with:

```javascript
/**
 * What the page hero says, and which category its button preselects.
 *
 * Text arrives two ways and the shape keeps them apart: `title`/`subtitle` are
 * literal strings taken from data, `titleKey`/`subtitleKey` are i18n keys the
 * component resolves through `themePrefix`. A caller never has to ask where a
 * string came from — exactly one of each pair is set.
 *
 * @typedef {Object} HeroContent
 * @property {String|null} title
 * @property {String|null} titleKey
 * @property {Object|null} titleArgs
 * @property {String|null} subtitle
 * @property {String|null} subtitleKey
 * @property {Object|null} category
 */

const HOME = {
  title: null,
  titleKey: "hero.home.title",
  titleArgs: null,
  subtitle: null,
  subtitleKey: "hero.home.subtitle",
  category: null,
};

/**
 * @param {Object} [context]
 * @param {Object} [context.category] the category in scope, if any
 * @param {String} [context.tag] the tag in scope, if any
 * @returns {HeroContent}
 */
export function heroContentFor({ category, tag } = {}) {
  // A category wins over a tag: `/c/5?tag=x` is a category page that happens
  // to be filtered, and the band names the place rather than the filter.
  if (category) {
    // Measured on PRE 2026-08-28: 5 of 17 categories carry no description, and
    // they are the busiest ones. Title-only is the correct rendering there —
    // the band never invents filler and never repeats the name as its own
    // subtitle.
    const description = category.description_text?.trim();

    return {
      title: category.name,
      titleKey: null,
      titleArgs: null,
      subtitle: description || null,
      subtitleKey: null,
      category,
    };
  }

  if (tag) {
    // A raw tag name is a slug — "poster-evf" is a poor headline — so it is
    // interpolated into a locale string instead of printed on its own.
    return {
      title: null,
      titleKey: "hero.tag.title",
      titleArgs: { tag },
      subtitle: null,
      subtitleKey: "hero.tag.subtitle",
      category: null,
    };
  }

  // The homepage and every generic listing (/latest, /top, /unread). A generic
  // listing has no identity of its own, and inventing one would be filler.
  return HOME;
}
```

- [ ] **Step 5: Lint, then push and confirm green**

```bash
npx pnpm@10.28.0 lint
git add javascripts/discourse/lib/hero-content.js
git commit -m "feat: resolve page hero content from route context"
git push
```

Expected: `lint` passes locally; CI `frontend_tests` green, 7 new tests passing.

---

### Task 2: Locale strings

Five strings in two languages. Doing this before the component means the component's own test can assert on rendered text rather than on a raw key.

**Files:**
- Modify: `locales/en.yml`
- Modify: `locales/es.yml`

**Interfaces:**
- Consumes: the key names fixed in Task 1 (`hero.home.title`, `hero.home.subtitle`, `hero.tag.title`, `hero.tag.subtitle`).
- Produces: those four keys plus `hero.button`, resolvable via `themePrefix`.

- [ ] **Step 1: Add the English strings**

In `locales/en.yml`, add a top-level `hero:` block under `en:`, as a sibling of `homepage:` (order in the file: after `topbar:`, before `homepage:`):

```yaml
  # The heading band at the top of the homepage and every listing. A category
  # page overrides both strings with its own name and description, so these are
  # the fallback the community sees on /latest, /top and /unread.
  hero:
    home:
      title: "We keep learning together"
      subtitle: "Share your ideas or get advice from other certified users"
    tag:
      title: "Topics tagged %{tag}"
      subtitle: "Everything the community has filed under this tag"
    button: "Ask a question"
```

- [ ] **Step 2: Add the Spanish strings**

In `locales/es.yml`, in the same position:

```yaml
  # La banda de cabecera de la portada y de cada listado. Una página de
  # categoría sustituye ambos textos por su propio nombre y descripción, así que
  # esto es lo que se ve en /latest, /top y /unread.
  hero:
    home:
      title: "Seguimos aprendiendo juntos"
      subtitle: "Comparte tus ideas o recibe consejos de otros usuarios certificados"
    tag:
      title: "Temas etiquetados %{tag}"
      subtitle: "Todo lo que la comunidad ha guardado bajo esta etiqueta"
    button: "Hacer una pregunta"
```

- [ ] **Step 3: Lint and commit**

```bash
npx pnpm@10.28.0 lint
git add locales/en.yml locales/es.yml
git commit -m "feat: add page hero strings"
```

Expected: `lint` passes. A YAML indentation error fails here, which is why this is its own commit.

---

### Task 3: The band component

Presentational and context-free: it is handed `title`/`subtitle`/`category` and renders. It does not know which page it is on.

**Files:**
- Create: `javascripts/discourse/components/page-hero.gjs`
- Test: `test/integration/page-hero-test.gjs`

**Interfaces:**
- Consumes: `heroContentFor` from Task 1; the locale keys from Task 2.
- Produces: `PageHero`, a Glimmer component taking one argument, `@content`, of the `HeroContent` shape. Renders `.page-hero` with `.page-hero__title`, `.page-hero__subtitle` and `.page-hero__button`.

- [ ] **Step 1: Write the failing tests**

Create `test/integration/page-hero-test.gjs`:

```javascript
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PageHero from "../../discourse/components/page-hero";

// Rendered directly rather than through an outlet: this component is mounted
// two different ways in production and neither is what is under test here.

function stubComposer(owner) {
  const calls = [];
  owner.unregister("service:composer");
  owner.register(
    "service:composer",
    { openNewTopic: (options) => calls.push(options) },
    { instantiate: false }
  );
  return calls;
}

// The band must not throw when there is no signed-in user. The instance is
// login_required so this is the login page only, but that is the one page an
// exception would be visible on.
function stubCurrentUser(owner, user) {
  owner.unregister("service:current-user");
  owner.register("service:current-user", user, { instantiate: false });
}

module("Espublico Theme | Integration | page hero", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a category's own name and description", async function (assert) {
    stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: true });
    const content = {
      title: "Foro del Certificado",
      titleKey: null,
      titleArgs: null,
      subtitle: "Donde se resuelven las dudas.",
      subtitleKey: null,
      category: { id: 5, name: "Foro del Certificado" },
    };

    await render(<template><PageHero @content={{content}} /></template>);

    assert.dom(".page-hero__title").hasText("Foro del Certificado");
    assert.dom(".page-hero__subtitle").hasText("Donde se resuelven las dudas.");
  });

  test("omits the subtitle entirely when the category has no description", async function (assert) {
    stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: true });
    const content = {
      title: "Noticias",
      titleKey: null,
      titleArgs: null,
      subtitle: null,
      subtitleKey: null,
      category: { id: 4, name: "Noticias" },
    };

    await render(<template><PageHero @content={{content}} /></template>);

    assert.dom(".page-hero__title").hasText("Noticias");
    assert.dom(".page-hero__subtitle").doesNotExist("no empty element either");
  });

  test("clicking the button opens the composer on the category in scope", async function (assert) {
    const calls = stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: true });
    const category = { id: 5, name: "Foro del Certificado" };
    const content = {
      title: "Foro del Certificado",
      titleKey: null,
      titleArgs: null,
      subtitle: null,
      subtitleKey: null,
      category,
    };

    await render(<template><PageHero @content={{content}} /></template>);
    await click(".page-hero__button");

    assert.strictEqual(calls.length, 1, "opened once");
    assert.strictEqual(calls[0].category, category, "on this category");
  });

  test("opens the composer with no category on a generic listing", async function (assert) {
    const calls = stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: true });
    const content = {
      title: null,
      titleKey: "hero.home.title",
      titleArgs: null,
      subtitle: null,
      subtitleKey: "hero.home.subtitle",
      category: null,
    };

    await render(<template><PageHero @content={{content}} /></template>);
    await click(".page-hero__button");

    assert.strictEqual(calls[0].category, null, "user picks it in the composer");
  });

  // The check the API keys cannot measure — /categories.json answers with the
  // admin key's own permissions. This is the unit that proves the branch works;
  // which categories fall on this side is verified on PRE with a non-admin.
  test("hides the button from a user who cannot create topics", async function (assert) {
    stubComposer(this.owner);
    stubCurrentUser(this.owner, { can_create_topic: false });
    const content = {
      title: "Administradores",
      titleKey: null,
      titleArgs: null,
      subtitle: null,
      subtitleKey: null,
      category: { id: 3, name: "Administradores" },
    };

    await render(<template><PageHero @content={{content}} /></template>);

    assert.dom(".page-hero__title").exists("the band still renders");
    assert.dom(".page-hero__button").doesNotExist("but not the action");
  });

  test("renders without a button and without throwing for an anonymous visitor", async function (assert) {
    stubComposer(this.owner);
    stubCurrentUser(this.owner, null);
    const content = {
      title: null,
      titleKey: "hero.home.title",
      titleArgs: null,
      subtitle: null,
      subtitleKey: "hero.home.subtitle",
      category: null,
    };

    await render(<template><PageHero @content={{content}} /></template>);

    assert.dom(".page-hero").exists();
    assert.dom(".page-hero__button").doesNotExist();
  });
});
```

- [ ] **Step 2: Create a stub component so the import resolves**

Create `javascripts/discourse/components/page-hero.gjs`:

```javascript
import Component from "@glimmer/component";

export default class PageHero extends Component {
  <template><div class="page-hero"></div></template>
}
```

- [ ] **Step 3: Push the red step**

```bash
git add javascripts/discourse/components/page-hero.gjs test/integration/page-hero-test.gjs
git commit -m "test: describe the page hero band"
git push
```

Expected: the 6 new tests FAIL on missing `.page-hero__title` / `.page-hero__button`. The rest of the suite stays green.

- [ ] **Step 4: Implement**

Replace `javascripts/discourse/components/page-hero.gjs` with:

```javascript
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

// The heading band at the top of the homepage and every listing.
//
// Presentational and context-free: it is handed a HeroContent and renders it.
// Deciding what that content is belongs to `lib/hero-content.js`, which is
// pure and unit-tested; deciding where the band appears belongs to the two
// mounting points. This component knows neither.
export default class PageHero extends Component {
  @service composer;
  @service currentUser;

  // Exactly one of `title` / `titleKey` is ever set — see the HeroContent
  // typedef. A category supplies a literal name; everything else a locale key.
  get title() {
    const { title, titleKey, titleArgs } = this.args.content;
    return title ?? i18n(themePrefix(titleKey), titleArgs ?? {});
  }

  get subtitle() {
    const { subtitle, subtitleKey } = this.args.content;

    if (subtitle) {
      return subtitle;
    }

    // Null rather than an empty string: 5 of the 17 categories on PRE carry no
    // description, and the template drops the element entirely rather than
    // rendering an empty paragraph that still takes up its margin.
    return subtitleKey ? i18n(themePrefix(subtitleKey)) : null;
  }

  // Two conditions, and the second only where there is a category.
  //
  // The permission cannot be read over the API — /categories.json answers with
  // the permissions of the key's own user, who is an admin and can write
  // everywhere — so which categories land on the false branch is verified on
  // PRE with a non-admin account rather than asserted here.
  //
  // `currentUser` is null for an anonymous visitor. The instance is
  // login_required so that is the login page alone, but it is also the one page
  // where an exception would be on show.
  get canCreateTopic() {
    if (!this.currentUser?.can_create_topic) {
      return false;
    }

    const { category } = this.args.content;
    return category ? category.permission === 1 : true;
  }

  @action
  openComposer() {
    this.composer.openNewTopic({ category: this.args.content.category });
  }

  <template>
    <section class="page-hero">
      <div class="page-hero__inner">
        {{! `dReplaceEmoji`, not the `emojiUnescape` used on news excerpts. The
            discriminator is what the field already holds: an excerpt is
            HTML-encoded and escaping it again prints "&rsquo;" verbatim, while
            a category name and its description_text are plain text and must be
            escaped before the emoji images are substituted in. `block-library`
            applies the same helper to a category name for the same reason. }}
        <h1 class="page-hero__title">{{trustHTML
            (dReplaceEmoji this.title)
          }}</h1>

        {{#if this.subtitle}}
          <p class="page-hero__subtitle">{{trustHTML
              (dReplaceEmoji this.subtitle)
            }}</p>
        {{/if}}

        {{#if this.canCreateTopic}}
          <DButton
            class="btn-primary page-hero__button"
            @action={{this.openComposer}}
            @translatedLabel={{i18n (themePrefix "hero.button")}}
          />
        {{/if}}
      </div>
    </section>
  </template>
}
```

> **Note on `category.permission === 1`:** `1` is Discourse's `full` permission
> constant. If the CI run shows the button hidden for a category a member can
> genuinely post in, read the actual value off `/categories.json` before
> changing the comparison — do not loosen it to a truthiness check, which would
> show the button in read-only categories.

- [ ] **Step 5: Lint, push, confirm green**

```bash
npx pnpm@10.28.0 lint
git add javascripts/discourse/components/page-hero.gjs
git commit -m "feat: add the page hero band component"
git push
```

Expected: 6 new tests pass; the suite stays green.

---

### Task 4: Styling

**Files:**
- Create: `stylesheets/blocks/page-hero.scss`
- Modify: `stylesheets/blocks/_index.scss`
- Modify: `stylesheets/app/variables.scss:6-9`

**Interfaces:**
- Consumes: the class names rendered in Task 3 (`.page-hero`, `__inner`, `__title`, `__subtitle`, `__button`).
- Produces: nothing other tasks import.

- [ ] **Step 1: Declare the radius the brand system's third step needs**

The identity system specifies radii **8 / 14 / 20**. `stylesheets/app/variables.scss`
declares only the first two, because nothing until now was large enough to want the third.
The band is, so add it beside them rather than writing `20px` inline:

```scss
  --d-border-radius-xlarge: 20px;
```

- [ ] **Step 2: Write the stylesheet**

Create `stylesheets/blocks/page-hero.scss`:

```scss
// The heading band at the top of the homepage and every listing.
//
// Edge to edge of the content column, not of the window. Full-bleed would mean
// fighting the measure cap `layout.scss` already negotiates, and the reference
// (community.hubspot.com) bleeds its chrome, not its page heading.
//
// If full-bleed is ever wanted here, test the rule by inserting it into the
// theme's own compiled sheet. A <style> appended to <head> from the console is
// not a faithful preview of a theme rule — that mistake produced a confident,
// wrong conclusion about this instance's cascade that reached a commit message.
.page-hero {
  // The gradient runs dark-to-brand so the title sits on the deeper end. In the
  // dark scheme both stops drop a step: on that background petrol-700 is a
  // surface, not a lift.
  background: linear-gradient(
    135deg,
    light-dark(var(--ga-petrol-800), var(--ga-petrol-950)),
    light-dark(var(--ga-petrol-700), var(--ga-petrol-900))
  );
  border-radius: var(--d-border-radius-xlarge);
  margin-block: var(--space-5);
  padding: var(--space-6) var(--space-5);

  &__inner {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-3);
    text-align: center;
  }

  &__title {
    margin: 0;
    // 5.94:1 on petrol-700 — the deepest stop the gradient reaches under it.
    color: var(--ga-neutral-0);
    // Roboto Slab, the system's typographic signature. The theme vendors it
    // and decides where it lands precisely so it stays on page titles and
    // brand moments — it "pierde su valor si se reparte".
    font-family: var(--ga-font-slab);
    font-size: var(--font-up-4);
    line-height: var(--line-height-small);
  }

  &__subtitle {
    // 5.00:1 on petrol-700. A step down from the title in tone, not in size,
    // so the two read as one voice.
    max-width: 46rem;
    margin: 0;
    color: var(--ga-petrol-100);
    font-size: var(--font-up-1);
    line-height: var(--line-height-medium);

    // Category 85 carries 414 characters. Clamping is presentation: the whole
    // description goes on serving the native categories page, and nobody has to
    // rewrite a description in admin to keep this band in proportion.
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  &__button.btn-primary {
    // Brand cyan is a fill here, never text on a light surface — the constraint
    // recorded in colors.scss. Ink on it measures 6.81:1.
    margin-block-start: var(--space-2);
    background: var(--ga-mark);
    color: var(--ga-petrol-950);

    &:hover,
    &:focus-visible {
      background: var(--ga-cyan-400);
      color: var(--ga-petrol-950);
    }
  }

  @include viewport.until(sm) {
    padding: var(--space-5) var(--space-4);

    &__title {
      font-size: var(--font-up-2);
    }

    &__subtitle {
      font-size: var(--font-0);
    }
  }
}
```

- [ ] **Step 3: Register it**

`stylesheets/blocks/_index.scss` imports folders' own files; add the new one at the end:

```scss
@import "page-hero";
```

- [ ] **Step 4: Verify the viewport mixin resolves**

`common/common.scss` already carries `@use "lib/viewport";` before it imports `blocks`, so `viewport.until(sm)` resolves without a per-file `@use`. Confirm by lint, which runs stylelint over the compiled tree:

```bash
npx pnpm@10.28.0 lint:css
```

Expected: PASS. An "unknown namespace viewport" error here means the `@use` is missing — add `@use "../lib/viewport";` at the top of `page-hero.scss` rather than editing `common.scss`.

- [ ] **Step 5: Commit**

```bash
npx pnpm@10.28.0 lint
git add stylesheets/blocks/page-hero.scss stylesheets/blocks/_index.scss \
        stylesheets/app/variables.scss
git commit -m "feat: style the page hero band"
```

---

### Task 5: Mount it on the homepage

The Block wrapper. The homepage is a custom route and does not render the discovery outlets, so this is the only way the band reaches it.

**Files:**
- Create: `javascripts/discourse/blocks/block-hero.gjs`
- Modify: `javascripts/discourse/api-initializers/homepage-blocks.gjs`
- Modify: `stylesheets/layouts/homepage.scss:1-70`
- Test: `test/integration/homepage-lanes-test.gjs`

**Interfaces:**
- Consumes: `PageHero` (Task 3), `heroContentFor` (Task 1).
- Produces: `BlockHero`, registered as `theme:espublico:hero`, taking **no args**.

- [ ] **Step 1: Write the failing test**

Append to `test/integration/homepage-lanes-test.gjs`, inside the existing outer `module` callback, after the `news lane` module:

```javascript
  module("hero band", function () {
    test("renders the community copy at the top of the homepage", async function (assert) {
      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [{ block: BlockHero }])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".page-hero__title").hasText("Seguimos aprendiendo juntos");
    });
  });
```

Add the import at the top of that file, in alphabetical order with the others:

```javascript
import BlockHero from "../../discourse/blocks/block-hero";
```

> The assertion reads Spanish because the test suite runs under the default
> locale of this theme's fixtures. If CI reports the English string instead,
> assert on `"We keep learning together"` — the point of the test is that the
> block resolves *a* locale string rather than printing the raw key.

- [ ] **Step 2: Create the block**

Create `javascripts/discourse/blocks/block-hero.gjs`:

```javascript
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { heroContentFor } from "../lib/hero-content";
import PageHero from "../components/page-hero";

// The homepage's copy of the band.
//
// A Block only because the homepage is a custom route and does not render the
// discovery outlets — there is no single mount that reaches both it and the
// category pages. Everything it does is delegated: the same component the
// listings use, fed by the same resolver, called with no context so it returns
// the community copy.
//
// It declares no args. Adding one later means declaring it inert first and
// honouring it in a second commit: an undeclared arg aborts the entire QUnit
// run with an uncaught BlockError, taking down tests unrelated to blocks.
@block("theme:espublico:hero", {
  description: "The heading band at the top of the homepage",
  args: {},
})
export default class BlockHero extends Component {
  get content() {
    return heroContentFor();
  }

  <template><PageHero @content={{this.content}} /></template>
}
```

- [ ] **Step 3: Place it first in the homepage layout**

In `javascripts/discourse/api-initializers/homepage-blocks.gjs`, add the import alongside the others:

```javascript
import BlockHero from "../blocks/block-hero";
```

and make it the first entry of the `renderBlocks` array, before the `home-main` group:

```javascript
    {
      block: BlockHero,
      id: "home-hero",
    },
```

- [ ] **Step 4: Give it a grid row**

In `stylesheets/layouts/homepage.scss`, add `home-hero` as the first area in both templates and give it a placement rule.

In the one-column template, the areas become:

```scss
    grid-template-areas:
      "home-hero"
      "home-main"
      "home-side"
      "home-showcase"
      "home-library";
```

In the `@container homepage-blocks (width > 60rem)` block, spanning both columns:

```scss
      grid-template-areas:
        "home-hero home-hero"
        "home-main home-side"
        "home-showcase home-showcase"
        "home-library home-library";
```

And alongside the existing `&--home-main` / `&--home-side` rules:

```scss
    &--home-hero {
      grid-area: home-hero;
    }
```

- [ ] **Step 5: Lint, push, confirm green**

```bash
npx pnpm@10.28.0 lint
git add javascripts/discourse/blocks/block-hero.gjs \
        javascripts/discourse/api-initializers/homepage-blocks.gjs \
        stylesheets/layouts/homepage.scss \
        test/integration/homepage-lanes-test.gjs
git commit -m "feat: put the hero band at the top of the homepage"
git push
```

Expected: the new test passes and the existing 47 stay green. A failure in an *unrelated* lane test here means the Block registration is at fault, not the lane.

---

### Task 6: Mount it on the listings

The one task with an unknown in it, isolated here on purpose so nothing else waits on it.

**Files:**
- Create: `javascripts/discourse/api-initializers/<outlet-name>.gjs` — named after the outlet, as the repo's two existing initializers are
- Test: none automated (see below)

**Interfaces:**
- Consumes: `PageHero` (Task 3), `heroContentFor` (Task 1).
- Produces: the band on `/latest`, `/top`, `/unread`, category pages and tag pages.

- [ ] **Step 1: Identify the outlet on PRE**

**This step is the maintainer's, and it needs a browser.** Open PRE, enable Discourse's developer toolbar, and find the outlet above the topic list that (a) spans the content column and (b) exposes `category` in its arguments — the toolbar shows each outlet's args on hover.

`discovery-list-container-top` is the documented candidate and does receive the category, but it sits *inside* the list container, so check whether the band spans the column there before settling on it. There is no usage of any such outlet across the 19 themes in `.reference/`, which is why this cannot be answered from the repo.

Record the answer here before continuing: **outlet name = `________`**.

- [ ] **Step 2: Write the initializer**

Create `javascripts/discourse/api-initializers/<outlet-name>.gjs`, substituting the name found in Step 1 in both the filename and the `renderInOutlet` call:

```javascript
import { apiInitializer } from "discourse/lib/api";
import { heroContentFor } from "../lib/hero-content";
import PageHero from "../components/page-hero";

// The heading band on every listing: categories, tags, /latest, /top, /unread.
//
// A plugin outlet rather than a block, which is the agreed split for this theme
// — Blocks stay on the custom homepage, outlets and SCSS carry everything else.
//
// The category arrives as an outlet argument rather than being read from a
// service, and that is the whole reason this approach was chosen over mounting
// once high and filtering by route name. Ember's autotracking updates the band
// when the argument changes, so moving between categories needs no remount and
// no subscription; and if core ever renames a route, this fails visibly at the
// outlet rather than silently rendering the wrong text.
export default apiInitializer((api) => {
  api.renderInOutlet(
    "<outlet-name>",
    <template>
      <PageHero
        @content={{heroContentFor
          category=@outletArgs.category
          tag=@outletArgs.tag
        }}
      />
    </template>
  );
});
```

> If `heroContentFor` cannot be invoked as a helper directly in the template,
> wrap it in a small component with a `get content()` the way `block-hero.gjs`
> does, rather than reaching for a service. The wrapper is three lines and keeps
> the argument flow intact.

- [ ] **Step 3: Lint and commit**

```bash
npx pnpm@10.28.0 lint
git add javascripts/discourse/api-initializers/
git commit -m "feat: put the hero band above every listing"
git push
```

Expected: CI green. There is no automated test for this mount — category listings are outside the CI net (`skip_examples` takes `topics:read`, which removes "lists topics for a category"), so Task 7 is where it is actually verified.

---

### Task 7: Verify on PRE and release

The three risks no test covers. **Every one of these needs a browser on PRE**, and two need a non-admin account.

**Files:**
- Modify: `about.json`
- Modify: `traceability.md`

**Interfaces:**
- Consumes: everything above.
- Produces: `theme_version` 0.25.0 on `main`.

- [ ] **Step 1: Bump the version**

In `about.json`, `"theme_version": "0.24.0"` → `"0.25.0"`.

- [ ] **Step 2: Open the PR and let CI go green**

```bash
npx pnpm@10.28.0 lint
git add about.json
git commit -m "chore: theme_version 0.25.0"
git push
gh pr create --fill
```

`main` requires `ci / linting`, `ci / backend_tests`, `ci / frontend_tests` and `ci / system_tests`. Wait for all four — `gh pr merge --auto` genuinely waits now that the branch is protected.

- [ ] **Step 3: Merge, then force the pull and confirm PRE actually has it**

`commits_behind: 0` is not proof of currency — a remote theme pulls when Discourse next checks, not when a PR merges. Force it:

```bash
set -a && source .env.local && set +a
curl -s -X PUT -H "Api-Key: $PRE_DISCOURSE_GLOBAL_API_KEY" \
  -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" \
  -H "Content-Type: application/json" -d '{"theme":{"remote_update":true}}' \
  "$PRE_DISCOURSE_URL/admin/themes/15.json" > /dev/null

curl -s -H "Api-Key: $PRE_DISCOURSE_API_KEY" -H "Api-Username: $PRE_DISCOURSE_API_USERNAME" \
  "$PRE_DISCOURSE_URL/admin/themes/15.json" |
  python3 -c "import json,sys; rt=json.load(sys.stdin)['theme']['remote_theme']; \
    print({k: rt[k] for k in ['branch','remote_compat_ref','local_version','commits_behind','updated_at']})"
```

Expected: `remote_compat_ref: None` and `commits_behind: 0` with an `updated_at` *after* the merge. `POST /admin/themes/<id>/update.json` is a 404 — that route does not exist.

- [ ] **Step 4: The three manual checks**

1. **No double band on the homepage.** Load `/`. Exactly one `.page-hero`. The Block and the outlet should never both fire because `custom_homepage` keeps the homepage off the discovery route — this confirms it. Symptom if wrong: two stacked bands, visible and absurd.
2. **The button is genuinely absent in a read-only category, checked with a non-admin account.** This is the check the API keys cannot make: they answer with the admin's own permissions. Try category 3 (*Administradores*) and one of the *Recursos Analítica* tree.
3. **390px.** Title, subtitle and button legible, no horizontal overflow, subtitle clamped at two lines. Category 85 *Comparte* (414 characters) is the worst case — load it specifically.

- [ ] **Step 5: Record the session**

Add a `traceability.md` entry: what shipped, the outlet that Step 1 of Task 6 resolved, and the result of each of the three manual checks — particularly which categories turned out to hide the button, since that is the fact nothing in the repo can currently derive.

- [ ] **Step 6: Hand the admin task back**

Four categories need a description written in admin before their bands show a subtitle: **4 Noticias, 5 Foro del Certificado, 14 Aula de formación, 59 Eventos**. Category 3 is staff-only and 75 already has a short one. Until then those bands render title-only, which is correct behaviour rather than a bug. The text also improves the native categories page.

---

## Self-Review

**Spec coverage.** Every section maps to a task: scope → Tasks 5 and 6; components table → Tasks 1, 3, 5, 6; content resolution and its four decisions → Task 1 (resolution, no-description, generic fallback) and Tasks 3–4 (`dReplaceEmoji`, CSS clamp); the 5-empty-categories measurement → Task 7 Step 6; every edge case → Task 1 (subcategories, tags, category-outranks-tag) and Task 3 (permission, anonymous, autotracking via Task 6's outlet args); visual → Task 4; testing → Tasks 1, 3, 5, 7; delivery → Task 7.

**Two spec statements deliberately not implemented as written.**

1. **`emojiUnescape` → `dReplaceEmoji`.** The spec was corrected on 2026-08-28 before this plan was written; `block-library.gjs:65` already applies `dReplaceEmoji` to a plain-text category name, and `description_text` is plain text.
2. **Contrast ratios.** The spec states 5.94:1 / 5.00:1 / 6.81:1 as computed during design and requires re-validation before the PR. Task 4 carries them as comments; validate them in Task 7 Step 4 alongside the visual check, and correct both files if any is wrong.

**Two tokens the first draft invented, caught by grepping the stylesheets rather than
trusting the draft.** `--radius-lg` does not exist — the theme declares `--d-border-radius`
(8px) and `--d-border-radius-large` (14px), so Task 4 Step 1 now adds the brand system's
third step explicitly. `--font-family-display` does not exist either; the Roboto Slab token
is `--ga-font-slab`, and reaching for `--heading-font-family` would have rendered the title
in Roboto, silently losing the typographic signature the spec asked for. Everything else the
stylesheet uses — `--font-up-4`, `--space-6`, `--line-height-small` — is confirmed present
in core's scale.

**Open item carried deliberately:** the discovery outlet name (Task 6 Step 1). It is the spec's one declared unknown, it needs a browser, and it is isolated in the last implementation task so Tasks 1–5 do not wait on it.

**Type consistency.** `heroContentFor` returns the same six properties in Task 1's implementation, Task 1's tests, Task 3's fixtures, Task 5's block and Task 6's initializer. `PageHero` takes `@content` everywhere. Class names in Task 3's template match Task 3's assertions and Task 4's selectors.

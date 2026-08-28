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
    assert.strictEqual(
      content.subtitle,
      null,
      "empty string is not a subtitle"
    );
    assert.strictEqual(
      content.subtitleKey,
      null,
      "and no fallback copy either"
    );
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

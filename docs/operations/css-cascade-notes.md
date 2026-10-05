#### Test a cascade override in the compiled theme sheet, never from the console

The theme's compiled stylesheet is unlayered and is the **last** `<link>` on the
page, so a theme rule that ties core on specificity **wins**. Measured on PRE
2026-08-28: `body.has-sidebar-page .wrap { max-width: 555px }` inserted into the
theme sheet via `CSSStyleSheet.insertRule` takes effect; core's own rule at the
same (0,2,1) loses.

**The same rule injected as a `<style>` appended to `<head>` loses** — even
though it is later in document order, and even with no `@layer` anywhere on the
page. The mechanism is unexplained. What matters is the consequence: a
console-injected `<style>` is **not** a faithful preview of a theme rule, and
measuring one produced a confident, wrong conclusion about this instance's
cascade that reached a commit message (`0959c2c`). Prototype geometry that way
if it helps — it is how `layout.scss` was designed — but test any rule whose
outcome depends on the cascade by inserting it into the theme's own sheet.

Preferring a selector that outranks core rather than ties it sidesteps the whole
question, and costs one class. `layout.scss` does that.


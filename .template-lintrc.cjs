// @discourse/lint-configs dropped its ./template-lint export in 3.x — template
// rules moved into the eslint config via ember-eslint-parser. The shared CI
// workflow still runs a template-lint step, so keep a self-contained config
// here rather than reintroducing the older lint-configs release.
module.exports = {
  extends: "recommended",
};

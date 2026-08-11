# Espublico Theme

Custom Discourse theme for the es|public community, installed as a remote theme on Discourse Cloud.

## Requirements

- Node 22+
- Ruby 3+ (`brew install ruby`) for the `discourse_theme` CLI
- Access to the target Discourse instance with a Global-scope API key

## Setup

```bash
npx pnpm@10.28.0 install
```

pnpm is invoked through `npx` at a pinned version because corepack cannot reach the npm registry from behind the corporate TLS proxy.

## Development

Development happens against the PRE instance, `https://discourse.gestiona4dev.tech`.
Production (`https://gestionaavanza.espublico.com`) only receives reviewed work.

Sync the working tree to a live Discourse instance on every save:

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$(/opt/homebrew/opt/ruby/bin/gem environment gemdir)/bin:$PATH"
gem install discourse_theme     # once
discourse_theme watch .
```

Gem binaries install into the RubyGems executable dir, which on Homebrew Ruby is
not the interpreter's own `bin` — hence both entries on `PATH`.

The first run asks for the site URL and an API key and stores them in `~/.discourse_theme`,
keyed by project path. That file lives outside the repo, so `.gitignore` does not
cover it — treat it as a credential store. Point the CLI at a staging site, not production.

It also needs a real TTY on that first run (`tty-prompt` selection menus), so run it
from a terminal rather than from an editor or agent shell. Afterwards it is fully
non-interactive.

## Linting

```bash
npx pnpm@10.28.0 lint       # stylelint + eslint + prettier + type check
npx pnpm@10.28.0 lint:fix
```

This is the same check CI runs.

## Installing on Discourse

Admin → Customize → Themes → Install → *From a git repository*, using the SSH URL of this repo. Discourse pulls `main`.

## Layout

```
about.json               theme metadata, color schemes, modifiers
settings.yml             admin-configurable functional settings
locales/                 all user-visible strings
common/common.scss       SCSS import manifest (no rules)
stylesheets/             brand/ app/ blocks/ layouts/
javascripts/discourse/   api-initializers/ and blocks/
spec/system/             RSpec system specs (run by CI)
bin/                     sync-reference, sync-skills
```

See `CLAUDE.md` for architecture and conventions.

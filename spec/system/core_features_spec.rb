# frozen_string_literal: true

# Parts of the core features examples can be skipped like so:
#   it_behaves_like "having working core features", skip_examples: %i[login likes]
#
# List of keywords for skipping examples:
# login, likes, profile, topics, topics:read, topics:reply, topics:create,
# search, search:quick_search, search:full_page
#
# For more details, see https://meta.discourse.org/t/-/361381
RSpec.describe "Core features" do
  before { upload_theme_or_component }

  # This theme sets the `custom_homepage` modifier, so `/` renders the theme's
  # own five lanes instead of core's topic list. Every skipped example below
  # starts by visiting `/` and then either clicks a topic title out of the core
  # list or looks for `#create-topic`, neither of which exists there any more.
  # The failure is the modifier working as intended, not a regression.
  #
  # Coverage this costs, and it is more than the homepage: `topics:read` also
  # takes "lists topics for a category", which passes on its own merits since
  # /c/... is untouched by this theme. Discourse exposes no narrower key than
  # `topics:read` for listing examples, so there is no way to keep it while
  # skipping the homepage listing. 19 examples drop to 10.
  #
  # Category listings are therefore unguarded by CI and need checking by hand
  # whenever topic-list styling changes.
  #
  # `search:quick_search` is skipped for a different reason. The theme sets the
  # `search_experience` theme site setting to `search_field`, so the header
  # renders a search input rather than core's magnifying-glass button, and the
  # example fails on `find(".d-header #search-button")` before it can type
  # anything. Quick search itself is untouched — same SearchMenu component,
  # different entry point — so what is lost here is coverage of the icon flow
  # this theme deliberately does not use. `search:full_page` still runs.
  it_behaves_like "having working core features",
                  skip_examples: %i[
                    topics:read
                    topics:reply
                    topics:create
                    likes
                    search:quick_search
                  ]
end

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
  #
  # The failure is the modifier working as intended, not a regression. Note
  # that "lists topics for a category" still runs and passes, because it visits
  # /c/... rather than the homepage — category listings are untouched by this
  # theme and stay covered.
  it_behaves_like "having working core features",
                  skip_examples: %i[topics:read topics:reply topics:create likes]
end

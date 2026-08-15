import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

/**
 * Site-wide figures for the topbar, from /about.json.
 *
 * The same endpoint core's own /about route reads. There is no client-side
 * About model to go through — the old models/about.js no longer exists — and
 * visibility is not gated: Guardian#can_see_about_stats? returns true
 * unconditionally.
 *
 * A service rather than a module-level `let cached`, because the memo has to
 * live exactly as long as the application instance. A module-scope cache lives
 * as long as the module, which in a QUnit run is the whole suite: the first
 * test to resolve /about.json would pin its response for every test after it,
 * and the failure cases — the ones worth testing — would be unreachable.
 */
export default class SiteStats extends Service {
  // The `about.stats` object once it arrives, null otherwise.
  @tracked stats = null;

  // True once the request has settled, whether it produced data or not. This
  // is what separates "still loading" from "failed"; the topbar collapses on
  // the second and not the first.
  @tracked loaded = false;

  #request;

  /**
   * Load the figures once. Idempotent: repeated calls return the same promise,
   * so route transitions never refetch.
   *
   * The rejection is memoised along with the success. On a login-required site
   * an anonymous or 403 response must not turn into a request on every
   * navigation.
   *
   * @returns {Promise}
   */
  load() {
    this.#request ||= ajax("/about.json")
      .then((result) => (this.stats = result?.about?.stats ?? null))
      .catch(() => (this.stats = null))
      .finally(() => (this.loaded = true));

    return this.#request;
  }
}

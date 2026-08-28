import Component from "@glimmer/component";
import { block } from "discourse/blocks";

// STUB — args declared, behaviour not yet honoured.
//
// Deliberate, and the order matters. An undeclared arg raises an uncaught
// BlockError that aborts the entire QUnit run, taking down tests that have
// nothing to do with blocks; and an import of a missing export makes Rollup
// hard-fail the whole theme bundle, reported as a compile error rather than a
// test failure. So the export and the arg schema land first, inert, and the
// implementation follows on top of a suite that still reports.
@block("theme:espublico:latest", {
  description: "The site-wide latest topics, as core's own topic list",
  args: {
    title: { type: "string" },
    linkText: { type: "string" },
    linkUrl: { type: "string" },
    count: { type: "number", default: 8 },
  },
})
export default class BlockLatest extends Component {
  <template>
    <section class="block-latest"></section>
  </template>
}

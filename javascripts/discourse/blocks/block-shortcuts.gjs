import Component from "@glimmer/component";
import { block } from "discourse/blocks";

// STUB — see the note in block-latest.gjs for why the args land inert first.
@block("theme:espublico:shortcuts", {
  description: "A short card of destinations, beside the latest list",
  args: {
    title: { type: "string" },
    newTopicText: { type: "string" },
  },
})
export default class BlockShortcuts extends Component {
  <template>
    <section class="block-shortcuts"></section>
  </template>
}

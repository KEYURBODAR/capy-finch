# SPDX-License-Identifier: AGPL-3.0-only
import karax/[karaxdsl, vdom]

proc renderFeature*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    h1: text "Unsupported feature"
    tdiv(role="alert", `data-variant`="warning"):
      text "This feature isn't supported in Finch right now."

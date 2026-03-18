# SPDX-License-Identifier: AGPL-3.0-only
import karax/[karaxdsl, vdom]

proc renderFeature*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    h2: text "Not supported"
    p: text "This feature isn't available in Finch yet."
    p:
      a(href="/"): text "← Back to home"

# SPDX-License-Identifier: AGPL-3.0-only
import uri
import karax/[karaxdsl, vdom]
import renderutils

proc searchHref(query: string): string =
  "/go?q=" & encodeUrl(query)

proc renderChip(label, query: string): VNode =
  buildHtml(a(class="badge outline", href=searchHref(query))):
    text label

proc renderHome*(): VNode =
  buildHtml(tdiv(class="panel-container finch-home")):
    tdiv(class="finch-home-intro"):
      h1(class="finch-home-title"): text "Finch"
      p(class="finch-home-subtitle"):
        text "Search profiles, posts, operators, lists, and RSS."

    tdiv(class="finch-home-search"):
      form(`method`="get", action="/go", autocomplete="off", class="finch-home-search-form"):
        fieldset(class="group finch-home-search-shell"):
          input(`type`="text", name="q", id="finch-go-input", autofocus="",
                placeholder="from:elonmusk filter:links min_faves:50", dir="auto")
          button(`type`="submit", class="button", title="Search"):
            icon "search"

    tdiv(class="finch-home-examples"):
      span(class="finch-home-examples-label"): text "Examples"
      tdiv(class="finch-home-chip-row"):
        renderChip("@naval", "@naval")
        renderChip("@elonmusk", "@elonmusk")
        renderChip("naval links 100+", "from:naval filter:links min_faves:100 -filter:replies -filter:quote")
        renderChip("elon links 500+", "from:elonmusk filter:links min_faves:500 -filter:replies -filter:quote")
        renderChip("AI agents links 50+", "\"AI agents\" filter:links min_faves:50 -filter:replies -filter:quote")
        renderChip("naval 2025 links", "from:naval since:2025-01-01 until:2025-12-31 filter:links -filter:replies -filter:quote")

    tdiv(class="finch-home-links"):
      a(class="button ghost small", href="/f/following"): text "Following"
      a(class="button ghost small", href="/f/lists"): text "Lists"

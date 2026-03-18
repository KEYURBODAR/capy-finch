# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, sequtils, tables, options, uri
import karax/[karaxdsl, vdom]

import renderutils, timeline, actions
import ".."/[types, query]

const toggles = {
  "nativeretweets": "Retweets",
  "media": "Media",
  "videos": "Videos",
  "news": "News",
  "native_video": "Native videos",
  "replies": "Replies",
  "links": "Links",
  "images": "Images",
  "quote": "Quotes",
  "spaces": "Spaces"
}.toOrderedTable

const localCollectionToggles = {
  "links": "Links",
  "media": "Media",
  "images": "Images",
  "videos": "Videos",
  "quote": "Quotes",
  "replies": "Replies",
  "nativeretweets": "Retweets"
}.toOrderedTable

proc panelText(query: Query): string =
  result = query.text
  if result.len == 0:
    return

  let tokens = result.splitWhitespace()
  result = tokens.filterIt(
    not it.startsWith("from:") and
    not it.startsWith("to:") and
    not it.startsWith("@")
  ).join(" ").strip()

proc showSummary(query: Query; inputText, summary: string): bool =
  if summary.len == 0:
    return false

  let onlyRouteUser =
    inputText.len == 0 and
    query.fromUser.len == 1 and
    query.toUser.len == 0 and
    query.mentions.len == 0 and
    query.filters.len == 0 and
    query.excludes.len == 0 and
    query.includes.len == 0 and
    query.minLikes.len == 0 and
    query.minRetweets.len == 0 and
    query.minReplies.len == 0 and
    query.since.len == 0 and
    query.until.len == 0 and
    summary == ("from:" & query.fromUser[0])

  result = not onlyRouteUser

proc renderSearch*(): VNode =
  buildHtml(tdiv(class="panel-container")):
    tdiv(class="search-bar"):
      form(`method`="get", action="/search", autocomplete="off"):
        hiddenField("f", "tweets")
        input(`type`="text", name="q", autofocus="",
              placeholder="Search...", dir="auto")
        button(`type`="submit"): icon "search"

proc renderProfileTabs*(query: Query; username: string;
                        tabs=ProfileTabState(showArticles: true, showHighlights: true, showAffiliates: true);
                        forceShowAffiliates=false): VNode =
  discard tabs
  discard forceShowAffiliates
  let link = "/" & username
  buildHtml(tdiv(role="tablist", class="profile-tablist")):
    a(role="tab", href=link, aria-selected=(if query.kind == posts: "true" else: "false")): text "Tweets"
    a(role="tab", href=(link & "/media"), aria-selected=(if query.kind == media: "true" else: "false")): text "Media"
    a(role="tab", href=(link & "/articles"), aria-selected=(if query.kind == articles: "true" else: "false")): text "Articles"
    a(role="tab", href=(link & "/highlights"), aria-selected=(if query.kind == highlights: "true" else: "false")): text "Highlights"
    a(role="tab", href=(link & "/affiliates"), aria-selected=(if query.kind == affiliates: "true" else: "false")): text "Affiliates"
    a(role="tab", href=(link & "/lists"), aria-selected=(if query.kind == lists: "true" else: "false")): text "Lists"
    a(role="tab", href=(link & "/search"), aria-selected=(if query.kind == tweets: "true" else: "false")): text "Search"

proc renderSearchTabs*(query: Query): VNode =
  var
    tweetQuery = query
    userQuery = query

  userQuery.kind = users
  if userQuery.text.len == 0:
    if query.fromUser.len > 0:
      userQuery.text = query.fromUser.join(" ")
    elif query.toUser.len > 0:
      userQuery.text = query.toUser.join(" ")
    elif query.mentions.len > 0:
      userQuery.text = query.mentions.join(" ")
    else:
      userQuery.text = displayQuery(query)

  buildHtml(tdiv(role="tablist", class="profile-tablist")):
    tweetQuery.kind = tweets
    a(role="tab", href=("?" & genQueryUrl(tweetQuery)),
      aria-selected=(if query.kind == tweets: "true" else: "false")):
      text "Tweets"
    a(role="tab", href=("?" & genQueryUrl(userQuery)),
      aria-selected=(if query.kind == users: "true" else: "false")):
      text "Users"

proc localCollectionQueryUrl*(query: Query; memberScope=""): string

proc isPanelOpen(q: Query): bool =
  @[q.filters.len, q.excludes.len, q.includes.len, q.toUser.len,
    q.mentions.len].anyIt(it > 0) or
  @[q.minLikes, q.minRetweets, q.minReplies, q.until, q.since].anyIt(it.len > 0)

proc collectionScopedQuery*(query: Query): Query =
  result = query
  result.fromUser = @[]

proc localCollectionQueryUrl*(query: Query; memberScope=""): string =
  let scoped = collectionScopedQuery(query)
  var params: seq[string]
  let display = displayQuery(scoped)
  params.add "f=tweets"
  if scoped.sort != latest:
    params.add "sort=" & encodeUrl($scoped.sort)
  if scoped.scope != scopeAll:
    params.add "scope=" & encodeUrl($scoped.scope)
  if display.len > 0:
    params.add "q=" & encodeUrl(display)
  if memberScope.len > 0:
    params.add "members=" & encodeUrl(memberScope)
  params.join("&")

proc renderSearchPanel*(query: Query; path: string): VNode =
  let
    action = path.split('#')[0].split('?')[0]
    inputText = panelText(query)
  var summaryQuery = query
  summaryQuery.text = inputText
  let summary = displayQuery(summaryQuery)
  buildHtml(form(`method`="get", action=action,
                 class="search-field", autocomplete="off")):
    hiddenField("f", "tweets")
    hiddenField("sort", $query.sort)
    hiddenField("scope", $query.scope)
    input(id="search-panel-toggle", `type`="checkbox", checked=isPanelOpen(query))

    tdiv(class="search-primary"):
      tdiv(class="search-primary-input"):
        genInput("q", "", inputText, "Enter search...", class="pref-inline")
      tdiv(class="search-primary-actions"):
        button(`type`="submit"): icon "search"
        label(`for`="search-panel-toggle", class="search-panel-trigger", title="Toggle advanced filters"):
          icon "down"

    if showSummary(query, inputText, summary):
      tdiv(class="search-summary"):
        text summary

    tdiv(class="search-panel"):
      tdiv(class="search-grid"):
        for f in @["filter", "exclude"]:
          article(class="search-section"):
            tdiv(class="search-section-head"):
              span(class="search-title"): text capitalizeAscii(f)
            tdiv(class="search-toggles"):
              for k, v in toggles:
                let state =
                  if f == "filter": k in query.filters
                  else: k in query.excludes
                genCheckbox(&"{f[0]}-{k}", v, state)

        article(class="search-section"):
          tdiv(class="search-section-head"):
            span(class="search-title"): text "Users"
          tdiv(class="search-row search-row-3"):
            genInput("from_user", "", query.fromUser.join(", "), "from:user", autofocus=false)
            genInput("to_user", "", query.toUser.join(", "), "to:user", autofocus=false)
            genInput("mentions", "", query.mentions.mapIt("@" & it).join(", "), "@user", autofocus=false)

        article(class="search-section"):
          tdiv(class="search-section-head"):
            span(class="search-title"): text "Time range"
          tdiv(class="date-range"):
            genDate("since", query.since)
            span(class="search-range-sep"): text "to"
            genDate("until", query.until)

        article(class="search-section"):
          tdiv(class="search-section-head"):
            span(class="search-title"): text "Minimum engagement"
          tdiv(class="search-row search-row-3"):
            genNumberInput("min_faves", "", query.minLikes, "Likes", autofocus=false)
            genNumberInput("min_retweets", "", query.minRetweets, "Retweets", autofocus=false)
            genNumberInput("min_replies", "", query.minReplies, "Replies", autofocus=false)

proc renderLocalCollectionSearchPanel*(query: Query; path, memberScope: string;
                                       extraParams: openArray[(string, string)] = [];
                                       attentionMode=false): VNode =
  let
    action = path.split('#')[0].split('?')[0]
    scoped = collectionScopedQuery(query)
    inputText = panelText(scoped)
    summary = displayQuery(scoped)
    scopeText = memberScope.strip
    searchPlaceholder =
      if attentionMode: "Filter source posts with X operators"
      else: "Search this collection with X operators"
  buildHtml(form(`method`="get", action=action,
                 class="search-field", autocomplete="off")):
    hiddenField("f", "tweets")
    for pair in extraParams:
      hiddenField(pair[0], pair[1])
    hiddenField("sort", $query.sort)
    hiddenField("scope", $query.scope)
    input(id="search-panel-toggle", `type`="checkbox", checked=(isPanelOpen(scoped) or scopeText.len > 0))

    tdiv(class="search-primary"):
      tdiv(class="search-primary-input"):
        genInput("q", "", inputText, searchPlaceholder, class="pref-inline")
      tdiv(class="search-primary-actions"):
        button(`type`="submit"): icon "search"
        label(`for`="search-panel-toggle", class="search-panel-trigger", title="Toggle advanced filters"):
          icon "down"

    if showSummary(scoped, inputText, summary) or scopeText.len > 0:
      tdiv(class="search-summary"):
        if scopeText.len > 0:
          text "profiles: " & scopeText
          if summary.len > 0:
            text " · "
        if summary.len > 0:
          text summary

    tdiv(class="search-panel"):
      if attentionMode:
        p(class="search-section-note"):
          text "These filters apply to the source posts from your tracked members before Attention is computed."
      tdiv(class="search-grid"):
        for f in @["filter", "exclude"]:
          article(class="search-section"):
            tdiv(class="search-section-head"):
              span(class="search-title"):
                text(if attentionMode and f == "filter": "Filter source posts" elif attentionMode and f == "exclude": "Exclude source posts" else: capitalizeAscii(f))
            tdiv(class="search-toggles"):
              for k, v in localCollectionToggles:
                let state =
                  if f == "filter": k in scoped.filters
                  else: k in scoped.excludes
                genCheckbox(&"{f[0]}-{k}", v, state)

        article(class="search-section"):
          tdiv(class="search-section-head"):
            span(class="search-title"): text "Profiles"
          p(class="search-section-note"):
            if scopeText.len > 0:
              text "Currently filtered to: " & scopeText
            elif attentionMode:
              text "Use the Filter profiles control above to choose which tracked members contribute source posts."
            else:
              text "Use the Filter profiles control above to scope this collection to specific members."

        article(class="search-section"):
          tdiv(class="search-section-head"):
            span(class="search-title"):
              text(if attentionMode: "Source post time range" else: "Time range")
          tdiv(class="date-range"):
            genDate("since", scoped.since)
            span(class="search-range-sep"): text "to"
            genDate("until", scoped.until)

        article(class="search-section"):
          tdiv(class="search-section-head"):
            span(class="search-title"):
              text(if attentionMode: "Minimum source post engagement" else: "Minimum engagement")
          tdiv(class="search-row search-row-3"):
            genNumberInput("min_faves", "", scoped.minLikes, "Likes", autofocus=false)
            genNumberInput("min_retweets", "", scoped.minRetweets, "Retweets", autofocus=false)
            genNumberInput("min_replies", "", scoped.minReplies, "Replies", autofocus=false)

      details(class="search-advanced"):
        summary: text "Other operators"
        p(class="search-section-note"):
          if attentionMode:
            text "Use the main box for rarer X operators. These operators still filter source posts before Attention is computed."
          else:
            text "Use the main search box for rarer X operators like quoted_tweet_id:, conversation_id:, exact phrases, or list:."

proc profileSurfaceEmptyMessage(query: Query): string =
  let username =
    if query.fromUser.len > 0: "@" & query.fromUser[0]
    else: ""
  case query.kind
  of replies:
    "No replies are available for " & username & " in this view right now."
  of media:
    "No media available for " & username & " yet."
  of articles:
    "No articles published by " & username & " yet."
  of highlights:
    "No highlights available for " & username & " yet."
  of affiliates:
    "No affiliate accounts available for " & username & "."
  of tweets:
    "No posts matched this search right now."
  else:
    if username.len > 0:
      "No posts available for " & username & " yet."
    else:
      "Nothing matched this surface right now."

proc renderTweetSearch*(results: Timeline; prefs: Prefs; path: string;
                        pinned=none(Tweet);
                        tabs=ProfileTabState(showArticles: true, showHighlights: true, showAffiliates: false);
                        forceShowAffiliates=false): VNode =
  let query = results.query
  let basePath = path.split('#')[0].split('?')[0]
  let queryString = genQueryUrl(query)
  buildHtml(tdiv(class="timeline-container")):
    if query.fromUser.len > 1:
      tdiv(class="timeline-header"):
        text query.fromUser.join(" | ")

    if query.fromUser.len > 0:
      renderProfileTabs(query, query.fromUser.join(","), tabs, forceShowAffiliates=forceShowAffiliates)

    if query.fromUser.len > 0 and query.kind != tweets:
      tdiv(class="timeline-header timeline-header-left"):
        renderExportControls(basePath, queryString, "export-profile-surface",
          includeRss=(if queryString.len > 0: basePath & "/rss?" & queryString else: basePath & "/rss"))
        renderPageMeta("Stored content is retained for 45 days. Use LIVE for a fresh read of the current surface.")

    if query.fromUser.len == 0 or query.kind == tweets:
      tdiv(class="timeline-header"):
        tdiv(class="search-surface"):
          renderSearchPanel(query, basePath)
          tdiv(class="search-surface-footer"):
            renderExportControls(basePath, queryString, "export-search-surface",
              includeRss=(basePath & "/rss?" & queryString))
            renderPageMeta("Stored content is retained for 45 days. Use LIVE for a fresh read of current search results.")

    if query.fromUser.len == 0:
      renderSearchTabs(query)

    let emptyMessage =
      if query.fromUser.len > 0:
        profileSurfaceEmptyMessage(query)
      else:
        "No posts matched this search right now."
    renderTimelineTweets(results, prefs, path, pinned, emptyMessage,
      exportFormId=(if query.fromUser.len == 0 or query.kind == tweets:
        "export-search-surface"
      else:
        "export-profile-surface"))

proc renderUserSearch*(results: Result[User]; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header"):
      tdiv(class="search-surface search-surface-users"):
        form(`method`="get", action="/search", class="search-field search-field-simple", autocomplete="off"):
          hiddenField("f", "users")
          tdiv(class="search-primary"):
            tdiv(class="search-primary-input"):
              genInput("q", "", results.query.text, "Search accounts...", class="pref-inline")
            tdiv(class="search-primary-actions"):
              button(`type`="submit"): icon "search"
        tdiv(class="search-surface-footer"):
          renderPageActions([
            ("LIVE", "/search/live/json?f=users&q=" & encodeUrl(results.query.text)),
            ("JSON", "/search/json?f=users&q=" & encodeUrl(results.query.text)),
            ("MD", "/search/md?f=users&q=" & encodeUrl(results.query.text)),
            ("TXT", "/search/txt?f=users&q=" & encodeUrl(results.query.text))
          ])
          renderPageMeta("Stored content is retained for 45 days. Use LIVE for a fresh read of current search results.")

    renderSearchTabs(results.query)
    renderTimelineUsers(results, prefs)

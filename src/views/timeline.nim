# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, algorithm, uri, options
import karax/[karaxdsl, vdom, vstyles]

import ".."/[types, query, formatters]
import tweet, renderutils

proc getQuery(query: Query): string =
  if query.kind != posts:
    result = genQueryUrl(query)
  if result.len > 0:
    result &= "&"

proc renderToTop*(focus="#"): VNode =
  buildHtml(tdiv(class="top-ref")):
    icon "down", href=focus

proc renderNewer*(query: Query; path: string; focus=""): VNode =
  let
    q = genQueryUrl(query)
    url = if q.len > 0: "?" & q else: ""
    p = if focus.len > 0: path.replace("#m", focus) else: path
  buildHtml(tdiv(class="show-newer")):
    a(class="button ghost small", href=(p & url)):
      text "← Back to start"

proc renderMore*(query: Query; cursor: string; focus=""): VNode =
  buildHtml(nav(class="finch-pagination")):
    span(class="finch-pagination-spacer")
    a(class="button ghost small",
      href=(&"?{getQuery(query)}cursor={encodeUrl(cursor, usePlus=false)}{focus}"),
      `data-infinite-target`="load-more"):
      text "Load more"

proc renderNoMore(): VNode =
  buildHtml(tdiv(class="timeline-footer")):
    span(class="timeline-end-text"): text "No more posts"

proc renderTweetSkeleton*(): VNode =
  buildHtml(tdiv(class="timeline-item timeline-item-skeleton")):
    figure(`data-variant`="avatar", role="status", class="skeleton box")
    tdiv(class="skeleton-body"):
      tdiv(role="status", class="skeleton line", style={width: "38%"})
      tdiv(role="status", class="skeleton line")
      tdiv(role="status", class="skeleton line", style={width: "60%"})

proc renderNoneFound(message="Nothing matched this surface right now."): VNode =
  let safeMessage =
    if message.len > 0: message
    else: "Nothing matched this surface right now."
  buildHtml(tdiv(class="timeline-header")):
    h2(class="timeline-none"):
      text safeMessage

proc renderUnavailable(message: string): VNode =
  let safeMessage = if message.len > 0: message else: "This surface could not be refreshed right now."
  buildHtml(tdiv(class="timeline-header")):
    tdiv(role="alert", `data-variant`="warning"):
      text safeMessage

proc renderWarning(message: string): VNode =
  if message.len == 0:
    return buildHtml(tdiv())
  buildHtml(tdiv(class="timeline-header", role="alert", `data-variant`="warning")):
    text message

proc renderThread(thread: Tweets; prefs: Prefs; path: string; exportFormId=""): VNode =
  buildHtml(tdiv(class="thread-line")):
    let sortedThread = thread.sortedByIt(it.id)
    for i, tweet in sortedThread:
      # thread has a gap, display "more replies" link
      if i > 0 and tweet.replyId != sortedThread[i - 1].id:
        tdiv(class="timeline-item thread more-replies-thread"):
          tdiv(class="more-replies"):
            a(class="more-replies-text", href=getLink(tweet)):
              text "more replies"

      let show = i == thread.high and sortedThread[0].id != tweet.threadId
      let header = if tweet.pinned or tweet.retweet.isSome: "with-header " else: ""
      renderTweet(tweet, prefs, path, class=(header & "thread"),
                  index=i, last=(i == thread.high), exportFormId=exportFormId)

proc renderUser(user: User; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline-item profile-result-row", data-username=user.username)):
    a(class="tweet-link", href=("/" & user.username))
    a(class="profile-result-avatar", href=("/" & user.username)):
      genAvatarFigure(user.getUserPic("_bigger"), ("@" & user.username))
    tdiv(class="profile-result-body"):
      tdiv(class="profile-result-head"):
        tdiv(class="profile-result-name"):
          linkUser(user, class="fullname")
          verifiedIcon(user)
          affiliateBadge(user)
        linkUser(user, class="username")

      tdiv(class="tweet-content media-body profile-result-bio", dir="auto"):
        verbatim replaceUrls(user.bio, prefs)

proc renderTimelineUsers*(results: Result[User]; prefs: Prefs; path=""): VNode =
  buildHtml(tdiv(class="timeline")):
    if not results.beginning:
      renderNewer(results.query, path)

    if results.content.len > 0:
      if results.errorText.len > 0:
        renderWarning(results.errorText)
      for user in results.content:
        renderUser(user, prefs)
      if results.bottom.len > 0:
        renderMore(results.query, results.bottom)
      renderToTop()
    elif not results.beginning:
      # Load-more page with no results: show "No more items" not the error
      renderNoMore()
    elif results.errorText.len > 0:
      renderUnavailable(results.errorText)
    else:
      renderNoneFound()

proc renderTimelineTweets*(results: Timeline; prefs: Prefs; path: string;
                           pinned=none(Tweet); emptyMessage="Nothing matched this surface right now.";
                           exportFormId=""): VNode =
  buildHtml(tdiv(class="timeline")):
    if not results.beginning:
      renderNewer(results.query, parseUri(path).path)

    if not prefs.hidePins and pinned.isSome:
      let tweet = get pinned
      renderTweet(tweet, prefs, path, exportFormId=exportFormId)

    if results.content.len == 0:
      if not results.beginning:
        # Load-more page with no results: show "No more items" not the error
        renderNoMore()
      elif results.errorText.len > 0:
        renderUnavailable(results.errorText)
      else:
        renderNoneFound(emptyMessage)
    else:
      if results.errorText.len > 0:
        renderWarning(results.errorText)
      var retweets: seq[int64]

      for thread in results.content:
        if thread.len == 1:
          let
            tweet = thread[0]
            retweetId = if tweet.retweet.isSome: get(tweet.retweet).id else: 0

          if retweetId in retweets or tweet.id in retweets or
             tweet.pinned and prefs.hidePins:
            continue

          if retweetId != 0 and tweet.retweet.isSome:
            retweets &= retweetId
          renderTweet(tweet, prefs, path, exportFormId=exportFormId)
        else:
          renderThread(thread, prefs, path, exportFormId)

      if results.bottom.len > 0:
        renderMore(results.query, results.bottom)
      renderToTop()

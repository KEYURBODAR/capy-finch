# SPDX-License-Identifier: AGPL-3.0-only
import strformat, strutils
import karax/[karaxdsl, vdom]

import renderutils, actions
import ".."/[types, utils, formatters]

proc renderListTabs*(query: Query; path: string): VNode =
  buildHtml(tdiv(role="tablist", class="profile-tablist")):
    a(role="tab", href=path, aria-selected=(if query.kind == posts: "true" else: "false")):
      text "Tweets"
    a(role="tab", href=(path & "/members"), aria-selected=(if query.kind == userList: "true" else: "false")):
      text "Members"

proc renderListMembers*(results: Result[User]): VNode =
  buildHtml(tdiv(class="table finch-table-wrap")):
    table:
      thead:
        tr:
          th: text "Profile"
          th(class="finch-table-num"): text "Followers"
      tbody:
        if results.content.len == 0:
          tr:
            td(colspan="2", class="finch-table-empty"):
              text (if results.errorText.len > 0: results.errorText else: "No members available for this X list right now.")
        else:
          for user in results.content:
            tr:
              td:
                a(class="finch-table-account", href=("/" & user.username)):
                  if user.userPic.len > 0:
                    genAvatarFigure(user.getUserPic("_bigger"), ("@" & user.username), size="small", style="border-radius: 0")
                  tdiv(class="finch-table-account-copy"):
                    span(class="finch-table-account-primary"):
                      span(class="finch-table-account-handle"):
                        text "@" & user.username
                      verifiedIcon(user)
                      affiliateBadge(user)
              td(class="finch-table-num"):
                text compactCount(user.followers)

proc renderList*(body: VNode; query: Query; list: List): VNode =
  let
    suffix = if query.kind == userList: "/members" else: ""
    basePath = &"/i/lists/{list.id}{suffix}"
    rssPath = if query.kind == userList: "" else: &"/i/lists/{list.id}/rss"
    handle = if list.username.len > 0: "@" & list.username else: "X list"
    memberLabel =
      if list.members <= 0: "public list"
      elif list.members == 1: "1 member"
      else: &"{list.members} members"

  buildHtml(tdiv(class="timeline-container")):
    if list.banner.len > 0:
      tdiv(class="timeline-banner"):
        a(href=getPicUrl(list.banner), target="_blank"):
          genImg(list.banner)

    tdiv(class="timeline-header list-header-card card"):
      tdiv(class="list-header-topline"):
        text "List"

      h1(class="list-title"):
        text list.name
        text " "
        span(class="badge secondary"): text memberLabel

      tdiv(class="list-subtitle"):
        text handle

      if list.description.len > 0:
        tdiv(class="timeline-description list-description"):
          text list.description

      renderExportControls(basePath, "", "export-public-list-" & list.id, includeRss=rssPath)
      renderPageMeta("Stored content is retained for 45 days. Use LIVE for a fresh read.")

    renderListTabs(query, &"/i/lists/{list.id}")
    body

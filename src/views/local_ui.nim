# SPDX-License-Identifier: AGPL-3.0-only
import strformat, strutils, sequtils, times, uri
import karax/[karaxdsl, vdom]

import renderutils, actions, timeline, search
import ".."/[types, local_data, query, formatters]

proc renderMemberMini(member: FinchCollectionMember; linked=true): VNode =
  if linked:
    return buildHtml(a(class="finch-member-mini", href=("/" & member.username), title=member.fullname)):
      if member.avatar.len > 0:
        genAvatarFigure(member.avatar, ("@" & member.username))
      else:
        span(class="finch-member-fallback"): text member.username[0 .. 0].toUpperAscii

  buildHtml(span(class="finch-member-mini", title=member.fullname)):
    if member.avatar.len > 0:
      genAvatarFigure(member.avatar, ("@" & member.username))
    else:
      span(class="finch-member-fallback"): text member.username[0 .. 0].toUpperAscii

proc renderMemberIdentity(member: FinchCollectionMember; square=false): VNode =
  let avatarStyle = if square: "border-radius: 0" else: ""
  let displayName =
    if member.fullname.len > 0: member.fullname
    else: "@" & member.username
  buildHtml(a(class="finch-table-account", href=("/" & member.username), title=member.fullname)):
    if member.avatar.len > 0:
      genAvatarFigure(member.avatar, ("@" & member.username), size="small", style=avatarStyle)
    else:
      span(class="finch-member-fallback"): text member.username[0 .. 0].toUpperAscii
    tdiv(class="finch-table-account-copy"):
      tdiv(class="finch-table-account-primary"):
        span(class="finch-table-account-name"): text displayName
        memberVerifiedIcon(member)
        memberAffiliateBadge(member)
      tdiv(class="finch-table-account-meta"):
        text "@" & member.username

proc renderAttentionIdentity(entity: AttentionEntity): VNode =
  let isAccount = entity.kind == attentionAccount
  let accountLabel =
    if isAccount and entity.label.len > 0:
      if entity.label.startsWith("@"): entity.label else: "@" & entity.label
    else:
      entity.title
  buildHtml(tdiv(class="finch-attention-entity")):
    if entity.avatar.len > 0:
      a(class="finch-attention-avatar", href=entity.href):
        genAvatarFigure(entity.avatar, entity.label, size="small", style="border-radius: 0")
    else:
      a(class="finch-attention-avatar finch-attention-avatar-fallback", href=entity.href):
        text (if isAccount: "@" else: entity.label[0 .. 0].toUpperAscii)
    tdiv(class="finch-attention-entity-copy"):
      tdiv(class="finch-attention-primary-line"):
        a(class="finch-attention-link", href=entity.href):
          text(if isAccount: accountLabel else: entity.title)
        if isAccount and entity.verifiedType != VerifiedType.none:
          renderVerifiedBadge(entity.verifiedType)
        if isAccount and entity.affiliateBadgeName.len > 0:
          renderAffiliateBadge(entity.affiliateBadgeName, entity.affiliateBadgeUrl, entity.affiliateBadgeTarget)
      let secondary =
        if isAccount: ""
        elif not isAccount and entity.subtitle.len > 0: entity.subtitle
        else: ""
      if secondary.len > 0:
        tdiv(class="finch-attention-secondary-line"):
          text secondary

proc renderCollectionCard*(collection: FinchCollection): VNode =
  let href =
    if collection.kind == following: "/f/following"
    else: "/f/lists/" & collection.id
  buildHtml(a(class="finch-collection-card card", href=href)):
    tdiv(class="finch-collection-card-head"):
      h3(class="finch-collection-card-title"): text collection.name
      span(class="finch-collection-card-count"):
        text &"{compactCount(collection.membersCount)} profiles"
    if collection.description.len > 0:
      p(class="finch-collection-card-copy"): text collection.description
    if collection.previewMembers.len > 0:
      tdiv(class="finch-collection-card-strip"):
        for member in collection.previewMembers:
          renderMemberMini(member, linked=false)
    else:
      span(class="finch-collection-card-empty"): text "No members yet"

proc selectedMemberSummary(memberScope: string): string =
  if memberScope.strip.toLowerAscii == "__finch_none__":
    return "No profiles selected"
  let names = memberScope.split(',').mapIt(it.strip).filterIt(it.len > 0)
  if names.len == 0:
    return ""
  if names.len == 1:
    return names[0]
  if names.len == 2:
    return names[0] & ", " & names[1]
  names[0] & ", " & names[1] & " +" & $(names.len - 2)

proc defaultCollectionSince(): string =
  (now().utc - initDuration(hours=24)).format("yyyy-MM-dd")

proc memberAddedLabel(member: FinchCollectionMember): string =
  if member.addedAtIso.len >= 10:
    member.addedAtIso[0 .. 9]
  elif member.addedAtIso.len > 0:
    member.addedAtIso
  else:
    "—"

proc collectionEmptyMessage(collection: FinchCollection; query: Query; memberScope: string): string =
  let
    hasText = query.text.strip.len > 0
    hasDate = query.since.len > 0 or query.until.len > 0
    hasFilters = query.filters.len > 0 or query.excludes.len > 0 or query.includes.len > 0
    hasEngagement = query.minLikes.len > 0 or query.minRetweets.len > 0 or query.minReplies.len > 0
    explicitNone = memberScope.strip.toLowerAscii == "__finch_none__"
    collectionLabel = if collection.kind == following: "Following" else: "this list"

  if explicitNone:
    return "No profiles are selected right now. Clear the profile filter or choose members to see posts again."
  if hasDate and (hasText or hasFilters or hasEngagement):
    return "No posts matched the current filters in the selected date range."
  if hasDate:
    return "No posts were found in the selected date range."
  if hasText or hasFilters or hasEngagement:
    return "No posts matched the current filters on " & collectionLabel & "."
  "No posts are available on " & collectionLabel & " right now."

proc rangePresetLabel(query: Query): string =
  if query.since.len == 0 and query.until.len == 0:
    return "all"
  let since = query.since
  if query.until.len > 0:
    return "custom"
  if since == defaultCollectionSince():
    return "24h"
  if since == (now().utc - initDuration(days=3)).format("yyyy-MM-dd"):
    return "3d"
  if since == (now().utc - initDuration(days=7)).format("yyyy-MM-dd"):
    return "7d"
  if since == (now().utc - initDuration(days=30)).format("yyyy-MM-dd"):
    return "30d"
  "custom"

proc collectionHref(basePath: string; query: Query; memberScope: string;
                    includeMembers=false; extraParams: openArray[(string, string)] = []): string =
  let scopedMembers =
    if memberScope.strip.toLowerAscii == "__finch_none__": ""
    else: memberScope
  let queryString = localCollectionQueryUrl(query, scopedMembers)
  result = basePath
  if queryString.len > 0:
    result &= "?" & queryString
  if includeMembers:
    result &= (if "?" in result: "&" else: "?") & "include_members=on"
  for pair in extraParams:
    if pair[0].len == 0 or pair[1].len == 0:
      continue
    result &= (if "?" in result: "&" else: "?") & encodeUrl(pair[0]) & "=" & encodeUrl(pair[1])

proc collectionRangeHref(basePath: string; query: Query; memberScope, preset: string;
                         includeMembers=false; extraParams: openArray[(string, string)] = []): string =
  var scoped = query
  case preset
  of "24h":
    scoped.since = defaultCollectionSince()
    scoped.until.setLen 0
  of "3d":
    scoped.since = (now().utc - initDuration(days=3)).format("yyyy-MM-dd")
    scoped.until.setLen 0
  of "7d":
    scoped.since = (now().utc - initDuration(days=7)).format("yyyy-MM-dd")
    scoped.until.setLen 0
  of "30d":
    scoped.since = (now().utc - initDuration(days=30)).format("yyyy-MM-dd")
    scoped.until.setLen 0
  of "all":
    scoped.since.setLen 0
    scoped.until.setLen 0
  else:
    discard
  result = collectionHref(basePath, scoped, memberScope, includeMembers=includeMembers,
    extraParams=extraParams)

proc renderCollectionRangeChips(query: Query; basePath, memberScope: string;
                                includeMembers=false; extraParams: openArray[(string, string)] = []): VNode =
  let active = rangePresetLabel(query)
  buildHtml(tdiv(class="finch-range-chips")):
    for preset in ["24h", "3d", "7d", "30d", "all"]:
      let
        label = if preset == "all": "All" else: preset
        klass = if active == preset: "button outline compact active" else: "button outline compact"
      a(class=klass, href=collectionRangeHref(basePath, query, memberScope, preset,
                                              includeMembers=includeMembers,
                                              extraParams=extraParams)):
        text label

proc renderAttentionMembersToggle(query: Query; basePath, memberScope: string;
                                  includeMembers: bool; extraParams: openArray[(string, string)] = []): VNode =
  var scoped = query
  let
    externalHref = collectionHref(basePath, scoped, memberScope, includeMembers=false, extraParams=extraParams)
    includeHref = collectionHref(basePath, scoped, memberScope, includeMembers=true, extraParams=extraParams)
  buildHtml(tdiv(class="finch-range-chips")):
    a(class=(if not includeMembers: "button outline compact active" else: "button outline compact"),
      href=externalHref):
      text "External only"
    a(class=(if includeMembers: "button outline compact active" else: "button outline compact"),
      href=includeHref):
      text "Include members"

proc renderMemberFilter*(collection: FinchCollection; query: Query; basePath, memberScope: string;
                         extraParams: openArray[(string, string)] = []): VNode =
  let summary = selectedMemberSummary(memberScope)
  let selectedMembers = memberScope.split(',').mapIt(it.strip.toLowerAscii).filterIt(it.len > 0 and it != "__finch_none__")
  let explicitNone = memberScope.strip.toLowerAscii == "__finch_none__"
  let clearHref = collectionHref(basePath, query, "", extraParams=extraParams)
  buildHtml(details(class="finch-member-filter")):
    summary(class="button outline finch-member-filter-summary"):
      if summary.len > 0:
        text "Profiles: " & summary
      else:
        text "Filter profiles"
    form(`method`="get", action=basePath,
         class="finch-member-filter-panel", id=("member-scope-" & collection.id)):
      hiddenField("f", "tweets")
      hiddenField("member_scope_mode", "explicit")
      for pair in extraParams:
        hiddenField(pair[0], pair[1])
      if query.text.len > 0:
        hiddenField("q", displayQuery(collectionScopedQuery(query)))
      if query.sort != latest:
        hiddenField("sort", $query.sort)
      if query.scope != scopeAll:
        hiddenField("scope", $query.scope)
      for member in getCollectionMembers(collection.id):
        let checked = (not explicitNone) and (selectedMembers.len == 0 or selectedMembers.anyIt(it == member.username.toLowerAscii))
        genNamedCheckbox("scope_member_" & member.username, "@" & member.username,
          checked=checked, class="finch-list-choice")
      tdiv(class="finch-member-filter-actions"):
        tdiv(class="finch-member-filter-select"):
          button(`type`="button", class="button outline compact",
                 `data-checkbox-scope`="member-scope", `data-checkbox-action`="select-all",
                 `data-checkbox-root`=("member-scope-" & collection.id)):
            text "Select all"
          button(`type`="button", class="button outline compact",
                 `data-checkbox-scope`="member-scope", `data-checkbox-action`="clear",
                 `data-checkbox-root`=("member-scope-" & collection.id)):
            text "Clear"
        button(`type`="submit", class="button outline"): text "Apply"
        a(class="button outline", href=clearHref):
          text "Clear"

proc renderProfileLocalActions*(user: User; actions: FinchProfileActions): VNode =
  if not actions.hasIdentity:
    return buildHtml(tdiv(class="finch-profile-actions")):
      a(class="button outline", href=("/f/identity?referer=" & encodeUrl(actions.referer))):
        text "Create key"

  buildHtml(tdiv(class="finch-profile-actions")):
    form(`method`="post", action=("/api/f/follow/" & user.username), class="finch-profile-action-form"):
      refererField(actions.referer)
      button(`type`="submit", class="button outline"):
        text(if actions.followed: "Following" else: "Follow")

    details(class="finch-list-picker"):
      summary(class="button outline"):
        span(class="finch-list-picker-label"): text "Add to list"
      form(`method`="post", action=("/api/f/profile/" & user.username & "/lists"), class="finch-list-picker-panel"):
        refererField(actions.referer)
        if actions.collections.len == 0:
          p(class="finch-list-picker-empty"): text "No lists yet."
        else:
          for choice in actions.collections:
            genNamedCheckbox("list_" & choice.collection.id, choice.collection.name,
              checked=choice.selected, class="finch-list-choice")
        input(`type`="text", name="new_list_name", placeholder="New list", dir="auto")
        input(`type`="text", name="new_list_description", placeholder="Optional description", dir="auto")
        button(`type`="submit", class="button outline"):
          text "Save"

proc renderCollectionsIndex*(title, subtitle: string; collections: seq[FinchCollection];
                             canCreate=false): VNode =
  buildHtml(tdiv(class="timeline-container finch-local-surface finch-local-surface-wide")):
    tdiv(class="timeline-header timeline-header-left"):
      h1(class="finch-local-title"): text title
      if subtitle.len > 0:
        p(class="finch-local-copy"): text subtitle

    if canCreate:
      form(`method`="post", action="/api/f/lists", class="finch-inline-create"):
        input(`type`="text", name="name", placeholder="Create a new list", dir="auto")
        input(`type`="text", name="description", placeholder="Optional description", dir="auto")
        button(`type`="submit", class="button outline"): text "Create"

    if collections.len == 0:
      tdiv(class="timeline-item"):
        tdiv(class="timeline-none"): text "Nothing here yet."
    else:
      tdiv(class="finch-collection-grid"):
        for collection in collections:
          renderCollectionCard(collection)

proc renderLocalAddForm*(action, referer: string; placeholder="Add @username, @username"): VNode =
  buildHtml(form(`method`="post", action=action, class="finch-local-add")):
    refererField(referer)
    input(`type`="text", name="username", placeholder=placeholder, dir="auto")
    button(`type`="submit", class="button outline"):
      text "Add"

proc renderCollectionHeader*(collection: FinchCollection; query: Query; basePath, memberScope, meta: string): VNode =
  let queryString = localCollectionQueryUrl(query, memberScope)
  proc withQuery(path: string): string =
    if queryString.len > 0:
      path & "?" & queryString
    else:
      path

  let addAction =
    if collection.kind == following: "/api/f/following/members"
    else: "/api/f/lists/" & collection.id & "/members"
  let attentionPath = basePath & "/attention"
  buildHtml(tdiv(class="timeline-header timeline-header-left finch-local-header")):
    tdiv(class="finch-local-header-top"):
      h1(class="finch-local-title"): text collection.name
      tdiv(class="finch-local-header-actions"):
        a(class="button outline", href=attentionPath): text "Attention"
        a(class="button outline", href=(basePath & "/members")): text "Members"
        if collection.xListId.len > 0:
          a(class="button outline", href=("/i/lists/" & collection.xListId)): text "Open X list"
        if collection.kind == localList:
          form(`method`="post", action=("/api/f/lists/" & collection.id & "/delete"), class="finch-inline-action finch-list-delete-form"):
            refererField(basePath)
            button(`type`="submit", class="button outline"):
              text "Delete"
    if collection.description.len > 0:
      p(class="finch-local-copy"): text collection.description
    tdiv(class="finch-local-strip-wrap"):
      if collection.previewMembers.len > 0:
        tdiv(class="finch-collection-card-strip"):
          for member in collection.previewMembers:
            renderMemberMini(member)
      span(class="finch-local-meta"):
        text &"{compactCount(collection.membersCount)} profiles"
    if collection.membersCount > 0:
      renderMemberFilter(collection, query, basePath, memberScope)
      if memberScope.strip.toLowerAscii == "__finch_none__":
        p(class="finch-local-warning"):
          text "No profiles are currently selected in the member filter. Clear the filter or pick profiles to see posts again."
    renderLocalAddForm(addAction, basePath)
    renderCollectionRangeChips(query, basePath, memberScope)
    tdiv(class="search-surface finch-local-search-surface"):
      renderLocalCollectionSearchPanel(query, basePath, memberScope)
    renderExportControls(basePath, queryString, "export-local-" & collection.id,
      includeRss=withQuery(basePath & "/rss"))
    renderPageMeta(meta)

proc renderXListInfo*(collection: FinchCollection; basePath: string): VNode =
  if collection.xListId.len == 0:
    return buildHtml(tdiv())
  buildHtml(tdiv(class="finch-migrate-banner")):
    p(class="finch-migrate-copy"):
      if collection.kind == following:
        text "Following is backed by X List: "
      else:
        text "This Finch list is backed by X List: "
      a(href=("/i/lists/" & collection.xListId)):
        text collection.xListId
      text " — add/remove actions here sync to that backing list."

proc renderLocalTimeline*(collection: FinchCollection; results: Timeline; prefs: Prefs; path, memberScope: string): VNode =
  let basePath =
    if collection.kind == following: "/f/following"
    else: "/f/lists/" & collection.id
  let meta =
    if collection.kind == following:
      "Following is your synced monitor set. Search stays scoped to the accounts you added here."
    else:
      "This Finch list is synced to X. Search and exports stay scoped to the profiles saved in this list."
  let emptyMessage =
    collectionEmptyMessage(collection, results.query, memberScope)
  buildHtml(tdiv(class="timeline-container finch-local-surface finch-local-feed-surface")):
    renderCollectionHeader(collection, results.query, basePath, memberScope,
      meta)
    renderXListInfo(collection, basePath)
    renderTimelineTweets(results, prefs, path, emptyMessage=emptyMessage,
      exportFormId=("export-local-" & collection.id))

proc renderLocalMembers*(collection: FinchCollection; members: seq[FinchCollectionMember]): VNode =
  let addAction =
    if collection.kind == following: "/api/f/following/members"
    else: "/api/f/lists/" & collection.id & "/members"
  let basePath =
    if collection.kind == following: "/f/following/members"
    else: "/f/lists/" & collection.id & "/members"
  let listPath = if collection.kind == following: "/f/following" else: "/f/lists/" & collection.id
  let bulkFormId = "bulk-remove-" & collection.id
  buildHtml(tdiv(class="timeline-container finch-local-surface finch-local-surface-wide")):
    renderXListInfo(collection, listPath)
    tdiv(class="timeline-header timeline-header-left finch-local-header"):
      tdiv(class="finch-local-header-top"):
        h1(class="finch-local-title"): text collection.name & " members"
        tdiv(class="finch-local-header-actions"):
          a(class="button outline", href=listPath): text "View posts"
          a(class="button outline", href=(listPath & "/attention")): text "Attention"
          if collection.xListId.len > 0:
            a(class="button outline", href=("/i/lists/" & collection.xListId)): text "Open X list"
      p(class="finch-local-copy"):
        text &"{compactCount(collection.membersCount)} profiles"
        if collection.kind == following:
          text " in your synced Following monitor set."
        else:
          text " in this synced Finch list."
      renderLocalAddForm(addAction, basePath)
    if members.len == 0:
      tdiv(class="timeline-item"):
        tdiv(class="timeline-none"): text "No profiles yet."
    else:
      form(`method`="post",
           action=(if collection.kind == following:
             "/api/f/following/members/remove"
           else:
             "/api/f/lists/" & collection.id & "/members/remove"),
           class="finch-member-bulk-form", id=bulkFormId):
        refererField(basePath)
      tdiv(class="finch-member-toolbar"):
        tdiv(class="finch-member-toolbar-copy"):
          span(class="affiliate-surface-count"): text "Manage saved profiles"
          span(class="affiliate-surface-copy"): text "Bulk remove accounts or set per-profile hide rules."
        tdiv(class="affiliate-selection-tools"):
          button(`type`="button", class="button outline compact",
                 `data-checkbox-scope`="member-remove", `data-checkbox-action`="select-all",
                 `data-checkbox-root`=bulkFormId):
            text "Select all"
          button(`type`="button", class="button outline compact",
                 `data-checkbox-scope`="member-remove", `data-checkbox-action`="clear",
                 `data-checkbox-root`=bulkFormId):
            text "Clear"
          button(`type`="submit", class="button outline compact", form=bulkFormId):
            text "Remove selected"
      tdiv(class="table finch-table-wrap"):
        table(class="finch-members-table"):
          thead:
            tr:
              th(class="finch-table-select-col")
              th: text "Profile"
              th: text "Saved"
              th(class="finch-table-actions-col"): text "Actions"
          tbody:
            for member in members:
              let filterAction =
                if collection.kind == following:
                  "/api/f/following/members/" & member.username & "/filters"
                else:
                  "/api/f/lists/" & collection.id & "/members/" & member.username & "/filters"
              tr:
                td(class="finch-table-select-col"):
                  label(class="tickbox finch-member-select"):
                    input(`type`="checkbox", name=("remove_member_" & member.username), form=bulkFormId)
                td:
                  renderMemberIdentity(member, square=true)
                td:
                  text memberAddedLabel(member)
                td(class="finch-table-actions-col"):
                  tdiv(class="finch-member-actions"):
                    details(class="finch-member-settings"):
                      summary(class="button outline compact"): text "Filters"
                      form(`method`="post", action=filterAction, class="finch-member-filter-form"):
                        refererField(basePath)
                        genNamedCheckbox("hideRetweets", "Hide Retweets",
                          checked=member.filters.hideRetweets)
                        genNamedCheckbox("hideQuotes", "Hide Quotes",
                          checked=member.filters.hideQuotes)
                        genNamedCheckbox("hideReplies", "Hide Replies",
                          checked=member.filters.hideReplies)
                        button(`type`="submit", class="button outline compact"): text "Save"
                    form(`method`="post",
                         action=(if collection.kind == following:
                           "/api/f/following/members/" & member.username & "/remove"
                         else:
                           "/api/f/lists/" & collection.id & "/members/" & member.username & "/remove"),
                         class="finch-member-remove-form"):
                      refererField(basePath)
                      button(`type`="submit", class="button outline compact"):
                        text "Remove"

proc renderLocalAttention*(collection: FinchCollection; entities: seq[AttentionEntity];
                           query: Query; memberScope: string; includeMembers: bool;
                           sortBy: string): VNode =
  proc sourceReasonLabel(kind: AttentionSignalKind): string =
    case kind
    of attentionMention: "mentioned"
    of attentionRepost: "reposted"
    of attentionQuote: "quoted"
    of attentionLink: "linked"

  proc sourceReasonsLabel(source: AttentionSource): string =
    var labels: seq[string]
    for kind in [attentionQuote, attentionRepost, attentionMention, attentionLink]:
      if kind in source.reasons:
        labels.add sourceReasonLabel(kind)
    labels.join(" + ")

  proc sortHref(basePath, memberScope, sortBy: string): string =
    collectionHref(basePath, query, memberScope, includeMembers=includeMembers,
      extraParams = [("sort_by", sortBy)])

  proc sortChip(basePath, memberScope, current, value, label: string): VNode =
    let klass =
      if current.toLowerAscii == value.toLowerAscii: "button outline compact active"
      else: "button outline compact"
    buildHtml(a(class=klass, href=sortHref(basePath, memberScope, value))):
      text label
  let
    basePath = if collection.kind == following: "/f/following" else: "/f/lists/" & collection.id
    attentionPath = basePath & "/attention"
    attentionHref = collectionHref(attentionPath, query, memberScope, includeMembers=includeMembers,
      extraParams = [("sort_by", sortBy)])
    queryPos = attentionHref.find('?')
    attentionQueryString =
      if queryPos >= 0 and queryPos < attentionHref.high:
        attentionHref[queryPos + 1 .. ^1]
      else:
        ""
    meta =
      if includeMembers:
        "Attention highlights who or what this collection mentioned, reposted, linked, or quoted in the selected window."
      else:
        "Attention highlights outside accounts and domains this collection mentioned, reposted, linked, or quoted in the selected window."
  var attentionExtraParams = @[("sort_by", sortBy)]
  if includeMembers:
    attentionExtraParams.add(("include_members", "on"))
  buildHtml(tdiv(class="timeline-container finch-local-surface finch-local-surface-wide")):
    renderXListInfo(collection, basePath)
    tdiv(class="timeline-header timeline-header-left finch-local-header"):
      tdiv(class="finch-local-header-top"):
        h1(class="finch-local-title"): text collection.name & " attention"
        tdiv(class="finch-local-header-actions"):
          a(class="button outline", href=basePath): text "View posts"
          a(class="button outline", href=(basePath & "/members")): text "Members"
          if collection.xListId.len > 0:
            a(class="button outline", href=("/i/lists/" & collection.xListId)): text "Open X list"
      p(class="finch-local-copy"):
        text "Ranked by how many unique saved profiles paid attention to an account or domain."
      if collection.membersCount > 0:
        renderMemberFilter(collection, query, attentionPath, memberScope, extraParams=attentionExtraParams)
      renderCollectionRangeChips(query, attentionPath, memberScope,
        includeMembers=includeMembers, extraParams=[("sort_by", sortBy)])
      renderAttentionMembersToggle(query, attentionPath, memberScope,
        includeMembers, extraParams=[("sort_by", sortBy)])
      tdiv(class="finch-range-chips"):
        span(class="finch-local-meta"): text "Sort:"
        sortChip(attentionPath, memberScope, sortBy, "score", "Score")
        sortChip(attentionPath, memberScope, sortBy, "members", "Members")
        sortChip(attentionPath, memberScope, sortBy, "signals", "Signals")
        sortChip(attentionPath, memberScope, sortBy, "recent", "Recent")
        sortChip(attentionPath, memberScope, sortBy, "followers", "Followers")
        sortChip(attentionPath, memberScope, sortBy, "alpha", "A-Z")
      tdiv(class="search-surface finch-local-search-surface"):
        renderLocalCollectionSearchPanel(query, attentionPath, memberScope,
          extraParams=attentionExtraParams, attentionMode=true)
      renderExportControls(attentionPath, attentionQueryString, "export-attention-" & collection.id,
        includeRss=(if attentionQueryString.len > 0: attentionPath & "/rss?" & attentionQueryString else: attentionPath & "/rss"),
        selectionScope="")
      renderPageMeta(meta)
    if entities.len == 0:
      tdiv(class="timeline-item"):
        tdiv(class="timeline-none"):
          text "No attention signals stood out in this window."
    else:
      tdiv(class="finch-attention-scroll"):
        table(class="finch-attention-table"):
          colgroup:
            col(class="finch-attention-col-entity")
            col(class="finch-attention-col-metric")
            col(class="finch-attention-col-metric")
            col(class="finch-attention-col-metric")
            col(class="finch-attention-col-last")
            col(class="finch-attention-col-bio")
            col(class="finch-attention-col-why")
            col(class="finch-attention-col-action")
          thead:
            tr:
              th(class="finch-attention-th finch-attention-entity-cell"): text "Entity"
              th(class="finch-attention-th finch-attention-num"): text "Followers"
              th(class="finch-attention-th finch-attention-num"): text "Members"
              th(class="finch-attention-th finch-attention-num"): text "Signals"
              th(class="finch-attention-th finch-attention-num"): text "Last seen"
              th(class="finch-attention-th finch-attention-bio-cell"): text "Bio"
              th(class="finch-attention-th finch-attention-why-cell"): text "Why"
              th(class="finch-attention-th finch-attention-action-cell")
          tbody:
            for entity in entities:
              tr(class="finch-attention-row"):
                td(class="finch-attention-td finch-attention-entity-cell"):
                  renderAttentionIdentity(entity)
                td(class="finch-attention-td finch-attention-num"):
                  span(class="finch-attention-metric"):
                    text(if entity.followers.len > 0: entity.followers else: "—")
                td(class="finch-attention-td finch-attention-num"):
                  span(class="finch-attention-metric"):
                    text compactCount(entity.uniqueMembers)
                td(class="finch-attention-td finch-attention-num"):
                  span(class="finch-attention-metric"):
                    text compactCount(entity.touches)
                td(class="finch-attention-td finch-attention-num"):
                  span(class="finch-attention-metric"):
                    text entity.lastSeenLabel
                td(class="finch-attention-td finch-attention-bio-cell"):
                  tdiv(class="finch-attention-bio"):
                    text(if entity.bio.len > 0: entity.bio else: "—")
                td(class="finch-attention-td finch-attention-why-cell"):
                  tdiv(class="finch-attention-reasons"):
                    for source in entity.sources:
                      a(class="finch-attention-reason", href=source.href):
                        text source.actorLabel & " "
                        text sourceReasonsLabel(source)
                td(class="finch-attention-td finch-attention-action-cell"):
                  form(`method`="post",
                       action=(if collection.kind == following:
                         "/api/f/following/attention/hide"
                       else:
                         "/api/f/lists/" & collection.id & "/attention/hide"),
                       class="finch-inline-action finch-attention-hide-form"):
                    refererField(attentionHref)
                    hiddenField("entity_key", entity.key)
                    button(`type`="submit", class="button outline compact"):
                      text "Hide"

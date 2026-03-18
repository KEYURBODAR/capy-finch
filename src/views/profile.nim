# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, uri
import karax/[karaxdsl, vdom, vstyles]

import renderutils, search, actions, local_ui, timeline
import ".."/[types, utils, formatters, query, local_data]

proc renderStat(num: int; label, href: string): VNode =
  buildHtml(a(href=href, class="profile-stat")):
    span(class="profile-stat-value", `data-tooltip`=($num)):
      text compactCount(num)
    span(class="profile-stat-label"):
      text label

proc renderUserCard*(user: User; prefs: Prefs; profileActions=FinchProfileActions()): VNode =
  buildHtml(tdiv(class="profile-card card")):
    tdiv(class="profile-card-info"):
      let
        url = getPicUrl(user.getUserPic())
        size =
          if prefs.autoplayGifs and user.userPic.endsWith("gif"): ""
          else: "_400x400"

      a(class="profile-card-avatar", href=url, target="_blank"):
        genAvatarFigure(user.getUserPic(size), ("@" & user.username), loading="eager", size="large")

      tdiv(class="profile-card-tabs-name"):
        tdiv(class="profile-card-name-row"):
          linkUser(user, class="profile-card-fullname")
          verifiedIcon(user)
          affiliateBadge(user)
        linkUser(user, class="profile-card-username")

    tdiv(class="profile-card-extra"):
      if prefs.showProfileBio and user.bio.len > 0:
        tdiv(class="profile-bio"):
          p(dir="auto"):
            verbatim replaceUrls(user.bio, prefs)

      if user.location.len > 0:
        tdiv(class="profile-location"):
          span: icon "location"
          let (place, url) = getLocation(user)
          if url.len > 1:
            a(href=url): text place
          elif "://" in place:
            a(href=place): text place
          else:
            span: text place

      if user.website.len > 0:
        tdiv(class="profile-website"):
          span:
            let url = replaceUrls(user.website, prefs)
            icon "link"
            a(href=url): text url.shortLink

      tdiv(class="profile-joindate"):
        span(title=getJoinDateFull(user)):
          icon "calendar", getJoinDate(user)

      tdiv(class="profile-card-extra-links"):
        tdiv(class="profile-statlist"):
          renderStat(user.tweets, "Tweets", "/" & user.username)
          renderStat(user.following, "Following", "/" & user.username & "/following")
          renderStat(user.followers, "Followers", "/" & user.username & "/followers")
          renderStat(user.likes, "Likes", "/" & user.username & "/likes")
      if user.affiliatesCount > 0:
        tdiv(class="profile-affiliates-summary"):
          span(class="profile-affiliates-label"): text "Affiliates"
          a(class="profile-affiliates-link", href=(&"/{user.username}/affiliates")):
            text compactCount(user.affiliatesCount) & " linked accounts"
      renderProfileLocalActions(user, profileActions)

proc renderPhotoRail(profile: Profile): VNode =
  let count =
    if profile.user.media > 0:
      compactCount(profile.user.media)
    elif profile.photoRail.len > 0:
      compactCount(profile.photoRail.len) & "+"
    else:
      "0"
  buildHtml(tdiv(class="photo-rail-card")):
    tdiv(class="photo-rail-header"):
      a(href=(&"/{profile.user.username}/media")):
        icon "picture", count & " Photos and videos"

    input(id="photo-rail-grid-toggle", `type`="checkbox")
    label(`for`="photo-rail-grid-toggle", class="photo-rail-header-mobile"):
      icon "picture", count & " Photos and videos"
      icon "down"

    tdiv(class="photo-rail-grid"):
      for i, photo in profile.photoRail:
        if i == 16: break
        let photoSuffix =
          if "format" in photo.url or "placeholder" in photo.url: ""
          else: ":thumb"
        a(href=(&"/{profile.user.username}/status/{photo.tweetId}#m")):
          genImg(photo.url & photoSuffix)

proc renderBanner(banner: string): VNode =
  buildHtml():
    if banner.len == 0:
      a()
    elif banner.startsWith('#'):
      a(style={backgroundColor: banner})
    else:
      a(href=getPicUrl(banner), target="_blank"): genImg(banner)

proc renderProtected(username: string): VNode =
  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header timeline-protected"):
      h2: text "This account's tweets are protected."
      p: text &"Only confirmed followers have access to @{username}'s tweets."

proc renderProfileListItem(list: List): VNode =
  let
    handle = if list.username.len > 0: "@" & list.username else: "X list"
    membersLabel = if list.members == 1: "1 member" else: &"{compactCount(list.members)} members"
    subscribersLabel =
      if list.subscribers == 1: "1 subscriber"
      else: &"{compactCount(list.subscribers)} subscribers"
  buildHtml(a(class="profile-list-item", href=(&"/i/lists/{list.id}"))):
    tdiv(class="profile-list-item-title"): text list.name
    tdiv(class="profile-list-item-meta"):
      text handle & " • " & membersLabel & " • " & subscribersLabel
    if list.description.len > 0:
      tdiv(class="profile-list-item-description"):
        text list.description

proc renderProfileListsBody(user: User; results: Result[List]): VNode =
  buildHtml(tdiv()):
    tdiv(class="timeline-header timeline-header-left"):
      text "Lists"
    if results.content.len == 0:
      tdiv(class="timeline-item"):
        tdiv(class="timeline-none"):
          text "@" & user.username & " hasn’t created any Lists"
    else:
      for list in results.content:
        renderProfileListItem(list)

proc renderProfileLists*(user: User; results: Result[List]; prefs: Prefs; path: string;
                         profileActions=FinchProfileActions();
                         tabs=ProfileTabState(showArticles: true, showHighlights: true, showAffiliates: false)): VNode =
  var query = results.query
  query.fromUser = @[user.username]

  buildHtml(tdiv(class="profile-tabs")):
    if not prefs.hideBanner and user.banner.len > 0:
      tdiv(class="profile-banner"):
        renderBanner(user.banner)

    let sticky = if prefs.stickyProfile: " sticky" else: ""
    tdiv(class=("profile-tab" & sticky)):
      renderUserCard(user, prefs, profileActions)
    tdiv(class="timeline-container"):
      tdiv(class="timeline-header timeline-header-left"):
        renderPageActions([
          ("LIVE", &"/{user.username}/lists/live/json"),
          ("JSON", &"/{user.username}/lists/json"),
          ("MD", &"/{user.username}/lists/md"),
          ("TXT", &"/{user.username}/lists/txt")
        ])
        renderPageMeta("Stored content is retained for 45 days. Use LIVE for a fresh read.")

      renderProfileTabs(query, user.username, tabs,
        forceShowAffiliates=(user.affiliatesCount > 0))
      renderProfileListsBody(user, results)

proc renderAffiliateBulkPanel(ownerId: string; user: User; affiliateResults: Result[User]; referer: string): VNode =
  if affiliateResults.content.len == 0:
    return buildHtml(tdiv())

  if ownerId.len == 0:
    return buildHtml(tdiv(class="timeline-item")):
      a(class="button outline", href=("/f/identity?referer=" & encodeUrl(referer))):
        text "Create Finch key to follow or save affiliate accounts"

  let
    listChoices = getCollections(ownerId, "list")
    panelId = "affiliate-panel-" & user.username
  buildHtml(form(`method`="post",
                 action=(&"/api/f/affiliates/{user.username}/following"),
                 class="timeline-item affiliate-bulk-panel",
                 id=panelId)):
    refererField(referer)
    tdiv(class="affiliate-bulk-copy"):
      text "Select affiliated accounts to add to Following or save into Finch Lists."

    details(class="finch-list-picker affiliate-list-picker"):
      summary(class="button outline"):
        span(class="finch-list-picker-label"):
          text(if listChoices.len > 0: "Choose lists" else: "Create list")
      tdiv(class="finch-list-picker-panel"):
        if listChoices.len > 0:
          for choice in listChoices:
            genNamedCheckbox("list_" & choice.id, choice.name, class="finch-list-choice")
        input(`type`="text", name="new_list_name", placeholder="New list", dir="auto")
        input(`type`="text", name="new_list_description", placeholder="Optional description", dir="auto")

    tdiv(class="affiliate-selection-tools"):
        button(`type`="button", class="button outline compact",
             `data-checkbox-scope`="affiliates", `data-checkbox-action`="select-all",
             `data-checkbox-root`=panelId):
          text "Select all"
        button(`type`="button", class="button outline compact",
             `data-checkbox-scope`="affiliates", `data-checkbox-action`="clear",
             `data-checkbox-root`=panelId):
          text "Clear"

    tdiv(class="affiliate-member-grid"):
      for affiliate in affiliateResults.content:
        label(class="affiliate-member-row tickbox"):
          input(`type`="checkbox", name=("affiliate_" & affiliate.username), checked="")
          a(class="affiliate-member-link", href=("/" & affiliate.username)):
            if affiliate.userPic.len > 0:
              genAvatarFigure(affiliate.getUserPic("_bigger"), ("@" & affiliate.username), size="small")
            tdiv(class="affiliate-member-copy"):
              tdiv(class="affiliate-member-title"):
                linkUser(affiliate, class="fullname")
                verifiedIcon(affiliate)
                affiliateBadge(affiliate)
              if affiliate.fullname.len > 0 and affiliate.fullname.toLowerAscii != affiliate.username.toLowerAscii:
                span(class="affiliate-member-subtitle"):
                  text affiliate.username

    tdiv(class="affiliate-bulk-actions"):
      button(`type`="submit", class="button outline"):
        text "Add selected to Following"
      button(`type`="submit", class="button outline",
             formaction=(&"/api/f/affiliates/{user.username}/lists")):
        text "Add selected to Lists"

proc renderProfileAffiliates*(user: User; affiliateResults: Result[User]; prefs: Prefs; path, ownerId: string;
                              profileActions=FinchProfileActions();
                              tabs=ProfileTabState(showArticles: true, showHighlights: true, showAffiliates: true)): VNode =
  var query = Query(kind: affiliates, fromUser: @[user.username])
  let xHref =
    if user.username.len > 0: "https://x.com/" & user.username & "/affiliates"
    else: ""

  buildHtml(tdiv(class="profile-tabs")):
    if not prefs.hideBanner and user.banner.len > 0:
      tdiv(class="profile-banner"):
        renderBanner(user.banner)

    let sticky = if prefs.stickyProfile: " sticky" else: ""
    tdiv(class=("profile-tab" & sticky)):
      renderUserCard(user, prefs, profileActions)
    tdiv(class="timeline-container"):
      tdiv(class="timeline-header timeline-header-left"):
        renderPageActions([
          ("LIVE", &"/{user.username}/affiliates/live/json"),
          ("JSON", &"/{user.username}/affiliates/json"),
          ("MD", &"/{user.username}/affiliates/md"),
          ("TXT", &"/{user.username}/affiliates/txt")
        ])
        renderPageMeta("Affiliates are fetched directly from X business-profile roster data.")

      renderProfileTabs(query, user.username, tabs,
        forceShowAffiliates=(user.affiliatesCount > 0))
      tdiv(class="timeline-header timeline-header-left"):
        text "Affiliates"
      if affiliateResults.content.len == 0 and user.affiliatesCount == 0:
        tdiv(class="timeline-item"):
          tdiv(class="timeline-none"):
            text "@" & user.username & " has no affiliate accounts"
      else:
        tdiv(class="timeline-header timeline-header-left"):
          if user.affiliatesCount > 0:
            text compactCount(user.affiliatesCount) & " linked accounts"
          if xHref.len > 0:
            text " "
            a(class="button outline compact", href=xHref): text "Open on X"
        renderAffiliateBulkPanel(ownerId, user, affiliateResults, path)
        if affiliateResults.content.len > 0 or affiliateResults.errorText.len > 0:
          renderTimelineUsers(affiliateResults, prefs, path)

proc renderProfile*(profile: var Profile; prefs: Prefs; path: string;
                    profileActions=FinchProfileActions();
                    tabs=ProfileTabState(showArticles: true, showHighlights: true, showAffiliates: false)): VNode =
  profile.tweets.query.fromUser = @[profile.user.username]
  let
    tabPath =
      case profile.tweets.query.kind
      of media: &"/{profile.user.username}/media"
      of articles: &"/{profile.user.username}/articles"
      of highlights: &"/{profile.user.username}/highlights"
      of affiliates: &"/{profile.user.username}/affiliates"
      of tweets: &"/{profile.user.username}/search"
      else: &"/{profile.user.username}"
    queryString =
      if profile.tweets.query.kind == tweets:
        "?" & genQueryUrl(profile.tweets.query)
      else:
        ""
    rssPath =
      case profile.tweets.query.kind
      of media: tabPath & "/rss"
      of articles: tabPath & "/rss"
      of highlights: tabPath & "/rss"
      of tweets: tabPath & "/rss" & queryString
      else: &"/{profile.user.username}/rss"

  buildHtml(tdiv(class="profile-tabs")):
    if not prefs.hideBanner and profile.user.banner.len > 0:
      tdiv(class="profile-banner"):
        renderBanner(profile.user.banner)

    let sticky = if prefs.stickyProfile: " sticky" else: ""
    tdiv(class=("profile-tab" & sticky)):
      renderUserCard(profile.user, prefs, profileActions)
      let showPhotoRail =
        not prefs.hideMediaRail and
        profile.photoRail.len > 0 and
        profile.tweets.query.kind in {tweets, media} and
        not path.endsWith("/search")
      if showPhotoRail:
        renderPhotoRail(profile)

    if profile.user.protected:
      renderProtected(profile.user.username)
    else:
      renderTweetSearch(profile.tweets, prefs, path, profile.pinned, tabs,
        forceShowAffiliates=(profile.user.affiliatesCount > 0))

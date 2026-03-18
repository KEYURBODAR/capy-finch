# SPDX-License-Identifier: AGPL-3.0-only
import sequtils
import karax/[karaxdsl, vdom]

import renderutils
import ../types

proc renderPreferences*(prefs: Prefs; path, identityKey: string; collections: seq[FinchCollection]): VNode =
  let
    followingCount = collections.filterIt(it.kind == following).foldl(a + b.membersCount, 0)
    listCount = collections.countIt(it.kind == localList)
  buildHtml(tdiv(class="overlay-panel settings-panel")):
    tdiv(class="settings-header"):
      h1(class="settings-title"): text "Preferences"
      p(class="settings-subtitle"):
        text "Compact controls for layout, reading, media, and fetch behavior on this browser."

    form(`method`="post", action="/saveprefs", autocomplete="off", class="settings-form"):
      refererField path

      tdiv(class="settings-grid"):
        details(open=""):
          summary: text "Layout"
          tdiv(class="settings-toggle-grid"):
            genCheckbox("stickyNav", "Keep top bar fixed", prefs.stickyNav)
            genCheckbox("stickyProfile", "Keep profile rail fixed", prefs.stickyProfile)
            genCheckbox("squareAvatars", "Use square avatars", prefs.squareAvatars)
            genCheckbox("hideBanner", "Hide profile banners", prefs.hideBanner)
            genCheckbox("hideMediaRail", "Hide profile media rail", prefs.hideMediaRail)
            genCheckbox("showProfileBio", "Show profile bio in sidebar", prefs.showProfileBio)

        details(open=""):
          summary: text "Reading"
          tdiv(class="settings-toggle-grid"):
            genCheckbox("hideTweetStats", "Hide reply/retweet/like stats", prefs.hideTweetStats)
            genCheckbox("hidePins", "Hide pinned posts", prefs.hidePins)
            genCheckbox("hideReplies", "Hide reply threads", prefs.hideReplies)
            genCheckbox("excludeRepliesByDefault", "Exclude replies in search, Following, and Lists", prefs.excludeRepliesByDefault)
            genCheckbox("hideCommunityNotes", "Hide community notes", prefs.hideCommunityNotes)
            genCheckbox("hideLinkCards", "Hide link cards", prefs.hideLinkCards)
            genCheckbox("hideInlineArticles", "Hide inline article panels", prefs.hideInlineArticles)
            genCheckbox("bidiSupport", "Enable bidi text support", prefs.bidiSupport)

        details():
          summary: text "Media"
          tdiv(class="settings-toggle-grid"):
            genCheckbox("autoplayGifs", "Autoplay gifs", prefs.autoplayGifs)
            genCheckbox("mp4Playback", "Play gifs as mp4", prefs.mp4Playback)
            genCheckbox("hlsPlayback", "Enable HLS playback", prefs.hlsPlayback)
            genCheckbox("proxyVideos", "Proxy videos through Finch", prefs.proxyVideos)
            genCheckbox("muteVideos", "Mute videos by default", prefs.muteVideos)
            genCheckbox("hideMediaPreviews", "Hide photo/video/gif previews", prefs.hideMediaPreviews)

        details():
          summary: text "Speed and calls"
          tdiv(class="settings-toggle-grid"):
            genCheckbox("preloadMedia", "Preload banners and media images", prefs.preloadMedia)
            genCheckbox("infiniteScroll", "Enable infinite scroll", prefs.infiniteScroll)

        details():
          summary: text "Link rewrites"
          tdiv(class="settings-input-grid"):
            genInput("replaceTwitter", "X / Twitter", prefs.replaceTwitter, "nitter hostname", autofocus=false)
            genInput("replaceYouTube", "YouTube", prefs.replaceYouTube, "piped / invidious hostname", autofocus=false)
            genInput("replaceReddit", "Reddit", prefs.replaceReddit, "teddit / libreddit hostname", autofocus=false)

        details():
          summary: text "Finch data"
          if identityKey.len > 0:
            tdiv(class="settings-input-grid"):
              genSecretInput("identity_key_display", "Current recovery key", identityKey)
            tdiv(class="settings-toggle-grid identity-stats"):
              tdiv(class="identity-stat"):
                span(class="identity-stat-label"): text "Following"
                span(class="identity-stat-value"): text $followingCount
              tdiv(class="identity-stat"):
                span(class="identity-stat-label"): text "Lists"
                span(class="identity-stat-value"): text $listCount
            tdiv(class="settings-actions"):
              a(class="button outline", href="/f/following"): text "Open Following"
              a(class="button outline", href="/f/lists"): text "Open Lists"
              a(class="button outline", href="/f/data/export"): text "Export data"
              a(class="button outline", href=("/f/identity?referer=" & path)): text "Manage key"
              buttonReferer("/api/f/data/reset", "Cleanup caches", path, class="pref-reset")
              buttonReferer("/api/f/data/delete", "Delete everything", path, class="pref-reset")
          else:
            tdiv(class="settings-actions"):
              a(class="button outline", href=("/f/identity?referer=" & path)): text "Create or import key"
          form(`method`="post", action="/api/f/identity/import", autocomplete="off", class="settings-form compact data-key-form"):
            refererField(path)
            tdiv(class="settings-input-grid"):
              genInput("identity_key", "Import recovery key", "", "Paste recovery key", class="full", autofocus=false)
            tdiv(class="settings-actions"):
              button(`type`="submit", class="button outline"):
                text(if identityKey.len > 0: "Replace key" else: "Import key")

      tdiv(class="settings-actions"):
        button(`type`="submit", class="button"):
          text "Save preferences"
        text " "
        buttonReferer("/resetprefs", "Reset", path, class="pref-reset")

    form(`method`="post", action="/api/f/data/import", autocomplete="off", class="settings-form compact data-import-form"):
      refererField(path)
      section(class="settings-section-wide"):
        h2(class="settings-section-title"): text "Import Finch bundle"
        p(class="settings-section-desc"): text "Paste an exported Finch JSON bundle to restore Following and Lists on this browser."
        tdiv(class="settings-input-grid"):
          tdiv(class="pref-group pref-input full"):
            label(`for`="bundle"): text "Bundle"
            textarea(name="bundle", placeholder="Paste exported Finch JSON bundle", rows="6")
        tdiv(class="settings-actions"):
          button(`type`="submit", class="button"):
            text "Import data"

    p(class="settings-note"):
      text "Preferences are stored locally in cookies on this browser. They only change Finch behavior here and are not attached to your X account."

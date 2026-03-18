# SPDX-License-Identifier: AGPL-3.0-only
import uri, strutils
import karax/[karaxdsl, vdom]

import renderutils
import ../utils, ../types, ../prefs, ../formatters
import ../local_identity
import identity

import jester

const
  doctype = "<!DOCTYPE html>\n"

proc shouldShowIdentityPrompt(req: Request): bool =
  shouldPromptForIdentity(req)

proc needsLocalActionsScript(req: Request): bool =
  let path = req.path
  if path.len == 0:
    return false
  if path.startsWith("/api/") or path.startsWith("/about"):
    return false
  if path == "/" or path == "/settings" or path == "/f/identity":
    return false
  true

proc renderNavAction(label, href, title: string): VNode =
  buildHtml(a(class="nav-action", title=title, href=href, aria-label=label)):
    text label

proc renderNavbar(cfg: Config; req: Request; rss, canonical: string): VNode =
  var path = req.params.getOrDefault("referer")
  if path.len == 0:
    path = $(parseUri(req.path) ? filterParams(req.params))
    if "/status/" in path: path.add "#m"

  buildHtml(nav):
    tdiv(class="inner-nav"):
      tdiv(class="nav-item left"):
        a(class="site-name", href="/"): text "Finch"

      tdiv(class="nav-item right"):
        renderNavAction("Search", "/search", "Search")
        renderNavAction("Following", "/f/following", "Following")
        renderNavAction("Lists", "/f/lists", "Lists")
        if cfg.enableAdmin:
          renderNavAction("Admin", "/api/private/meta", "Private Admin")
        renderNavAction("Prefs", ("/settings?referer=" & encodeUrl(path)), "Preferences")
        tdiv(class="nav-overflow-menu"):
          verbatim "<ot-dropdown>"
          button(class="button ghost small nav-overflow-trigger", popovertarget="nav-popover", `aria-label`="Menu", `aria-expanded`="false"):
            text "···"
          tdiv(popover="", role="menu", id="nav-popover", class="nav-overflow-popover"):
            a(role="menuitem", href="/search"): text "Search"
            a(role="menuitem", href="/f/following"): text "Following"
            a(role="menuitem", href="/f/lists"): text "Lists"
            if cfg.enableAdmin:
              a(role="menuitem", href="/api/private/meta"): text "Admin"
            a(role="menuitem", href=("/settings?referer=" & encodeUrl(path))): text "Preferences"
          verbatim "</ot-dropdown>"

proc renderHead*(prefs: Prefs; cfg: Config; req: Request; titleText=""; desc="";
                 video=""; images: seq[string] = @[]; banner=""; ogTitle="";
                 rss=""; alternate=""): VNode =
  let ogType =
    if video.len > 0: "video"
    elif rss.len > 0: "object"
    elif images.len > 0: "photo"
    else: "article"

  let opensearchUrl = getUrlPrefix(cfg) & "/opensearch"
  let needsIdentityScript = req.path == "/f/identity" or shouldShowIdentityPrompt(req)
  let needsLocalActions = needsLocalActionsScript(req)

  buildHtml(head):
    link(rel="stylesheet", type="text/css", href="/css/oat.css")
    link(rel="stylesheet", type="text/css", href="/css/style.css?v=63")
    link(rel="stylesheet", type="text/css", href="/css/fontello.css?v=4")
    script(src="/js/oat.js", `defer`="")
    if needsIdentityScript:
      script(src="/js/recoveryKey.js?v=1", `defer`="")
    if needsLocalActions:
      script(src="/js/localActions.js?v=6", `defer`="")
    link(rel="apple-touch-icon", sizes="180x180", href="/apple-touch-icon.png")
    link(rel="icon", type="image/png", sizes="32x32", href="/favicon-32x32.png")
    link(rel="icon", type="image/png", sizes="16x16", href="/favicon-16x16.png")
    link(rel="manifest", href="/site.webmanifest")
    link(rel="mask-icon", href="/safari-pinned-tab.svg", color="#ff6c60")
    link(rel="search", type="application/opensearchdescription+xml", title=cfg.title,
                            href=opensearchUrl)

    if alternate.len > 0:
      link(rel="alternate", href=alternate, title="View on X")

    if rss.len > 0:
      link(rel="alternate", type="application/rss+xml", href=rss, title="RSS feed")

    if prefs.hlsPlayback:
      script(src="/js/hls.min.js", `defer`="")
      script(src="/js/hlsPlayback.js", `defer`="")

    script(src="/js/infiniteScroll.js?v=4", `defer`="")

    title:
      if titleText.len > 0:
        text titleText & " | " & cfg.title
      else:
        text cfg.title

    meta(name="viewport", content="width=device-width, initial-scale=1.0")
    meta(name="theme-color", content="#09090b")
    meta(property="og:type", content=ogType)
    meta(property="og:title", content=(if ogTitle.len > 0: ogTitle else: titleText))
    meta(property="og:description", content=stripHtml(desc))
    meta(property="og:site_name", content=cfg.title)
    meta(property="og:locale", content="en_US")

    if prefs.preloadMedia:
      if banner.len > 0 and not banner.startsWith('#'):
        let bannerUrl = getPicUrl(banner)
        link(rel="preload", type="image/png", href=bannerUrl, `as`="image")

      for url in images:
        let preloadUrl = if "400x400" in url: getPicUrl(url)
                         else: getSmallPic(url)
        link(rel="preload", type="image/png", href=preloadUrl, `as`="image")

    for url in images:
      let image = getUrlPrefix(cfg) & getPicUrl(url)
      meta(property="og:image", content=image)
      meta(property="twitter:image:src", content=image)

      if rss.len > 0:
        meta(property="twitter:card", content="summary")
      else:
        meta(property="twitter:card", content="summary_large_image")

    if video.len > 0:
      meta(property="og:video:url", content=video)
      meta(property="og:video:secure_url", content=video)
      meta(property="og:video:type", content="text/html")

    # this is last so images are also preloaded
    # if this is done earlier, Chrome only preloads one image for some reason
    link(rel="preload", type="font/woff2", `as`="font",
         href="/fonts/fontello.woff2?61663884", crossorigin="anonymous")

proc renderMain*(body: VNode; req: Request; cfg: Config; prefs=defaultPrefs;
                 titleText=""; desc=""; ogTitle=""; rss=""; video="";
                 images: seq[string] = @[]; banner=""): string =

  let twitterLink = getTwitterLink(req.path, req.params)

  let node = buildHtml(html(lang="en", data-theme="dark")):
    renderHead(prefs, cfg, req, titleText, desc, video, images, banner, ogTitle,
               rss, twitterLink)

    let bodyClass = if prefs.stickyNav: "fixed-nav" else: ""
    body(class=bodyClass):
      renderNavbar(cfg, req, rss, twitterLink)

      if req.path != "/f/identity" and shouldShowIdentityPrompt(req):
        renderIdentityPrompt(req.path)

      tdiv(class="toast-container", `data-placement`="bottom-right")

      tdiv(class="container"):
        body

  result = doctype & $node

proc renderError*(error: string): VNode =
  ## Renders error with HTML escaping (safe for user/exception input).
  buildHtml(tdiv(class="panel-container")):
    tdiv(role="alert", `data-variant`="danger"):
      text error

proc renderErrorHtml*(error: string): VNode =
  ## Renders error with raw HTML (only use for trusted, hardcoded strings).
  buildHtml(tdiv(class="panel-container")):
    tdiv(role="alert", `data-variant`="danger"):
      verbatim error

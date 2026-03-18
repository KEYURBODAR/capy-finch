# SPDX-License-Identifier: AGPL-3.0-only
import strutils, sequtils, strformat, options, algorithm
import karax/[karaxdsl, vdom, vstyles]
from jester import Request

import renderutils
import ".."/[types, utils, formatters]
from ../articles import getArticleUrl
import general
import article

const doctype = "<!DOCTYPE html>\n"

proc effectiveArticleUrl(tweet: Tweet): string =
  getArticleUrl(tweet)

proc articlePathFromText(value: string): string =
  let lowered = value.toLowerAscii
  let pos =
    if "/i/article/" in lowered: lowered.find("/i/article/")
    else: -1
  if pos < 0:
    return ""
  let tail = value[pos + "/i/article/".len .. ^1]
  var articleId = ""
  for ch in tail:
    if ch in {'0'..'9'}:
      articleId.add ch
    else:
      break
  if articleId.len == 0:
    return ""
  "/i/article/" & articleId

proc effectiveArticleHref(tweet: Tweet): string =
  getLink(tweet, focus=false) & "/article"

proc looksLikeStandaloneArticleToken(value: string): bool =
  let stripped = value.strip.toLowerAscii()
  if stripped.len == 0:
    return true
  if stripped.startsWith("x.com/i/article/") or
     stripped.startsWith("twitter.com/i/article/") or
     stripped.startsWith("/i/article/"):
    return true
  if (stripped.startsWith("https://t.co/") or
      stripped.startsWith("http://t.co/") or
      stripped.startsWith("t.co/")) and
      ' ' notin stripped and '\n' notin stripped and '\t' notin stripped:
    return true
  false

proc renderInlineArticlePreview(tweet: Tweet): VNode =
  let articleUrl = effectiveArticleUrl(tweet)
  if articleUrl.len == 0:
    return buildHtml(tdiv())

  var
    title = ""
    body = ""
    coverUrl = ""
  if tweet.card.isSome:
    let card = tweet.card.get
    title = card.title.strip
    body = card.text.strip
    coverUrl = card.image

  if title.len == 0:
    title = articleUrl
  if body.len == 0:
    body = tweet.text.strip

  renderCompactArticlePreview(articleUrl, title, body, coverUrl,
    hrefOverride=effectiveArticleHref(tweet))

proc shouldHideArticleUrlText(tweet: Tweet): bool =
  let stripped = tweet.text.strip.toLowerAscii
  if tweet.article.isSome:
    if stripped.startsWith("x.com/i/article/") or
       stripped.startsWith("https://x.com/i/article/") or
       stripped.startsWith("http://x.com/i/article/") or
       stripped.startsWith("twitter.com/i/article/") or
       stripped.startsWith("https://twitter.com/i/article/") or
       stripped.startsWith("http://twitter.com/i/article/") or
       stripped.startsWith("/i/article/"):
      return true
    if looksLikeStandaloneArticleToken(tweet.text):
      return true

  let effectiveUrl = effectiveArticleUrl(tweet)
  if effectiveUrl.len == 0:
    return false
  proc canonicalArticleText(value: string): string =
    result = value.strip.toLowerAscii()
    for prefix in ["https://", "http://", "www."]:
      if result.startsWith(prefix):
        result = result[prefix.len .. ^1]
    if result.endsWith("/"):
      result.setLen(result.len - 1)

  let articleUrl = canonicalArticleText(effectiveUrl)
  if stripped.len == 0:
    return false

  if stripped.startsWith("x.com/i/article/") or
     stripped.startsWith("twitter.com/i/article/") or
     stripped.startsWith("/i/article/"):
    return true

  let pathOnly =
    if "/i/article/" in articleUrl:
      articleUrl[articleUrl.find("/i/article/") .. ^1]
    else:
      articleUrl

  var remainder = stripped
  for candidate in [
    articleUrl,
    pathOnly,
    "x.com" & pathOnly,
    "twitter.com" & pathOnly,
    "https://x.com" & pathOnly,
    "http://x.com" & pathOnly,
    "https://twitter.com" & pathOnly,
    "http://twitter.com" & pathOnly
  ]:
    if candidate.len > 0:
      remainder = remainder.replace(candidate, "")

  remainder = remainder.multiReplace(("\n", " "), ("\t", " "), ("…", ""), ("/", " "), ("\u00a0", " "))
  remainder = remainder.strip()

  remainder.len == 0 or
    stripped == articleUrl or
    stripped.startsWith("x.com/i/article/") or
    stripped.startsWith("twitter.com/i/article/")

proc renderMiniAvatar(user: User; prefs: Prefs): VNode =
  genImg(user.getUserPic("_mini"), class=(prefs.getAvatarClass & " mini"))

proc renderHeader(tweet: Tweet; retweet: string; pinned: bool; prefs: Prefs): VNode =
  buildHtml(tdiv):
    if pinned:
      tdiv(class="pinned"):
        span(class="badge secondary"):
          icon "pin", "Pinned Tweet"
    elif retweet.len > 0:
      tdiv(class="retweet-header"):
        span(class="badge secondary"):
          icon "retweet", retweet & " retweeted"

    tdiv(class="tweet-header"):
      a(class="tweet-avatar", href=("/" & tweet.user.username)):
        var size = "_bigger"
        if not prefs.autoplayGifs and tweet.user.userPic.endsWith("gif"):
          size = "_400x400"
        genAvatarFigure(tweet.user.getUserPic(size), ("@" & tweet.user.username),
          loading="lazy", size="",
          style=(if prefs.squareAvatars: "border-radius: var(--radius-small)" else: ""))

      tdiv(class="tweet-name-row"):
        tdiv(class="fullname-and-username"):
          linkUser(tweet.user, class="fullname")
          verifiedIcon(tweet.user)
          affiliateBadge(tweet.user)
          linkUser(tweet.user, class="username")
        span(class="tweet-date"):
          a(href=getLink(tweet), title=tweet.getTime, `data-tooltip`=tweet.getTime):
            text tweet.getShortTime

proc renderAlbum(tweet: Tweet): VNode =
  let
    groups = if tweet.photos.len < 3: @[tweet.photos]
             else: tweet.photos.distribute(2)

  buildHtml(tdiv(class="attachments")):
    for i, photos in groups:
      let margin = if i > 0: ".25em" else: ""
      tdiv(class="gallery-row", style={marginTop: margin}):
        for photo in photos:
          tdiv(class="attachment image"):
            let
              named = "name=" in photo.url
              small = if named: photo.url else: photo.url & smallWebp
            a(href=getOrigPicUrl(photo.url), class="still-image", target="_blank"):
              genImg(small, alt=photo.altText)
            if photo.altText.len > 0:
              p(class="alt-text"): text "ALT  " & photo.altText

proc isPlaybackEnabled(prefs: Prefs; playbackType: VideoType): bool =
  case playbackType
  of mp4: prefs.mp4Playback
  of m3u8, vmap: prefs.hlsPlayback

proc hasMp4Url(video: Video): bool =
  video.variants.anyIt(it.contentType == mp4)

proc renderVideoDisabled(playbackType: VideoType; path: string): VNode =
  buildHtml(tdiv(class="video-overlay")):
    case playbackType
    of mp4:
      p: text "mp4 playback disabled in preferences"
    of m3u8, vmap:
      buttonReferer "/enablehls", "Enable hls playback", path

proc renderVideoUnavailable(video: Video): VNode =
  buildHtml(tdiv(class="video-overlay")):
    case video.reason
    of "dmcaed":
      p: text "This media has been disabled in response to a report by the copyright owner"
    else:
      p: text "This media is unavailable"

proc renderVideo*(video: Video; prefs: Prefs; path: string): VNode =
  let
    container = if video.description.len == 0 and video.title.len == 0: ""
                else: " card-container"
    playbackType = if not prefs.proxyVideos and video.hasMp4Url: mp4
                   else: video.playbackType

  buildHtml(tdiv(class="attachments card")):
    tdiv(class="gallery-video" & container):
      tdiv(class="attachment video-container"):
        let thumb = getSmallPic(video.thumb)
        if not video.available:
          img(src=thumb, loading="lazy")
          renderVideoUnavailable(video)
        elif not prefs.isPlaybackEnabled(playbackType):
          img(src=thumb, loading="lazy")
          renderVideoDisabled(playbackType, path)
        else:
          let
            vars = video.variants.filterIt(it.contentType == playbackType)
            vidUrl = vars.sortedByIt(it.resolution)[^1].url
            source = if prefs.proxyVideos: getVidUrl(vidUrl)
                     else: vidUrl
          case playbackType
          of mp4:
            video(poster=thumb, controls="", muted=prefs.muteVideos):
              source(src=source, `type`="video/mp4")
          of m3u8, vmap:
            video(poster=thumb, data-url=source, data-autoload="false", muted=prefs.muteVideos)
            verbatim "<div class=\"video-overlay\" onclick=\"playVideo(this)\">"
            tdiv(class="overlay-circle"): span(class="overlay-triangle")
            tdiv(class="overlay-duration"): text getDuration(video)
            verbatim "</div>"
      if container.len > 0:
        tdiv(class="card-content"):
          h2(class="card-title"): text video.title
          if video.description.len > 0:
            p(class="card-description"): text video.description

proc renderGif(gif: Gif; prefs: Prefs): VNode =
  buildHtml(tdiv(class="attachments media-gif")):
    tdiv(class="gallery-gif", style={maxHeight: "unset"}):
      tdiv(class="attachment"):
        video(class="gif", poster=getSmallPic(gif.thumb), autoplay=prefs.autoplayGifs,
              controls="", muted="", loop=""):
          source(src=getPicUrl(gif.url), `type`="video/mp4")

proc renderPoll(poll: Poll): VNode =
  buildHtml(tdiv(class="poll")):
    for i in 0 ..< poll.options.len:
      let
        leader = if poll.leader == i: " leader" else: ""
        val = poll.values[i]
        perc = if val > 0: val / poll.votes * 100 else: 0
        percStr = (&"{perc:>3.0f}").strip(chars={'.'}) & '%'
      tdiv(class=("poll-option" & leader)):
        span(class="poll-option-label"): text poll.options[i]
        progress(value = $perc.int, max = "100")
        span(class="poll-option-pct"): text percStr
    span(class="poll-info"):
      text &"{compactCount(poll.votes)} votes • {poll.status}"

proc renderCardImage(card: Card): VNode =
  buildHtml(tdiv(class="card-image-container")):
    tdiv(class="card-image"):
      genImg(card.image)
      if card.kind == player:
        tdiv(class="card-overlay"):
          tdiv(class="overlay-circle"):
            span(class="overlay-triangle")

proc renderCardContent(card: Card): VNode =
  buildHtml(tdiv(class="card-content")):
    h2(class="card-title"): text card.title
    if card.text.len > 0:
      p(class="card-description"): text card.text
    if card.dest.len > 0:
      span(class="card-destination"): text card.dest

proc renderCard(card: Card; prefs: Prefs; path: string): VNode =
  const smallCards = {app, player, summary, storeLink}
  let large = if card.kind notin smallCards: " large" else: ""
  let url = replaceUrls(card.url, prefs)

  buildHtml(tdiv(class=("card" & large))):
    if card.video.isSome:
      tdiv(class="card-container"):
        renderVideo(get(card.video), prefs, path)
        a(class="card-content-container", href=url):
          renderCardContent(card)
    else:
      a(class="card-container", href=url):
        if card.image.len > 0:
          renderCardImage(card)
        tdiv(class="card-content-container"):
          renderCardContent(card)

func formatStat(stat: int): string =
  if stat > 0: compactCount(stat)
  else: ""

proc renderStats(stats: TweetStats): VNode =
  buildHtml(tdiv(class="tweet-stats")):
    span(class="tweet-stat"): icon "comment", formatStat(stats.replies)
    span(class="tweet-stat"): icon "retweet", formatStat(stats.retweets)
    span(class="tweet-stat"): icon "heart", formatStat(stats.likes)
    span(class="tweet-stat"): icon "views", formatStat(stats.views)

proc renderReply(tweet: Tweet): VNode =
  buildHtml(tdiv(class="replying-to")):
    text "Replying to "
    for i, u in tweet.reply:
      if i > 0: text " "
      a(href=("/" & u)): text "@" & u

proc renderAttribution(user: User; prefs: Prefs): VNode =
  buildHtml(a(class="attribution", href=("/" & user.username))):
    renderMiniAvatar(user, prefs)
    strong: text user.fullname
    verifiedIcon(user)
    affiliateBadge(user)

proc renderMediaTags(tags: seq[User]): VNode =
  buildHtml(tdiv(class="media-tag-block")):
    icon "user"
    for i, p in tags:
      a(class="media-tag", href=("/" & p.username), title=p.username):
        text p.fullname
      if i < tags.high:
        text ", "

proc renderLatestPost(username: string; id: int64): VNode =
  buildHtml(tdiv(class="latest-post-version")):
    text "There's a new version of this post. "
    a(href=getLink(id, username)):
      text "See the latest post"

proc renderQuoteMedia(quote: Tweet; prefs: Prefs; path: string): VNode =
  buildHtml(tdiv(class="quote-media-container")):
    if quote.photos.len > 0:
      renderAlbum(quote)
    elif quote.video.isSome:
      renderVideo(quote.video.get(), prefs, path)
    elif quote.gif.isSome:
      renderGif(quote.gif.get(), prefs)

proc renderCommunityNote(note: string; prefs: Prefs): VNode =
  buildHtml(tdiv(class="community-note", role="alert", `data-variant`="warning")):
    tdiv(class="community-note-header"):
      icon "group"
      span: text "Community note"
    tdiv(class="community-note-text", dir="auto"):
      verbatim replaceUrls(note, prefs)

proc renderQuote(quote: Tweet; prefs: Prefs; path: string): VNode =
  if not quote.available:
    return buildHtml(tdiv(class="quote unavailable")):
      a(class="unavailable-quote", href=getLink(quote, focus=false)):
        if quote.tombstone.len > 0:
          text quote.tombstone
        elif quote.text.len > 0:
          text quote.text
        else:
          text "This tweet is unavailable"

  buildHtml(tdiv(class="quote quote-big")):
    a(class="quote-link", href=getLink(quote))

    tdiv(class="tweet-name-row"):
      tdiv(class="fullname-and-username"):
        renderMiniAvatar(quote.user, prefs)
        linkUser(quote.user, class="fullname")
        verifiedIcon(quote.user)
        affiliateBadge(quote.user)
        linkUser(quote.user, class="username")

      span(class="tweet-date"):
        a(href=getLink(quote), title=quote.getTime):
          text quote.getShortTime

    if quote.reply.len > 0:
      renderReply(quote)

    let hideQuoteArticleText = shouldHideArticleUrlText(quote)

    if quote.text.len > 0 and not hideQuoteArticleText:
      tdiv(class="quote-text", dir="auto"):
        verbatim replaceUrls(quote.text, prefs)

    if not prefs.hideInlineArticles:
      if quote.article.isSome:
        let articleData = quote.article.get
        let coverUrl =
          if articleData.cover.isSome: articleData.cover.get.url
          elif articleData.photos.len > 0: articleData.photos[0].url
          else: ""
        renderCompactArticlePreview(articleData.url, articleData.title, articleData.body, coverUrl,
          hrefOverride=effectiveArticleHref(quote))
      elif hideQuoteArticleText and effectiveArticleUrl(quote).len > 0:
        renderInlineArticlePreview(quote)

    if quote.photos.len > 0 or quote.video.isSome or quote.gif.isSome:
      renderQuoteMedia(quote, prefs, path)

    if quote.note.len > 0 and not prefs.hideCommunityNotes:
      renderCommunityNote(quote.note, prefs)

    if quote.hasThread:
      a(class="show-thread", href=getLink(quote)):
        text "Show this thread"

    if quote.history.len > 0 and quote.id != max(quote.history):
      tdiv(class="quote-latest"):
        text "There's a new version of this post"

proc renderLocation*(tweet: Tweet): string =
  let (place, url) = tweet.getLocation()
  if place.len == 0: return
  let node = buildHtml(span(class="tweet-geo")):
    text " – at "
    if url.len > 1:
      a(href=url): text place
    else:
      text place
  return $node

proc renderTweet*(tweet: Tweet; prefs: Prefs; path: string; class=""; index=0;
                  last=false; mainTweet=false; afterTweet=false; exportFormId=""): VNode =
  var divClass = class
  if index == -1 or last:
    divClass = "thread-last " & class

  if not tweet.available:
    return buildHtml(tdiv(class=divClass & "unavailable timeline-item", data-username=tweet.user.username)):
      a(class="unavailable-box", href=getLink(tweet)):
        if tweet.tombstone.len > 0:
          text tweet.tombstone
        elif tweet.text.len > 0:
          text tweet.text
        else:
          text "This tweet is unavailable"

      if tweet.quote.isSome:
        renderQuote(tweet.quote.get(), prefs, path)

  let
    fullTweet = tweet
    pinned = tweet.pinned

  var retweet: string
  var tweet = fullTweet
  if tweet.retweet.isSome:
    tweet = tweet.retweet.get
    retweet = fullTweet.user.fullname

  let selectableClass = if exportFormId.len > 0: " select-enabled" else: ""
  buildHtml(tdiv(class=("timeline-item " & divClass & selectableClass), data-username=tweet.user.username)):
    if exportFormId.len > 0:
      tdiv(class="tweet-export-select"):
        input(`type`="checkbox", value=($tweet.id), `data-export-select`="tweet", `data-export-form`=exportFormId)
    if not mainTweet:
      a(class="tweet-link", href=getLink(tweet))

    tdiv(class="tweet-body"):
      renderHeader(tweet, retweet, pinned, prefs)

      if not afterTweet and index == 0 and tweet.reply.len > 0 and
         (tweet.reply.len > 1 or tweet.reply[0] != tweet.user.username or pinned):
        renderReply(tweet)

      var tweetClass = "tweet-content media-body"
      if prefs.bidiSupport:
        tweetClass &= " tweet-bidi"

      let hideArticleText =
        shouldHideArticleUrlText(tweet) or
        (tweet.article.isSome and "/i/article/" in tweet.text.toLowerAscii)

      if tweet.text.len > 0 and not hideArticleText:
        tdiv(class=tweetClass, dir="auto"):
          verbatim replaceUrls(tweet.text, prefs) & renderLocation(tweet)

      if tweet.attribution.isSome:
        renderAttribution(tweet.attribution.get(), prefs)

      if not prefs.hideLinkCards and tweet.card.isSome and tweet.card.get().kind != hidden:
        renderCard(tweet.card.get(), prefs, path)

      if not prefs.hideMediaPreviews and tweet.photos.len > 0:
        renderAlbum(tweet)
      elif not prefs.hideMediaPreviews and tweet.video.isSome:
        renderVideo(tweet.video.get(), prefs, path)
      elif not prefs.hideMediaPreviews and tweet.gif.isSome:
        renderGif(tweet.gif.get(), prefs)

      if tweet.poll.isSome:
        renderPoll(tweet.poll.get())

      if tweet.quote.isSome:
        renderQuote(tweet.quote.get(), prefs, path)

      if not prefs.hideInlineArticles:
        if tweet.article.isSome:
          let articleData = tweet.article.get
          let coverUrl =
            if articleData.cover.isSome: articleData.cover.get.url
            elif articleData.photos.len > 0: articleData.photos[0].url
            else: ""
          renderCompactArticlePreview(articleData.url, articleData.title, articleData.body, coverUrl,
            hrefOverride=effectiveArticleHref(tweet))
        elif effectiveArticleUrl(tweet).len > 0:
          renderInlineArticlePreview(tweet)

      if tweet.note.len > 0 and not prefs.hideCommunityNotes:
        renderCommunityNote(tweet.note, prefs)

      let
        hasEdits = tweet.history.len > 1
        isLatest = hasEdits and tweet.id == max(tweet.history)

      if mainTweet:
        p(class="tweet-published"): 
          if hasEdits and isLatest:
            a(href=(getLink(tweet, focus=false) & "/history")):
              text &"Last edited {getTime(tweet)}"
          else:
            text &"{getTime(tweet)}"

        if hasEdits and not isLatest:
          renderLatestPost(tweet.user.username, max(tweet.history))

      if tweet.mediaTags.len > 0:
        renderMediaTags(tweet.mediaTags)

      if not prefs.hideTweetStats:
        renderStats(tweet.stats)

proc renderTweetEmbed*(tweet: Tweet; path: string; prefs: Prefs; cfg: Config; req: Request): string =
  let node = buildHtml(html(lang="en")):
    renderHead(prefs, cfg, req)

    body:
      tdiv(class="tweet-embed"):
        renderTweet(tweet, prefs, path, mainTweet=true)

  result = doctype & $node

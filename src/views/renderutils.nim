# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, sequtils
import karax/[karaxdsl, vdom, vstyles]
import ".."/[types, utils]
from .. / formatters import getLink

const smallWebp* = "?name=small&format=webp"

proc getSmallPic*(url: string): string =
  result = url
  if "?" notin url and not url.endsWith("placeholder.png"):
    result &= smallWebp
  result = getPicUrl(result)

proc icon*(icon: string; text=""; title=""; class=""; href=""): VNode =
  var c = "icon-" & icon
  if class.len > 0: c = &"{c} {class}"
  buildHtml(tdiv(class="icon-container")):
    if href.len > 0:
      a(class=class, title=title, href=href):
        span(class=c, title=title)
    else:
      span(class=c, title=title)

    if text.len > 0:
      text " " & text

proc finchInternalHref*(value: string): string =
  let raw = value.strip()
  if raw.len == 0:
    return ""
  if raw.startsWith("/"):
    return raw

  var url = raw
  if url.startsWith("x.com/"):
    url = "/" & url["x.com/".len .. ^1]
  elif url.startsWith("twitter.com/"):
    url = "/" & url["twitter.com/".len .. ^1]
  if url.startsWith("https://x.com/"):
    url = url["https://x.com".len .. ^1]
  elif url.startsWith("http://x.com/"):
    url = url["http://x.com".len .. ^1]
  elif url.startsWith("https://twitter.com/"):
    url = url["https://twitter.com".len .. ^1]
  elif url.startsWith("http://twitter.com/"):
    url = url["http://twitter.com".len .. ^1]
  else:
    return raw

  let clean = url.split({'?', '#'}, maxsplit=1)[0]
  if clean.len == 0:
    return "/"
  if clean.startsWith("/i/article/"):
    return clean
  if clean.startsWith("/i/lists/"):
    return clean
  let parts = clean.strip(chars={'/'}).split('/').filterIt(it.len > 0)
  if parts.len >= 4 and parts[0] == "i" and parts[1] == "web" and parts[2] == "status" and parts[3].allCharsInSet({'0'..'9'}):
    return "/i/status/" & parts[3]
  if parts.len >= 3 and parts[0] == "i" and parts[1] == "status" and parts[2].allCharsInSet({'0'..'9'}):
    return getLink(parseBiggestInt(parts[2]).int64, focus=false)
  if parts.len == 1:
    return "/" & parts[0]
  if parts.len >= 3 and parts[1] == "status":
    return "/" & parts[0] & "/status/" & parts[2]
  clean

proc renderVerifiedBadge*(verifiedType: VerifiedType): VNode =
  if verifiedType == VerifiedType.none:
    return buildHtml(tdiv())
  let lower = ($verifiedType).toLowerAscii()
  buildHtml(span(class=(&"verified-icon {lower}"), title=(&"Verified {lower} account"),
                 `data-tooltip`=(&"Verified {lower} account"))):
    span(class="verified-icon-circle")
    span(class="verified-icon-check"):
      text "✓"

template verifiedIcon*(user: User): untyped {.dirty.} =
  if user.verifiedType != VerifiedType.none:
    renderVerifiedBadge(user.verifiedType)
  else:
    text ""

proc renderAffiliateBadge*(name, imageUrl, target: string): VNode =
  if name.len == 0:
    return buildHtml(tdiv())
  let
    badgeTitle = "Affiliated with " & name
    badgeHref = finchInternalHref(target)
  buildHtml():
    if badgeHref.len > 0:
      a(class="affiliate-badge", href=badgeHref, title=badgeTitle):
        if imageUrl.len > 0:
          img(src=getPicUrl(imageUrl), class="affiliate-badge-image", alt=name, loading="lazy")
        else:
          span(class="affiliate-badge-fallback"): text name[0 .. 0]
    else:
      span(class="affiliate-badge", title=badgeTitle):
        if imageUrl.len > 0:
          img(src=getPicUrl(imageUrl), class="affiliate-badge-image", alt=name, loading="lazy")
        else:
          span(class="affiliate-badge-fallback"): text name[0 .. 0]

template affiliateBadge*(user: User): untyped {.dirty.} =
  if user.affiliateBadgeName.len > 0:
    renderAffiliateBadge(user.affiliateBadgeName, user.affiliateBadgeUrl, user.affiliateBadgeTarget)
  else:
    text ""

template memberVerifiedIcon*(member: FinchCollectionMember): untyped {.dirty.} =
  if member.verifiedType != VerifiedType.none:
    renderVerifiedBadge(member.verifiedType)
  else:
    text ""

template memberAffiliateBadge*(member: FinchCollectionMember): untyped {.dirty.} =
  if member.affiliateBadgeName.len > 0:
    renderAffiliateBadge(member.affiliateBadgeName, member.affiliateBadgeUrl, member.affiliateBadgeTarget)
  else:
    text ""


proc linkUser*(user: User, class=""): VNode =
  let
    isName = "username" notin class
    href = "/" & user.username
    nameText = if isName: user.fullname
               else: "@" & user.username

  buildHtml(a(href=href, class=class, title=nameText)):
    text nameText
    if isName:
      if user.protected:
        text " "
        icon "lock", title="Protected account"

proc linkText*(text: string; class=""): VNode =
  let url = if "http" notin text: https & text else: text
  buildHtml():
    a(href=url, class=class): text text

proc hiddenField*(name, value: string): VNode =
  buildHtml():
    input(name=name, style={display: "none"}, value=value)

proc refererField*(path: string): VNode =
  hiddenField("referer", path)

proc buttonReferer*(action, text, path: string; class=""; `method`="post"): VNode =
  buildHtml(form(`method`=`method`, action=action, class=class)):
    refererField path
    button(`type`="submit", class="button outline"):
      text text

proc genCheckbox*(pref, label: string; state: bool): VNode =
  buildHtml(label(class="pref-group tickbox", title=pref)):
    if state:
      input(name=pref, `type`="checkbox", checked="")
    else:
      input(name=pref, `type`="checkbox")
    span(class="tickbox-label"): text label

proc genNamedCheckbox*(name, label: string; checked=false; title=""; class=""): VNode =
  let
    rowClass =
      if class.len > 0: "tickbox " & class
      else: "tickbox"
    rowTitle = if title.len > 0: title else: name
  buildHtml(label(class=rowClass, title=rowTitle)):
    if checked:
      input(name=name, `type`="checkbox", checked="")
    else:
      input(name=name, `type`="checkbox")
    span(class="tickbox-label"): text label

proc genInput*(pref, label, state, placeholder: string; class=""; autofocus=true): VNode =
  let p = placeholder
  buildHtml(tdiv(class=("pref-group pref-input " & class), title=pref)):
    if label.len > 0:
      label(`for`=pref): text label
    input(name=pref, `type`="text", placeholder=p, value=state, autofocus=(autofocus and state.len == 0))

proc genSecretInput*(pref, label, state: string; note="Hidden by default. Click Show to reveal for 10 seconds."): VNode =
  buildHtml(tdiv(class="pref-group pref-input full settings-secret", title=pref, `data-secret-field`="")):
    if label.len > 0:
      label(`for`=pref): text label
    tdiv(class="settings-secret-row"):
      input(id=pref, name=pref, class="settings-secret-input", `type`="password",
            value=state, readonly="", spellcheck="false", autocomplete="off",
            `data-secret-input`="")
      button(`type`="button", class="button outline settings-secret-toggle",
             `data-secret-toggle`="", `aria-pressed`="false"):
        text "Show"
    p(class="settings-secret-note", `data-secret-note`=""):
      text note

proc genSelect*(pref, label, state: string; options: seq[string]): VNode =
  buildHtml(tdiv(class="pref-group pref-input", title=pref)):
    label(`for`=pref): text label
    select(name=pref):
      for opt in options:
        option(value=opt, selected=(opt == state)):
          text opt

proc genDate*(pref, state: string): VNode =
  let
    shortValue =
      if state.len == 10 and state[4] == '-' and state[7] == '-':
        state[2 .. ^1]
      else:
        state
  buildHtml(span(class="date-input")):
    input(id=pref, name=pref, `type`="text", value=shortValue, placeholder="YY-MM-DD",
          inputmode="numeric", spellcheck="false", autocomplete="off",
          pattern="\\d{2}-\\d{2}-\\d{2}", maxlength="8", `data-short-date`="")

proc genNumberInput*(pref, label, state, placeholder: string; class=""; autofocus=true; min="0"): VNode =
  let p = placeholder
  buildHtml(tdiv(class=("pref-group pref-input " & class))):
    if label.len > 0:
      label(`for`=pref): text label
    input(name=pref, `type`="number", placeholder=p, value=state, autofocus=(autofocus and state.len == 0), min=min, step="1")

proc genImg*(url: string; class=""; alt=""; loading="lazy"): VNode =
  buildHtml():
    img(src=getPicUrl(url), class=class, alt=alt, loading=loading)

proc genAvatarFigure*(url: string; alt: string; loading="lazy"; class=""; size=""; style=""): VNode =
  let figureClassBase =
    if size.len > 0 and class.len > 0: class & " " & size
    elif size.len > 0: size
    else: class
  let figureClass =
    if style.len > 0:
      if figureClassBase.len > 0: figureClassBase & " is-square"
      else: "is-square"
    else:
      figureClassBase
  buildHtml(figure(data-variant="avatar", class=figureClass)):
    img(src=getPicUrl(url), alt=alt, loading=loading)

proc getTabClass*(query: Query; tab: QueryKind): string =
  if query.kind == tab: "tab-item active"
  else: "tab-item"

proc getAvatarClass*(prefs: Prefs): string =
  if prefs.squareAvatars: "avatar"
  else: "avatar round"

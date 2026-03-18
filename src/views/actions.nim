# SPDX-License-Identifier: AGPL-3.0-only
import karax/[karaxdsl, vdom]
import strutils, uri

type PageActionLink* = tuple[label, href: string]

proc renderPageActions*(links: openArray[PageActionLink]): VNode =
  buildHtml(menu(class="buttons page-actions")):
    for link in links:
      if link.href.len == 0:
        continue
      li:
        a(class="page-action button outline small", href=link.href):
          text link.label

proc renderPageMeta*(textValue: string): VNode =
  if textValue.len == 0:
    buildHtml(tdiv())
  else:
    buildHtml(tdiv(class="page-meta")):
      text textValue

proc renderExportControls*(basePath, queryString, formId: string; includeRss=""; selectionScope="tweet-export"): VNode =
  proc hiddenPairs(): seq[(string, string)] =
    if queryString.len == 0:
      return @[]
    for chunk in queryString.split('&'):
      if chunk.len == 0:
        continue
      let pos = chunk.find('=')
      if pos < 0:
        result.add (decodeUrl(chunk), "")
      else:
        result.add (decodeUrl(chunk[0 ..< pos]), decodeUrl(chunk[pos + 1 .. ^1]))

  buildHtml(tdiv(class="page-export-toolbar")):
    if includeRss.len > 0:
      menu(class="buttons page-actions"):
        li:
          a(class="page-action button outline small", href=includeRss):
            text "RSS"

    form(`method`="get", action=(basePath & "/json"), class="page-export-form", id=formId):
      for (name, value) in hiddenPairs():
        input(`type`="hidden", name=name, value=value)
      input(`type`="hidden", name="selected_ids", value="", id=(formId & "-selected"))

      if selectionScope.len > 0:
        tdiv(class="page-export-select-actions"):
          button(`type`="button", class="button outline compact",
                 `data-checkbox-scope`=selectionScope, `data-checkbox-action`="select-all",
                 `data-checkbox-root`=formId):
            text "Select visible"
          button(`type`="button", class="button outline compact",
                 `data-checkbox-scope`=selectionScope, `data-checkbox-action`="clear",
                 `data-checkbox-root`=formId):
            text "Clear"

      tdiv(class="page-export-inline"):
        label(class="page-export-limit"):
          span: text "Last"
          input(`type`="number", name="limit", min="1", max="500", step="1",
                placeholder="100", inputmode="numeric", `data-export-limit`=formId)

        menu(class="buttons page-actions"):
          li:
            button(`type`="submit", class="page-action button outline small", formaction=(basePath & "/live/json")):
              text "LIVE"
          li:
            button(`type`="submit", class="page-action button outline small", formaction=(basePath & "/json")):
              text "JSON"
          li:
            button(`type`="submit", class="page-action button outline small", formaction=(basePath & "/md")):
              text "MD"
          li:
            button(`type`="submit", class="page-action button outline small", formaction=(basePath & "/txt")):
              text "TXT"

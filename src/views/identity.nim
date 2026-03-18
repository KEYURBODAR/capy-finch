# SPDX-License-Identifier: AGPL-3.0-only
import karax/[karaxdsl, vdom]

import renderutils

proc renderIdentityPrompt*(path: string): VNode =
  buildHtml(tdiv(class="finch-identity-modal")):
    tdiv(class="finch-identity-sheet"):
      tdiv(class="finch-identity-head"):
        h2(class="finch-identity-title"): text "Create your Finch key"
        p(class="finch-identity-copy"):
          text "Use one local recovery key for Following, Lists, import, and export. Skip for now if you only want public read access."

      tdiv(class="finch-identity-actions"):
        form(`method`="post", action="/api/f/identity/create", class="finch-identity-form"):
          refererField(path)
          button(`type`="submit", class="button outline"):
            text "Create key"

        form(`method`="post", action="/api/f/identity/import", class="finch-identity-form finch-identity-import"):
          refererField(path)
          input(`type`="text", name="identity_key", placeholder="Import existing recovery key", dir="auto")
          button(`type`="submit", class="button outline"):
            text "Import"

        form(`method`="post", action="/api/f/identity/skip", class="finch-identity-form"):
          refererField(path)
          button(`type`="submit", class="button outline muted"):
            text "Skip for now"

proc renderIdentityPage*(identityKey, referer, notice: string; followingCount, listCount: int): VNode =
  buildHtml(tdiv(class="overlay-panel settings-panel")):
    tdiv(class="settings-header"):
      h1(class="settings-title"): text "Finch key"
      if notice.len > 0:
        p(class="settings-subtitle"): text notice
      elif identityKey.len > 0:
        p(class="settings-subtitle"):
          text "This recovery key unlocks your local Following, Lists, and data import/export across devices."
      else:
        p(class="settings-subtitle"):
          text "Create or import a Finch key to keep personal Following and Lists on a public Finch instance."

    if identityKey.len > 0:
      tdiv(class="settings-grid"):
        article(class="card settings-section settings-section-wide"):
          h2(class="settings-section-title"): text "Recovery key"
          p(class="settings-section-desc"): text "Store it somewhere safe. Anyone with this key can import your Finch data."
          tdiv(class="settings-input-grid"):
            genSecretInput("identity_key_display", "", identityKey)
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
            text " "
            buttonReferer("/api/f/identity/clear", "Forget this key", referer, class="pref-reset")

    tdiv(class="settings-grid"):
      article(class="card settings-section"):
        h2(class="settings-section-title"): text "Create new key"
        p(class="settings-section-desc"): text "Start a fresh local identity on this Finch instance."
        form(`method`="post", action="/api/f/identity/create", class="settings-form compact"):
          refererField(referer)
          button(`type`="submit", class="button outline"):
            text "Create key"

      article(class="card settings-section"):
        h2(class="settings-section-title"): text "Import existing key"
        p(class="settings-section-desc"): text "Switch to a previously exported Finch identity."
        form(`method`="post", action="/api/f/identity/import", class="settings-form compact"):
          refererField(referer)
          genInput("identity_key", "", "", "Paste recovery key", autofocus=false)
          tdiv(class="settings-actions"):
            button(`type`="submit", class="button outline"):
              text "Import key"

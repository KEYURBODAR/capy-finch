(() => {
  const seen = new Set();
  const MAX_PREFETCH = 48;

  const shouldPrefetch = (href) => {
    if (!href) return false;
    if (!href.startsWith("/")) return false;
    if (href.startsWith("//")) return false;
    if (href.startsWith("/api/")) return false;
    if (href.includes("/rss")) return false;
    if (href.includes("/live/")) return false;
    if (href.endsWith("/json") || href.endsWith("/md") || href.endsWith("/txt")) return false;
    if (href.includes("cursor=")) return false;
    return true;
  };

  const prefetch = (href) => {
    if (!shouldPrefetch(href) || seen.has(href) || seen.size >= MAX_PREFETCH) return;
    seen.add(href);
    fetch(href, {
      method: "GET",
      credentials: "same-origin",
      headers: {
        "X-Finch-Prefetch": "1"
      }
    }).catch(() => {
      seen.delete(href);
    });
  };

  let timer = null;
  const queuePrefetch = (href, delay = 50) => {
    window.clearTimeout(timer);
    timer = window.setTimeout(() => prefetch(href), delay);
  };

  const linkFromEvent = (event) => {
    const link = event.target.closest("a[href]");
    if (!link) return null;
    const href = link.getAttribute("href");
    if (!href) return null;
    return href;
  };

  document.addEventListener("mouseover", (event) => {
    const href = linkFromEvent(event);
    if (href) queuePrefetch(href, 80);
  }, { passive: true });

  document.addEventListener("touchstart", (event) => {
    const href = linkFromEvent(event);
    if (href) prefetch(href);
  }, { passive: true });

  document.addEventListener("mousedown", (event) => {
    const href = linkFromEvent(event);
    if (href) prefetch(href);
  }, { passive: true });
})();

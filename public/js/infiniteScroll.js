(function() {
  'use strict';

  function createSkeletonHTML() {
    return '<div class="timeline-item timeline-item-skeleton">' +
      '<figure data-variant="avatar" role="status" class="skeleton box"></figure>' +
      '<div class="skeleton-body">' +
        '<div role="status" class="skeleton line" style="width:38%"></div>' +
        '<div role="status" class="skeleton line"></div>' +
        '<div role="status" class="skeleton line" style="width:60%"></div>' +
      '</div>' +
    '</div>';
  }

  document.addEventListener('click', function(e) {
    var btn = e.target.closest('[data-infinite-target="load-more"]');
    if (!btn) return;
    e.preventDefault();

    var timeline = document.querySelector('.timeline');
    var pagination = document.querySelector('.finch-pagination');
    if (!timeline || !pagination) return;

    var url = btn.getAttribute('href');
    btn.setAttribute('disabled', '');
    btn.textContent = 'Loading…';

    var skeletons = [];
    for (var i = 0; i < 3; i++) {
      var tmp = document.createElement('div');
      tmp.innerHTML = createSkeletonHTML();
      var sk = tmp.firstChild;
      timeline.insertBefore(sk, pagination);
      skeletons.push(sk);
    }

    fetch(url)
      .then(function(res) {
        if (!res.ok) throw new Error('fetch failed');
        return res.text();
      })
      .then(function(html) {
        skeletons.forEach(function(s) { s.remove(); });

        var parser = new DOMParser();
        var doc = parser.parseFromString(html, 'text/html');
        var nodes = doc.querySelectorAll(
          '.timeline > .timeline-item, .timeline > .thread-line'
        );

        if (nodes.length === 0) {
          pagination.innerHTML = '<span class="timeline-end-text">No more posts</span>';
          return;
        }

        nodes.forEach(function(node) {
          timeline.insertBefore(document.adoptNode(node), pagination);
        });

        var nextBtn = doc.querySelector('[data-infinite-target="load-more"]');
        if (nextBtn) {
          btn.setAttribute('href', nextBtn.getAttribute('href'));
          btn.removeAttribute('disabled');
          btn.textContent = 'Load more';
        } else {
          pagination.innerHTML = '<span class="timeline-end-text">No more posts</span>';
        }
      })
      .catch(function() {
        skeletons.forEach(function(s) { s.remove(); });
        btn.removeAttribute('disabled');
        btn.textContent = 'Load more';
        window.location.href = url;
      });
  });
})();

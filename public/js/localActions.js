window.finchToast = function(message, variant) {
  if (window.ot && window.ot.toast) {
    var opts = { placement: 'bottom-right' };
    if (variant) opts.variant = variant;
    window.ot.toast(message, '', opts);
  }
};

(() => {
  const BUTTON_TEXT = {
    "finch-profile-action-form": "Saving...",
    "finch-list-picker-panel": "Saving...",
    "finch-inline-create": "Creating...",
    "finch-local-add": "Adding...",
    "finch-list-delete-form": "Deleting...",
    "finch-member-remove-form": "Removing...",
    "finch-member-bulk-form": "Removing...",
    "affiliate-bulk-panel": "Saving..."
  };

  function normalizeShortDate(value) {
    const raw = (value || "").trim();
    if (!raw) return "";
    const m = raw.match(/^(\d{2})[-/](\d{2})[-/](\d{2})$/);
    if (!m) return raw;
    return `20${m[1]}-${m[2]}-${m[3]}`;
  }

  function formatShortDateInput(value) {
    const digits = (value || "").replace(/\D/g, "").slice(0, 6);
    if (digits.length <= 2) return digits;
    if (digits.length <= 4) return `${digits.slice(0, 2)}-${digits.slice(2)}`;
    return `${digits.slice(0, 2)}-${digits.slice(2, 4)}-${digits.slice(4, 6)}`;
  }

  function isValidShortDate(raw) {
    const m = (raw || "").trim().match(/^(\d{2})-(\d{2})-(\d{2})$/);
    if (!m) return false;
    const year = Number(`20${m[1]}`);
    const month = Number(m[2]);
    const day = Number(m[3]);
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;
    const dt = new Date(Date.UTC(year, month - 1, day));
    return dt.getUTCFullYear() === year &&
      dt.getUTCMonth() === month - 1 &&
      dt.getUTCDate() === day;
  }

  function isTargetForm(form) {
    return Object.keys(BUTTON_TEXT).some((className) => form.classList.contains(className));
  }

  function syncExportSelection(formId) {
    if (!formId) return;
    const hidden = document.getElementById(`${formId}-selected`);
    if (!(hidden instanceof HTMLInputElement)) return;
    const selector = `input[data-export-select][data-export-form="${formId}"]`;
    const ids = Array.from(document.querySelectorAll(selector))
      .filter((box) => box instanceof HTMLInputElement && box.checked)
      .map((box) => box.value)
      .filter(Boolean);
    hidden.value = ids.join(",");
  }

  function getExportLimitInput(formId) {
    return document.querySelector(`input[data-export-limit="${formId}"]`);
  }

  function clearExportLimit(formId) {
    const input = getExportLimitInput(formId);
    if (input instanceof HTMLInputElement) {
      input.value = "";
    }
  }

  function clearExportSelection(formId) {
    if (!formId) return;
    const selector = `input[data-export-select][data-export-form="${formId}"]`;
    for (const box of document.querySelectorAll(selector)) {
      if (box instanceof HTMLInputElement) {
        box.checked = false;
      }
    }
    syncExportSelection(formId);
  }

  function pendingText(form, button) {
    for (const [className, label] of Object.entries(BUTTON_TEXT)) {
      if (form.classList.contains(className)) return label;
    }
    return button.dataset.pendingLabel || "Saving...";
  }

  document.addEventListener("submit", (event) => {
    const form = event.target;
    if (!(form instanceof HTMLFormElement) || !isTargetForm(form)) return;

    const submitter = event.submitter instanceof HTMLElement
      ? event.submitter
      : form.querySelector('button[type="submit"], input[type="submit"]');

    form.setAttribute("aria-busy", "true");
    form.classList.add("is-pending");

    if (submitter instanceof HTMLButtonElement || submitter instanceof HTMLInputElement) {
      if (submitter instanceof HTMLButtonElement) {
        if (!submitter.dataset.originalText) {
          submitter.dataset.originalText = submitter.textContent || "";
        }
        submitter.textContent = pendingText(form, submitter);
      } else if (!submitter.dataset.originalValue) {
        submitter.dataset.originalValue = submitter.value;
        submitter.value = pendingText(form, submitter);
      }
      submitter.disabled = true;
    }
  }, true);

  document.addEventListener("click", (event) => {
    const trigger = event.target instanceof Element
      ? event.target.closest("[data-checkbox-scope][data-checkbox-action]")
      : null;
    if (!trigger) return;

    const scope = trigger.getAttribute("data-checkbox-scope");
    const action = trigger.getAttribute("data-checkbox-action");
    const rootId = trigger.getAttribute("data-checkbox-root");
    const explicitRoot = rootId ? document.getElementById(rootId) : null;
    const container = explicitRoot || trigger.closest(".finch-member-filter-panel, .affiliate-bulk-panel, .finch-local-surface, form, .timeline-item, .timeline-container, details");
    if (!scope || !action || !container) return;

    let selector = 'input[type="checkbox"][name^="member_"]';
    if (scope === "affiliates") {
      selector = 'input[type="checkbox"][name^="affiliate_"]';
    } else if (scope === "member-scope") {
      selector = 'input[type="checkbox"][name^="scope_member_"]';
    } else if (scope === "member-remove") {
      selector = 'input[type="checkbox"][name^="remove_member_"]';
    } else if (scope === "tweet-export") {
      selector = 'input[type="checkbox"][data-export-select]';
    }

    let boxes = Array.from(container.querySelectorAll(selector));
    if (rootId) {
      if (scope === "tweet-export") {
        const exportBoxes = Array.from(document.querySelectorAll(`${selector}[data-export-form="${rootId}"]`));
        boxes = boxes.concat(exportBoxes);
      }
      const externalBoxes = Array.from(document.querySelectorAll(`${selector}[form="${rootId}"]`));
      boxes = boxes.concat(externalBoxes);
    }
    boxes = boxes.filter((box, index, arr) => arr.indexOf(box) === index);
    if (!boxes.length) return;

    event.preventDefault();
    const checked = action === "select-all";
    for (const box of boxes) {
      if (box instanceof HTMLInputElement) {
        box.checked = checked;
        const exportFormId = box.getAttribute("data-export-form");
        if (exportFormId) {
          if (checked) clearExportLimit(exportFormId);
          syncExportSelection(exportFormId);
        }
      }
    }
    if (scope === "tweet-export" && rootId) {
      syncExportSelection(rootId);
    }
  });

  document.addEventListener("change", (event) => {
    const source = event.target;
    if (!(source instanceof HTMLInputElement)) return;

    if (source.matches('[data-short-date]')) {
      source.value = formatShortDateInput(source.value);
      if (source.value && !isValidShortDate(source.value)) {
        source.setCustomValidity("Use a real date in YY-MM-DD format.");
      } else {
        source.setCustomValidity("");
      }
      return;
    }

    if (source.matches('[data-export-select][data-export-form]')) {
      const formId = source.getAttribute("data-export-form");
      if (source.checked) clearExportLimit(formId);
      syncExportSelection(formId);
    }
  });

  document.addEventListener("submit", (event) => {
    const form = event.target;
    if (!(form instanceof HTMLFormElement)) return;
    for (const input of form.querySelectorAll('input[data-short-date]')) {
      if (input instanceof HTMLInputElement) {
        input.value = formatShortDateInput(input.value);
        if (input.value && !isValidShortDate(input.value)) {
          input.setCustomValidity("Use a real date in YY-MM-DD format.");
          input.reportValidity();
          event.preventDefault();
          return;
        }
        input.setCustomValidity("");
        input.value = normalizeShortDate(input.value);
      }
    }
  }, true);

  document.addEventListener("input", (event) => {
    const source = event.target;
    if (!(source instanceof HTMLInputElement)) return;
    if (source.matches('[data-short-date]')) {
      const cursorAtEnd = source.selectionStart === source.value.length;
      source.value = formatShortDateInput(source.value);
      if (cursorAtEnd && source.setSelectionRange) {
        source.setSelectionRange(source.value.length, source.value.length);
      }
      if (source.value && !isValidShortDate(source.value) && source.value.length === 8) {
        source.setCustomValidity("Use a real date in YY-MM-DD format.");
      } else {
        source.setCustomValidity("");
      }
      return;
    }

    if (source.matches('[data-export-limit]')) {
      const formId = source.getAttribute("data-export-limit");
      if (formId && Number(source.value || 0) > 0) {
        clearExportSelection(formId);
      }
    }
  });
})();

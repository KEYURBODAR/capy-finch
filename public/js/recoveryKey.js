(() => {
  const hideAfterMs = 10000;

  const initSecretField = (field) => {
    const input = field.querySelector("[data-secret-input], .settings-secret-input");
    const toggle = field.querySelector("[data-secret-toggle]");
    const note = field.querySelector("[data-secret-note]");
    if (!input || !toggle || !note) return;

    let timer = null;

    const hide = () => {
      if (timer) {
        window.clearTimeout(timer);
        timer = null;
      }
      input.type = "password";
      toggle.textContent = "Show";
      toggle.setAttribute("aria-pressed", "false");
      note.textContent = "Hidden by default. Click Show to reveal for 10 seconds.";
    };

    const show = () => {
      if (timer) {
        window.clearTimeout(timer);
      }
      input.type = "text";
      toggle.textContent = "Hide";
      toggle.setAttribute("aria-pressed", "true");
      note.textContent = "Visible for 10 seconds.";
      timer = window.setTimeout(hide, hideAfterMs);
    };

    toggle.addEventListener("click", () => {
      if (input.type === "password") show();
      else hide();
    });

    field.addEventListener("focusout", (event) => {
      if (!field.contains(event.relatedTarget)) {
        hide();
      }
    });

    hide();
  };

  const init = () => {
    document.querySelectorAll("[data-secret-field]").forEach(initSecretField);
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();

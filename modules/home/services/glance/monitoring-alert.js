// Colours the Monitoring tab while that page shows an alert: a hot CPU, a
// nearly full disk, an unreachable host or a failing gatus probe. The
// widgets mark each alert with the `dafos-alert` class (temperatures.nix,
// gatus.nix). On the Monitoring page itself the live DOM is read; anywhere
// else the page's content is fetched, which honours each widget's cache.
// Loaded from branding.custom-footer, like rer-ticker.js. No template
// literals: Dynacat expands every dollar-brace NAME in its config.
(() => {
  const slug = "monitoring";
  const every = 2 * 60 * 1000;

  function tabs() {
    return document.querySelectorAll('a.nav-item[href$="/' + slug + '"]');
  }

  function mark(alerting) {
    tabs().forEach((a) => {
      a.classList.toggle("nav-item-alert", alerting);
      a.title = alerting ? "Alerte en cours sur le monitoring" : "";
    });
  }

  async function check() {
    if (document.hidden || tabs().length === 0) return;
    const here = document.querySelector('a.nav-item-current[href$="/' + slug + '"]');
    if (here) {
      mark(document.querySelector(".dafos-alert") !== null);
      return;
    }
    try {
      const response = await fetch("/api/pages/" + slug + "/content/");
      if (!response.ok) return;
      const page = new DOMParser().parseFromString(await response.text(), "text/html");
      mark(page.querySelector(".dafos-alert") !== null);
    } catch (e) {
      // Keep the last known state; the next round retries.
    }
  }

  setInterval(check, every);
  document.addEventListener("visibilitychange", check);
  // The Monitoring page's widgets refresh in place; recheck when one does.
  new MutationObserver(() => {
    if (document.querySelector('a.nav-item-current[href$="/' + slug + '"]')) {
      mark(document.querySelector(".dafos-alert") !== null);
    }
  }).observe(document.body, { childList: true, subtree: true });
  check();
})();

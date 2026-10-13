// Keeps the chosen tab of every group widget (sports, weather) across live
// updates and page loads. Dynacat 3.0.1 morphs a refreshed widget from the
// server HTML, where tab 0 is current, and its own tab-state save only looks
// at groups *inside* the refreshed widget, never the widget itself, so a
// top-level group snaps back to its first tab on every update.
// The tab is set straight on the DOM, the way Dynacat's setCurrentTab does:
// a synthetic click could hit its "already current" branch, whose closure
// still holds the pre-morph tab.
// Loaded from branding.custom-footer, like rer-ticker.js. No template
// literals: Dynacat expands every dollar-brace NAME in its config.
(() => {
  const key = "dafos-group-tabs";
  let saved = {};
  try {
    saved = JSON.parse(localStorage.getItem(key) || "{}");
  } catch (e) {
    saved = {};
  }

  function store() {
    try {
      localStorage.setItem(key, JSON.stringify(saved));
    } catch (e) {
      // Private window or blocked storage: the in-memory copy still works.
    }
  }

  function parts(group) {
    const header = group.querySelector(".widget-group-header .widget-header");
    const contents = group.querySelector(".widget-group-contents");
    if (!header || !contents) return null;
    return { titles: header.children, tabs: contents.children };
  }

  function restore(group) {
    const id = group.dataset.widgetId;
    const want = saved[id];
    const p = parts(group);
    if (want === undefined || !p || want >= p.titles.length) return;
    if (p.titles[want].classList.contains("widget-group-title-current")) return;

    group.dataset.currentTab = String(want);
    for (let i = 0; i < p.titles.length; i++) {
      const on = i === want;
      p.titles[i].classList.toggle("widget-group-title-current", on);
      p.titles[i].setAttribute("aria-selected", String(on));
      p.tabs[i].classList.toggle("widget-group-content-current", on);
      p.tabs[i].setAttribute("aria-hidden", String(!on));
    }
  }

  function restoreAll(root) {
    if (root.matches && root.matches(".widget-type-group")) restore(root);
    if (root.querySelectorAll) root.querySelectorAll(".widget-type-group").forEach(restore);
  }

  // Remember the tab the user picks.
  document.addEventListener(
    "click",
    (event) => {
      const title = event.target.closest(".widget-group-title");
      const group = title && title.closest(".widget-type-group");
      if (!group || !group.dataset.widgetId) return;
      saved[group.dataset.widgetId] = [...title.parentElement.children].indexOf(title);
      store();
    },
    true,
  );

  // Live updates (SSE, per-widget polling) announce themselves.
  document.addEventListener("dynacat:widget-updated", (event) => {
    restoreAll(event.target);
    const group = event.target.closest && event.target.closest(".widget-type-group");
    if (group) restore(group);
  });

  // Page content arrives after this script runs.
  new MutationObserver((mutations) => {
    mutations.forEach((m) => m.addedNodes.forEach((n) => n.nodeType === 1 && restoreAll(n)));
  }).observe(document.body, { childList: true, subtree: true });
  restoreAll(document);
})();

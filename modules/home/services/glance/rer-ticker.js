// Live countdown for the RER widget (rer.nix). The widget refetches PRIM only
// every `refreshEvery`, to stay under the 1000 requests/day quota; this
// recomputes each row from its departure timestamp every 15 s instead:
// minutes left, stripe state, "pars dans" hint, and hides departed trains.
// Loaded from branding.custom-footer: widget HTML is inserted with innerHTML,
// so a <script> inside a widget template would never run.
// No template literals: Dynacat expands every dollar-brace NAME in its config
// as an environment variable, and this file is inlined into that config.
(() => {
  const states = ["rer-ok", "rer-hurry", "rer-missed"];

  function tick() {
    const now = Date.now() / 1000;

    document.querySelectorAll(".rer-list").forEach((list) => {
      const walkMin = Number(list.dataset.walkMin);
      const walkMax = Number(list.dataset.walkMax);
      const margin = Number(list.dataset.margin);
      const limit = Number(list.dataset.limit);
      let shown = 0;

      list.querySelectorAll("li[data-rer-departure]").forEach((row) => {
        const minutes = Math.floor((Number(row.dataset.rerDeparture) - now) / 60);
        if (minutes < 0 || shown >= limit) {
          row.hidden = true;
          return;
        }
        row.hidden = false;
        row.classList.remove("rer-extra");
        shown++;

        if (row.dataset.rerCancelled === "true") return;

        const leave = minutes - walkMax;
        const state = minutes < walkMin ? "missed" : leave < margin ? "hurry" : "ok";
        row.classList.remove(...states);
        row.classList.add("rer-" + state);

        const min = row.querySelector(".rer-min");
        if (min) min.textContent = minutes === 0 ? "à quai" : minutes + " min";
        const status = row.querySelector(".rer-status");
        if (status) {
          status.textContent =
            state === "missed" ? "trop tard" : state === "hurry" ? "pars maintenant" : "pars dans " + leave + " min";
        }
      });

      const empty = list.parentElement.querySelector(".rer-empty");
      if (empty) empty.hidden = shown > 0;
    });

    document.querySelectorAll(".rer-age[data-fetched]").forEach((el) => {
      const minutes = Math.floor((now - Number(el.dataset.fetched)) / 60);
      el.textContent = minutes < 1 ? "maj à l'instant" : "maj il y a " + minutes + " min";
    });
  }

  window.dafosRerTick = tick;
  setInterval(tick, 15000);
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) tick();
  });

  // Page content and widget refreshes arrive after this script runs. Only
  // react to inserted elements that hold the widget: tick() itself rewrites
  // text nodes, and reacting to those would loop.
  new MutationObserver((mutations) => {
    const added = mutations.some((m) =>
      [...m.addedNodes].some(
        (n) => n.nodeType === 1 && (n.matches(".rer-list, .rer-age") || n.querySelector(".rer-list")),
      ),
    );
    if (added) tick();
  }).observe(document.body, { childList: true, subtree: true });
})();

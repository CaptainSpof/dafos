// Colours the Monitoring and Sécurité tabs while their page shows an alert:
// a hot CPU, a nearly full disk, an unreachable host, a failing gatus probe,
// a defence that is down. The widgets mark each alert with the `dafos-alert`
// class (temperatures.nix, gatus.nix, security.nix). On the page itself the
// live DOM is read; anywhere else the page's content is fetched, which
// honours each widget's cache. Loaded from branding.custom-footer, like
// rer-ticker.js. No template literals: Dynacat expands every dollar-brace
// NAME in its config.
(() => {
	const slugs = ["monitoring", "securite"];
	const every = 2 * 60 * 1000;

	function tabs(slug) {
		return document.querySelectorAll('a.nav-item[href$="/' + slug + '"]');
	}

	function current(slug) {
		return (
			document.querySelector('a.nav-item-current[href$="/' + slug + '"]') !==
			null
		);
	}

	function mark(slug, alerting) {
		tabs(slug).forEach((a) => {
			a.classList.toggle("nav-item-alert", alerting);
			a.title = alerting ? "Alerte en cours" : "";
		});
	}

	async function check(slug) {
		if (document.hidden || tabs(slug).length === 0) return;
		if (current(slug)) {
			mark(slug, document.querySelector(".dafos-alert") !== null);
			return;
		}
		try {
			const response = await fetch("/api/pages/" + slug + "/content/");
			if (!response.ok) return;
			const page = new DOMParser().parseFromString(
				await response.text(),
				"text/html",
			);
			mark(slug, page.querySelector(".dafos-alert") !== null);
		} catch (e) {
			// Keep the last known state; the next round retries.
		}
	}

	function checkAll() {
		slugs.forEach(check);
	}

	setInterval(checkAll, every);
	document.addEventListener("visibilitychange", checkAll);
	// The current page's widgets refresh in place; recheck when one does.
	new MutationObserver(() => {
		slugs.forEach((slug) => {
			if (current(slug))
				mark(slug, document.querySelector(".dafos-alert") !== null);
		});
	}).observe(document.body, { childList: true, subtree: true });
	checkAll();
})();

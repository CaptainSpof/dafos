pragma ComponentBehavior: Bound

// DMS launcher plugin: one "Games" folder instead of every game sitting flat in
// the app drawer.
//
// The game list is NOT computed here — it is read from games.json, written by
// the dms-games-sync service (see ../../games.nix). That service also hides the
// same desktop entries from the launcher's flat app list (session.json
// `hiddenApps`), so the classification rule lives in exactly one place and the
// two halves can never disagree.
//
// Launching goes through SessionService.launchDesktopEntry so per-app overrides
// (env vars, extra flags, dGPU) and frecency keep working exactly as they do for
// a normal app entry.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

QtObject {
    id: root

    property var pluginService: null

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/dms-games"
    readonly property string gamesPath: stateDir + "/games.json"

    // [{ id, name, icon, comment, exec }], already sorted by name.
    property var games: []

    signal itemsChanged

    property var gamesFile: FileView {
        path: root.gamesPath
        preload: true
        blockLoading: true
        watchChanges: true
        onLoaded: root._parse(text())
        onLoadFailed: {
            root.games = [];
            root.itemsChanged();
        }
    }

    function _parse(raw) {
        var list = [];
        try {
            var parsed = JSON.parse(raw || "{}");
            if (Array.isArray(parsed.games))
                list = parsed.games;
        } catch (e) {
            list = [];
        }

        // Prefer the live desktop entry for name/icon so a renamed or re-iconed
        // game is right immediately, without waiting for the next sync run.
        var resolved = [];
        for (var i = 0; i < list.length; i++) {
            var g = list[i];
            if (!g || !g.id)
                continue;
            var entry = DesktopEntries.byId(g.id);
            resolved.push({
                "id": g.id,
                "name": (entry && entry.name) || g.name || g.id,
                "icon": (entry && entry.icon) || g.icon || "input-gaming",
                "comment": g.comment || (entry && entry.comment) || "",
                "exec": g.exec || ""
            });
        }
        resolved.sort(function (a, b) {
            return a.name.localeCompare(b.name);
        });
        root.games = resolved;
        root.itemsChanged();
    }

    // Rough match score: prefix > word start > substring > acronym.
    function _score(text, query) {
        if (!text)
            return 0;
        var lower = text.toLowerCase();
        var idx = lower.indexOf(query);
        if (idx === 0)
            return 1000;
        if (idx > 0)
            return " :-_/".indexOf(lower.charAt(idx - 1)) !== -1 ? 800 : 600;

        var acronym = "";
        var words = lower.split(/[^a-z0-9]+/);
        for (var i = 0; i < words.length; i++) {
            if (words[i].length > 0)
                acronym += words[i].charAt(0);
        }
        return acronym.indexOf(query) === 0 ? 400 : 0;
    }

    function _item(game, score) {
        return {
            "id": "game:" + game.id,
            "entryId": game.id,
            "name": game.name,
            "comment": game.comment,
            "icon": game.icon,
            "iconType": "image",
            "keywords": [game.id],
            "_preScored": score
        };
    }

    function getItems(query) {
        // First call of the session can land before the FileView signals
        // onLoaded; blockLoading makes this read synchronous.
        if (games.length === 0)
            _parse(gamesFile.text());

        var q = (query || "").trim().toLowerCase();
        var items = [];

        if (q.length === 0) {
            // No query: keep the alphabetical order. Scores must stay above 900
            // or DMS's scorer re-ranks them itself (see Scorer.js).
            for (var i = 0; i < games.length; i++)
                items.push(_item(games[i], 1000 + games.length - i));
            return items;
        }

        var matched = [];
        for (var j = 0; j < games.length; j++) {
            var score = _score(games[j].name, q);
            if (score > 0)
                matched.push({
                    "game": games[j],
                    "score": score
                });
        }
        matched.sort(function (a, b) {
            return b.score - a.score || a.game.name.localeCompare(b.game.name);
        });
        for (var k = 0; k < matched.length; k++)
            items.push(_item(matched[k].game, matched[k].score));
        return items;
    }

    function executeItem(item) {
        if (!item || !item.entryId)
            return;
        var entry = DesktopEntries.byId(item.entryId) || DesktopEntries.heuristicLookup(item.entryId);
        if (!entry)
            return;
        SessionService.launchDesktopEntry(entry);
        AppUsageHistoryData.addAppUsage(entry);
    }
}

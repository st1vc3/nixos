pragma Singleton

// The launcher's command vocabulary, in one place because two surfaces render
// it: AppLauncher lists the commands among its search results, and Cheatsheet
// shows them as a reference. Keeping the table here means a new command shows
// up in both without either having to be told about it.

import Quickshell

Singleton {
    id: root

    // Icons come from the Nerd Font the rest of the shell uses. Mixed Unicode
    // symbols are drawn on wildly different em boxes, so their ink lands up to
    // 7px apart vertically no matter how the row is aligned. Write them as
    // \uXXXX escapes: literal private-use characters do not survive every
    // editor round-trip, and an empty icon collapses its row rather than
    // showing a placeholder.
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    // Search engines are pure query-in/URL-out, so one descriptor per engine
    // drives a whole launcher mode.
    readonly property var engines: ({
        youtube: {
            keyword: "yt", icon: "\uF16A", name: "YouTube",
            base: "https://www.youtube.com/results?search_query="
        },
        google: {
            keyword: "ggl", icon: "\uF1A0", name: "Google",
            base: "https://www.google.com/search?q="
        }
    })

    function icon(target) {
        if (target === "clipboard") return "\uF0EA";
        if (target === "ssh") return "\uF120";
        if (target === "nsearch") return "\uF313";
        if (engines[target]) return engines[target].icon;
        return "\uF002";
    }

    function label(target) {
        if (target === "clipboard") return "Clipboard";
        if (target === "ssh") return "SSH";
        if (target === "nsearch") return "Nix";
        if (engines[target]) return engines[target].name;
        return "Quickshell";
    }

    // Ordered: the order here is the order both surfaces show, and the
    // tiebreak when several commands match the same query.
    readonly property var list: {
        const items = [
            { target: "clipboard", keyword: "cli",
              title: "Clipboard history", hint: "Recent copies, text and images" },
            { target: "ssh", keyword: "ssh",
              title: "SSH to a host", hint: "Connect in a terminal session" },
            { target: "nsearch", keyword: "nsearch",
              title: "Search Nix packages", hint: "Query nixpkgs and copy the attribute" }
        ];
        for (const name in engines) {
            items.push({
                target: name, keyword: engines[name].keyword,
                title: "Search " + engines[name].name,
                hint: "Open results in the default browser"
            });
        }
        return items.map((item, i) => ({
            isCommand: true, target: item.target, keyword: item.keyword,
            label: item.title, hint: item.hint, glyph: icon(item.target),
            order: i
        }));
    }
}

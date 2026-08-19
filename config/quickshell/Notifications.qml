pragma Singleton

// Owns the freedesktop notification server (org.freedesktop.Notifications).
// Quickshell is the sole daemon configured to claim this DBus name.
//
// `list` is the full tracked history (shown in the notification centre);
// `activeToasts` is the transient subset currently shown as on-screen popups.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property alias list: server.trackedNotifications

    // Do not disturb: incoming notifications still land in the history, but no
    // toast is shown while it is on. Backed by the state file below so the mode
    // survives a config reload or a restart of the shell.
    property alias dnd: settings.dnd

    // A native model avoids rebuilding a Repeater from a JavaScript array every
    // time a toast arrives, which can crash Qt during a rapid notification burst.
    readonly property alias activeToasts: activeToastModel
    property var queuedToasts: []

    // Default on-screen dwell for a toast when the app gives no expireTimeout.
    readonly property int defaultToastMs: 5000
    readonly property int maxVisibleToasts: 5
    readonly property int maxHistory: 100
    property int nextToastKey: 1

    ListModel {
        id: activeToastModel
        dynamicRoles: true
    }

    function activeContainsKey(key) {
        for (let i = 0; i < activeToastModel.count; i++) {
            if (activeToastModel.get(i).toastKey === key)
                return true;
        }
        return false;
    }

    function addToast(n) {
        if (!n)
            return;

        const entry = { toastKey: nextToastKey++, notification: n };
        if (activeToastModel.count < maxVisibleToasts)
            activeToastModel.append(entry);
        else
            queuedToasts = queuedToasts.concat([entry]);
    }

    function removeToastByKey(key) {
        for (let i = activeToastModel.count - 1; i >= 0; i--) {
            if (activeToastModel.get(i).toastKey === key)
                activeToastModel.remove(i);
        }
        queuedToasts = queuedToasts.filter(entry => entry.toastKey !== key);

        while (activeToastModel.count < maxVisibleToasts && queuedToasts.length > 0) {
            const next = queuedToasts[0];
            queuedToasts = queuedToasts.slice(1);
            if (next && !activeContainsKey(next.toastKey))
                activeToastModel.append(next);
        }
    }

    function removeToast(n) {
        for (let i = activeToastModel.count - 1; i >= 0; i--) {
            if (activeToastModel.get(i).notification === n)
                removeToastByKey(activeToastModel.get(i).toastKey);
        }
        const queued = queuedToasts.filter(entry => entry.notification === n);
        for (const entry of queued)
            removeToastByKey(entry.toastKey);
    }

    function toastTimeout(n) {
        if (!n || n.expireTimeout === undefined || n.expireTimeout < 0)
            return defaultToastMs;
        return n.expireTimeout;
    }

    function pruneHistory() {
        // Copy first because dismiss() mutates trackedNotifications.
        const values = [];
        for (let i = 0; i < server.trackedNotifications.values.length; i++)
            values.push(server.trackedNotifications.values[i]);
        const overflow = Math.max(0, values.length - maxHistory);
        for (let i = 0; i < overflow; i++) {
            const oldest = values[i];
            if (!oldest || !oldest.dismiss)
                continue;
            removeToast(oldest);
            oldest.dismiss();
        }
    }

    function dismiss(n, toastKey) {
        if (toastKey !== undefined && toastKey >= 0)
            removeToastByKey(toastKey);
        else
            removeToast(n);
        if (n && n.dismiss)
            n.dismiss();
    }

    function toggleDnd() {
        dnd = !dnd;
        // Toasts already on screen would otherwise sit there until their own
        // timers expire; the history keeps every one of them.
        if (dnd) {
            activeToastModel.clear();
            queuedToasts = [];
        }
    }

    function clearAll() {
        activeToastModel.clear();
        queuedToasts = [];
        // Copy first: dismiss() mutates trackedNotifications as we go.
        const all = [];
        for (let i = 0; i < server.trackedNotifications.values.length; i++)
            all.push(server.trackedNotifications.values[i]);
        for (const n of all)
            if (n && n.dismiss)
                n.dismiss();
    }

    NotificationServer {
        id: server

        // Advertise what our QML UI can actually render, so apps send rich
        // notifications instead of degrading.
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true

        onNotification: function (n) {
            // tracked=true keeps it in trackedNotifications (history) until we
            // explicitly dismiss it; without this it would vanish immediately.
            n.tracked = true;
            if (!root.dnd)
                root.addToast(n);
            // trackedNotifications is updated after this callback returns.
            Qt.callLater(root.pruneHistory);
        }
    }

    // Runtime state, kept out of ~/.config because home-manager owns that tree.
    // The directory is created by home/quickshell.nix; FileView writes the file
    // itself on the first toggle (or right away when it is missing).
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/notifications.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: settings
            property bool dnd: false
        }
    }
}

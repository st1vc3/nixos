pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool sinkMuted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    readonly property string volumeIcon: volume < 0.01 ? "" : volume < 0.5 ? "" : ""
    property int osdSerial: 0

    property bool vpnActive: false
    property string vpnName: ""
    property var vpnProfiles: []
    property var interfaceAddresses: ({})
    property var wifiNetworks: []
    property string pendingWifiSsid: ""
    property string wifiError: ""
    property string connectingWifiSsid: ""
    property string pendingWifiPassword: ""
    property string weatherLocation: weatherSettings.location
    property string weatherTemp: ""
    property string weatherDescription: ""
    property string weatherIcon: ""
    property bool weatherLoading: false
    property string weatherError: ""

    PwObjectTracker { objects: [root.sink, root.source] }

    function showOsd() { osdSerial++ }
    function changeVolume(delta) {
        if (!sink || !sink.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta));
        showOsd();
    }
    function toggleSinkMute() {
        if (!sink || !sink.audio) return;
        sink.audio.muted = !sink.audio.muted;
        showOsd();
    }
    function toggleMicMute() {
        if (source && source.audio) source.audio.muted = !source.audio.muted;
    }
    function setWeatherLocation(value) {
        const clean = value.trim();
        if (!clean) return;
        weatherSettings.location = clean;
        weatherLocation = clean;
        refreshWeather();
    }
    function refreshWeather() {
        if (!weatherLocation) return;
        weatherLoading = true;
        weatherError = "";
        weatherProc.command = ["curl", "--fail", "--silent", "--show-error", "--max-time", "10",
            "https://wttr.in/" + encodeURIComponent(weatherLocation) + "?format=j1"];
        weatherProc.running = true;
    }
    function parseWeather(text) {
        weatherLoading = false;
        try {
            const data = JSON.parse(text);
            const current = data.current_condition[0];
            weatherTemp = current.temp_C + "°";
            weatherDescription = current.weatherDesc[0].value;
            const code = parseInt(current.weatherCode);
            weatherIcon = code === 113 ? "" : code === 116 ? "" : code >= 200 && code < 400 ? "" : code >= 300 && code < 600 ? "" : code >= 600 && code < 700 ? "" : "";
        } catch (e) { weatherError = "Weather unavailable"; }
    }
    function refreshVpn() { vpnProc.running = true }
    function refreshAddresses() { addressProc.running = true }
    function refreshWifi() { wifiScanProc.running = true }
    function splitNmcli(line) {
        const fields = [];
        let field = "";
        let escaped = false;
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (escaped) { field += c; escaped = false; }
            else if (c === "\\") escaped = true;
            else if (c === ":") { fields.push(field); field = ""; }
            else field += c;
        }
        fields.push(field);
        return fields;
    }
    function parseWifi(text) {
        const byName = ({});
        for (const line of text.trim().split("\n")) {
            if (!line) continue;
            const p = splitNmcli(line);
            if (p.length < 4 || !p[1]) continue;
            const item = { connected: p[0] === "*", ssid: p[1], signal: parseInt(p[2]) || 0, security: p[3] };
            if (!byName[item.ssid] || item.signal > byName[item.ssid].signal)
                byName[item.ssid] = item;
        }
        wifiNetworks = Object.keys(byName).map(k => byName[k]).sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return b.signal - a.signal;
        });
    }
    function connectWifi(ssid, password) {
        connectingWifiSsid = ssid;
        pendingWifiSsid = "";
        wifiError = "";
        pendingWifiPassword = password;
        wifiConnectProc.command = password
            ? ["nmcli", "--ask", "device", "wifi", "connect", ssid]
            : ["nmcli", "device", "wifi", "connect", ssid];
        wifiConnectProc.running = true;
    }
    function disconnectWifi(device) {
        wifiDisconnectProc.command = ["nmcli", "device", "disconnect", device];
        wifiDisconnectProc.running = true;
    }
    function parseAddresses(text) {
        const addresses = ({});
        try {
            const links = JSON.parse(text);
            for (const link of links) {
                for (const info of link.addr_info || []) {
                    if (info.family === "inet" && info.scope === "global") {
                        addresses[link.ifname] = info.local + "/" + info.prefixlen;
                        break;
                    }
                }
            }
        } catch (e) {}
        interfaceAddresses = addresses;
    }
    function addressFor(device) {
        return device && interfaceAddresses[device.name] ? interfaceAddresses[device.name] : "";
    }
    function parseVpn(text) {
        const profiles = [];
        let active = "";
        for (const line of text.trim().split("\n")) {
            const p = splitNmcli(line);
            if (p.length < 3 || (p[1] !== "vpn" && p[1] !== "wireguard")) continue;
            profiles.push(p[0]);
            if (p[2] === "yes") active = p[0];
        }
        vpnProfiles = profiles;
        vpnName = active;
        vpnActive = active.length > 0;
    }
    function toggleVpn(name) {
        vpnToggle.command = vpnActive ? ["nmcli", "connection", "down", vpnName]
                                      : ["nmcli", "connection", "up", name || vpnProfiles[0]];
        vpnToggle.running = true;
    }

    Process {
        id: weatherProc
        stdout: StdioCollector { onStreamFinished: root.parseWeather(this.text) }
        onExited: code => {
            root.weatherLoading = false;
            if (code !== 0) root.weatherError = "Weather unavailable";
        }
    }
    Process {
        id: vpnProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector { onStreamFinished: root.parseVpn(this.text) }
    }
    Process { id: vpnToggle; onExited: root.refreshVpn() }
    Process {
        id: addressProc
        command: ["ip", "-j", "-4", "address", "show", "scope", "global"]
        stdout: StdioCollector { onStreamFinished: root.parseAddresses(this.text) }
    }
    Process {
        id: wifiScanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector { onStreamFinished: root.parseWifi(this.text) }
    }
    Process {
        id: wifiConnectProc
        stdinEnabled: true
        onStarted: {
            if (root.pendingWifiPassword.length > 0) {
                write(root.pendingWifiPassword + "\n");
                root.pendingWifiPassword = "";
            }
        }
        onExited: code => {
            root.pendingWifiPassword = "";
            if (code !== 0) {
                root.pendingWifiSsid = root.connectingWifiSsid;
                root.wifiError = "Password required or connection failed";
            }
            root.connectingWifiSsid = "";
            root.refreshWifi();
        }
    }
    Process { id: wifiDisconnectProc; onExited: root.refreshWifi() }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.refreshVpn();
            root.refreshAddresses();
            root.refreshWifi();
        }
    }
    Timer { interval: 900000; running: root.weatherLocation.length > 0; repeat: true; triggeredOnStart: true; onTriggered: root.refreshWeather() }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/status.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter { id: weatherSettings; property string location: "" }
    }
}

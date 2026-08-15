pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland

PanelWindow {
    id: root
    anchors.top: true
    anchors.right: true
    margins.right: BarMetrics.edgeMargin
    exclusiveZone: -1
    color: "transparent"
    implicitWidth: 380
    implicitHeight: BarMetrics.stripHeight + panel.openHeight
    visible: true

    WlrLayershell.namespace: "quickshell-status-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region { item: ShellState.statusCenterOpen ? panel : closedInputRegion }

    Item {
        id: closedInputRegion
        width: 0
        height: 0
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    property bool editingWeather: false
    readonly property var wifiDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wifi) return devices[i];
        return null;
    }
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values : []
    readonly property var wiredDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wired) return devices[i];
        return null;
    }

    function close() { ShellState.statusCenterOpen = false }
    function connectedWifi() {
        for (const n of wifiNetworks) if (n.connected) return n.name;
        return Networking.wifiEnabled ? "Not connected" : "Wi-Fi off";
    }

    IpcHandler { target: "status"; function toggle(): void { ShellState.toggleStatusCenter() } }

    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: BarMetrics.stripHeight
        // Keep the panel horizontally settled beneath the button. Animating
        // this width while right-anchored makes it look like a side drawer.
        width: parent.width
        readonly property real openHeight: 690
        readonly property real closedHeight: BarMetrics.pillHeight

        height: ShellState.statusCenterOpen ? openHeight : closedHeight
        radius: ShellState.statusCenterOpen ? 20 : 13
        clip: true
        color: ShellState.statusCenterOpen ? Colors.glass(0.6) : "transparent"

        Behavior on height {
            // No back-ease here either, for the same reason as the
            // notification centre: it grows far enough that an overshoot reads
            // as a bounce rather than a spring.
            NumberAnimation { duration: 340; easing.type: Easing.OutQuint }
        }
        Behavior on color { ColorAnimation { duration: 200 } }

        Flickable {
            anchors.fill: parent; anchors.margins: 16
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            opacity: ShellState.statusCenterOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 200 } }

            ColumnLayout {
                id: content
                width: parent.width
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Control Center"; color: Colors.text; font.pixelSize: 20; font.bold: true; Layout.fillWidth: true }
                    Rectangle {
                        width: 30; height: 30; radius: 15; color: closeHover.hovered ? Colors.glass(1) : Colors.glass(0.7)
                        Text { anchors.centerIn: parent; text: ""; font.family: "JetBrainsMono Nerd Font"; color: Colors.subtext }
                        HoverHandler { id: closeHover }
                        TapHandler { onTapped: root.close() }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: locationInput.visible ? 108 : 72
                    radius: 18
                    color: Colors.glass(0.72)
                    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: SystemStatus.weatherIcon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 28; color: Colors.accent }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text {
                                    id: weatherAddress
                                    text: SystemStatus.weatherLocation || "Set weather location"
                                    color: addressHover.hovered ? Colors.accent : Colors.text
                                    font.pixelSize: 14
                                    font.bold: true
                                    HoverHandler { id: addressHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: {
                                            root.editingWeather = true;
                                            locationInput.text = SystemStatus.weatherLocation;
                                            Qt.callLater(() => {
                                                locationInput.forceActiveFocus();
                                                locationInput.selectAll();
                                            });
                                        }
                                    }
                                }
                                Text { text: SystemStatus.weatherError || SystemStatus.weatherDescription || "Enter an address below"; color: Colors.subtext; font.pixelSize: 12 }
                            }
                            Text { text: SystemStatus.weatherLoading ? "…" : SystemStatus.weatherTemp; color: Colors.text; font.pixelSize: 28; font.bold: true }
                        }
                        TextField {
                            id: locationInput
                            visible: SystemStatus.weatherLocation.length === 0 || root.editingWeather
                            Layout.fillWidth: true; implicitHeight: 32
                            placeholderText: "City or address"
                            color: Colors.text
                            background: Rectangle { radius: 10; color: Colors.glass(0.8); border.width: 1; border.color: locationInput.activeFocus ? Colors.accent : Colors.outline }
                            onAccepted: {
                                SystemStatus.setWeatherLocation(text);
                                text = "";
                                root.editingWeather = false;
                                focus = false;
                            }
                        }
                    }
                }

                GridLayout {
                    columns: 2; columnSpacing: 10; rowSpacing: 10; Layout.fillWidth: true
                    Repeater {
                        model: [
                            { icon: "", title: "Wi-Fi", detail: root.connectedWifi(), active: Networking.wifiEnabled, action: "wifi" },
                            { icon: "", title: "Bluetooth", detail: root.adapter && root.adapter.enabled ? "On" : "Off", active: root.adapter && root.adapter.enabled, action: "bluetooth" },
                            { icon: "", title: "VPN", detail: SystemStatus.vpnActive ? SystemStatus.vpnName : (SystemStatus.vpnProfiles.length ? "Off" : "No profile"), active: SystemStatus.vpnActive, action: "vpn" },
                            { icon: "", title: "Microphone", detail: SystemStatus.micMuted ? "Muted" : "Live", active: !SystemStatus.micMuted, action: "mic" }
                        ]
                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            Layout.fillWidth: true; implicitHeight: 72; radius: 17
                            color: modelData.active ? Colors.accent : (tileHover.hovered ? Colors.glass(0.95) : Colors.glass(0.72))
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 10
                                Text { text: tile.modelData.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 19; color: tile.modelData.active ? Colors.accentText : Colors.subtext }
                                ColumnLayout {
                                    spacing: 1; Layout.fillWidth: true
                                    Text { text: tile.modelData.title; color: tile.modelData.active ? Colors.accentText : Colors.text; font.bold: true; font.pixelSize: 13 }
                                    Text { text: tile.modelData.detail; color: tile.modelData.active ? Colors.accentText : Colors.subtext; opacity: 0.8; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                            }
                            HoverHandler { id: tileHover }
                            TapHandler { onTapped: {
                                if (tile.modelData.action === "wifi") Networking.wifiEnabled = !Networking.wifiEnabled;
                                else if (tile.modelData.action === "bluetooth" && root.adapter) root.adapter.enabled = !root.adapter.enabled;
                                else if (tile.modelData.action === "vpn" && SystemStatus.vpnProfiles.length) SystemStatus.toggleVpn();
                                else if (tile.modelData.action === "mic") SystemStatus.toggleMicMute();
                            }}
                        }
                    }
                }

                Text { text: "Networks"; color: Colors.text; font.pixelSize: 14; font.bold: true }
                Rectangle {
                    visible: root.wiredDevice && root.wiredDevice.connected
                    Layout.fillWidth: true; implicitHeight: 42; radius: 12
                    color: Colors.glass(0.6)
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 11
                        Text { text: ""; font.family: "JetBrainsMono Nerd Font"; color: Colors.accent }
                        Text { text: "Ethernet"; color: Colors.text; Layout.fillWidth: true }
                        ColumnLayout {
                            spacing: 0
                            Text { text: root.wiredDevice ? root.wiredDevice.name : ""; color: Colors.subtext; font.pixelSize: 11; Layout.alignment: Qt.AlignRight }
                            Text { text: SystemStatus.addressFor(root.wiredDevice); color: Colors.subtext; font.pixelSize: 10; Layout.alignment: Qt.AlignRight }
                        }
                    }
                }
                Repeater {
                    model: SystemStatus.wifiNetworks
                    delegate: Rectangle {
                        id: networkRow
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 42; radius: 12
                        color: netHover.hovered ? Colors.glass(0.95) : Colors.glass(0.6)
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 11
                            Text { text: ""; font.family: "JetBrainsMono Nerd Font"; color: networkRow.modelData.connected ? Colors.accent : Colors.subtext }
                            Text { text: networkRow.modelData.ssid; color: Colors.text; Layout.fillWidth: true; elide: Text.ElideRight }
                            ColumnLayout {
                                spacing: 0
                                Text { text: SystemStatus.connectingWifiSsid === networkRow.modelData.ssid ? "Connecting…" : networkRow.modelData.connected ? "Connected" : networkRow.modelData.signal + "%"; color: Colors.subtext; font.pixelSize: 11; Layout.alignment: Qt.AlignRight }
                                Text { text: networkRow.modelData.security || "Open"; color: Colors.subtext; font.pixelSize: 10; Layout.alignment: Qt.AlignRight }
                            }
                        }
                        HoverHandler { id: netHover }
                        TapHandler {
                            onTapped: networkRow.modelData.connected
                                ? SystemStatus.disconnectWifi(root.wifiDevice ? root.wifiDevice.name : "")
                                : SystemStatus.connectWifi(networkRow.modelData.ssid, "")
                        }
                    }
                }
                TextField {
                    id: wifiPassword
                    visible: SystemStatus.pendingWifiSsid.length > 0
                    Layout.fillWidth: true
                    implicitHeight: 36
                    placeholderText: "Password for " + SystemStatus.pendingWifiSsid
                    echoMode: TextInput.Password
                    color: Colors.text
                    background: Rectangle { radius: 10; color: Colors.glass(0.8); border.width: 1; border.color: wifiPassword.activeFocus ? Colors.accent : Colors.outline }
                    onAccepted: {
                        SystemStatus.connectWifi(SystemStatus.pendingWifiSsid, text);
                        text = "";
                    }
                }

                Text { text: "Bluetooth devices"; color: Colors.text; font.pixelSize: 14; font.bold: true; visible: root.adapter && root.adapter.enabled }
                Repeater {
                    // As above, keep discovery results live instead of taking
                    // a startup-time snapshot of the BlueZ device model.
                    model: root.adapter && root.adapter.enabled ? Bluetooth.devices : null
                    delegate: Rectangle {
                        id: deviceRow
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 46; radius: 12; color: btHover.hovered ? Colors.glass(0.95) : Colors.glass(0.6)
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 11
                            Text { text: ""; font.family: "JetBrainsMono Nerd Font"; color: deviceRow.modelData.connected ? Colors.accent : Colors.subtext }
                            Text { text: deviceRow.modelData.name || deviceRow.modelData.deviceName; color: Colors.text; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: deviceRow.modelData.connected ? "Connected" : deviceRow.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…" : deviceRow.modelData.paired ? "Connect" : "Pair"; color: Colors.subtext; font.pixelSize: 11 }
                        }
                        HoverHandler { id: btHover }
                        TapHandler { onTapped: {
                            if (deviceRow.modelData.connected) deviceRow.modelData.disconnect();
                            else if (deviceRow.modelData.paired) deviceRow.modelData.connect();
                            else deviceRow.modelData.pair();
                        }}
                    }
                }
                Rectangle {
                    visible: root.adapter && root.adapter.enabled
                    Layout.fillWidth: true; implicitHeight: 38; radius: 12; color: scanHover.hovered ? Colors.glass(0.95) : Colors.glass(0.6)
                    Text { anchors.centerIn: parent; text: root.adapter && root.adapter.discovering ? "Scanning…" : "Scan for devices"; color: Colors.subtext; font.pixelSize: 12 }
                    HoverHandler { id: scanHover }
                    TapHandler { onTapped: if (root.adapter) root.adapter.discovering = !root.adapter.discovering }
                }
            }
        }
    }
}

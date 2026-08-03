// Generic circular progress ring drawn on a Canvas. Value is 0..1. Reused for
// any status gauge (disk now, CPU/RAM later).

import QtQuick

Item {
    id: ring

    property real value: 0
    property real thickness: 6
    property color trackColor: Colors.glass(0.35)
    property color fillColor: Colors.accent

    implicitWidth: 64
    implicitHeight: 64

    onValueChanged: canvas.requestPaint()
    onThicknessChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onFillColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2;
            const cy = height / 2;
            const r = Math.min(width, height) / 2 - ring.thickness / 2;

            ctx.lineWidth = ring.thickness;
            ctx.lineCap = "round";

            ctx.beginPath();
            ctx.strokeStyle = ring.trackColor;
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.stroke();

            const v = Math.max(0, Math.min(1, ring.value));
            if (v > 0) {
                const start = -Math.PI / 2;
                ctx.beginPath();
                ctx.strokeStyle = ring.fillColor;
                ctx.arc(cx, cy, r, start, start + 2 * Math.PI * v);
                ctx.stroke();
            }
        }
    }
}

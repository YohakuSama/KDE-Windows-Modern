// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QImage>
#include <QPainter>
#include <QRect>

namespace WindowsModern
{
inline QImage normalizedPanelImage(const QImage &source)
{
    if (source.isNull()) {
        return {};
    }
    const QImage image = source.convertToFormat(QImage::Format_ARGB32_Premultiplied);
    int left = image.width(), right = -1, top = image.height(), bottom = -1;
    for (int y = 0; y < image.height(); ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            if (qAlpha(line[x]) >= 12) {
                left = qMin(left, x);
                right = qMax(right, x);
                top = qMin(top, y);
                bottom = qMax(bottom, y);
            }
        }
    }
    if (right < left || bottom < top) {
        return {};
    }
    constexpr int canvasSize = 96;
    constexpr int paintedSize = 84;
    QImage canvas(canvasSize, canvasSize, QImage::Format_ARGB32_Premultiplied);
    canvas.fill(Qt::transparent);
    const QImage painted = image.copy(QRect(QPoint(left, top), QPoint(right, bottom)))
        .scaled(paintedSize, paintedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    QPainter painter(&canvas);
    painter.drawImage((canvasSize - painted.width()) / 2, (canvasSize - painted.height()) / 2, painted);
    painter.end();
    return canvas;
}
}

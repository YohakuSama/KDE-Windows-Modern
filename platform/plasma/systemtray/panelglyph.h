// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QImage>
#include <QImageReader>
#include <QRectF>
#include <QtGlobal>

namespace WindowsTray
{
// Optical bounds in the square into which Qt fits the source. Include faint
// state indicators, but ignore nearly transparent antialiasing fringes.
inline QRectF panelGlyphBounds(const QImage &source)
{
    const QRectF full(0, 0, 1, 1);
    if (source.isNull()) return full;
    const QImage image = source.convertToFormat(QImage::Format_ARGB32);
    int left = image.width(), top = image.height(), right = -1, bottom = -1;
    for (int y = 0; y < image.height(); ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            if (qAlpha(line[x]) < 12) continue;
            left = qMin(left, x); right = qMax(right, x);
            top = qMin(top, y); bottom = qMax(bottom, y);
        }
    }
    if (right < left || bottom < top) return full;
    const qreal side = qMax(image.width(), image.height());
    return QRectF((left + (side - image.width()) / 2) / side,
                  (top + (side - image.height()) / 2) / side,
                  (right - left + 1) / side, (bottom - top + 1) / side);
}

// Shared production and test decoder. Qt renders the actual local artwork,
// including viewBox transforms and alpha, before bounds are calculated.
inline QRectF panelGlyphFileBounds(const QString &path)
{
    QImageReader reader(path);
    const QSize intrinsic = reader.size();
    if (!intrinsic.isValid()) return QRectF(0, 0, 1, 1);
    reader.setScaledSize(intrinsic.scaled(128, 128, Qt::KeepAspectRatio));
    return panelGlyphBounds(reader.read());
}
}

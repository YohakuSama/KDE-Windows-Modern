// SPDX-License-Identifier: GPL-2.0-or-later
#include "../../plasma/applets/org.kde.windowsmodern.icontasks/panelicon.h"
#include <cassert>

int main()
{
    QImage wide(100, 100, QImage::Format_ARGB32_Premultiplied);
    wide.fill(Qt::transparent);
    {
        QPainter p(&wide);
        p.fillRect(20, 35, 60, 30, Qt::white);
    }
    const QImage out = WindowsModern::normalizedPanelImage(wide);
    assert(out.size() == QSize(96, 96));
    int x0 = 96, x1 = -1, y0 = 96, y1 = -1;
    for (int y = 0; y < 96; ++y) {
        for (int x = 0; x < 96; ++x) {
            if (qAlpha(out.pixel(x, y)) >= 12) {
                x0 = qMin(x0, x); x1 = qMax(x1, x);
                y0 = qMin(y0, y); y1 = qMax(y1, y);
            }
        }
    }
    assert(x1 - x0 + 1 == 84);
    assert(y1 - y0 + 1 == 42);
    assert(x0 == 6 && y0 == 27);
    QImage blank(20,20,QImage::Format_ARGB32_Premultiplied);
    blank.fill(Qt::transparent);
    assert(WindowsModern::normalizedPanelImage(blank).isNull());
    return 0;
}

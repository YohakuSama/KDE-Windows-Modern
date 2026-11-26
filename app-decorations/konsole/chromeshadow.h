// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <KWindowShadow>
#include <QPointer>

class QWindow;

// Compositor-rendered shadow, outside the real window geometry.
class ChromeShadow final
{
public:
    void clear();
    void update(QWindow *window, bool visible, bool active);

private:
    KWindowShadow m_shadow;
    QPointer<QWindow> m_window;
    int m_padding = 0;
    bool m_active = false;
    bool m_attempted = false;
};

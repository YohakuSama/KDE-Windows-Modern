// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QAction>
#include <QList>
#include <QMenu>

class DesktopMenuLayout
{
public:
    DesktopMenuLayout();
    QList<QAction *> build(const QList<QAction *> &nativeActions,
                           QAction *refresh, QAction *personalize,
                           QAction *undo = nullptr, QAction *openTerminal = nullptr);
    static QAction *named(const QList<QAction *> &actions, const QString &name);
    static QAction *sortAction(QAction *view);
    bool ownsMenu(const QMenu *menu) const;
    static bool darkMode(const QString &plasmaTheme, const QString &scheme, bool paletteDark);
    static void applyAppearance(QMenu *menu, bool dark);
    static void restoreAppearance(QMenu *menu);
private:
    QMenu m_view, m_more;
    QAction m_separator1, m_pasteSeparator, m_separator2, m_extensionSeparator, m_separator3;
};

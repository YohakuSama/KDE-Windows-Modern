// SPDX-License-Identifier: GPL-2.0-or-later
// Unlike source-based QML tests, inspect the real compiled applet's QRC.
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QLibrary>
#include <QStringList>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (argc != 3) {
        qCritical() << "Usage: test_tray_resources PLUGIN SOURCE_UI_DIR";
        return 2;
    }
    QLibrary plugin(QString::fromLocal8Bit(argv[1]));
    plugin.setLoadHints(QLibrary::ResolveAllSymbolsHint | QLibrary::PreventUnloadHint);
    if (!plugin.load()) {
        qCritical() << "Cannot load compiled applet:" << plugin.errorString();
        return 1;
    }
    const QDir source(QString::fromLocal8Bit(argv[2]));
    const QString prefix = QStringLiteral(":/qt/qml/plasma/applet/org/kde/windowsmodern/systemtray/");
    const QStringList patterns = {
        QStringLiteral("*.qml"), QStringLiteral("*.js"), QStringLiteral("*.mjs"),
        QStringLiteral("*.svg"), QStringLiteral("*.svgz"), QStringLiteral("*.png"),
        QStringLiteral("*.webp"), QStringLiteral("*.jpg"), QStringLiteral("*.jpeg")
    };
    QDirIterator it(source.absolutePath(), patterns, QDir::Files, QDirIterator::Subdirectories);
    int checked = 0;
    bool failed = false;
    while (it.hasNext()) {
        const QString relative = source.relativeFilePath(it.next());
        const QString resource = prefix + relative;
        if (!QFile::exists(resource)) {
            qCritical().noquote() << "Missing embedded applet resource:" << resource;
            failed = true;
        }
        ++checked;
    }
    // Explicitly guard the file that previously prevented the entire tray
    // from loading, even if it is accidentally deleted from the source tree.
    for (const auto &required : {QStringLiteral("main.qml"),
                                 QStringLiteral("ActionPanel.qml"),
                                 QStringLiteral("lib/FluentScrollBar.qml"),
                                 QStringLiteral("icons/battery-saver-symbolic.svg")}) {
        if (!QFile::exists(prefix + required)) {
            qCritical().noquote() << "Required tray resource missing:" << prefix + required;
            failed = true;
        }
    }
    if (!checked) {
        qCritical() << "No source UI resources enumerated";
        return 1;
    }
    qInfo() << "Checked" << checked << "resources in the compiled system tray";
    return failed ? 1 : 0;
}

# SPDX-License-Identifier: GPL-3.0-or-later
# Built inside the exact Konsole source tree, not against a public SDK.
find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS Svg DBus)
find_package(KF6WindowSystem ${KF6_DEP_VERSION} CONFIG REQUIRED)
configure_file(windowsmodernchrome.in.json windowsmodernchrome.json @ONLY)
kcoreaddons_add_plugin(konsole_windowsmodernchrome
    SOURCES windowsmodernchrome.cpp captionsnapbridge.cpp captionsnapbridge.h chromeshadow.cpp chromeshadow.h
    INSTALL_NAMESPACE "konsoleplugins"
)
target_include_directories(konsole_windowsmodernchrome PRIVATE
    "${PROJECT_SOURCE_DIR}/src"
    "${PROJECT_BINARY_DIR}/src"
)
target_link_libraries(konsole_windowsmodernchrome PRIVATE
    konsoleprivate konsoleapp Qt6::Widgets Qt6::Svg Qt6::DBus KF6::CoreAddons KF6::XmlGui KF6::WindowSystem
)

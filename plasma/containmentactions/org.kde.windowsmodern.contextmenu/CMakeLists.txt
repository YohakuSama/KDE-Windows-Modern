cmake_minimum_required(VERSION 3.20)
project(windowsmodern-contextmenu LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(ECM REQUIRED 6.0)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
find_package(Qt6 REQUIRED COMPONENTS Widgets)
find_package(KF6 REQUIRED COMPONENTS CoreAddons Config I18n)
find_package(Plasma REQUIRED)
kcoreaddons_add_plugin(org.kde.windowsmodern.contextmenu
    SOURCES nativecontextmenu.cpp menulayout.cpp
    INSTALL_NAMESPACE "plasma/containmentactions")
set_target_properties(org.kde.windowsmodern.contextmenu PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib/plasma/containmentactions"
    PREFIX "")
target_link_libraries(org.kde.windowsmodern.contextmenu PRIVATE
    Qt6::Widgets KF6::CoreAddons KF6::ConfigCore KF6::I18n Plasma::Plasma)
option(WINDOWSMODERN_TEST_CONTEXTMENU "Build desktop menu action regression tests" OFF)
if(WINDOWSMODERN_TEST_CONTEXTMENU)
    enable_testing()
    add_executable(test_contextmenu tests/test_contextmenu.cpp menulayout.cpp)
    target_include_directories(test_contextmenu PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    target_link_libraries(test_contextmenu PRIVATE Qt6::Widgets KF6::I18n)
    add_test(NAME native-contextmenu-actions COMMAND test_contextmenu)
    set_tests_properties(native-contextmenu-actions PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
endif()

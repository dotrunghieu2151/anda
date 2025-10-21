# ==============================
# Portfile for Slint (custom)
# ==============================
cmake_minimum_required(VERSION 4.1.2)
# 1. Download Slint source
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO slint-ui/slint
    REF v1.13.1
    SHA512 4b6126cf239d95bcba3c8e4264b2c6a580d93e11213679f98a331e1820c50a41c0c10cf8ffa2aba1fa20678b269d7734db097d162262f455c3d1ccce1986d680
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/api/cpp"
    OPTIONS
        -DSLINT_BUILD_EXAMPLES=OFF
        -DSLINT_BUILD_TESTING=OFF
        -DSLINT_BUILD_DOCS=OFF
        -DSLINT_BUILD_DEMOS=OFF
)

message(STATUS "Configuring Slint ${CURRENT_PACKAGES_DIR}")
set(CMAKE_FIND_DEBUG_MODE TRUE)
vcpkg_cmake_build()
vcpkg_cmake_install()

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSES")
# ==============================
# Portfile for Slint (custom)
# ==============================
cmake_minimum_required(VERSION 3.31.10)
# 1. Download Slint source
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO slint-ui/slint
    REF v1.14.0
    SHA512 f42d5cb3569e927f96eaacb630252ddbeab279304a520293f0e35d847514b09387ff30d88748b46404e7183b9bc055e0cda3d2883948badf2ee7dab9a4ad9703
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/api/cpp"
    OPTIONS
        -DSLINT_FEATURE_LIVE_PREVIEW=ON
        -DRust_COMPILER=${RUSTBIN_RUSTC_EXECUTABLE}
        -DRust_CARGO=${RUSTBIN_CARGO_EXECUTABLE}
)

message(STATUS "Configuring Slint ${CURRENT_PACKAGES_DIR}")

vcpkg_cmake_install()

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSES")
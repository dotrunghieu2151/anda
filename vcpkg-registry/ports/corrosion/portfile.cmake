vcpkg_from_github(
    OUT_SOURCE_PATH CORROSION_SOURCE
    REPO "corrosion-rs/corrosion"
    REF "v0.5.2"
    SHA512 2510d4d0484fc12a6b429244b283515fda650b52ea74fbfdcc141298b452b20e2bef800b8f8a573a2bf509f4147ecb2d68e795cbd86cc8edd092f57ccff8b86b
)

vcpkg_cmake_configure(
    SOURCE_PATH "${CORROSION_SOURCE}"
)
vcpkg_cmake_build()
vcpkg_cmake_install()

vcpkg_cmake_config_fixup(PACKAGE_NAME Corrosion CONFIG_PATH lib/cmake/Corrosion)
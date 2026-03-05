vcpkg_from_github(
    OUT_SOURCE_PATH CORROSION_SOURCE
    REPO "corrosion-rs/corrosion"
    REF "v0.6.0"
    SHA512 e1f7b74f9757057e9f2e929f3d3bcf73583b9fd1cd717038d285d8b3730ec0ba8c5fbd0986b2523080736e015a37a17de640bee14d8ffb5d4a253d3ebe8800c5
)
vcpkg_cmake_configure(
    SOURCE_PATH "${CORROSION_SOURCE}"
    OPTIONS
      -DRust_COMPILER=${RUSTBIN_RUSTC_EXECUTABLE}
      -DRust_CARGO=${RUSTBIN_CARGO_EXECUTABLE}
)

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(PACKAGE_NAME Corrosion CONFIG_PATH lib/cmake/Corrosion)

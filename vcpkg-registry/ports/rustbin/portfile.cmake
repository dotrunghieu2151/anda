# Detect platform
if(VCPKG_TARGET_IS_WINDOWS)
    set(RUST_VERSION "1.85.0")
    set(RUST_URL "https://static.rust-lang.org/dist/rust-${RUST_VERSION}-x86_64-pc-windows-msvc.tar.gz")
    set(RUST_FILENAME "rust-${RUST_VERSION}-x86_64-windows.tar.gz")
    set(RUST_SHA512 "6a2e4c2996726815efdb1ce89305bbcba863dad46f1510dd57f9732fc689f0bbccdd453ac1984537a77fa90c5e19c1b73d27acb5f976481ab020b9eeeb102e49")
elseif(VCPKG_TARGET_IS_LINUX)
    set(RUST_VERSION "1.85.0")
    set(RUST_URL "https://static.rust-lang.org/dist/rust-${RUST_VERSION}-x86_64-unknown-linux-gnu.tar.gz")
    set(RUST_FILENAME "rust-${RUST_VERSION}-x86_64-linux.tar.gz")
    set(RUST_SHA512 "6a2e4c2996726815efdb1ce89305bbcba863dad46f1510dd57f9732fc689f0bbccdd453ac1984537a77fa90c5e19c1b73d27acb5f976481ab020b9eeeb102e49")
elseif(VCPKG_TARGET_IS_OSX)
    set(RUST_VERSION "1.85.0")
    set(RUST_URL "https://static.rust-lang.org/dist/rust-${RUST_VERSION}-x86_64-apple-darwin.tar.gz")
    set(RUST_FILENAME "rust-${RUST_VERSION}-x86_64-macos.tar.gz")
    set(RUST_SHA512 "6a2e4c2996726815efdb1ce89305bbcba863dad46f1510dd57f9732fc689f0bbccdd453ac1984537a77fa90c5e19c1b73d27acb5f976481ab020b9eeeb102e49")
else()
    message(FATAL_ERROR "Unsupported platform for Rust")
endif()

# Download appropriate Rust package
vcpkg_download_distfile(
    RUST_INSTALLER
    URLS "${RUST_URL}"
    FILENAME "${RUST_FILENAME}"
    SHA512 ${RUST_SHA512}
)

# Extract
vcpkg_extract_source_archive_ex(
    OUT_SOURCE_PATH SOURCE_PATH
    ARCHIVE "${RUST_INSTALLER}"
)

# Copy everything to tools directory
file(INSTALL
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/rust/bin/cargo"
    TYPE DIRECTORY
    FILES "${SOURCE_PATH}/cargo"
)

file(INSTALL
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/rust/bin/rustc"
    TYPE DIRECTORY
    FILES "${SOURCE_PATH}/rustc"
)

# Add to PATH so dependent ports can use rustc, cargo, etc.
vcpkg_add_to_path("${CURRENT_PACKAGES_DIR}/tools/rust/bin/cargo")
vcpkg_add_to_path("${CURRENT_PACKAGES_DIR}/tools/rust/bin/rustc")

# Install license info (if available)
if(EXISTS "${RUST_ROOT}/LICENSE.txt")
    vcpkg_install_copyright(FILE_LIST "${RUST_ROOT}/LICENSE.txt")
endif()

message(STATUS "Rust ${RUST_VERSION} installed for ${VCPKG_TARGET_TRIPLET}")
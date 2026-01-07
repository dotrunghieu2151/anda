set(VCPKG_POLICY_CMAKE_HELPER_PORT enabled)

# Detect platform
if(VCPKG_TARGET_IS_WINDOWS)
    set(RUST_VERSION "1.88.0")
    set(RUST_URL "https://static.rust-lang.org/dist/rust-${RUST_VERSION}-x86_64-pc-windows-msvc.tar.gz")
    set(RUST_FILENAME "rust-${RUST_VERSION}-x86_64-windows.tar.gz")
    set(RUST_SHA512 "33f8faf0fd3d33fcc326d797183c76ebb8a7f364678fddde36b7377edfa9ecdac7e29e23a72f60c4b5d6b165f7e4f0d75b3625480d8aaff1ad6d265c6b43e2b6")
elseif(VCPKG_TARGET_IS_LINUX)
    set(RUST_VERSION "1.88.0")
    set(RUST_URL "https://static.rust-lang.org/dist/rust-${RUST_VERSION}-x86_64-unknown-linux-gnu.tar.gz")
    set(RUST_FILENAME "rust-${RUST_VERSION}-x86_64-linux.tar.gz")
    set(RUST_SHA512 "6a2e4c2996726815efdb1ce89305bbcba863dad46f1510dd57f9732fc689f0bbccdd453ac1984537a77fa90c5e19c1b73d27acb5f976481ab020b9eeeb102e49")
elseif(VCPKG_TARGET_IS_OSX)
    set(RUST_VERSION "1.88.0")
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
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}"
    TYPE DIRECTORY
    FILES "${SOURCE_PATH}/rustc"
)

file(INSTALL
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}"
    TYPE DIRECTORY
    FILES "${SOURCE_PATH}/cargo"
)

# Find the rust-std component directory
file(GLOB RUST_STD_DIRS "${SOURCE_PATH}/rust-std-*")
list(LENGTH RUST_STD_DIRS RUST_STD_COUNT)
if(RUST_STD_COUNT EQUAL 0)
    message(FATAL_ERROR "Could not find rust-std component for ${RUST_TARGET}")
elseif(RUST_STD_COUNT GREATER 1)
    message(WARNING "Multiple rust-std directories found, using first: ${RUST_STD_DIRS}")
endif()
list(GET RUST_STD_DIRS 0 RUST_STD_DIR)

# Copy standard library into rustc's lib directory
# The rust-std component contains lib/rustlib/ which needs to be merged
if(EXISTS "${RUST_STD_DIR}/lib/rustlib")
    file(INSTALL
        DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}/rustc/lib"
        TYPE DIRECTORY
        FILES "${RUST_STD_DIR}/lib/rustlib"
    )
else()
    message(FATAL_ERROR "rust-std component does not contain lib/rustlib directory")
endif()


configure_file("${CMAKE_CURRENT_LIST_DIR}/rustbinConfig.cmake"
               "${CURRENT_PACKAGES_DIR}/share/${PORT}/rustbinConfig.cmake"
               @ONLY)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/vcpkg-port-config.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

               # Fix permissions cross-platform
if(VCPKG_TARGET_IS_LINUX OR VCPKG_TARGET_IS_OSX)
    message(STATUS "Fixing executable permissions for Rust binaries...")
    file(GLOB_RECURSE RUST_BINARIES "${CURRENT_PACKAGES_DIR}/tools/${PORT}/*")
    foreach(f ${RUST_BINARIES})
        file(CHMOD ${f}
            PERMISSIONS
            OWNER_READ OWNER_WRITE OWNER_EXECUTE
            GROUP_READ GROUP_EXECUTE
            WORLD_READ WORLD_EXECUTE
        )
    endforeach()

    # if(APPLE)
    #     # Remove Gatekeeper quarantine
    #     execute_process(
    #         COMMAND xattr -dr com.apple.quarantine "${CURRENT_PACKAGES_DIR}/tools/rust/bin"
    #         COMMAND_ERROR_IS_FATAL ANY
    #     )
    # endif()
endif()

# Install license info (if available)
if(EXISTS "${RUST_ROOT}/LICENSE.txt")
    vcpkg_install_copyright(FILE_LIST "${RUST_ROOT}/LICENSE.txt")
endif()

message(STATUS "Rust ${RUST_VERSION} installed for ${VCPKG_TARGET_TRIPLET}")

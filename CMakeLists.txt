cmake_minimum_required(VERSION 4.1.2)

project(anda LANGUAGES CXX)

# append path for local cmake modules (for find_package() to work)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/modules")

# include cmake Macros/functions/shared configs/utils
include(cmake/config/ProjectDefaults.cmake)

#include modules
include(ClangFormat)


# dependencies
find_package(fmt REQUIRED)
find_package(spdlog REQUIRED)
find_package(Slint REQUIRED)
find_package(portaudio CONFIG REQUIRED)

# soxr doesn't provide CMake config files, so we set it up manually
find_path(SOXR_INCLUDE_DIR soxr.h)
find_library(SOXR_LIBRARY NAMES soxr)

if(SOXR_INCLUDE_DIR AND SOXR_LIBRARY)
    # Create an imported target for soxr
    add_library(soxr::soxr UNKNOWN IMPORTED)
    set_target_properties(soxr::soxr PROPERTIES
        IMPORTED_LOCATION "${SOXR_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${SOXR_INCLUDE_DIR}"
    )
    message(STATUS "Found SoXR: ${SOXR_LIBRARY}")
else()
    message(FATAL_ERROR "Could not find SoXR library. Make sure it's installed via vcpkg.")
endif()

get_target_property(slint_enabled_features Slint::Slint SLINT_ENABLED_FEATURES)
message(STATUS "Slint enabled features: ${slint_enabled_features}")
# subdirectories
add_subdirectory(src)

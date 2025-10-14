set(CMAKE_SYSTEM_NAME Windows)

# Assume MSVC; allow override via MINGW
if (MINGW)
    message(STATUS "Using MinGW on Windows")
    set(BASE_FLAGS "-Wall -Wextra -Wpedantic -Wshadow -Wconversion -fPIC")
    set(CMAKE_CXX_FLAGS_INIT "${BASE_FLAGS}")
    set(CMAKE_CXX_FLAGS_DEBUG_INIT "-O0 -g3 -DDEBUG")
    set(CMAKE_CXX_FLAGS_RELEASE_INIT "-O3 -DNDEBUG -march=native -mtune=native")
    set(CMAKE_CXX_FLAGS_FAST_INIT "-Ofast -DNDEBUG -march=native -mtune=native -funroll-loops -ffast-math")
else()
    message(STATUS "Using MSVC compiler")
    set(CMAKE_GENERATOR_PLATFORM "x64" CACHE STRING "Target architecture")

    # Modern C++ & strict warnings
    set(BASE_FLAGS "/W4 /permissive- /EHsc /Zc:__cplusplus /utf-8")
    set(CMAKE_CXX_FLAGS_INIT "${BASE_FLAGS}")

    set(CMAKE_CXX_FLAGS_DEBUG_INIT "/Od /Zi /DDEBUG")
    set(CMAKE_CXX_FLAGS_RELEASE_INIT "/O2 /DNDEBUG /GL /Gw")
    set(CMAKE_CXX_FLAGS_FAST_INIT "/Ox /Ot /Oi /GL /Gw /fp:fast /DNDEBUG")
    
    # Enable Link Time Code Generation
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_FAST ON)

    # Static runtime (good for standalone apps)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

# vcpkg integration
set(VCPKG_ROOT "${CMAKE_SOURCE_DIR}/.vcpkg")
if (EXISTS "${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
    include("${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
endif()

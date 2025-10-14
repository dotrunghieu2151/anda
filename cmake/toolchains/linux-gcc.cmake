set(CMAKE_SYSTEM_NAME Linux)

# Compiler setup
if (DEFINED ENV{CC})
    set(CMAKE_C_COMPILER "$ENV{CC}")
    set(CMAKE_CXX_COMPILER "$ENV{CXX}")
else()
    find_program(CMAKE_C_COMPILER gcc)
    find_program(CMAKE_CXX_COMPILER g++)
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ---------------------------------
# Compiler flags
# ---------------------------------
set(BASE_FLAGS "-Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wno-unused-parameter -fPIC")

set(CMAKE_CXX_FLAGS_INIT "${BASE_FLAGS}")
set(CMAKE_CXX_FLAGS_DEBUG_INIT "-O0 -g3 -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE_INIT "-O3 -DNDEBUG -march=native -mtune=native")
set(CMAKE_CXX_FLAGS_FAST_INIT "-Ofast -DNDEBUG -march=native -mtune=native -funroll-loops -ffast-math")

# Enable LTO in Release/Fast
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_FAST ON)

# ---------------------------------
# vcpkg integration
# ---------------------------------
set(VCPKG_ROOT "${CMAKE_SOURCE_DIR}/.vcpkg")
if (EXISTS "${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
    include("${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
endif()

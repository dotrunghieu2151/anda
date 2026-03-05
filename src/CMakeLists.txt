add_executable(${PROJECT_NAME}
    main.cpp
)

target_link_libraries(${PROJECT_NAME} PRIVATE Slint::Slint fmt::fmt spdlog::spdlog)

# macOS requires additional system frameworks for Slint
if(APPLE)
    target_link_libraries(${PROJECT_NAME} PRIVATE
        "-framework Foundation"
        "-framework AppKit"
        # "-framework CoreGraphics"
        "-framework QuartzCore"
        # "-framework Metal"
        # "-framework IOKit"
        # "-framework Security"
        "-framework OpenGL"
        "-framework Carbon"
    )
endif()

# Slint UI files - app-window.slint is the main entry point
# It imports all component files automatically
slint_target_sources(${PROJECT_NAME} 
        ui/app-window.slint
)


# Include asset copying utility
include(${CMAKE_SOURCE_DIR}/cmake/utils/CopyAssets.cmake)

# Copy assets to build directory
copy_assets_to_build_dir(
    TARGET_NAME ${PROJECT_NAME}
    ASSETS_SOURCE_DIR "${CMAKE_SOURCE_DIR}/assets"
    ASSETS_DEST_SUBDIR "assets"
)

# On Windows, copy the Slint DLL next to the application binary so that it's found.
if (WIN32)
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_RUNTIME_DLLS:${PROJECT_NAME}> $<TARGET_FILE_DIR:${PROJECT_NAME}> COMMAND_EXPAND_LISTS)
endif()
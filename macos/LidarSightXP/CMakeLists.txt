cmake_minimum_required(VERSION 3.20)
project(LidarSightXP)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED XPLANE_SDK)
    set(XPLANE_SDK "/Applications/X-Plane 12/Developer SDK/XPLM")
endif()

if(NOT EXISTS ${XPLANE_SDK})
    message(WARNING "X-Plane SDK not found at ${XPLANE_SDK}. Set XPLANE_SDK path manually.")
endif()

include_directories(${XPLANE_SDK}/SDK/CHeaders)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/Sources)

set(PLUGIN_SOURCES
    Sources/LidarSightXP.cpp
    Sources/LidarSightXP.h
    Sources/Processing/OneEuroFilter.h
)

set(PLUGIN_NAME "LidarSightXP")

add_library(${PLUGIN_NAME} MODULE ${PLUGIN_SOURCES})

target_link_libraries(${PLUGIN_NAME}
    ${XPLANE_SDK}/SDK/Libraries/Mac/libXPLM.a
)

set_target_properties(${PLUGIN_NAME} PROPERTIES
    PREFIX ""
    OUTPUT_NAME "${PLUGIN_NAME}.xpl"
    LINK_FLAGS "-bundle"
    MACOSX_BUNDLE TRUE
)

install(TARGETS ${PLUGIN_NAME}
    RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
)

message(STATUS "LidarSightXP plugin configured")
message(STATUS "X-Plane SDK: ${XPLANE_SDK}")

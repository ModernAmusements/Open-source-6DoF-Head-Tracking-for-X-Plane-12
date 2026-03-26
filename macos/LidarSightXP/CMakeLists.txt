cmake_minimum_required(VERSION 3.20)
project(LidarSightXP)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DAPL=1 -arch arm64 -arch x86_64")

set(XPLANE_SDK ${CMAKE_SOURCE_DIR}/../../SDK)

if(NOT EXISTS ${XPLANE_SDK})
    message(FATAL_ERROR "X-Plane SDK not found at ${XPLANE_SDK}")
endif()

message(STATUS "Using X-Plane SDK at: ${XPLANE_SDK}")

include_directories(${XPLANE_SDK}/CHeaders)
include_directories(${XPLANE_SDK}/CHeaders/XPLM)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/Sources)

set(PLUGIN_SOURCES
    Sources/LidarSightXP.cpp
    Sources/LidarSightXP.h
    Sources/Processing/OneEuroFilter.h
)

set(PLUGIN_NAME "LidarSightXP")

add_library(${PLUGIN_NAME} MODULE ${PLUGIN_SOURCES})

target_link_libraries(${PLUGIN_NAME}
    ${XPLANE_SDK}/Libraries/Mac/XPLM.framework/XPLM
    ${XPLANE_SDK}/Libraries/Mac/XPWidgets.framework/XPWidgets
)

set_target_properties(${PLUGIN_NAME} PROPERTIES
    PREFIX ""
    OUTPUT_NAME "${PLUGIN_NAME}.xpl"
    LINK_FLAGS "-bundle -Wl,-e,_XPluginStart"
    MACOSX_BUNDLE FALSE
    SUFFIX ""
)

set_target_properties(${PLUGIN_NAME} PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/dist"
)

install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/dist/ DESTINATION .)

message(STATUS "LidarSightXP plugin configured")

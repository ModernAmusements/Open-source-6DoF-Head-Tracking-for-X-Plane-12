cmake_minimum_required(VERSION 3.20)
project(LidarSightXP)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED XPLANE_SDK)
    set(XPLANE_SDK "/Applications/X-Plane 12/Developer SDK/XPLM")
endif()

include_directories(${XPLANE_SDK}/SDK/CHeaders)

set(SOURCES
    Sources/LidarSightXP.cpp
    Sources/LidarSightXP.cpp
)

set(PLUGIN_NAME "LidarSightXP")

add_library(${PLUGIN_NAME} MODULE
    Sources/LidarSightXP.cpp
    Sources/LidarSightXP.cpp
)

target_link_libraries(${PLUGIN_NAME}
    ${XPLANE_SDK}/SDK/Libraries/Mac/libXPLM.a
)

set_target_properties(${PLUGIN_NAME} PROPERTIES
    PREFIX ""
    OUTPUT_NAME "${PLUGIN_NAME}.xpl"
    LINK_FLAGS "-bundle"
)

install(TARGETS ${PLUGIN_NAME}
    RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
)

cmake_minimum_required(VERSION 3.30.5)

#[=======================[ Global CMake Configuration ]=======================]
if( CMAKE_C_COMPILER )
    #Do nothing, just shut up the build because clion adds this from the toolchain
endif ()

set( FETCHCONTENT_UPDATES_DISCONNECTED OFF CACHE BOOL "Stop updating every configure")

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

### Cmake options to expose
option( CMAKE_EXPORT_COMPILE_COMMANDS
        "Generate compilation DB (`compile_commands.json`) for external tools"
        ON )

# So that I can condifgure for the flatc compiler, and not the extension.
option( BUILD_EXTENSION "build the extension" ON)

## Target options
set( GDE_NAME "gdflatbuffers" )

### Information regarding the godot executable
set( GODOT_EXECUTABLE "" CACHE FILEPATH
        "Path to the godot executable you are targeting" )

set( GODOT_PROJECT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/project" CACHE PATH
        "Path to a demo project that can test the gdextension" )

#[==============================[ Dependencies ]==============================]
include(FetchContent)
include(CMakePrintHelpers)

include(cmake/findGodotExecutable.cmake)
include(cmake/godot-dump.cmake)

#[==============[ Git ]==============]
find_program(GIT_EXECUTABLE NAMES "git" DOC "" NO_CACHE REQUIRED)
if( NOT EXISTS "${GIT_EXECUTABLE}" )
    message( FATAL_ERROR "Unable to find Git at: '${GIT_EXECUTABLE}'")
endif()

# MARK: flatbuffs
# ╒════════════════════════════════════════════════════════════════════════════╕
# │ ███████ ██       █████  ████████ ██████  ██    ██ ███████ ███████ ███████  │
# │ ██      ██      ██   ██    ██    ██   ██ ██    ██ ██      ██      ██       │
# │ █████   ██      ███████    ██    ██████  ██    ██ █████   █████   ███████  │
# │ ██      ██      ██   ██    ██    ██   ██ ██    ██ ██      ██           ██  │
# │ ██      ███████ ██   ██    ██    ██████   ██████  ██      ██      ███████  │
# ╘════════════════════════════════════════════════════════════════════════════╛

set( FLATBUFFERS_GIT_URL "https://github.com/enetheru/flatbuffers.git"
        CACHE STRING "Location of the godot-cpp git repository" )
set( FLATBUFFERS_GIT_TAG "gdscript"
        CACHE STRING "git hash, branch or tag to fetch" )

# Configuration Options
set( FLATBUFFERS_BUILD_FLATHASH     NO )
set( FLATBUFFERS_BUILD_SHAREDLIB    NO )
set( FLATBUFFERS_BUILD_TESTS        NO )
set( FLATBUFFERS_INSTALL            NO )
set( FLATBUFFERS_STATIC_FLATC      YES )
set( FLATBUFFERS_BUILD_FLATC       YES )

FetchContent_Declare( FlatBuffers
        GIT_REPOSITORY  "${FLATBUFFERS_GIT_URL}"
        GIT_TAG         "${FLATBUFFERS_GIT_TAG}"
        SOURCE_DIR      "${CMAKE_CURRENT_SOURCE_DIR}/lib/flatbuffers"
        SYSTEM
        EXCLUDE_FROM_ALL
)
FetchContent_MakeAvailable( FlatBuffers )

set_target_properties(
        flatc
        PROPERTIES
        EXCLUDE_FROM_ALL OFF
        OUTPUT_NAME "flatc$<$<CONFIG:Debug,RelWithDebInfo>:.$<LOWER_CASE:$<CONFIG>>>"
        RUNTIME_OUTPUT_DIRECTORY "$<1:${CMAKE_CURRENT_SOURCE_DIR}/project/addons/${GDE_NAME}/bin>"
)

# If we dont want to build the extension then we can stop here
# This does break any other targets for this configuration
# so currently only useful for building flatc.
if( NOT BUILD_EXTENSION )
    return()
endif ()

# MARK: godot-cpp
# ╒════════════════════════════════════════════════════════════════════════════╕
# │  ██████   ██████  ██████   ██████  ████████     ██████ ██████  ██████      │
# │ ██       ██    ██ ██   ██ ██    ██    ██       ██      ██   ██ ██   ██     │
# │ ██   ███ ██    ██ ██   ██ ██    ██    ██ █████ ██      ██████  ██████      │
# │ ██    ██ ██    ██ ██   ██ ██    ██    ██       ██      ██      ██          │
# │  ██████   ██████  ██████   ██████     ██        ██████ ██      ██          │
# ╘════════════════════════════════════════════════════════════════════════════╛

set( GODOTCPP_GIT_URL "https://github.com/godotengine/godot-cpp.git" CACHE STRING "Location of the godot-cpp git repository" )
set( GODOTCPP_GIT_TAG "4.4" CACHE STRING "git hash, branch or tag to fetch" )

set( GODOTCPP_TARGET "template_debug" CACHE STRING "")
set( GODOTCPP_BUILD_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/godot-cpp.build_profile.json" )

#if( GODOT_GIT_TAG STREQUAL "" )
#    include( godot-cpp-git-tag )
#endif()

FetchContent_Declare( godot-cpp
        GIT_REPOSITORY  "${GODOTCPP_GIT_URL}"
        GIT_TAG         "${GODOTCPP_GIT_TAG}"
        SOURCE_DIR      "${CMAKE_CURRENT_SOURCE_DIR}/lib/godot-cpp"
        SYSTEM
        EXCLUDE_FROM_ALL
)
FetchContent_MakeAvailable( godot-cpp )

# MARK: project
# ╒════════════════════════════════════════════════════════════════════════════╕
# │ ██████  ██████   ██████       ██ ███████  ██████ ████████                  │
# │ ██   ██ ██   ██ ██    ██      ██ ██      ██         ██                     │
# │ ██████  ██████  ██    ██      ██ █████   ██         ██                     │
# │ ██      ██   ██ ██    ██ ██   ██ ██      ██         ██                     │
# │ ██      ██   ██  ██████   █████  ███████  ██████    ██                     │
# ╘════════════════════════════════════════════════════════════════════════════╛

project( godot-flatbuffers-extension
        VERSION 1.0
        DESCRIPTION ""
        LANGUAGES CXX)

### Global options
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_subdirectory( src )

add_library( ${GDE_NAME} SHARED )

target_sources( ${GDE_NAME}
    PRIVATE
        ${SOURCES}
)

target_link_libraries( ${GDE_NAME} PRIVATE godot-cpp FlatBuffers::FlatBuffers )

### Get useful properties of the library
get_target_property( GODOTCPP_SUFFIX godot::cpp GODOTCPP_SUFFIX )

set_target_properties( ${GDE_NAME}
        PROPERTIES
        FOLDER "gdflatbuffers"
        #The generator expression here prevents a subdir from being created.
        RUNTIME_OUTPUT_DIRECTORY "$<1:${CMAKE_CURRENT_SOURCE_DIR}/project/addons/${GDE_NAME}/bin>"
        OUTPUT_NAME "${GDE_NAME}${GODOTCPP_SUFFIX}$<$<CONFIG:Debug,RelWithDebInfo>:.$<LOWER_CASE:$<CONFIG>>>"
        PREFIX "lib"
)

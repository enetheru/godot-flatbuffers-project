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
option( BUILD_EXTENSION
        "build the extension"
        ON)

## Target options
set( GDE_NAME "gdflatbuffers" )

### Information regarding the godot executable
set( GODOT_EXECUTABLE ""
        CACHE FILEPATH "Path to the godot executable you are targeting" )

set( GODOT_PROJECT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/project"
        CACHE PATH "Path to a demo project that can test the gdextension" )

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

#[==========[ Flatbuffers ]==========]
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
        RUNTIME_OUTPUT_DIRECTORY "$<1:${CMAKE_CURRENT_SOURCE_DIR}/project/addons/${GDE_NAME}/bin>"
)

# If we dont want to build the extension then we can stop here
# This does break any other targets for this configuration
# so currently only useful for building flatc.
if( NOT BUILD_EXTENSION )
    return()
endif ()

#[============[ godot-cpp ]============]
set( GODOTCPP_GIT_URL "https://github.com/enetheru/godot-cpp.git" CACHE STRING "Location of the godot-cpp git repository" )
set( GODOTCPP_GIT_TAG "c2712bb0ab03618443a8942f079481b315988253" CACHE STRING "git hash, branch or tag to fetch" )
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

#[===========================[ Project Definition ]===========================]
project( godot-flatbuffers-extension
        VERSION 1.0
        DESCRIPTION ""
        LANGUAGES CXX)

### Global options
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_subdirectory( src )

### separate CMakeLists for our gdextension sources.
foreach ( TARGET_TYPE template_debug template_release editor )
    set( LIBNAME "${GDE_NAME}.${TARGET_TYPE}" )

    add_library( ${LIBNAME} SHARED )

    target_sources( ${LIBNAME}
        PRIVATE
            ${SOURCES}
    )

    target_link_libraries( ${LIBNAME} PRIVATE godot-cpp.${TARGET_TYPE} FlatBuffers::FlatBuffers )

    ### Get useful properties of the library
    get_target_property( GODOTCPP_SUFFIX godot-cpp.${TARGET_TYPE} GODOTCPP_SUFFIX )

    set_target_properties( ${LIBNAME}
            PROPERTIES
            FOLDER "gdflatbuffers"
            #The generator expression here prevents a subdir from being created.
            RUNTIME_OUTPUT_DIRECTORY "$<1:${CMAKE_CURRENT_SOURCE_DIR}/project/addons/${GDE_NAME}/bin>"
            OUTPUT_NAME "${GDE_NAME}${GODOTCPP_SUFFIX}$<$<CONFIG:Debug,RelWithDebInfo>:.$<LOWER_CASE:$<CONFIG>>>"
            PREFIX "lib"
    )
endforeach ()

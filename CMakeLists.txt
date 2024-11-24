cmake_minimum_required(VERSION 3.28)

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

get_property(is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if( is_multi_config )
    set( CMAKE_CONFIGURATION_TYPES "template_debug;template_release;editor;dev_build")
#    set( CMAKE_DEFAULT_CONFIGS "template_debug;template_release;editor;dev_build" )
#    if( NOT MSVC )
#        set( CMAKE_DEFAULT_BUILD_TYPE "template_release" )
#    endif ()
#    set( CMAKE_CROSS_CONFIGS "all" )
elseif (CMAKE_CONFIG_TYPE STREQUAL "")
    set( CMAKE_CONFIG_TYPE "template_release" )
endif ()

set( CMAKE_MAP_IMPORTED_CONFIG_dev_build Debug )
set( CMAKE_MAP_IMPORTED_CONFIG_editor Debug )
set( CMAKE_MAP_IMPORTED_CONFIG_template_debug Debug )
set( CMAKE_MAP_IMPORTED_CONFIG_template_release Release )

# We need git to perform some actions so make sure we have it.
find_program(GIT_EXECUTABLE NAMES "git" DOC "" NO_CACHE REQUIRED)
if( NOT EXISTS "${GIT_EXECUTABLE}" )
    message( FATAL_ERROR "Unable to find Git at: '${GIT_EXECUTABLE}'")
endif()

include(cmake/findGodotExecutable.cmake)
include(cmake/godot-dump.cmake)

### Independent Global CMake options
include(FetchContent)
include(CMakePrintHelpers)

# The name of the project is used for the build target
project( godot-flatbuffers-extension
        VERSION 1.0
        DESCRIPTION ""
        LANGUAGES CXX)

include(options.cmake)

if( CMAKE_C_COMPILER )
    #Do nothing, just shut up the build because clion adds this from the toolchain
endif ()

### Global options
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Output Directory
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${GODOT_PROJECT_PATH}/addons/${GDE_NAME}/bin )

### Add Flatbuffers as a sub project
FetchContent_Declare( FlatBuffers
        GIT_REPOSITORY "https://github.com/enetheru/flatbuffers.git"
        GIT_TAG "gdscript"
        SOURCE_DIR "${PROJECT_SOURCE_DIR}/lib/flatbuffers"
        UPDATE_DISCONNECTED ON
)
FetchContent_MakeAvailable( FlatBuffers )

# If we dont want to build the extension then we can stop here
# This does break any other targets for this configuration
# so currently only useful for building flatc.
if( NOT BUILD_EXTENSION )
    return()
endif ()

# if we dont have a tag specified, try to match up our godot.exe version and the remote godot-cpp repo.
#if( GODOT_GIT_TAG STREQUAL "" )
#    include( godot-cpp-git-tag )
#endif()

FetchContent_Declare( godot-cpp
        GIT_REPOSITORY ${GODOTCPP_GIT_URL}
        GIT_TAG ${GODOTCPP_GIT_TAG}
        GIT_SHALLOW ON
        SOURCE_DIR "${PROJECT_SOURCE_DIR}/lib/godot-cpp"
)
FetchContent_MakeAvailable( godot-cpp )

add_subdirectory( src )

### separate CMakeLists for our gdextension sources.
foreach ( TARGET_TYPE ${GDE_TARGETS} )
    if( TARGET_TYPE STREQUAL "template_debug" )
        set( TARGET_ABBREV "_td" )
    elseif (TARGET_TYPE STREQUAL "template_release")
        set( TARGET_ABBREV "_tr" )
    elseif (TARGET_TYPE STREQUAL "editor")
        set( TARGET_ABBREV "_e" )
    endif ()

    set( LIBNAME "${GDE_NAME}${TARGET_ABBREV}" )

    add_library( ${LIBNAME} SHARED )

    target_sources( ${LIBNAME}
        PRIVATE
            ${SOURCES}
    )

    target_link_libraries( ${LIBNAME} PRIVATE godot-cpp::${TARGET_TYPE} FlatBuffers::FlatBuffers )

    ### Get useful properties of the library
    get_target_property( GODOT_PLATFORM godot-cpp::${TARGET_TYPE} GODOT_PLATFORM )
    get_target_property( GODOT_TARGET godot-cpp::${TARGET_TYPE} GODOT_TARGET )
    get_target_property( GODOT_ARCH godot-cpp::${TARGET_TYPE} GODOT_ARCH )

    set( DOUBLE "$<$<STREQUAL:${FLOAT_PRECISION},double>:.double>")

    set_target_properties( ${LIBNAME}
            PROPERTIES
            FOLDER "gdflatbuffers"
            #The generator expression here prevents a subdir from being created.
            RUNTIME_OUTPUT_DIRECTORY "$<1:${CMAKE_RUNTIME_OUTPUT_DIRECTORY}>"
            # godot.<platform>.<target>[.dev][.double].<arch>[.custom_suffix][.console].exe
            OUTPUT_NAME "${GDE_NAME}.${GODOT_PLATFORM}.${GODOT_TARGET}${DOUBLE}.${GODOT_ARCH}"
    )

endforeach ()

### Cmake options to expose
set( CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE BOOL "Generate compilation DB (`compile_commands.json`) for external tools")

# So that I can condifgure for the flatc compiler, and not the extension.
set( BUILD_EXTENSION ON CACHE STRING "build the extension" )

## Target options
set( GDE_NAME "gdflatbuffers" CACHE STRING "The name of the extension library" )
set( GDE_SUFFIX "" CACHE STRING "an additional suffix you can append to builds" )
set( GDE_OUTPUT_NAME "" CACHE STRING "A custom output name, resulting binary will be: GDE_NAME.{editor|template_{release|debug}}[.GDE_SUFFIX].dll" )

### Information regarding the godot executable
set( GODOT_EXECUTABLE "" CACHE FILEPATH "Path to the godot executable you are targeting" )
set( GODOT_PROJECT_PATH "${PROJECT_SOURCE_DIR}/project" CACHE PATH "Path to a demo project that can test the gdextension" )

### godot-cpp
set( GODOTCPP_GIT_URL "https://github.com/enetheru/godot-cpp.git" CACHE STRING "Location of the godot-cpp git respository" )
set( GODOTCPP_GIT_TAG "4.3-modernise" CACHE STRING "The git tag to use when pulling godot-cpp, will try to automatically detect based on godot.exe --version" )
set( GODOTCPP_DIR "${PROJECT_SOURCE_DIR}/lib/godot-cpp" CACHE PATH "Path to the directory containing the godot-cpp GDExtension library, if we're fetching then this is where it will go" )

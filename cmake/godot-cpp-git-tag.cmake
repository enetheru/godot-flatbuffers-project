function(godot_cpp_git_tag)
    message(STATUS "Using Git:  ${GIT_EXECUTABLE}" )
    message(STATUS "Git Repository: ${GODOTCPP_GIT_URL}" )

    execute_process(
            COMMAND ${GIT_EXECUTABLE} ls-remote --tags ${GODOTCPP_GIT_URL}
            OUTPUT_VARIABLE REMOTE_RAW
            COMMAND_ERROR_IS_FATAL ANY)

    string( REGEX MATCHALL "godot-[0-9]\.[0-9](\.[0-9])?-stable" REMOTE_TAGS ${REMOTE_RAW} )

    list(REVERSE REMOTE_TAGS )

    foreach ( TAG ${REMOTE_TAGS} )
        string( REGEX MATCH "godot-${GODOT_VERSION_MAJOR}.${GODOT_VERSION_MINOR}-stable" GODOTCPP_GIT_TAG ${TAG} )
        if( GODOTCPP_GIT_TAG )
            break()
        endif ()
    endforeach ()

    if (GODOTCPP_GIT_TAG )
        message( "Found Tag: ${GODOTCPP_GIT_TAG}" )
    else ()
        message( FATAL_ERROR
"Unable to find a match for godot version: ${GODOT_VERSION_MAJOR}.${GODOT_VERSION_MINOR}.${GODOT_VERSION_POINT}
Run: 'git ls-remote --tags ${GODOTCPP_GIT_URL}'
Add: '-DGODOTCPP_GIT_TAG=<git-tag>' to your cmake configuration")
    endif ()

    # Get the tag hash
    string( REGEX REPLACE "([a-z0-9]+).*$" "\\1" GODOT_GIT_HASH "${REMOTE_RAW}")
    message( "Tag Hash: ${GODOT_GIT_HASH}" )

    set( GODOTCPP_GIT_TAG ${GODOTCPP_GIT_TAG} PARENT_SCOPE)
    return( PROPAGATE GODOTCPP_GIT_TAG GODOT_GIT_HASH )

endfunction()

godot_cpp_git_tag()

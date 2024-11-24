function( godot_version )
    if( NOT GODOT_EXECUTABLE )
        return()
    endif ()
    # Lets get the version
    execute_process(COMMAND ${GODOT_EXECUTABLE} --version
            OUTPUT_VARIABLE GODOT_VERSION )
    if( GODOT_VERSION STREQUAL "" )
        message( FATAL_ERROR "Godot executable did not produce an understandable version string: ${GODOT_EXECUTABLE}" )
    endif ()
    string(STRIP ${GODOT_VERSION} GODOT_VERSION)

    string(REPLACE "." ";" GODOT_VERSION_LIST ${GODOT_VERSION})
    list(POP_FRONT GODOT_VERSION_LIST GODOT_VERSION_MAJOR)
    list(POP_FRONT GODOT_VERSION_LIST GODOT_VERSION_MINOR)
    list(POP_FRONT GODOT_VERSION_LIST GODOT_VERSION_POINT)

    return( PROPAGATE GODOT_VERSION GODOT_VERSION_MAJOR GODOT_VERSION_MINOR GODOT_VERSION_POINT )
endfunction()

if( GODOT_EXECUTABLE AND EXISTS GODOT_EXECUTABLE AND IS_EXECUTABLE GODOT_EXECUTABLE )
    godot_version()
else ()
    # Specify godot executable to pull version information from
    # Compiling godot from source appears to produce the following name:
    # godot.<platform>.<target>[.dev][.double].<arch>[.custom_suffix][.console].exe
    # so in my case its:
    #   godot.windows.editor.x86_64.exe
    #   godot.windows.editor.x86_64.console.exe
    # Godot find paths
    # TODO Find godot automatically if not specified.
    # - installed locally
    # - installed by steam
    list( APPEND GODOT_FIND_NAMES ${GODOT_EXECUTABLE_NAME} )
    list( APPEND GODOT_FIND_NAMES "godot.windows.opt.tools.64.exe" ) #steam exe name
    list( APPEND GODOT_FIND_PATHS "/Program Files/ (x86)/Steam/steamapps/common/Godot\ Engine") #steam exe path
    list( APPEND GODOT_FIND_PATHS "/git/godot/bin")

    # This does not run if CMAKE_EXECUTABLE is already set.
    if( GODOT_EXECUTABLE STREQUAL "" )
        unset( GODOT_EXECUTABLE CACHE )
    endif()

    find_program( GODOT_EXECUTABLE
            NAMES ${GODOT_FIND_NAMES}
            PATHS ${GODOT_FIND_PATHS} )

    godot_version()
endif ()

function( godot_version )
    set( GODOT_VERSION 4.5.0 )
    set( GODOT_VERSION_MAJOR 4 )
    set( GODOT_VERSION_MINOR 5 )
    set( GODOT_VERSION_POINT 0 )

    if( GODOT_EXECUTABLE-FOUND )
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
    endif ()

    return( PROPAGATE GODOT_VERSION GODOT_VERSION_MAJOR GODOT_VERSION_MINOR GODOT_VERSION_POINT )
endfunction()

if( GODOT_EXECUTABLE AND EXISTS GODOT_EXECUTABLE AND IS_EXECUTABLE GODOT_EXECUTABLE )
    set( GODOT_EXECUTABLE-FOUND 1 )
else ()
    # Generate list of all possible names
    # godot.<platform>.<target>[.dev][.double].<arch>[.custom_suffix][.console].exe
    foreach ( PLATFORM linux macos windows android ios web )
        foreach( TARGET template_debug template_release editor )
            foreach ( ARCH universal x86_32 x86_64 arm32 arm64 rv64 ppc32 ppc64 wasm32 )
                list( APPEND GODOT_FIND_NAMES "godot.${PLATFORM}.${TARGET}.${ARCH}.exe")
                # TODO Account for dev, double, and console
            endforeach ()
        endforeach ()
    endforeach ()

    # installed by steam
    list( APPEND GODOT_FIND_NAMES "godot.windows.opt.tools.64.exe" ) #steam exe name
    list( APPEND GODOT_FIND_PATHS "/Program Files/ (x86)/Steam/steamapps/common/Godot\ Engine") #steam exe path

    find_program( GODOT_EXECUTABLE
            NAMES ${GODOT_FIND_NAMES}
            PATHS ${GODOT_FIND_PATHS} )

    if( GODOT_EXECUTABLE AND EXISTS GODOT_EXECUTABLE AND IS_EXECUTABLE GODOT_EXECUTABLE )
        set( GODOT_EXECUTABLE-FOUND 1 )
    endif ()
endif ()

godot_version()
message( "Using Godot version: ${GODOT_VERSION}" )

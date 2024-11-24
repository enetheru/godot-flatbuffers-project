### Dump extension-api and gdextension-interface
function(godot_dump_api)
    # TODO --dump-extension-api-with-docs
    file(MAKE_DIRECTORY ${GODOT_GDEXTENSION_DIR})
    execute_process(
            COMMAND ${GODOT_EXECUTABLE} --headless --dump-gdextension-interface
            WORKING_DIRECTORY ${GODOT_GDEXTENSION_DIR}
            TIMEOUT 60
            COMMAND_ECHO STDOUT
            COMMAND_ERROR_IS_FATAL ANY
    )

    execute_process(
            COMMAND ${GODOT_EXECUTABLE} --headless --dump-extension-api
            WORKING_DIRECTORY ${GODOT_GDEXTENSION_DIR}
            TIMEOUT 60
            COMMAND_ECHO STDOUT
            COMMAND_ERROR_IS_FATAL ANY
    )
endfunction()

if( GODOT_EXECUTABLE )
    set( DUMP_FILES
            ${GODOT_GDEXTENSION_DIR}/extension_api.json
            ${GODOT_GDEXTENSION_DIR}/gdextension_interface.h
    )

    file(MAKE_DIRECTORY ${GODOT_GDEXTENSION_DIR})
    add_custom_command(OUTPUT ${DUMP_FILES}
            COMMAND ${GODOT_EXECUTABLE} --headless --dump-gdextension-interface
            COMMAND ${GODOT_EXECUTABLE} --headless --dump-extension-api
            MAIN_DEPENDENCY ${GODOT_EXECUTABLE}
            WORKING_DIRECTORY ${GODOT_GDEXTENSION_DIR}
    )
endif ()

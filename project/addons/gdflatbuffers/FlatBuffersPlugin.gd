@tool
class_name FlatBuffersPlugin extends EditorPlugin

const FlatBuffersHighlighter = preload('res://addons/gdflatbuffers/FlatBuffersHighlighter.gd')

const EDITOR_SETTINGS_BASE := &"plugin/FlatBuffers/"
const debug_verbosity := EDITOR_SETTINGS_BASE + &"fbs_debug_verbosity"
const flatc_path := EDITOR_SETTINGS_BASE + &"flatc_path"

var script_editor := EditorInterface.get_script_editor()
static var settings := EditorInterface.get_editor_settings()

var highlighter : EditorSyntaxHighlighter
var context_menus : Dictionary[EditorContextMenuPlugin.ContextMenuSlot,EditorContextMenuPlugin]

func _init() -> void:
	context_menus = {
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM: MyFileMenu.new(),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM_CREATE:MyFileCreateMenu.new(),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR:MyScriptTabMenu.new(),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR_CODE:MyCodeEditMenu.new(),
	}

func _get_plugin_name() -> String:
	return "flatbuffers"

func _get_plugin_icon() -> Texture2D:
	# You can use a custom icon:
	#return preload("res://addons/my_plugin/my_plugin_icon.svg")
	# Or use a built-in icon:
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")


func _enter_tree() -> void:
	change_editor_settings()

	# Syntax Highlighting for flatbuffer schema files
	highlighter = FlatBuffersHighlighter.new()
	script_editor.register_syntax_highlighter( highlighter )

	# Context menus
	for key in context_menus.keys():
		add_context_menu_plugin( key, context_menus[key] )


func _exit_tree() -> void:
	script_editor.unregister_syntax_highlighter( highlighter )
	for menu in context_menus.values():
		remove_context_menu_plugin( menu )


func change_editor_settings() -> void:
	# TODO make these project settings
	var settings : EditorSettings = EditorInterface.get_editor_settings()

	# Editor Settings
	# FIXME: When I loaded the project for the first time the below line failed, and the above line didnt solve it.
	if not settings.get( flatc_path ):
		settings.set( flatc_path, "")
		var property_info := {
			"name": flatc_path,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_GLOBAL_FILE,
			"hint_string": "flatc.exe" # This will the filter string in the file dialog
		}
		settings.add_property_info(property_info)

	if not settings.get( debug_verbosity ):
		settings.set(debug_verbosity, false )
		var property_info := {
			"name": debug_verbosity,
			"type": TYPE_INT,
		}
		settings.add_property_info(property_info)

#   ███████ ██       █████  ████████  ██████    ███████ ██   ██ ███████
#   ██      ██      ██   ██    ██    ██         ██       ██ ██  ██
#   █████   ██      ███████    ██    ██         █████     ███   █████
#   ██      ██      ██   ██    ██    ██         ██       ██ ██  ██
#   ██      ███████ ██   ██    ██     ██████ ██ ███████ ██   ██ ███████

static func flatc_generate( path : String ) -> Variant:
	# Make sure we have the flac compiler
	var flatc_path : String = settings.get( flatc_path )
	if flatc_path.is_empty():
		flatc_path = "res://addons/gdflatbuffers/bin/flatc.exe"

	flatc_path = flatc_path.replace('res://', './')

	if not FileAccess.file_exists(flatc_path):
		return {'retcode':ERR_FILE_BAD_PATH, 'output': ["Missing flatc compiler"]}

	# TODO make this an editor setting that can be added to.
	var include_paths : Array = ["res://addons/gdflatbuffers/"]
	for i in include_paths.size():
		include_paths[i] = include_paths[i].replace('res://', './')

	var source_path : String = path.replace('res://', './')
	if not FileAccess.file_exists(source_path):
		return {'retcode':ERR_FILE_BAD_PATH, 'output': ["Missing Schema File: %s" % source_path] }

	var output_path : String = source_path.get_base_dir()

	var args : PackedStringArray = []

	#-I PATH                Search for includes in the specified path.
	for include in include_paths: args.append_array(["-I", include])

	#--gdscript             Generate GDScript files for tables/structs
	args.append_array([ "--gdscript",  "-o", output_path, source_path, ])

	var result : Dictionary = {
		'flatc_path':flatc_path,
		'args':args,
	}
	var output : Array = []
	result['retcode'] = OS.execute( flatc_path, args, output, true )
	result['output'] = output

	#TODO Figure out a way to get the script in the editor to reload.
	#  the only reliable way I have found to refresh the script in the editor
	#  is to change the focus away from Godot and back again.

	# This line refreshes the filesystem dock.
	EditorInterface.get_resource_filesystem().scan()
	return result

static func print_results( result : Dictionary ):
	var output = result.get('output')
	result.erase('output')
	printerr( "flatc_generate result: ", JSON.stringify( result, '\t', false ) )
	for o in output: print( o )

#   ██████ ██████ ██     ██████    ███    ███ ██████ ███    ██ ██   ██
#   ██       ██   ██     ██        ████  ████ ██     ████   ██ ██   ██
#   ████     ██   ██     ████      ██ ████ ██ ████   ██ ██  ██ ██   ██
#   ██       ██   ██     ██        ██  ██  ██ ██     ██  ██ ██ ██   ██
#   ██     ██████ ██████ ██████    ██      ██ ██████ ██   ████  █████

#  NOTE A plugin instance can belong only to a single context menu slot.

# filesystem context menu
# EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM
class MyFileMenu extends EditorContextMenuPlugin:
	# _popup_menu() and option callback will be called with list of paths of the
	# currently selected files.
	func _popup_menu(paths):
		for path in paths:
			if path.get_extension() == 'fbs':
				add_context_menu_item("flatc --gdscript", call_flatc_on_paths )#, icon )
				return

	func call_flatc_on_paths( paths ) -> void:
		for path : String in paths:
			var abs_path : String = ProjectSettings.globalize_path( path )
			if path.get_extension() == 'fbs':
				var results : Dictionary = {'retcode':OK}
				results = FlatBuffersPlugin.flatc_generate( abs_path )
				if results.retcode: FlatBuffersPlugin.print_results( results )

# CONTEXT_SLOT_FILESYSTEM_CREATE
# The "Create..." submenu of FileSystem dock's context menu.
class MyFileCreateMenu extends EditorContextMenuPlugin:
	# _popup_menu() and option callback will be called with list of paths of the
	# currently selected files.
	func _popup_menu(paths):
		print( paths )
		add_context_menu_item("script_tab_context_menu_test", func(thing): print( thing ) )#, icon )

# CONTEXT_SLOT_SCRIPT_EDITOR
# Context menu of Script editor's script tabs.
class MyScriptTabMenu extends EditorContextMenuPlugin:
	# _popup_menu() will be called with the path to the currently edited script,
	# while option callback will receive reference to that script.
	func _popup_menu(paths):
		print( paths )
		add_context_menu_item("script_tab_context_menu_test", func(thing): print( thing ) )#, icon )

# CONTEXT_SLOT_SCRIPT_EDITOR_CODE
# Context menu of Script editor's code editor.
class MyCodeEditMenu extends EditorContextMenuPlugin:
	# _popup_menu() will be called with the path to the CodeEdit node.
	# The option callback will receive reference to that node.
	func _popup_menu(paths):
		print( paths )
		var code_edit = Engine.get_main_loop().root.get_node(paths[0]);
		add_context_menu_item("code_edit_context_menu_test", func(thing): print( thing ) )#, icon )

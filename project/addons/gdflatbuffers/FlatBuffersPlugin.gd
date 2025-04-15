@tool
class_name FlatBuffersPlugin extends EditorPlugin

const ICON_TINY_BW = preload('res://addons/gdflatbuffers/fpl_logo_tiny_bw.png')

var script_editor := EditorInterface.get_script_editor()

const fbsHighlighter = preload('res://addons/gdflatbuffers/FlatBuffersHighlighter.gd')
const Token = preload('res://addons/gdflatbuffers/scripts/token.gd')

var highlighter : EditorSyntaxHighlighter
var context_menus : Dictionary[EditorContextMenuPlugin.ContextMenuSlot,EditorContextMenuPlugin]

#   ███████ ███████ ████████ ████████ ██ ███    ██  ██████  ███████
#   ██      ██         ██       ██    ██ ████   ██ ██       ██
#   ███████ █████      ██       ██    ██ ██ ██  ██ ██   ███ ███████
#        ██ ██         ██       ██    ██ ██  ██ ██ ██    ██      ██
#   ███████ ███████    ██       ██    ██ ██   ████  ██████  ███████

# Editor Settings Things
var editor_settings_path : String = "plugin/FlatBuffers/"
var editor_settings_list = [
	"verbosity",
	# Compiler
	"compiler/flatc_exe",
	"compiler/include_paths",
	# Colours
	"syntac_highlighting/unknown_color",
	"syntac_highlighting/comment_color",
	"syntac_highlighting/keyword_color",
	"syntac_highlighting/type_color",
	"syntac_highlighting/string_color",
	"syntac_highlighting/punct_color",
	"syntac_highlighting/ident_color",
	"syntac_highlighting/scalar_color",
	"syntac_highlighting/meta_color",
	"syntac_highlighting/critical_color",
	"syntac_highlighting/error_color",
	"syntac_highlighting/warning_color",
	"syntac_highlighting/debug_color",
	"syntac_highlighting/notice_color",
	"syntac_highlighting/trace_color",
]
# Settings
var print_syntax_errors : bool = true

@export_global_file var flatc_exe : String = "addons/gdflatbuffers/bin/flatc.exe"

enum LogLevel {
	SILENT = 0,
	CRITICAL = 1,
	ERROR = 2,
	WARNING = 3,
	NOTICE = 4,
	DEBUG = 5,
	TRACE = 6,
}

#@export_enum("SILENT:0", "CRITICAL:1", "ERROR:2", "WARNING:3", "NOTICE:4", "DEBUG:5", "TRACE:6")
@export
var verbosity : LogLevel = 0

## Does this have a description?
@export_global_dir
var include_paths: Array[String]

# Colours
# Tokens
var unknown_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/text_color")
var comment_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_color")
var keyword_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/keyword_color")
var type_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/base_type_color")
var string_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/string_color")
var punct_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/text_color")
var ident_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/symbol_color")
var scalar_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/number_color")
var meta_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/text_color")
# log levels
var critical_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_markers/critical_color")
var error_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_markers/critical_color")
var warning_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_markers/warning_color")
var notice_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/text_color")
var debug_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_color")
var trace_color : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_color")


# Dictionary of colours
var colours : Dictionary[int, Color]


#   ███████ ██    ██ ███    ██  ██████ ███████
#   ██      ██    ██ ████   ██ ██      ██
#   █████   ██    ██ ██ ██  ██ ██      ███████
#   ██      ██    ██ ██  ██ ██ ██           ██
#   ██       ██████  ██   ████  ██████ ███████

func print_bright( value ):
	print_rich("%s.[color=yellow][b]%s[/b][/color]" % [name, value] )

func _get_plugin_name() -> String:
	print_bright("._get_plugin_name()")
	return "flatbuffers"


func _get_plugin_icon() -> Texture2D:
	print_bright("._get_plugin_icon()")
	return preload('res://addons/gdflatbuffers/fpl_logo_tiny_bw.png')


#           ██ ███    ██ ██ ████████
#           ██ ████   ██ ██    ██
#           ██ ██ ██  ██ ██    ██
#           ██ ██  ██ ██ ██    ██
#   ███████ ██ ██   ████ ██    ██

func _init() -> void:
	name = "FlatBuffersPlugin"
	init_settings()
	colours_changed()
	context_menus = {
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM: MyFileMenu.new(self),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM_CREATE:MyFileCreateMenu.new(),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR:MyScriptTabMenu.new(),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR_CODE:MyCodeEditMenu.new(),
	}

func get_property_info( property_name : StringName ) -> Dictionary:
	var prop_list := get_property_list()
	var prop_idx = prop_list.find_custom(
		func(info): return info.name == property_name )
	if prop_idx == -1: return {}
	return prop_list[prop_idx]

func init_settings():
	print_bright(".init_settings()")
	var editor_settings : EditorSettings = EditorInterface.get_editor_settings()
	var project_settings := ProjectSettings

	var prop_list := get_property_list()

	# Update editor Properties
	for item : String in editor_settings_list:
		var prop_info = get_property_info( item.get_file() )
		if not prop_info: continue

		# copy the prop_info and get the initial value
		var setting_info : Dictionary = prop_info.duplicate()
		var initial_value = get(prop_info.name)

		# update the name to include the path
		setting_info.name = editor_settings_path + item

		# update the settings.
		if not editor_settings.has_setting(setting_info.name):
			editor_settings.set_setting( setting_info.name, initial_value )
			editor_settings.mark_setting_changed(setting_info.name)
		editor_settings.set_initial_value(setting_info.name, initial_value, false)
		editor_settings.add_property_info(setting_info)

	ProjectSettings.settings_changed.connect( settings_changed.bind("project") )
	editor_settings.settings_changed.connect( settings_changed.bind("editor") )

func settings_changed( source : String ):
	var settings
	match source:
		"editor": settings = EditorInterface.get_editor_settings()
		"project": settings = ProjectSettings; return # FIXME Unimplemented
		_: push_error("invalid settings source"); return

	for prop_name : String in get("%s_settings_list" % source ):
		var setting_path = get("%s_settings_path" % source)
		if not setting_path:
			push_error("missing %s_settings_path" % source)
			return

		var setting_name : StringName = setting_path + prop_name
		if not settings.has_setting(setting_name): continue
		set( prop_name.get_file(), settings.get_setting(setting_name) )

	# Update colours after updating settings.
	colours_changed()

func colours_changed():
	colours = {
		LogLevel.CRITICAL : critical_color,
		LogLevel.ERROR : error_color,
		LogLevel.WARNING : warning_color,
		LogLevel.NOTICE : notice_color,
		LogLevel.DEBUG : debug_color,
		LogLevel.TRACE : trace_color,
		# Token.Type starts at 100
		Token.Type.NULL : unknown_color,
		Token.Type.COMMENT : comment_color,
		Token.Type.KEYWORD : keyword_color,
		Token.Type.TYPE : type_color,
		Token.Type.STRING : string_color,
		Token.Type.PUNCT : punct_color,
		Token.Type.IDENT : ident_color,
		Token.Type.SCALAR : scalar_color,
		Token.Type.META : meta_color,
		Token.Type.UNKNOWN : unknown_color,
	}


#   ███████ ███    ██  █████  ██████  ██      ███████
#   ██      ████   ██ ██   ██ ██   ██ ██      ██
#   █████   ██ ██  ██ ███████ ██████  ██      █████
#   ██      ██  ██ ██ ██   ██ ██   ██ ██      ██
#   ███████ ██   ████ ██   ██ ██████  ███████ ███████

func _enable_plugin() -> void:
	print_bright("._enable_plugin()")

func _disable_plugin() -> void:
	print_bright("._disable_plugin()")
	pass

#   ████████ ██████  ███████ ███████
#      ██    ██   ██ ██      ██
#      ██    ██████  █████   █████
#      ██    ██   ██ ██      ██
#      ██    ██   ██ ███████ ███████

func _enter_tree() -> void:
	print_bright("._enter_tree()")
	# Syntax Highlighting for flatbuffer schema files
	highlighter = fbsHighlighter.new(self)
	script_editor.register_syntax_highlighter( highlighter )

	# Context menus
	for key in context_menus.keys():
		add_context_menu_plugin( key, context_menus[key] )


func _exit_tree() -> void:
	print_bright("._exit_tree()")
	script_editor.unregister_syntax_highlighter( highlighter )
	for menu in context_menus.values():
		remove_context_menu_plugin( menu )


#   ███████ ██       █████  ████████  ██████    ███████ ██   ██ ███████
#   ██      ██      ██   ██    ██    ██         ██       ██ ██  ██
#   █████   ██      ███████    ██    ██         █████     ███   █████
#   ██      ██      ██   ██    ██    ██         ██       ██ ██  ██
#   ██      ███████ ██   ██    ██     ██████ ██ ███████ ██   ██ ███████

func print_flatc_help():
	print("flatc_help")

func flatc_generate( schema_path : String ) -> Variant:
	# Make sure we have the flac compiler
	if not FileAccess.file_exists(flatc_exe):
		var msg = "flatc compiler is not found at '%s'" % flatc_exe
		push_error(msg)
		return {'retcode':ERR_FILE_BAD_PATH, 'output': [msg]}

	if not FileAccess.file_exists(schema_path):
		var msg = "Missing Schema File: '%s'" % schema_path
		push_error(msg)
		return {'retcode':ERR_FILE_BAD_PATH, 'output': [msg] }

	# --gdscript             Generate GDScript files for tables/structs
	var args : PackedStringArray = ["--gdscript"]

	# -I <path>                Search for includes in the specified path.
	#var dir_access := DirAccess.open("res://")
	for ipath in include_paths + ["res://addons/gdflatbuffers/"]:
		if not DirAccess.dir_exists_absolute(ipath):
			push_warning("invalid include path: '%s'" % ipath)
			continue
		args.append_array(["-I", ipath.replace('res://', './')])

	# -o <path>
	args.append_array([ "-o", schema_path.get_base_dir()])

	# the schema path
	args.append( schema_path )

	var result : Dictionary = {
		'flatc_path':flatc_exe,
		'args':args,
	}
	var output : Array = []
	result['retcode'] = OS.execute( flatc_exe, args, output, true, true )
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

#   ██████   ██████         ███    ███ ███████ ███    ██ ██    ██ ███████
#   ██   ██ ██              ████  ████ ██      ████   ██ ██    ██ ██
#   ██████  ██              ██ ████ ██ █████   ██ ██  ██ ██    ██ ███████
#   ██   ██ ██              ██  ██  ██ ██      ██  ██ ██ ██    ██      ██
#   ██   ██  ██████ ███████ ██      ██ ███████ ██   ████  ██████  ███████

#  NOTE A plugin instance can belong only to a single context menu slot.

# filesystem context menu
# EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM
class MyFileMenu extends EditorContextMenuPlugin:
	var _plugin : FlatBuffersPlugin

	func _init( plugin : FlatBuffersPlugin ) -> void:
		_plugin = plugin

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
				results = _plugin.flatc_generate( abs_path )
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

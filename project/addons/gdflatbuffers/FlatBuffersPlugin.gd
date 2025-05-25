@tool
class_name FlatBuffersPlugin extends EditorPlugin

# Reference to self so we can do things since we are already instantiated.
static var _prime : FlatBuffersPlugin

## A variable to help me turn on and off debug features and tests.
var debug : bool = true

# Supporting Assets
const ICON_BW_TINY = preload('res://addons/gdflatbuffers/fpl_logo_tiny_bw.png')

# Supporting Scripts
const FlatbufferSchemaHighlighter = preload('res://addons/gdflatbuffers/FlatBuffersHighlighter.gd')
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
	"syntax_colors/unknown_color",
	"syntax_colors/comment_color",
	"syntax_colors/keyword_color",
	"syntax_colors/type_color",
	"syntax_colors/string_color",
	"syntax_colors/punct_color",
	"syntax_colors/ident_color",
	"syntax_colors/scalar_color",
	"syntax_colors/meta_color",
	# Notice Colours
	"notice_colors/critical_color",
	"notice_colors/error_color",
	"notice_colors/warning_color",
	"notice_colors/debug_color",
	"notice_colors/notice_color",
	"notice_colors/trace_color",
	# Highlights
	"highlighting/highlight_error",
	"highlighting/highlight_warning",
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

func print_log(level : LogLevel, message : String ) -> bool:
	if verbosity < level: return false
	var colour = colours[level].to_html()
	var padding = "".lpad(get_stack().size()-1, '\t') if level == LogLevel.TRACE else ""
	print_rich( padding + "[color=%s]%s[/color]" % [colour, message] )
	return true

func log_level( level : LogLevel ) -> bool:
	return verbosity >= level

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
# Highlighting
var highlight_error : bool = true
var highlight_warning : bool = true
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

func _get_plugin_name() -> String:
	print_log( LogLevel.TRACE, "%s._get_plugin_name()" % name )
	return "flatbuffers"


func _get_plugin_icon() -> Texture2D:
	print_log( LogLevel.TRACE, "%s._get_plugin_icon()" % name )
	return ICON_BW_TINY

func get_property_info( property_name : StringName ) -> Dictionary:
	var prop_list := get_property_list()
	var prop_idx = prop_list.find_custom(
		func(info): return info.name == property_name )
	if prop_idx == -1: return {}
	return prop_list[prop_idx]

#           ██ ███    ██ ██ ████████
#           ██ ████   ██ ██    ██
#           ██ ██ ██  ██ ██    ██
#           ██ ██  ██ ██ ██    ██
#   ███████ ██ ██   ████ ██    ██

func _init() -> void:
	name = "FlatBuffersPlugin"
	if not _prime: _prime = self
	#FIXME update editor property docks/filesystem/textfile_extensions to include fbs

	init_settings()
	context_menus = {
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM: MyFileMenu.new(self),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM_CREATE:MyFileCreateMenu.new(),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR:MyScriptTabMenu.new(self),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR_CODE:MyCodeEditMenu.new(),
	}
	print_log( LogLevel.TRACE, "%s._init() - Completed" % name )

func init_settings():
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
			#editor_settings.mark_setting_changed(setting_info.name)
		editor_settings.set_initial_value(setting_info.name, initial_value, false)
		editor_settings.add_property_info(setting_info)

	ProjectSettings.settings_changed.connect( settings_changed.bind("project") )
	editor_settings.settings_changed.connect( settings_changed.bind("editor") )
	settings_changed("editor")


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
		Token.Type.EOL : unknown_color,
		Token.Type.EOF : unknown_color,
	}


#   ███████ ███    ██  █████  ██████  ██      ███████
#   ██      ████   ██ ██   ██ ██   ██ ██      ██
#   █████   ██ ██  ██ ███████ ██████  ██      █████
#   ██      ██  ██ ██ ██   ██ ██   ██ ██      ██
#   ███████ ██   ████ ██   ██ ██████  ███████ ███████

func _enable_plugin() -> void:
	print_log( LogLevel.TRACE, "%s._enable_plugin()" % name )

func _disable_plugin() -> void:
	print_log( LogLevel.TRACE, "%s._disable_plugin()" % name )

#   ████████ ██████  ███████ ███████
#      ██    ██   ██ ██      ██
#      ██    ██████  █████   █████
#      ██    ██   ██ ██      ██
#      ██    ██   ██ ███████ ███████

func _enter_tree() -> void:
	print_log( LogLevel.TRACE, "%s._enter_tree()" % name )

	# Syntax Highlighting for flatbuffer schema files
	highlighter = FlatbufferSchemaHighlighter.new(self)
	EditorInterface.get_script_editor().register_syntax_highlighter( highlighter )

	# Context menus
	for key in context_menus.keys():
		add_context_menu_plugin( key, context_menus[key] )


func _exit_tree() -> void:
	print_log( LogLevel.TRACE, "%s._exit_tree()" % name )
	EditorInterface.get_script_editor().unregister_syntax_highlighter( highlighter )
	for menu in context_menus.values():
		remove_context_menu_plugin( menu )


#   ███████ ██       █████  ████████  ██████    ███████ ██   ██ ███████
#   ██      ██      ██   ██    ██    ██         ██       ██ ██  ██
#   █████   ██      ███████    ██    ██         █████     ███   █████
#   ██      ██      ██   ██    ██    ██         ██       ██ ██  ██
#   ██      ███████ ██   ██    ██     ██████ ██ ███████ ██   ██ ███████

func flatc_multi( paths : Array, args : Array ) -> Array:
	var results : Array
	for path : String in paths:
		var abs_path : String = ProjectSettings.globalize_path( path )
		if path.get_extension() == 'fbs':
			results.append( flatc_generate( abs_path, args ) )
	return results


func flatc_generate( schema_path : String, args : Array ) -> Variant:
	# Make sure we have the flac compiler
	if not FileAccess.file_exists(flatc_exe):
		var msg = "flatc compiler is not found at '%s'" % flatc_exe
		push_error(msg)
		return {'retcode':ERR_FILE_BAD_PATH, 'output': [msg]}

	if not FileAccess.file_exists(schema_path):
		var msg = "Missing Schema File: '%s'" % schema_path
		push_error(msg)
		return {'retcode':ERR_FILE_BAD_PATH, 'output': [msg] }

	# -I <path>                Search for includes in the specified path.
	#var dir_access := DirAccess.open("res://")
	for ipath in include_paths + ["res://addons/gdflatbuffers/"]:
		if not DirAccess.dir_exists_absolute(ipath):
			push_warning("invalid include path: '%s'" % ipath)
			continue
		args.append_array(["-I", ipath.replace('res://', './')])

	# -o <path>
	args.append_array([ "-o", schema_path.get_base_dir().replace('res://', './')])

	# the schema path
	args.append( schema_path.replace('res://', './') )

	var output : Array = []
	var retcode = OS.execute( flatc_exe, args, output, true )
	var log : Array[String]
	for o : String in output:
		log.append_array( o.split("\r") )

	#print( "flatc_generate result: ", JSON.stringify( result, '\t', false ) )
	print( "Compiling:    %s" % schema_path )
	print( "Using:        %s" % flatc_exe )
	print( "With Args:    %s" % " ".join( args ) )
	print( "Return Code: '%d'" % retcode )
	if retcode: print_rich( "[color=red][b]%s[/b][/color]" % "".join(log) )
	else: print( "".join(log) )

	#TODO Figure out a way to get the script in the editor to reload.
	#  the only reliable way I have found to refresh the script in the editor
	#  is to change the focus away from Godot and back again.

	# This line refreshes the filesystem dock.
	if not retcode: EditorInterface.get_resource_filesystem().scan()
	return {
		'flatc_path':flatc_exe,
		'args':args,
		'retcode':retcode,
		'output':log
	}

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
				add_context_menu_item("flatc --gdscript", _plugin.flatc_multi.bind(['--gdscript']), ICON_BW_TINY  )
				return


# CONTEXT_SLOT_FILESYSTEM_CREATE
# The "Create..." submenu of FileSystem dock's context menu.
class MyFileCreateMenu extends EditorContextMenuPlugin:
	# _popup_menu() and option callback will be called with list of paths of the
	# currently selected files.
	func _popup_menu(paths):
		add_context_menu_item("script_tab_context_menu_test", func(thing): print( thing ), ICON_BW_TINY )

# CONTEXT_SLOT_SCRIPT_EDITOR
# Context menu of Script editor's script tabs.
class MyScriptTabMenu extends EditorContextMenuPlugin:
	var _plugin : FlatBuffersPlugin

	func _init( plugin : FlatBuffersPlugin ) -> void:
		_plugin = plugin

	# _popup_menu() will be called with the path to the currently edited script,
	# while option callback will receive reference to that script.
	func _popup_menu(paths : PackedStringArray):
		if paths[0].get_extension() == 'fbs':
			add_context_menu_item("flatc --gdscript", call_flatc_on_path.bind( paths[0], ['--gdscript'] ), ICON_BW_TINY )
			add_context_menu_item("flatc --cpp", call_flatc_on_path.bind( paths[0], ['--cpp'] ), ICON_BW_TINY )
			add_context_menu_item("flatc --help", call_flatc_on_path.bind( paths[0], ['--help'] ), ICON_BW_TINY )
			add_context_menu_item("flatc --version", call_flatc_on_path.bind( paths[0], ['--version'] ), ICON_BW_TINY )
			return

	func call_flatc_on_path( script, path, args : Array ) -> void:
		_plugin.flatc_generate( path, args )


# CONTEXT_SLOT_SCRIPT_EDITOR_CODE
# Context menu of Script editor's code editor.
class MyCodeEditMenu extends EditorContextMenuPlugin:
	# _popup_menu() will be called with the path to the CodeEdit node.
	# The option callback will receive reference to that node.
	func _popup_menu(paths):
		print( paths )
		var code_edit = Engine.get_main_loop().root.get_node(paths[0]);
		add_context_menu_item("code_edit_context_menu_test", func(thing): print( thing ), ICON_BW_TINY )

#   ██████  ██████   █████  ███    ██ ███████ ██
#   ██   ██ ██   ██ ██   ██ ████   ██ ██      ██
#   ██████  ██████  ███████ ██ ██  ██ █████   ██
#   ██   ██ ██      ██   ██ ██  ██ ██ ██      ██
#   ██████  ██      ██   ██ ██   ████ ███████ ███████

const BPANEL = preload('res://bpanel/bpanel.tscn')
var bpanel_enabled : bool = false
var bpanel_control : Control
var bpanel_button : Button

func enable_bottom_panel():
	if bpanel_enabled: return
	print_rich( "\n[b]== GDFlatbuffer Bottom Panel Enable ==[/b]\n" )
	bpanel_control = BPANEL.instantiate()
	bpanel_button = add_control_to_bottom_panel(bpanel_control, bpanel_control.name)
	bpanel_button.name = bpanel_control.name
	bpanel_enabled = true


func disable_bottom_panel():
	if not bpanel_enabled: return
	print_rich( "\n[b]== GDFlatbuffer Bottom Panel Disable ==[/b]\n" )
	remove_control_from_bottom_panel(bpanel_control)
	bpanel_control.queue_free()
	bpanel_enabled = false


func bpanel_reload():
	call_deferred( "disable_bottom_panel" )
	call_deferred( "enable_bottom_panel" )

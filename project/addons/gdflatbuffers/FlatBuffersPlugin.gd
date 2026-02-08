@tool
class_name FlatBuffersPlugin
extends EditorPlugin

#           ████ ███    ███ ██████   ██████  ██████  ████████ ███████          #
#            ██  ████  ████ ██   ██ ██    ██ ██   ██    ██    ██               #
#            ██  ██ ████ ██ ██████  ██    ██ ██████     ██    ███████          #
#            ██  ██  ██  ██ ██      ██    ██ ██   ██    ██         ██          #
#           ████ ██      ██ ██       ██████  ██   ██    ██    ███████          #
func                        _________IMPORTS_________              ()->void:pass

const SettingsHelper = preload('uid://bqe6tk0yrwq8u')
var settings_mgr : SettingsHelper

# Supporting Scripts
const FlatbufferSchemaHighlighter = preload('FlatBuffersHighlighter.gd')
const Token = preload('scripts/token.gd')

# Supporting Assets
const ICON_BW_TINY = preload('fpl_logo_tiny_bw.png')


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

# Reference to self so we can do things since we are already instantiated.
static var _prime : FlatBuffersPlugin

var highlighter : EditorSyntaxHighlighter
var context_menus : Dictionary[EditorContextMenuPlugin.ContextMenuSlot,EditorContextMenuPlugin]

## A variable to help me turn on and off debug features and tests.
@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_INTERNAL)
var debug : bool = true


# │  __ _      _
# │ / _| |__ _| |_ __   _____ _____
# │|  _| / _` |  _/ _|_/ -_) \ / -_)
# │|_| |_\__,_|\__\__(_)___/_\_\___|
# ╰───────────────────────────────────
@export_custom( PROPERTY_HINT_GLOBAL_FILE, "*.exe",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var flatc_exe : String = "addons/gdflatbuffers/bin/flatc.exe"

@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var flatc_generate_debug : bool = false

@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var flatc_generate_pack_unpack : bool = false

## Include paths to use for flatc generation
@export_custom( PROPERTY_HINT_TYPE_STRING, "4/16:", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var flatc_include_paths: Array[String]

# │ ___    _ _ _           _
# │| __|__| (_) |_ ___ _ _| |   ___  __ _
# │| _|/ _` | |  _/ _ \ '_| |__/ _ \/ _` |
# │|___\__,_|_|\__\___/_| |____\___/\__, |
# ╰─────────────────────────────────|___/──
enum LogLevel {
	SILENT = 0,
	CRITICAL = 1,
	ERROR = 2,
	WARNING = 3,
	NOTICE = 4,
	DEBUG = 5,
	TRACE = 6,
}

@export_custom( PROPERTY_HINT_ENUM,
	"SILENT:0,CRITICAL:1,ERROR:2,WARNING:3,NOTICE:4,DEBUG:5,TRACE:6",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var editorlog_verbosity : LogLevel = 0

# │ _  _ _      _   _   _ _      _   _
# │| || (_)__ _| |_| |_| (_)__ _| |_| |_
# │| __ | / _` | ' \  _| | / _` | ' \  _|
# │|_||_|_\__, |_||_\__|_|_\__, |_||_\__|
# ╰───────|___/────────────|___/──────────
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var highlight_error : bool = true
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var highlight_warning : bool = true

# │  ___     _
# │ / __|___| |___ _  _ _ _ ___
# │| (__/ _ \ / _ \ || | '_(_-<
# │ \___\___/_\___/\_,_|_| /__/
# ╰──────────────────────────────
# Tokens
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_syntax_unknown : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/text_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_syntax_comment : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_syntax_keyword : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/keyword_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_syntax_type : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/base_type_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_syntax_string : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/string_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_syntax_punct : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/text_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_syntax_ident : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/symbol_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_syntax_scalar : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/number_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_syntax_meta : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/text_color")

# log levels
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_notice_critical : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_markers/critical_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_notice_error : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_markers/critical_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_notice_warning : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_markers/warning_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_notice_notice : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/text_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_notice_debug : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_color")
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var color_notice_trace : Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/comment_color")


# Dictionary of colours
var colours : Dictionary[int, Color]


#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_settings_changed( setting_name : StringName, value : Variant ) -> void:
	if setting_name.begins_with("color"):
		colours_changed()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init() -> void:
	name = "FlatBuffersPlugin"
	if not _prime: _prime = self
	#FIXME update editor property docks/filesystem/textfile_extensions to include fbs

	settings_mgr = SettingsHelper.new(self, "plugin/gdflatbuffers")
	settings_mgr.settings_changed.connect( _on_settings_changed )
	colours_changed()

	context_menus = {
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM: MyFileMenu.new(),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM_CREATE:MyFileCreateMenu.new(),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR:MyScriptTabMenu.new(),
		EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR_CODE:MyCodeEditMenu.new(),
	}
	print_log( LogLevel.TRACE, "%s._init() - Completed" % name )


func _enable_plugin() -> void:
	print_log( LogLevel.TRACE, "%s._enable_plugin()" % name )


func _disable_plugin() -> void:
	print_log( LogLevel.TRACE, "%s._disable_plugin()" % name )


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


func _get_plugin_name() -> String:
	print_log( LogLevel.TRACE, "%s._get_plugin_name()" % name )
	return "flatbuffers"


func _get_plugin_icon() -> Texture2D:
	print_log( LogLevel.TRACE, "%s._get_plugin_icon()" % name )
	return ICON_BW_TINY


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

func print_log(level : LogLevel, message : String ) -> bool:
	if editorlog_verbosity < level: return false
	var colour = colours[level].to_html()
	var padding = "".lpad(get_stack().size()-1, '\t') if level == LogLevel.TRACE else ""
	print_rich( padding + "[color=%s]%s[/color]" % [colour, message] )
	return true


func log_level( level : LogLevel ) -> bool:
	return editorlog_verbosity >= level


func colours_changed():
	colours = {
		LogLevel.CRITICAL : color_notice_critical,
		LogLevel.ERROR : color_notice_error,
		LogLevel.WARNING : color_notice_warning,
		LogLevel.NOTICE : color_notice_notice,
		LogLevel.DEBUG : color_notice_debug,
		LogLevel.TRACE : color_notice_trace,
		# Token.Type starts at color_10
		Token.Type.NULL : color_syntax_unknown,
		Token.Type.COMMENT : color_syntax_comment,
		Token.Type.KEYWORD : color_syntax_keyword,
		Token.Type.TYPE : color_syntax_type,
		Token.Type.STRING : color_syntax_string,
		Token.Type.PUNCT : color_syntax_punct,
		Token.Type.IDENT : color_syntax_ident,
		Token.Type.SCALAR : color_syntax_scalar,
		Token.Type.META : color_syntax_meta,
		Token.Type.UNKNOWN : color_syntax_unknown,
		Token.Type.EOL : color_syntax_unknown,
		Token.Type.EOF : color_syntax_unknown,
	}


#     ███████ ██       █████  ████████  ██████    ███████ ██   ██ ███████      #
#     ██      ██      ██   ██    ██    ██         ██       ██ ██  ██           #
#     █████   ██      ███████    ██    ██         █████     ███   █████        #
#     ██      ██      ██   ██    ██    ██         ██       ██ ██  ██           #
#     ██      ███████ ██   ██    ██     ██████ ██ ███████ ██   ██ ███████      #
func                        ________FLATC_EXE________              ()->void:pass

func flatc_multi( paths : Array, args : Array ) -> Array:
	print_log( LogLevel.TRACE, "%s.flatc_multi(%s, %s)" % [name, paths, args] )
	var results : Array
	for path : String in paths:
		if path.get_extension() == 'fbs':
			results.append( flatc_generate( path, args ) )
	return results


func flatc_generate( schema_path : String, args : Array ) -> Dictionary:
	print_log( LogLevel.TRACE, "%s.flatc_generate(%s, %s)" % [name, schema_path, args] )
	# Make sure we have the flac compiler
	if not FileAccess.file_exists(flatc_exe):
		var msg = "flatc compiler is not found at '%s'" % flatc_exe
		push_error(msg)
		return {'retcode':ERR_FILE_BAD_PATH, 'output': [msg]}

	if not FileAccess.file_exists(schema_path):
		var msg = "Missing Schema File: '%s'" % schema_path
		push_error(msg)
		return {'retcode':ERR_FILE_BAD_PATH, 'output': [msg] }

	# flatc_generate_debug
	if flatc_generate_debug:
		args.append("--gdscript-debug")
	if flatc_generate_pack_unpack:
		args.append("--gen-object-api")
	# -I <path>                Search for includes in the specified path.
	#var dir_access := DirAccess.open("res://")
	for ipath in flatc_include_paths + ["res://addons/gdflatbuffers/"]:
		if not DirAccess.dir_exists_absolute(ipath):
			push_warning("invalid include path: '%s'" % ipath)
			continue
		args.append_array(["-I", ipath.replace('res://', './')])

	# -o <path>
	args.append_array([ "-o", schema_path.get_base_dir().replace('res://', './')])

	# the schema path
	args.append( schema_path.replace('res://', './') )

	var report : Dictionary = {
		'schema': schema_path,
		'flatc_path':flatc_exe,
		'args':args,
	}

	if debug or editorlog_verbosity >= LogLevel.NOTICE:
		print( JSON.stringify(report, "  ", false) )

	var output : Array = []
	var retcode = OS.execute( flatc_exe, args, output, true )

	report['retcode'] = retcode
	report['output'] = '\n'.join(output).split('\n', false)

	if debug or editorlog_verbosity >= LogLevel.NOTICE:
		print( JSON.stringify({
			'retcode': retcode,
			'output': '\n'.join(output).split('\n', false),
		}, "  ", false) )

	if retcode:
		print_rich('\n'.join(["[color=salmon][b]",
		"ERROR: flatc failed with code '%s'[/b]" % [retcode],
		"\toutput: " + '\n'.join(output) + "[/color]"
		]))

	#TODO Figure out a way to get the script in the editor to reload.
	#  the only reliable way I have found to refresh the script in the editor
	#  is to change the focus away from Godot and back again.

	# This line refreshes the filesystem dock.
	if not retcode: EditorInterface.get_resource_filesystem().scan()
	return report


# ██████  ██  ██████  ██   ██ ████████      ██████ ██      ██  ██████ ██   ██  #
# ██   ██ ██ ██       ██   ██    ██        ██      ██      ██ ██      ██  ██   #
# ██████  ██ ██   ███ ███████    ██        ██      ██      ██ ██      █████    #
# ██   ██ ██ ██    ██ ██   ██    ██        ██      ██      ██ ██      ██  ██   #
# ██   ██ ██  ██████  ██   ██    ██         ██████ ███████ ██  ██████ ██   ██  #
func                        _______RIGHT_CLICK_______              ()->void:pass

#  NOTE A plugin instance can belong only to a single context menu slot.

# filesystem context menu
# EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM
class MyFileMenu extends EditorContextMenuPlugin:
	# _popup_menu() and option callback will be called with list of paths of the
	# currently selected files.
	func _popup_menu(paths):
		var fbp := FlatBuffersPlugin._prime
		for path in paths:
			if path.get_extension() == 'fbs':
				add_context_menu_item("flatc --gdscript", fbp.flatc_multi.bind(['--gdscript']), ICON_BW_TINY  )
				return


# CONTEXT_SLOT_FILESYSTEM_CREATE
# The "Create..." submenu of FileSystem dock's context menu.
class MyFileCreateMenu extends EditorContextMenuPlugin:
	# _popup_menu() and option callback will be called with list of paths of the
	# currently selected files.
	# TODO, use this menu to enable generating a flatbuffer schema by loading
	# and analysing a gdscript class for exported values.
	func _popup_menu(paths):
		var fbp := FlatBuffersPlugin._prime
		if fbp.debug:
			add_context_menu_item("create_flatbuffer_schema_from_object", func(thing): print( thing ), ICON_BW_TINY )

# CONTEXT_SLOT_SCRIPT_EDITOR
# Context menu of Script editor's script tabs.
class MyScriptTabMenu extends EditorContextMenuPlugin:
	# _popup_menu() will be called with the path to the currently edited script,
	# while option callback will receive reference to that script.
	func _popup_menu(paths : PackedStringArray):
		var fbp := FlatBuffersPlugin._prime
		if paths[0].get_extension() == 'fbs':
			add_context_menu_item("flatc --gdscript", call_flatc_on_path.bind(
					paths[0], ['--gdscript'] ), ICON_BW_TINY )
			if fbp.debug:
				add_context_menu_item("flatc --cpp", call_flatc_on_path.bind(
						paths[0], ['--cpp'] ), ICON_BW_TINY )
				add_context_menu_item("flatc --help", call_flatc_on_path.bind(
						paths[0], ['--help'] ), ICON_BW_TINY )
				add_context_menu_item("flatc --version", call_flatc_on_path.bind(
						paths[0], ['--version'] ), ICON_BW_TINY )

	func call_flatc_on_path( _ignore, path : String, args : Array ) -> void:
		var fbp := FlatBuffersPlugin._prime
		fbp.flatc_generate( path, args )


# CONTEXT_SLOT_SCRIPT_EDITOR_CODE
# Context menu of Script editor's code editor.
class MyCodeEditMenu extends EditorContextMenuPlugin:
	# _popup_menu() will be called with the path to the CodeEdit node.
	# The option callback will receive reference to that node.
	func _popup_menu( paths : PackedStringArray ):
		var fbp := FlatBuffersPlugin._prime
		if not fbp.debug: return
		print("paths.size: ", paths.size() )
		print("paths:\n\t", '\n\t'.join(paths) )
		var code_edit : CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
		print("selected_text: '%s'" % code_edit.get_selected_text() )
		add_context_menu_item("flatbuffers testing", func(thing): print( thing ), ICON_BW_TINY )

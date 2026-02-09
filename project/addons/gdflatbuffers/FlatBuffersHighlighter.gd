@tool
extends EditorSyntaxHighlighter

# │ ___ _      _   ___       __  __         _  _ _      _    _ _      _   _
# │| __| |__ _| |_| _ )_  _ / _|/ _|___ _ _| || (_)__ _| |_ | (_)__ _| |_| |_ ___ _ _
# │| _|| / _` |  _| _ \ || |  _|  _/ -_) '_| __ | / _` | ' \| | / _` | ' \  _/ -_) '_|
# │|_| |_\__,_|\__|___/\_,_|_| |_| \___|_| |_||_|_\__, |_||_|_|_\__, |_||_\__\___|_|
# ╰───────────────────────────────────────────────|___/─────────|___/──────────────────

func                        _________IMPORTS_________              ()->void:pass

# Supporting Scripts
const Token = preload('res://addons/gdflatbuffers/scripts/token.gd')
const Tips = preload('res://addons/gdflatbuffers/scripts/tooltips.gd')
const StackFrame = preload('res://addons/gdflatbuffers/scripts/stackframe.gd')
const FrameStack = preload('res://addons/gdflatbuffers/scripts/framestack.gd')

const LogLevel = FlatBuffersPlugin.LogLevel

# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var plugin:FlatBuffersPlugin
var parser:FlatBuffersParser

# ██   ██ ██  ██████  ██   ██ ██      ██  ██████  ██   ██ ████████ ███████ ██████
# ██   ██ ██ ██       ██   ██ ██      ██ ██       ██   ██    ██    ██      ██   ██
# ███████ ██ ██   ███ ███████ ██      ██ ██   ███ ███████    ██    █████   ██████
# ██   ██ ██ ██    ██ ██   ██ ██      ██ ██    ██ ██   ██    ██    ██      ██   ██
# ██   ██ ██  ██████  ██   ██ ███████ ██  ██████  ██   ██    ██    ███████ ██   ██

## The current resource file
## FIXME There is no way to retrieve the current source file_name from a TextEdit.
#var resource:Resource

## The location of the current file
## FIXME There is no way to retrieve the current source file_name from a TextEdit.
#var file_location:String

## per line colour information, key is line number, value is a dictionary
var dict:Dictionary[int, Dictionary]

## current line dictionary, key is column number
var line_dict:Dictionary[int,Dictionary]


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init( plugin_ref:FlatBuffersPlugin ):
	if plugin_ref:
		plugin = plugin_ref
	parser = FlatBuffersParser.new(plugin)
	parser._sync_constants_from_plugin()

	plugin.print_log(LogLevel.TRACE, "[b]FlatBuffersHighlighter._init() - Completed[/b]")


func _create() -> EditorSyntaxHighlighter:
	var self_script:GDScript = get_script()
	return self_script.new(plugin)


func _get_name ( ) -> String:
	return "FlatBuffersSchema"


func _get_supported_languages ( ) -> PackedStringArray:
	return ["FlatBuffersSchema", "fbs"]


func _clear_highlighting_cache ( ):
	#resource = get_edited_resource()
	# file_location = resource.resource_path.get_base_dir() + "/"
	# FIXME: This ^^ relies on a patch https://github.com/godotengine/godot/pull/96058

	plugin.print_log(LogLevel.TRACE, "[b]_clear_highlighting_cache( )[/b]")

	dict.clear()

	for line_num in range( get_text_edit().get_line_count() ):
		get_text_edit().set_line_background_color(line_num, Color(0,0,0,0) )

	# clear types
	parser.clear_cache()

	# resize the stack index to be the document size.
	parser.resize_stack_index(get_text_edit().text.length() + 10)


func _get_line_syntax_highlighting(line_num: int) -> Dictionary:
	if plugin.log_level(LogLevel.TRACE):
		print()
		plugin.print_log(LogLevel.TRACE, "[b]_get_line_syntax_highlighting( line_num:%d )[/b]" % [line_num+1])

	# Quick scan once
	if not parser.has_performed_quick_scan:
		parser.quick_scan_text(get_text_edit().text)

	var line = get_text_edit().get_line(line_num)
	if line.is_empty():
		return {}

	line_dict = {}
	dict[line_num] = line_dict

	# ── Let parser do all the work ──────────────────────────────────────────
	parser.active_highlighter = self
	var result: Dictionary = parser.parse_line(line_num, line)
	parser.active_highlighter = null

	get_text_edit().set_line_background_color(line_num, Color(0,0,0,0))
	return result


func _update_cache ( ):
	# Get settings
	plugin.print_log(LogLevel.TRACE, "[b]_update_cache( )[/b]")
	parser.quick_scan_text( get_text_edit().text )

	get_text_edit().set_tooltip_request_func( func( word ):
		var tip = Tips.keywords.get(word)
		return  tip if tip else "" )


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

func highlight( token:Token, override:Color = Color.ORANGE ):
	line_dict[token.col] = { 'color':plugin.colours.get( token.type, override ) }
	if not (parser.error_flag or parser.warning_flag):
		get_text_edit().set_line_background_color(token.line, Color(0,0,0,0) )


func syntax_warning( token:Token, reason = "" ):
	parser.warning_flag = true
	var colour:Color = plugin.colours[plugin.LogLevel.WARNING]
	if plugin.highlight_warning:
		get_text_edit().set_line_background_color(token.line, colour.blend(Color(0,0,0,.5)) )
	else: line_dict[token.col] = { 'color':colour }
	if plugin.log_level(LogLevel.WARNING):
		var frame_type = '#' if parser.stack.is_empty() else StackFrame.Type.find_key(parser.stack.top().type)
		plugin.print_log( LogLevel.WARNING, "%s:Warning in: %s - %s" % [frame_type, token, reason] )
		plugin.print_log( LogLevel.DEBUG, str(parser.stack) )


func syntax_error( token:Token, reason = "" ):
	parser.error_flag = true
	var colour:Color = plugin.colours[plugin.LogLevel.ERROR]
	if plugin.highlight_error:
		get_text_edit().set_line_background_color(token.line, colour.blend(Color(0,0,0,.5)) )
	else: line_dict[token.col] = { 'color':colour }
	if plugin.log_level(LogLevel.ERROR):
		var frame_type = '#' if parser.stack.is_empty() else StackFrame.Type.find_key(parser.stack.top().type)
		plugin.print_log( LogLevel.ERROR, "%s:Error in: %s - %s" % [frame_type, token, reason] )
		plugin.print_log( LogLevel.DEBUG, str(parser.stack) )

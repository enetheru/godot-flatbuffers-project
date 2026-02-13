@tool
extends EditorSyntaxHighlighter

# │ ___ _      _   ___       __  __         _  _ _      _    _ _      _   _
# │| __| |__ _| |_| _ )_  _ / _|/ _|___ _ _| || (_)__ _| |_ | (_)__ _| |_| |_ ___ _ _
# │| _|| / _` |  _| _ \ || |  _|  _/ -_) '_| __ | / _` | ' \| | / _` | ' \  _/ -_) '_|
# │|_| |_\__,_|\__|___/\_,_|_| |_| \___|_| |_||_|_\__, |_||_|_|_\__, |_||_\__\___|_|
# ╰───────────────────────────────────────────────|___/─────────|___/──────────────────

# TODO Debounce highlight actions, though its not expensive, i havent really
# run into trouble with it yet.


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

# FIXME, we're maintain our own cache here, but this might not be necessary
# we may be able to use the builtin cache and avoid having to manipulate the
# cache when the data changes.
## per line colour information, key is line number, value is a dictionary
var dict:Dictionary[int, Dictionary]

## current line dictionary, key is column number
var line_dict:Dictionary[int,Dictionary]


# TODO, this function is a little messy and needs a good audit.
# Still doesnt solve the problem it needs to solve.
## Account for added and removed lines
func _on_lines_edited_from(from_line: int, to_line: int):
	plugin.print_log( LogLevel.TRACE,
		"FlatBuffersHighlighter._on_lines_edited_from(from_line%d, to_line:%d)"%
		[from_line, to_line])
	if from_line == to_line: return

	var text_edit:TextEdit = get_text_edit()
	# How do I go about shifting all the indexes over, do I just increment?
	# build a new dictionary from the old?
	# I'm not really sure what the most efficient route here is for this.
	# perhaps my initial choice of containers is wrong.

	# I think the builtin dictionaries are automatically updated.

	# TODO dont forget to move the background colors.
	#text_edit.set_line_background_color(line_num, Color(0,0,0,0))
	#var bg_color:Color = text_edit.get_line_background_color(line_num)

	# If there was a cache entry where the start line was, it should be
	# copied to the new start position

	var from_dict:Dictionary = dict.get(from_line, {})

	# how many lines were added/removed
	var shift:int = from_line - to_line

	var shifted_dict:Dictionary[int, Dictionary] = {}

	# Ensure we start with the unchanged lines first
	var line_idxs:Array = dict.keys()
	line_idxs.sort()

	for line:int in line_idxs:
		# Unchanged Lines
		if line < from_line:
			shifted_dict[line] = dict[line]

		# displaced lines
		# dont overwrite unchanged lines
		if shifted_dict.has(line + shift): continue
		# Update position
		shifted_dict[line + shift] = dict[line]

	# Put back the starting position
	if not from_dict.is_empty():
		shifted_dict[from_line] = from_dict

	# replace highlighting cache.
	dict = shifted_dict



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
	var text_edit:TextEdit = get_text_edit()

	dict.clear()

	for line_num in range( text_edit.get_line_count() ):
		text_edit.set_line_background_color(line_num, Color(0,0,0,0) )

	# clear types
	parser.clear_cache()

	# resize the stack index to be the document size.
	parser.resize_stack_index(text_edit.text.length() + 10)


func _get_line_syntax_highlighting(line_num: int) -> Dictionary:
	if plugin.log_level(LogLevel.TRACE):
		print()
		plugin.print_log(LogLevel.TRACE, "[b]_get_line_syntax_highlighting( line_num:%d )[/b]" % [line_num+1])

	var text_edit:TextEdit = get_text_edit()

	# Quick scan once
	if not parser.has_performed_quick_scan:
		parser.quick_scan_text(text_edit.text)

	var line = text_edit.get_line(line_num)
	if line.is_empty():
		return {}

	line_dict = {}
	dict[line_num] = line_dict

	# ── Let parser do all the work ──────────────────────────────────────────
	parser.active_highlighter = self
	var result: Dictionary = parser.parse_line(line_num, line)
	parser.active_highlighter = null

	text_edit.set_line_background_color(line_num, Color(0,0,0,0))
	return result


func _update_cache():
	# Get settings
	plugin.print_log(LogLevel.TRACE, "[b]_update_cache( )[/b]")
	var text_edit:TextEdit = get_text_edit()

	if not text_edit.lines_edited_from.is_connected( _on_lines_edited_from ):
		text_edit.lines_edited_from.connect( _on_lines_edited_from )

	parser.quick_scan_text( text_edit.text )

	text_edit.set_tooltip_request_func( func( word ):
		var tip = Tips.keywords.get(word)
		return  tip if tip else "" )


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

func highlight( token:Token ):
	line_dict[token.col] = { 'color':plugin.get_colour( token.type ) }
	if not (parser.error_flag or parser.warning_flag):
		get_text_edit().set_line_background_color(token.line, Color(0,0,0,0) )

func highlight_colour( token:Token, colour:Color ):
	line_dict[token.col] = { 'color':colour }
	if not (parser.error_flag or parser.warning_flag):
		get_text_edit().set_line_background_color(token.line, Color(0,0,0,0) )


func syntax_warning( token:Token, reason = "" ):
	parser.warning_flag = true
	var colour:Color = plugin.get_colour(plugin.LogLevel.WARNING)
	if plugin.highlight_warning:
		get_text_edit().set_line_background_color(token.line, colour.blend(Color(0,0,0,.5)) )
	else: line_dict[token.col] = { 'color':colour }
	# TODO, if the token being warned about is on the line we are editing perhaps
	# we should not print any warnings at all, or change the loglevel
	if plugin.log_level(LogLevel.WARNING):
		var frame_type = '#' if parser.stack.is_empty() else StackFrame.Type.find_key(parser.stack.top().type)
		plugin.print_log( LogLevel.WARNING, "%s:Warning in: %s - %s" % [frame_type, token, reason] )
		plugin.print_log( LogLevel.DEBUG, str(parser.stack) )


func syntax_error( token:Token, reason = "" ):
	parser.error_flag = true
	var colour:Color = plugin.get_colour(plugin.LogLevel.ERROR)
	if plugin.highlight_error:
		get_text_edit().set_line_background_color(token.line, colour.blend(Color(0,0,0,.5)) )
	else: line_dict[token.col] = { 'color':colour }
	# TODO, if the token being warned about is on the line we are editing perhaps
	# we should not print any warnings at all, or change the loglevel
	if plugin.log_level(LogLevel.ERROR):
		var frame_type = '#' if parser.stack.is_empty() else StackFrame.Type.find_key(parser.stack.top().type)
		plugin.print_log( LogLevel.ERROR, "%s:Error in: %s - %s" % [frame_type, token, reason] )
		plugin.print_log( LogLevel.DEBUG, str(parser.stack) )

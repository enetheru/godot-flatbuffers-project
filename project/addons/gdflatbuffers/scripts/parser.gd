@tool
class_name FlatBuffersParser
# │ ___
# │| _ \__ _ _ _ ___ ___ _ _
# │|  _/ _` | '_(_-</ -_) '_|
# │|_| \__,_|_| /__/\___|_|
# ╰───────────────────────────
# A FlatBuffer schema file(fbs) parser

func                        _________IMPORTS_________              ()->void:pass

const Reader = preload('uid://cupdfm2aikswa')
const Token = preload('uid://cvcd6kyaa4f1a')
const Framestack = preload('uid://d3cyn1bbenwmo')
const StackFrame = preload('uid://c0ub8clj4bhhv')
const FlatBuffersHighlighter = preload('uid://ddcfjoxe7i5jo')

const LogLevel = FlatBuffersPlugin.LogLevel


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

# ── Dependencies ─────────────────────────────────────────────────────────────
var plugin: FlatBuffersPlugin           # temporary bridge
var reader: Reader             # we'll initialize it later

# ── Collected schema knowledge ───────────────────────────────────────────────
var struct_types: Array[StringName] = []
var table_types:  Array[StringName] = []
var union_types:  Array[StringName] = []
var enum_types:   Dictionary = {}       # StringName → Array[StringName]

# ── Include handling (will be improved later) ────────────────────────────────
var included_files: Array[String] = []

# ── Incremental parsing state ────────────────────────
var max_stack_size:int = 100
var stack : FrameStack = FrameStack.new(max_stack_size)   # initial capacity, can tune later

# saved stacks per line (key: line number, value: FrameStack)
# TODO: I wonder if we can keep the stack in the highlight cache.
var stack_list : Dictionary = {}               # int → FrameStack

# indicates if we saved a stack for this line index
# Where the Array index is the line_num, and stack_index[index] bool
# indicates whether the stack_list dictionary has an index saved.
# TODO They can probably be merged into the same field honestly.
var stack_index : Array[bool] = [false]        # grows as needed

# A block of false data which is used to expand on the stack index
var new_index_chunk:Array[bool]

# flags that influence parsing behaviour / highlighting
# NOTE: if error or warning is set, do not to save the stack to the next line
var error_flag : bool = false
var warning_flag : bool = false

var is_quick_scan_in_progress: bool = false # re-entrancy guard + "behave in discovery mode"
var has_performed_quick_scan: bool = false  # "can I trust struct_types/table_types etc.?"

# The line number that the stack was restored from.
var prev_idx : int = 0

# Per-line colour dictionary (temporarily here; highlighter will receive a copy)
var line_dict: Dictionary[int, Dictionary] = {}

# ── Grammar constants ───────────────────────────────
var keywords:Array[StringName] = [
	&'include', &'namespace', &'table', &'struct', &'enum',
	&'union', &'root_type', &'file_extension', &'file_identifier', &'attribute',
	&'rpc_service']

var integer_types:Array[StringName] = [
	&"byte", &"ubyte", &"short", &"ushort", &"int", &"uint", &"long", &"ulong",
	&"int8", &"uint8", &"int16", &"uint16", &"int32", &"uint32", &"int64", &"uint64"]

var float_types:Array[StringName] = [&"float", &"double", &"float32", &"float64"]

var boolean_types:Array[StringName] = [&"bool"]

var array_types: Array[StringName] = [
	&"string",
	&"String",
	&"StringName",
	&"NodePath", ]

# is assigned in _init()
var scalar_types: Array[StringName] # integer_types + float_types + boolean_types


var kw_frame_map:Dictionary[StringName, StackFrame.Type] = {
	&'include':StackFrame.Type.INCLUDE,
	&'namespace':StackFrame.Type.NAMESPACE_DECL,
	&'table':StackFrame.Type.TYPE_DECL,
	&'struct':StackFrame.Type.TYPE_DECL,
	&'enum':StackFrame.Type.ENUM_DECL,
	&'union':StackFrame.Type.ENUM_DECL,
	&'root_type':StackFrame.Type.ROOT_DECL,
	&'file_extension':StackFrame.Type.FILE_EXTENSION_DECL,
	&'file_identifier':StackFrame.Type.FILE_IDENTIFIER_DECL,
	&'attribute':StackFrame.Type.ATTRIBUTE_DECL,
	&'rpc_service':StackFrame.Type.RPC_DECL,
}

# ── Per-line parsing ────────────────────────────────────────────────────────
# Temporary bridge while we migrate parse_xxx functions
var active_highlighter: FlatBuffersHighlighter = null


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init(plugin_ref: FlatBuffersPlugin = null):
	if plugin_ref:
		plugin = plugin_ref
		_sync_constants_from_plugin()

	new_index_chunk.resize(10)
	new_index_chunk.fill(false)

	scalar_types = integer_types + float_types + boolean_types
	reader = Reader.new(self)
	# This saves us from having to highlight everything manually.
	reader.new_token.connect(func( token:Token ):
		highlight( token )
		if plugin.log_level(LogLevel.TRACE):
			var colour = plugin.get_colour(token.type).to_html()
			print_rich( lpad() + "\t[color=%s]%s[/color]" % [colour, token] )
	)
	reader.newline.connect( func(l,p):
		if error_flag: return
		save_stack(l, 0)
	)

#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

func clear_cache() -> void:
	has_performed_quick_scan = false
	error_flag = false
	warning_flag = false
	included_files.clear()
	struct_types.clear()
	table_types.clear()
	union_types.clear()
	enum_types.clear()
	reset_stack()


func resize_stack_index( size:int ) -> void:
	stack_index.resize( size )
	stack_index.fill(false)


func lpad( extra:int = 0 ) -> String:
	return "".lpad( stack.size() -1 + extra, '\t' )


func _sync_constants_from_plugin():
	# TODO: move these to a shared constants file later
	if "scalar_types" in plugin:
		scalar_types = plugin.scalar_types
	if "keywords" in plugin:
		keywords = plugin.keywords


# ── File Helper ────────────────────────────────
func using_file(file_path: String) -> String:
	if not file_path.is_valid_filename():
		plugin.print_log(LogLevel.ERROR, "Invalid filename: '%s'" % file_path )
		return ""

	if file_path == "godot.fbs":
		file_path = 'res://addons/gdflatbuffers/godot.fbs'

	if FileAccess.file_exists(file_path):
		return file_path

	if file_path.is_absolute_path():
		return ""

	plugin.print_log( LogLevel.DEBUG, "Search Locations: %s" % [plugin.flatc_include_paths])
	for ipath: String in plugin.flatc_include_paths:
		var try_path = ipath.path_join(file_path)
		if FileAccess.file_exists(try_path):
			plugin.print_log(LogLevel.DEBUG, "Found: '%s'" % try_path)
			return try_path

	return ""


#  ██   ██ ██  █████  ██   ██ ██     ██  █████  ██   ██ ██████ ██████ ██████   #
#  ██   ██ ██ ██      ██   ██ ██     ██ ██      ██   ██   ██   ██     ██   ██  #
#  ███████ ██ ██  ███ ███████ ██     ██ ██  ███ ███████   ██   ████   ██████   #
#  ██   ██ ██ ██   ██ ██   ██ ██     ██ ██   ██ ██   ██   ██   ██     ██   ██  #
#  ██   ██ ██  █████  ██   ██ ██████ ██  █████  ██   ██   ██   ██████ ██   ██  #
func                        _______HIGHLIGHTER_______              ()->void:pass
# ── Colour / error helpers ─────────────────────────

func highlight(token: Token):
	active_highlighter.highlight(token)


func highlight_colour(token: Token, colour:Color):
	active_highlighter.highlight_colour(token, colour)


func syntax_warning(token: Token, reason: String = ""):
	active_highlighter.syntax_warning(token, reason)


func syntax_error(token: Token, reason: String = ""):
	active_highlighter.syntax_error(token, reason)


# ███████ ██████  █████   █████ ██   ██      ██   ██ ██████ ██ ██     ███████  #
# ██        ██   ██   ██ ██     ██  ██       ██   ██   ██   ██ ██     ██       #
# ███████   ██   ███████ ██     █████  █████ ██   ██   ██   ██ ██     ███████  #
#      ██   ██   ██   ██ ██     ██  ██       ██   ██   ██   ██ ██          ██  #
# ███████   ██   ██   ██  █████ ██   ██       █████    ██   ██ ██████ ███████  #
func                       _______STACK_UTILS_______               ()->void:pass

# Call this at the end of a successful line parse
func save_stack(line_num: int, force: bool = false) -> void:
	if error_flag and not force:
		return  # don't save bad state

	# Grow arrays if needed
	while stack_index.size() <= line_num:
		stack_index.append(false)

	# Duplicate current stack
	stack_list[line_num] = stack.duplicate(true)  # deep copy
	stack_index[line_num] = true
	prev_idx = line_num
	plugin.print_log( LogLevel.TRACE, "Stack saved to line %s" % [line_num+1] )
	plugin.print_log( LogLevel.TRACE, "Saved: %s" % [stack_list[line_num]] )


# Get the stack to restore from for this line
func get_prev_stack(line_num: int) -> FrameStack:
	# Look backward for the last saved good stack
	for i in range(line_num, -1, -1):
		if stack_index.size() > i and stack_index[i]:
			prev_idx = i
			var saved = stack_list.get(i)
			if saved:
				return saved.duplicate(true)  # return a copy to avoid mutation issues
	# No previous state → fresh stack
	return FrameStack.new(20)


# Reset stack state (e.g. on full document change / cache clear)
func reset_stack() -> void:
	stack.clear()
	stack_list.clear()
	stack_index.clear()
	stack_index.append(false)  # index 0
	prev_idx = 0
	#STUB stack_index.resize( get_text_edit().text.length() + 10 )
	#STUB stack_index.fill(false)


func _dispatch(frame: StackFrame, token: Token) -> void:
	match frame.type:
		StackFrame.Type.NONE:                   syntax_error(token)
		StackFrame.Type.SCHEMA:                 parse_schema(token)
		StackFrame.Type.INCLUDE:                parse_include(token)
		StackFrame.Type.NAMESPACE_DECL:         parse_namespace_decl(token)
		StackFrame.Type.ATTRIBUTE_DECL:         parse_attribute_decl(token)
		StackFrame.Type.TYPE_DECL:              parse_type_decl(token)
		StackFrame.Type.ENUM_DECL:              parse_enum_decl(token)
		StackFrame.Type.ROOT_DECL:              parse_root_decl(token)
		StackFrame.Type.FIELD_DECL:             parse_field_decl(token)
		StackFrame.Type.RPC_DECL:               parse_rpc_decl(token)
		StackFrame.Type.RPC_METHOD:             parse_rpc_method(token)
		StackFrame.Type.TYPE:                   parse_type(token)
		StackFrame.Type.ENUMVAL_DECL:           parse_enumval_decl(token)
		StackFrame.Type.METADATA:               parse_metadata(token)
		StackFrame.Type.SCALAR:                 parse_scalar(token)
		StackFrame.Type.OBJECT:                 parse_object(token)
		StackFrame.Type.SINGLE_VALUE:           parse_single_value(token)
		StackFrame.Type.VALUE:                  parse_value(token)
		StackFrame.Type.COMMASEP:               parse_commasep(token)
		StackFrame.Type.FILE_EXTENSION_DECL:    parse_file_extension_decl(token)
		StackFrame.Type.FILE_IDENTIFIER_DECL:   parse_file_identifier_decl(token)
		StackFrame.Type.STRING_CONSTANT:        parse_string_constant(token)
		StackFrame.Type.IDENT:                  parse_ident(token)
		#StackFrame.Type.DIGIT:                  parse_digit(token)
		#StackFrame.Type.XDIGIT:                 parse_xdigit(token)
		#StackFrame.Type.DEC_INTEGER_CONSTANT:   parse_dec_integer_constant(token)
		#StackFrame.Type.HEX_INTEGER_CONSTANT:   parse_hex_integer_constant(token)
		StackFrame.Type.INTEGER_CONSTANT:       parse_integer_constant(token)
		#StackFrame.Type.DEC_FLOAT_CONSTANT:     parse_dec_float_constant(token)
		#StackFrame.Type.HEX_FLOAT_CONSTANT:     parse_hex_float_constant(token)
		#StackFrame.Type.SPECIAL_FLOAT_CONSTANT: parse_special_float_constant(token)
		#StackFrame.Type.FLOAT_CONSTANT:         parse_float_constant(token)
		#StackFrame.Type.BOOLEAN_CONSTANT:       parse_boolean_constant(token)
		_: syntax_error(token, "No parser for frame type %s" % StackFrame.Type.find_key(frame.type))


#             ███████ ██████   █████  ███    ███ ███████ ███████               #
#             ██      ██   ██ ██   ██ ████  ████ ██      ██                    #
#             █████   ██████  ███████ ██ ████ ██ █████   ███████               #
#             ██      ██   ██ ██   ██ ██  ██  ██ ██           ██               #
#             ██      ██   ██ ██   ██ ██      ██ ███████ ███████               #
func                        __________FRAMES_________              ()->void:pass

## start_frame() runs the appropriate stack frame function
func start_frame( frame:StackFrame, token:Token ):
	if plugin.log_level( LogLevel.TRACE ):
		var msg:Array = [
			"" if frame.data.is_empty() else "⮱Resume:",
			frame,
			JSON.stringify( token ) ]
		plugin.print_trace( lpad() + " ".join(msg) )
	_dispatch(frame, token)


## end_frame() pops the last stackframe from the stack
## if retval is not null, the top stack frame will have 'return' = retval added
func end_frame(retval = null):
	plugin.print_trace( lpad() + "⮶Return%s" % [" '%s'" % retval if retval else ""] )
	stack.pop()
	if not stack.is_empty() and retval != null:
		stack.top().data["return"] = retval


func error_frame( token:Token, message: String ):
	syntax_error(token, "decl_type != union | enum.")
	end_frame(&"error")


#  ██████  ██    ██ ██  ██████ ██   ██      ███████  ██████  █████  ███    ██  #
# ██    ██ ██    ██ ██ ██      ██  ██       ██      ██      ██   ██ ████   ██  #
# ██    ██ ██    ██ ██ ██      █████  █████ ███████ ██      ███████ ██ ██  ██  #
# ██ ▄▄ ██ ██    ██ ██ ██      ██  ██            ██ ██      ██   ██ ██  ██ ██  #
#  ██████   ██████  ██  ██████ ██   ██      ███████  ██████ ██   ██ ██   ████  #
#     ▀▀                                                                       #
func                       ________QUICK_SCAN_______               ()->void:pass

# ── Public: reset & scan the whole document for types ────────────────────────
func quick_scan_text(full_text: String) -> void:
	plugin.print_log( LogLevel.DEBUG, "[b]quick_scan_text[/b]")
	if is_quick_scan_in_progress:
		# Optional: could push a warning or just return silently
		print_rich("[color=orange]Quick scan already in progress — skipping nested call[/color]")
		return
	is_quick_scan_in_progress = true

	struct_types.clear()
	table_types.clear()
	union_types.clear()
	enum_types.clear()
	included_files.clear()

	var qreader := Reader.new(self)   # note: still passes self as parent for now
	qreader.reset(full_text)

	while not qreader.at_end():
		var token : Token = qreader.get_token()

		# We are only interested in keywords during a quickscan
		if token.type != Token.Type.KEYWORD:
			qreader.adv_line()
			continue

		# we want to include other files.
		if token.t == 'include':
			token = qreader.get_token()
			qreader.adv_line()
			if token.type != Token.Type.STRING: continue
			plugin.print_log(LogLevel.TRACE, "include %s" % token.t)
			# Strip quotes from token
			var file_path = token.t.substr(1, token.t.length() - 2)
			# validate the file
			file_path = using_file(file_path)
			# Scan the file
			if file_path and file_path not in included_files:
				plugin.print_log( LogLevel.DEBUG, "Including file: %s" % file_path )
				included_files.append(file_path)
				quick_scan_file(file_path)
			else: plugin.print_log(LogLevel.ERROR, "Invalid path: %s" % file_path)
			continue

		if token.t in ['struct', 'table', 'union']:
			var ident = qreader.get_token()
			if ident.type != Token.Type.IDENT:
				qreader.adv_line()
				continue
			plugin.print_log(LogLevel.TRACE, "%s %s" % [token.t, ident.t])
			match token.t:
				&"struct": struct_types.append(ident.t)
				&"table":  table_types.append(ident.t)
				&"union":  union_types.append(ident.t)
			qreader.adv_line()
			continue

		if token.t == 'enum':
			var ident = qreader.get_token()
			if ident.type != Token.Type.IDENT:
				qreader.adv_line()
				continue
			plugin.print_log(LogLevel.TRACE, "%s %s" % [token.t, ident.t])

			var enum_vals = enum_types.get_or_add(ident.t,
					Array([], TYPE_STRING_NAME, "", null))
			while token.t != '}':
				token = qreader.get_token()
				if token.type == Token.Type.IDENT:
					enum_vals.append( token.t )
			plugin.print_log(LogLevel.TRACE, "enum %s %s" % [ident.t, enum_vals])

		qreader.adv_line()

	is_quick_scan_in_progress = false
	has_performed_quick_scan = true


func quick_scan_file(file_path: String) -> bool:
	plugin.print_log( LogLevel.DEBUG, "[b]quick_scan_file: '%s'[/b]" % file_path)

	if not FileAccess.file_exists( file_path ):
		if plugin.print_log( LogLevel.ERROR,"Unable to locate file for inclusion: %s" % file_path):
			if file_path.is_relative_path():
				plugin.print_log( LogLevel.WARNING, "Relative Paths are only relative to project root, not their own location.")
		return false

	if file_path in included_files:
		return true # Dont create a loop

	var file:FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	var content:String = file.get_as_text()

	quick_scan_text(content)          # recursive call — safe because of included_files check
	return true


#               ██████   █████  ██████  ███████ ███████ ██████                 #
#               ██   ██ ██   ██ ██   ██ ██      ██      ██   ██                #
#               ██████  ███████ ██████  ███████ █████   ██████                 #
#               ██      ██   ██ ██   ██      ██ ██      ██   ██                #
#               ██      ██   ██ ██   ██ ███████ ███████ ██   ██                #
func                        __________PARSER_________              ()->void:pass


## returns true if token.t == t
func check_token_t(token: Token, t: StringName, msg: String = "") -> bool:
	if token.t == t: return true
	syntax_error(token, "'%s' != '%s'" % [token.t, t])
	if not msg.is_empty(): plugin.print_log(LogLevel.ERROR, msg)
	return false


## returns true if token.type == type
func check_token_type(token: Token, typ: Token.Type, msg: String = "") -> bool:
	if token.type == typ: return true
	syntax_error(token, "'%s' != '%s'" % [
		Token.Type.find_key(token.type), Token.Type.find_key(typ)])
	if not msg.is_empty(): plugin.print_log(LogLevel.ERROR, msg)
	return false


# ── Per-line parsing ────────────────────────────────────────────────────────
## Main entry point for highlighting one line.
## Called from highlighter._get_line_syntax_highlighting()
func parse_line(line_num: int, line_text: String) -> Dictionary:
	error_flag = false
	warning_flag = false

	# Grow stack_index if necessary
	while stack_index.size() <= line_num:
		stack_index.append_array(new_index_chunk)

	stack_index[line_num] = false

	# Restore stack state
	stack = get_prev_stack(line_num)
	if stack.is_empty():
		stack.push(StackFrame.new(StackFrame.Type.SCHEMA))

	# Reset lexer for this line
	reader.reset(line_text, line_num)

	# ── Early outs (exactly as before) ───────────────────────────────────────
	var token := reader.peek_token(false)   # false = do NOT auto-skip comments

	if token.type == Token.Type.COMMENT:
		highlight(token)          # writes to highlighter.line_dict
		if not error_flag:
			save_stack(line_num)
		return active_highlighter.line_dict

	if token.type == Token.Type.EOL or token.type == Token.Type.EOF:
		if not error_flag:
			save_stack(line_num)
		return active_highlighter.line_dict

	# ── Full parse loop ─────────────────────────────────────────────────────
	var loop_detection := 0
	var end_reached := false

	while not stack.is_empty():
		loop_detection += 1
		assert(loop_detection < max_stack_size, "Stack Limit Reached")

		if reader.at_end():
			if end_reached: break
			end_reached = true

		start_frame(stack.top(), reader.peek_token())

	# ── Finish ──────────────────────────────────────────────────────────────
	if not error_flag:
		save_stack(line_num)

	return active_highlighter.line_dict   # highlighter still owns the dict


#        ██████  ██████   █████  ███    ███ ███    ███  █████  ██████          #
#       ██       ██   ██ ██   ██ ████  ████ ████  ████ ██   ██ ██   ██         #
#       ██   ███ ██████  ███████ ██ ████ ██ ██ ████ ██ ███████ ██████          #
#       ██    ██ ██   ██ ██   ██ ██  ██  ██ ██  ██  ██ ██   ██ ██   ██         #
#        ██████  ██   ██ ██   ██ ██      ██ ██      ██ ██   ██ ██   ██         #
func                        _________GRAMMAR_________              ()->void:pass
# ── Grammar parsing helpers ──────────────────────────────────────────────────

#MARK: Schema
# │ ___     _
# │/ __| __| |_  ___ _ __  __ _
# │\__ \/ _| ' \/ -_) '  \/ _` |
# │|___/\__|_||_\___|_|_|_\__,_|
# ╰──────────────────────────────
#region Schema
func parse_schema( p_token:Token ):
	#schema # = include* ( namespace_decl | type_decl | enum_decl | root_decl
	#					 | file_extension_decl | file_identifier_decl
	#					 | attribute_decl | rpc_decl | object )*
	var frame:StackFrame = stack.top()

	if p_token.eof(): return

	var exclude = frame.data.get(&"exclude", 99999999)

	if p_token.t == &'include':
		if p_token.line < exclude:
			stack.push( StackFrame.new( StackFrame.Type.INCLUDE ) )
			return
		syntax_error( p_token, "Trying to use include mid file" )
		reader.adv_line()
		return

	if p_token.type == Token.Type.KEYWORD:
		frame.data[&"exclude"] = min( exclude, p_token.line )
		var type = kw_frame_map.get( p_token.t )
		stack.push( StackFrame.new( type ) )
		return

	syntax_error( p_token, "Wanted Token.Type.KEYWORD" )
	reader.adv_line()
	return
#endregion Schema


#MARK: Include
# │ ___         _         _
# │|_ _|_ _  __| |_  _ __| |___
# │ | || ' \/ _| | || / _` / -_)
# │|___|_||_\__|_|\_,_\__,_\___|
# ╰──────────────────────────────
#region Include
func parse_include( p_token:Token ):
	# INCLUDE = include string_constant;
	var frame:StackFrame = stack.top()

	var token:Token = reader.get_token()
	check_token_t(token, &'include')

	token = reader.get_token()
	if check_token_type(token, Token.Type.STRING ):
		var file_path: String = token.t.substr(1, token.t.length() -2)
		file_path = using_file(file_path)

		# Scan the file
		if file_path:
			if file_path not in included_files:
				# FIXME, change this to a warning about a file that was not caught in the quickscan.
				#STUB plugin.print_log( LogLevel.DEBUG, "Including file: %s" % filepath )
				included_files.append(file_path)
				quick_scan_file(file_path)
		else:
			syntax_error(token, "Unable to locate file: %s" % file_path )

	token = reader.get_token()
	check_token_t(token, &";")
	return end_frame()
#endregion Include


#MARK: Namespace Decl
# │ _  _                                       ___         _
# │| \| |__ _ _ __  ___ ____ __  __ _ __ ___  |   \ ___ __| |
# │| .` / _` | '  \/ -_|_-< '_ \/ _` / _/ -_) | |) / -_) _| |
# │|_|\_\__,_|_|_|_\___/__/ .__/\__,_\__\___| |___/\___\__|_|
# ╰───────────────────────|_|─────────────────────────────────
#region Namespace Decl
func parse_namespace_decl( p_token:Token ):
	#NAMESPACE_DECL = namespace ident ( . ident )* ;
	var frame:StackFrame = stack.top()

	var token:Token = reader.get_token()
	check_token_t(token, &"namespace")

	while true:
		token = reader.get_token()
		check_token_type(token, Token.Type.IDENT)

		token = reader.peek_token()
		if token.t == &".":
			reader.get_token()
			continue
		else: break

	token = reader.get_token()
	check_token_t(token, &";")
	return end_frame()
#endregion Namespace Decl


#MARK: Attribute Decl
# │   _  _   _       _ _         _         ___         _
# │  /_\| |_| |_ _ _(_) |__ _  _| |_ ___  |   \ ___ __| |
# │ / _ \  _|  _| '_| | '_ \ || |  _/ -_) | |) / -_) _| |
# │/_/ \_\__|\__|_| |_|_.__/\_,_|\__\___| |___/\___\__|_|
# ╰───────────────────────────────────────────────────────
#region Attribute Decl
func parse_attribute_decl( p_token:Token ):
	# ATTRIBUTE_DECL = attribute ident | "</tt>ident<tt>" ;
	var frame:StackFrame = stack.top()

	var token:Token = reader.get_token()
	check_token_t(token, &"attribute")

	token = reader.get_token()
	match token.type:
		Token.Type.IDENT: pass
		Token.Type.STRING:pass
		_: syntax_error(token, "Wanted 'ident | string_constant'")

	token = reader.get_token()
	check_token_t(token, &";")
	return end_frame()
#endregion Attribute Decl


#MARK: Type Decl
# │ _____                 ___         _
# │|_   _|  _ _ __  ___  |   \ ___ __| |
# │  | || || | '_ \/ -_) | |) / -_) _| |
# │  |_| \_, | .__/\___| |___/\___\__|_|
# ╰──────|__/|_|─────────────────────────
#region Type Decl
func parse_type_decl( p_token:Token ):
	#type_decl = ( table | struct ) ident [metadata] { field_decl+ }\
	var frame:StackFrame = stack.top()

	var decl_type:StringName = frame.data.get(&"decl_type", StringName())

	if frame.data.get(&"next") == null:
		var token = reader.get_token()
		if token.t not in [&'table',&'struct']:
			syntax_error(token, "wanted ( table | struct )")
		else:
			decl_type = token.t
			frame.data[&"decl_type"] = token.t

		token = reader.get_token()
		check_token_type(token, Token.Type.IDENT )
		# add token to appropriate array
		match decl_type:
			&"struct": struct_types.append(token.t)
			&"table": table_types.append(token.t)

		# We dont want to consume the next token.
		token = reader.peek_token()
		if token.t == &"(":
			frame.data[&'next'] = &'{'
			stack.push( StackFrame.new( StackFrame.Type.METADATA ) )
			return

		frame.data[&'next'] = &'{'
		# can immediately continue

	if frame.data.get(&'next') == &'{':
		var token = reader.get_token()
		if token.eof():return
		check_token_t( token, &"{" )
		frame.data[&'next'] = &'field_decl'

		# update p_token to continue
		p_token = reader.peek_token()

	if frame.data.get(&'next') == &'field_decl':
		if p_token.eof():return
		if p_token.t != &"}":
			stack.push( StackFrame.new( StackFrame.Type.FIELD_DECL, {&"decl_type":decl_type} ) )
			return
		reader.get_token() # Consume the }
		end_frame()
		return

	syntax_error(p_token, "reached end of parse_type_decl(...)")
	return end_frame()

#endregion Type Decl


#MARK: Enum Decl
# │ ___                  ___         _
# │| __|_ _ _  _ _ __   |   \ ___ __| |
# │| _|| ' \ || | '  \  | |) / -_) _| |
# │|___|_||_\_,_|_|_|_| |___/\___\__|_|
# ╰─────────────────────────────────────
#region Enum Decl
func parse_enum_decl( p_token:Token ):
	#enum_decl = ( enum ident:type | union ident ) metadata { commasep( enumval_decl ) }
	var frame:StackFrame = stack.top()

	var decl_type:StringName = frame.data.get(&"decl_type", StringName())
	var decl_name:StringName = frame.data.get(&"decl_name", StringName())

	reader.print_bright("Frame Next: '%s'" % frame.data.get(&"next"))

	if frame.data.get(&"next") == null:
		frame.data[&'next'] = &'meta'

		var token:Token = reader.get_token()
		if not token.t in [&'union', &'enum']:
			syntax_error(token, "wanted ( enum | union )")
		else:
			decl_type = token.t
			frame.data[&"decl_type"] = decl_type

		# ident
		token = reader.get_token()
		if check_token_type(token, Token.Type.IDENT):
			match decl_type:
				&"union":union_types.append(token.t)
				&"enum" :
					decl_name = token.t
					frame.data[&"decl_name"] = decl_name
					enum_types[ decl_name ] = Array([], TYPE_STRING_NAME, "", null)

		token = reader.peek_token()
		if decl_type == &"enum":
			if token.t == &":":
				reader.get_token() # consume token.
				stack.push( StackFrame.new( StackFrame.Type.TYPE, { &"decl_type":decl_type } ) )
				return

	if frame.data.get(&'next') == &'meta':
		frame.data[&'next'] = &'{'
		if p_token.t == &"(":
			stack.push(StackFrame.new( StackFrame.Type.METADATA ) )
			return

	if frame.data.get(&'next') == &'{':
		var token:Token = reader.get_token()
		if token.eof(): return
		frame.data[&'next'] = &'enumval_decl'
		check_token_t(token, &"{")
		p_token = reader.peek_token()

	if frame.data.get(&'next') == &'enumval_decl':
		reader.print_bright("Token: '%s'" % reader.peek_token().t)
		# Newlines are ok at the beginning/end
		if p_token.eof():return
		if p_token.t == &"}":
			reader.get_token() # Consume the '}'
			return end_frame()
		if p_token.t == &',':
			reader.get_token() # Consume the ','
			p_token = reader.peek_token()

		if check_token_type( p_token, Token.Type.IDENT ):
			match decl_type:
				&"union": stack.push( StackFrame.new( StackFrame.Type.ENUMVAL_DECL,
					{ &"decl_type":decl_type } ) )
				&"enum": stack.push( StackFrame.new( StackFrame.Type.ENUMVAL_DECL,
					{ &"decl_type":decl_type, &"decl_name":decl_name } ) )
			return

		reader.adv_token(p_token) # move on
		return

	syntax_error(p_token, "reached end of parse_enum_val( ... )" )
	return end_frame()
#endregion Enum Decl


#MARK: Root Decl
# │ ___          _     ___         _
# │| _ \___  ___| |_  |   \ ___ __| |
# │|   / _ \/ _ \  _| | |) / -_) _| |
# │|_|_\___/\___/\__| |___/\___\__|_|
# ╰───────────────────────────────────
#region Root Decl
func parse_root_decl( p_token:Token ):
	# ROOT_DECL = root_type ident ;
	var frame:StackFrame = stack.top()

	var token:Token = reader.get_token()
	check_token_t(token, &"root_type")

	token = reader.get_token()
	check_token_type(token, Token.Type.IDENT )

	token = reader.get_token()
	check_token_t(token, &";")
	return end_frame()
#endregion Root Decl


#MARK: Field Decl
# │ ___ _     _    _   ___         _
# │| __(_)___| |__| | |   \ ___ __| |
# │| _|| / -_) / _` | | |) / -_) _| |
# │|_| |_\___|_\__,_| |___/\___\__|_|
# ╰───────────────────────────────────
#region Field Decl
func parse_field_decl( p_token:Token ):
	# field_decl = ident:type [ = scalar ] metadata;
	var frame:StackFrame = stack.top()

	# field_decl can start on a newline, so this function is called
	# even on empty lines.
	if p_token.eof(): return

	var decl_type:StringName = frame.bindings.get(&"decl_type", StringName())
	var field_name:StringName = frame.data.get(&"field_name", StringName())

	if frame.data.get(&"next") == null:
		var token:Token = reader.get_token()
		if check_token_type(token, Token.Type.IDENT):
			field_name = token.t
			frame.data[&"field_name"] = token.t

		# TODO is this token already named in the type_decl?
		# I would need to fetch the parent frame and check if it is in the named list.
		# and add the name to the list.

		token = reader.get_token()
		if token.eof():return
		check_token_t( token, &":")

		frame.data[&"next"] = &"default"
		stack.push( StackFrame.new( StackFrame.Type.TYPE,
			{ &"decl_type":decl_type, &"field_name":field_name } ) )
		return

	# Handle defaults
	p_token = reader.peek_token()
	if frame.data.get(&"next") == &"default":
		frame.data[&"next"] = &"meta"
		if p_token.t == &"=":
			reader.get_token() # consume '='
			var token:Token = reader.get_token()
			var return_val:Dictionary = frame.data.get(&"return")
			frame.data.erase(&"return")
			if return_val.get(&"field_type") == &"enum":
				var enum_vals:Array[StringName] = enum_types.get(return_val.get(&"field_name"))
				if not token.t in enum_vals:
					syntax_error(token, "value not found in enum")
				else:
					highlight_colour(token, plugin.get_colour(Token.Type.SCALAR))
			elif not reader.is_scalar(token.t):
				syntax_error(token, "Only Scalar values can have defaults")

	# meta
	if frame.data.get(&"next") == &"meta":
		frame.data[&"next"] = &";"
		if p_token.t == &"(":
			stack.push( StackFrame.new( StackFrame.Type.METADATA ) )
			return

	# finish
	if frame.data.get(&"next") == &";":
		var token:Token = reader.get_token()
		check_token_t(token, &";")
		return end_frame()

	syntax_error(p_token, "reached end of parse_type_decl(...)")
	return end_frame()
#endregion Field Decl


#MARK: Rpc Decl
# │ ___            ___         _
# │| _ \_ __  __  |   \ ___ __| |
# │|   / '_ \/ _| | |) / -_) _| |
# │|_|_\ .__/\__| |___/\___\__|_|
# ╰────|_|────────────────────────
#region Rpc Decl
func parse_rpc_decl( p_token:Token ):
	syntax_warning( p_token, &"Unimplemented")
	reader.adv_line()
	return end_frame()
#endregion Rpc Decl


#MARK: Rpc Method
# │ ___            __  __     _   _            _
# │| _ \_ __  __  |  \/  |___| |_| |_  ___  __| |
# │|   / '_ \/ _| | |\/| / -_)  _| ' \/ _ \/ _` |
# │|_|_\ .__/\__| |_|  |_\___|\__|_||_\___/\__,_|
# ╰────|_|────────────────────────────────────────
#region Rpc Method
func parse_rpc_method( p_token:Token ):
	syntax_warning( p_token, &"Unimplemented")
	reader.adv_line()
	return end_frame()
#endregion Rpc Method


#MARK: Type
# │ _____
# │|_   _|  _ _ __  ___
# │  | || || | '_ \/ -_)
# │  |_| \_, | .__/\___|
# ╰──────|__/|_|─────────
#region Type
func parse_type( p_token:Token ):
	# TYPE = bool | byte | ubyte | short | ushort | int | uint | float | long
	#		| ulong | double | int8 | uint8 | int16 | uint16 | int32 | uint32
	#		| int64 | uint64 | float32 | float64 | string
	#		| [ type ]
	#		| ident

	# It is unfortunate that the type definition is vague in the spec
	# there is no official presentation of the Array Syntax.
	# The parsing depends on whether the containing type_decl is
	# a struct, vector, or enum so lets figure that out at the first moment
	# and store it in the frame information

	# Array Syntax
	# [struct/scalar type?:integer_constant]
	# Arrays are a convenience short-hand for a fixed-length collection of elements.
	# Arrays allow the following syntax, while maintaining binary equivalency.
	# Arrays are currently only supported in a struct.

	# Normal Syntax     # Array Syntax
	# struct Vec3 {     # struct Vec3 {
	#   x:float;        #   v:[float:3];
	#   y:float;        # }
	#   z:float;
	# }

	var frame:StackFrame = stack.top()

	# Find the type_decl frame and determine what we are parsing.
	var decl_type:StringName = frame.bindings.get(&"decl_type", StringName())

	# Simple parsing for enums
	if decl_type == &"enum":
		var token:Token = reader.get_token()
		if not token.t in integer_types:
			syntax_error( token, "Enum types must be an integral")
		else: highlight_colour(token, plugin.get_colour(Token.Type.TYPE))
		return end_frame()


	# compled parsing for structs and tables
	var has_bracket:bool = false
	var return_val:Dictionary = {
		&"field_type":StringName(),
		&"field_name":StringName()
	}

	var token:Token = reader.get_token()
	# for both table and struct decl '[' is allowed
	if token.t == &"[":
		# we have either vector or array syntax
		has_bracket = true
		token = reader.get_token()

	# we need to know if the field is scalar, for when we deal with defaults.
	if token.t in scalar_types: return_val[&"field_type"] = &"scalar"
	elif token.t in enum_types:
		return_val[&"field_type"] = &"enum"
		return_val[&"field_name"] = token.t

	if decl_type == &"struct":
		if not token.t in scalar_types + struct_types + enum_types.keys():
			syntax_error(token, "struct array/vector fields may only contain scalars or other structs")
		else: highlight_colour(token, plugin.get_colour(Token.Type.TYPE))
	elif decl_type == &"table":
		# Where table can contain vectors of any type
		if not token.t in (scalar_types + struct_types + table_types
								+ array_types + enum_types.keys() + union_types):
			syntax_error(token, "invalid type name")
		else: highlight_colour(token, plugin.get_colour(Token.Type.TYPE))

	# If we arent using brackets we can just end here
	if not has_bracket: return end_frame( return_val )

	token = reader.get_token()

	# Check for Array Syntax
	if decl_type == &"struct":
		if token.t == &":":
			token = reader.get_token()
			if not reader.is_integer(token.t):
				syntax_error(token, "Array Syntax count must be an integral value")
			token = reader.get_token()

	# Close out the brackets.
	check_token_t(token, &"]")
	return end_frame()
#endregion Type


#MARK: Enumval Decl
# │ ___                        _   ___         _
# │| __|_ _ _  _ _ ____ ____ _| | |   \ ___ __| |
# │| _|| ' \ || | '  \ V / _` | | | |) / -_) _| |
# │|___|_||_\_,_|_|_|_\_/\__,_|_| |___/\___\__|_|
# ╰───────────────────────────────────────────────
#region Enumval Decl
func parse_enumval_decl( p_token:Token ):
	# ENUMVAL_DECL = ident [ = integer_constant ]
	var frame:StackFrame = stack.top()

	var decl_name:String = frame.bindings.get(&"decl_name", StringName())
	var decl_type:String = frame.bindings.get(&"decl_type", StringName())

	reader.print_bright("Token: '%s'" % reader.peek_token().t)

	var token:Token = reader.get_token()
	reader.print_bright("Token: '%s'" % reader.peek_token().t)

	match decl_type:
		&"union":
			if check_token_type(token, Token.Type.IDENT ):
				highlight_colour(token, plugin.get_colour(Token.Type.SCALAR))

		&"enum":
			if check_token_type(token, Token.Type.IDENT ):
				if enum_types.has(decl_name):
					var enum_vals:Array[StringName] = enum_types.get(decl_name)
					enum_vals.append( token.t )
				else: return error_frame( token, "enum_types.has(decl_name) is false")

		_: return error_frame(token, "decl_type:'%s' != union | enum." % decl_type )

	p_token = reader.peek_token()
	if p_token.t == &"=":
		token = reader.get_token() # consume ='='
		token = reader.get_token() # get the value
		if not reader.is_integer(token.t):
			syntax_error(token, "enum values must be integer constants")

	return end_frame()
#endregion Enumval Decl


#MARK: Metadata
# │ __  __     _           _      _
# │|  \/  |___| |_ __ _ __| |__ _| |_ __ _
# │| |\/| / -_)  _/ _` / _` / _` |  _/ _` |
# │|_|  |_\___|\__\__,_\__,_\__,_|\__\__,_|
# ╰─────────────────────────────────────────
#region Metadata
func parse_metadata( p_token:Token ):
	#metadata = [ ( commasep( ident [:single_value ] ) ) ]
	# single_value = scalar | string_constant
	var frame:StackFrame = stack.top()

	if frame.data.get(&"next") == null:
		var token:Token = reader.get_token()
		check_token_t( token, &"(" )
		frame.data[&"next"] = &"continue"

	if frame.data.get(&"next") == &"continue":
		var token:Token = reader.get_token()

		if token.t == &")": return end_frame()
		check_token_type(token, Token.Type.IDENT )

		token = reader.get_token()
		if token.t == &":":
			token = reader.get_token()
			if not (token.type == Token.Type.SCALAR
				or token.type == Token.Type.STRING):
					syntax_error(token, "is not scalar or string constant")
		if token.t == &",": return
		if token.t == &")": return end_frame()

	syntax_error(p_token, "reached end of parse_metadata(...)")
	return end_frame()
#endregion Metadata


#MARK: Scalar
# │ ___          _
# │/ __| __ __ _| |__ _ _ _
# │\__ \/ _/ _` | / _` | '_|
# │|___/\__\__,_|_\__,_|_|
# ╰──────────────────────────
#region Scalar
func parse_scalar( p_token:Token ):
	# SCALAR = boolean_constant | integer_constant | float_constant
	var this_frame:StackFrame = stack.top()

	var token:Token = reader.get_token()
	if token.type == Token.Type.SCALAR:
		reader.get_token()
		return end_frame()
	#if token.t in user_enum_vals:
		#token.type = Token.Type.SCALAR
		#highlight( token )
		#reader.get_token()
		#return end_frame()
	#syntax_error( token, "Wanted Token.Type.SCALAR" )
	reader.adv_line()
	end_frame()
	return false
#endregion Scalar


#MARK: Object
# │  ___  _     _        _
# │ / _ \| |__ (_)___ __| |_
# │| (_) | '_ \| / -_) _|  _|
# │ \___/|_.__// \___\__|\__|
# ╰──────────|__/─────────────
#region Object
func parse_object( p_token:Token ):
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()
#endregion Object


#MARK: Single Value
# │ ___ _           _      __   __    _
# │/ __(_)_ _  __ _| |___  \ \ / /_ _| |_  _ ___
# │\__ \ | ' \/ _` | / -_)  \ V / _` | | || / -_)
# │|___/_|_||_\__, |_\___|   \_/\__,_|_|\_,_\___|
# ╰───────────|___/───────────────────────────────
#region Single Value
func parse_single_value( p_token:Token ):
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()
#endregion Single Value


#MARK: Value
# │__   __    _
# │\ \ / /_ _| |_  _ ___
# │ \ V / _` | | || / -_)
# │  \_/\__,_|_|\_,_\___|
# ╰───────────────────────
#region Value
func parse_value( p_token:Token ):
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()
#endregion Value


#MARK: Commasep
# │  ___
# │ / __|___ _ __  _ __  __ _ ___ ___ _ __
# │| (__/ _ \ '  \| '  \/ _` (_-</ -_) '_ \
# │ \___\___/_|_|_|_|_|_\__,_/__/\___| .__/
# ╰──────────────────────────────────|_|────
#region Commasep
func parse_commasep( p_token:Token ):
	# COMMASEP(x) = [ x ( , x )* ]
	var frame:StackFrame = stack.top()
	var arg_type:StackFrame.Type = frame.data.get(&"args")
	if arg_type == null:
		syntax_error(p_token, "commasep needs an argument")
		return end_frame()

	if not (p_token.type == Token.Type.IDENT || p_token.t == &","):
		return end_frame()

	if frame.data.get(&"next") == null:
		stack.push( StackFrame.new( arg_type ) )
		frame.data[&"next"] = &","
		return
	if frame.data.get(&"next") == &",":
		var token:Token = reader.get_token()
		frame.data.erase(&"return")
		if token.t != &",": return end_frame()
		frame.data.erase(&"next")
		return

	syntax_error(p_token, "Reached the end of parse_commasep(...)")
	return end_frame()

#endregion Commasep


#MARK: File Extension Decl
# │ ___ _ _       ___     _               _            ___         _
# │| __(_) |___  | __|_ _| |_ ___ _ _  __(_)___ _ _   |   \ ___ __| |
# │| _|| | / -_) | _|\ \ /  _/ -_) ' \(_-< / _ \ ' \  | |) / -_) _| |
# │|_| |_|_\___| |___/_\_\\__\___|_||_/__/_\___/_||_| |___/\___\__|_|
# ╰───────────────────────────────────────────────────────────────────
#region File Extension Decl
func parse_file_extension_decl( p_token:Token ):
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()
#endregion File Extension Decl


#MARK: File Identifier Decl
# │ ___ _ _       ___    _         _   _  __ _           ___         _
# │| __(_) |___  |_ _|__| |___ _ _| |_(_)/ _(_)___ _ _  |   \ ___ __| |
# │| _|| | / -_)  | |/ _` / -_) ' \  _| |  _| / -_) '_| | |) / -_) _| |
# │|_| |_|_\___| |___\__,_\___|_||_\__|_|_| |_\___|_|   |___/\___\__|_|
# ╰─────────────────────────────────────────────────────────────────────
#region File Identifier Decl
func parse_file_identifier_decl( p_token:Token ):
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()
#endregion File Identifier Decl


#MARK: String Constant
# │ ___ _       _              ___             _            _
# │/ __| |_ _ _(_)_ _  __ _   / __|___ _ _  __| |_ __ _ _ _| |_
# │\__ \  _| '_| | ' \/ _` | | (__/ _ \ ' \(_-<  _/ _` | ' \  _|
# │|___/\__|_| |_|_||_\__, |  \___\___/_||_/__/\__\__,_|_||_\__|
# ╰───────────────────|___/──────────────────────────────────────
#region String Constant
func parse_string_constant( p_token:Token ):
	var token:Token = reader.get_token()
	check_token_type(token, Token.Type.STRING)
	end_frame()
#endregion String Constant


#MARK: Ident
# │ ___    _         _
# │|_ _|__| |___ _ _| |_
# │ | |/ _` / -_) ' \  _|
# │|___\__,_\___|_||_\__|
# ╰───────────────────────
#region Ident
func parse_ident(p_token: Token) -> void:
	# ident = [a-zA-Z_][a-zA-Z0-9_]*
	var token := reader.get_token()

	if check_token_type(token, Token.Type.IDENT ):
		highlight(token)
		return end_frame()

	syntax_error( token, "Wanted ( IDENT )" )
	end_frame()
#endregion Ident
func                        __Digit__________________              ()->void:pass
#MARK: Digit
# │ ___  _      _ _
# │|   \(_)__ _(_) |_
# │| |) | / _` | |  _|
# │|___/|_\__, |_|\__|
# ╰───────|___/────────
#region Digit

#endregion Digit
func                        __Xdigit_________________              ()->void:pass
#MARK: Xdigit
# │__  __   _ _      _ _
# │\ \/ /__| (_)__ _(_) |_
# │ >  </ _` | / _` | |  _|
# │/_/\_\__,_|_\__, |_|\__|
# ╰────────────|___/────────
#region Xdigit

#endregion Xdigit
func                        __Dec_Integer_Constant___              ()->void:pass
#MARK: Dec Integer Constant
# │ ___           ___     _                       ___             _            _
# │|   \ ___ __  |_ _|_ _| |_ ___ __ _ ___ _ _   / __|___ _ _  __| |_ __ _ _ _| |_
# │| |) / -_) _|  | || ' \  _/ -_) _` / -_) '_| | (__/ _ \ ' \(_-<  _/ _` | ' \  _|
# │|___/\___\__| |___|_||_\__\___\__, \___|_|    \___\___/_||_/__/\__\__,_|_||_\__|
# ╰──────────────────────────────|___/──────────────────────────────────────────────
#region Dec Integer Constant

#endregion Dec Integer Constant
func                        __Hex_Integer_Constant___              ()->void:pass
#MARK: Hex Integer Constant
# │ _  _           ___     _                       ___             _            _
# │| || |_____ __ |_ _|_ _| |_ ___ __ _ ___ _ _   / __|___ _ _  __| |_ __ _ _ _| |_
# │| __ / -_) \ /  | || ' \  _/ -_) _` / -_) '_| | (__/ _ \ ' \(_-<  _/ _` | ' \  _|
# │|_||_\___/_\_\ |___|_||_\__\___\__, \___|_|    \___\___/_||_/__/\__\__,_|_||_\__|
# ╰───────────────────────────────|___/──────────────────────────────────────────────
#region Hex Integer Constant

#endregion Hex Integer Constant


#MARK: Integer Constant
# │ ___     _                       ___             _            _
# │|_ _|_ _| |_ ___ __ _ ___ _ _   / __|___ _ _  __| |_ __ _ _ _| |_
# │ | || ' \  _/ -_) _` / -_) '_| | (__/ _ \ ' \(_-<  _/ _` | ' \  _|
# │|___|_||_\__\___\__, \___|_|    \___\___/_||_/__/\__\__,_|_||_\__|
# ╰────────────────|___/──────────────────────────────────────────────
#region Integer Constant
func parse_integer_constant(p_token: Token) -> void:
	# INTEGER_CONSTANT = dec_integer_constant | hex_integer_constant
	var token:Token = reader.get_token()
	if reader.is_integer(token.t):
		highlight(token)   # colour it
		return end_frame()

	syntax_error(token, "Wanted (dec_integer_constant | hex_integer_constant)")
	end_frame()
#endregion Integer Constant


func                        __Dec_Float_Constant_____              ()->void:pass
#MARK: Dec Float Constant
# │ ___           ___ _           _      ___             _            _
# │|   \ ___ __  | __| |___  __ _| |_   / __|___ _ _  __| |_ __ _ _ _| |_
# │| |) / -_) _| | _|| / _ \/ _` |  _| | (__/ _ \ ' \(_-<  _/ _` | ' \  _|
# │|___/\___\__| |_| |_\___/\__,_|\__|  \___\___/_||_/__/\__\__,_|_||_\__|
# ╰────────────────────────────────────────────────────────────────────────
#region Dec Float Constant

#endregion Dec Float Constant
func                        __Hex_Float_Constant_____              ()->void:pass
#MARK: Hex Float Constant
# │ _  _           ___ _           _      ___             _            _
# │| || |_____ __ | __| |___  __ _| |_   / __|___ _ _  __| |_ __ _ _ _| |_
# │| __ / -_) \ / | _|| / _ \/ _` |  _| | (__/ _ \ ' \(_-<  _/ _` | ' \  _|
# │|_||_\___/_\_\ |_| |_\___/\__,_|\__|  \___\___/_||_/__/\__\__,_|_||_\__|
# ╰─────────────────────────────────────────────────────────────────────────
#region Hex Float Constant

#endregion Hex Float Constant
func                        __Special_Float_Constant_              ()->void:pass
#MARK: Special Float Constant
# │ ___              _      _   ___ _           _      ___             _            _
# │/ __|_ __  ___ __(_)__ _| | | __| |___  __ _| |_   / __|___ _ _  __| |_ __ _ _ _| |_
# │\__ \ '_ \/ -_) _| / _` | | | _|| / _ \/ _` |  _| | (__/ _ \ ' \(_-<  _/ _` | ' \  _|
# │|___/ .__/\___\__|_\__,_|_| |_| |_\___/\__,_|\__|  \___\___/_||_/__/\__\__,_|_||_\__|
# ╰────|_|───────────────────────────────────────────────────────────────────────────────
#region Special Float Constant

#endregion Special Float Constant
func                        __Float_Constant_________              ()->void:pass
#MARK: Float Constant
# │ ___ _           _      ___             _            _
# │| __| |___  __ _| |_   / __|___ _ _  __| |_ __ _ _ _| |_
# │| _|| / _ \/ _` |  _| | (__/ _ \ ' \(_-<  _/ _` | ' \  _|
# │|_| |_\___/\__,_|\__|  \___\___/_||_/__/\__\__,_|_||_\__|
# ╰──────────────────────────────────────────────────────────
#region Float Constant

#endregion Float Constant
func                        __Boolean_Constant_______              ()->void:pass
#MARK: Boolean Constant
# │ ___           _                  ___             _            _
# │| _ ) ___  ___| |___ __ _ _ _    / __|___ _ _  __| |_ __ _ _ _| |_
# │| _ \/ _ \/ _ \ / -_) _` | ' \  | (__/ _ \ ' \(_-<  _/ _` | ' \  _|
# │|___/\___/\___/_\___\__,_|_||_|  \___\___/_||_/__/\__\__,_|_||_\__|
# ╰────────────────────────────────────────────────────────────────────
#region Boolean Constant

#endregion Boolean Constant

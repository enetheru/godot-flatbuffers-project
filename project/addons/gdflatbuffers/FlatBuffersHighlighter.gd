@tool
extends EditorSyntaxHighlighter

static var _plugin : FlatBuffersPlugin

# Supporting Scripts
const Reader = preload('res://addons/gdflatbuffers/scripts/reader.gd')
const Token = preload('res://addons/gdflatbuffers/scripts/token.gd')
const Tips = preload('res://addons/gdflatbuffers/scripts/tooltips.gd')
const Regex = preload('res://addons/gdflatbuffers/scripts/regex.gd')
const StackFrame = preload('res://addons/gdflatbuffers/scripts/stackframe.gd')
const FrameStack = preload('res://addons/gdflatbuffers/scripts/framestack.gd')

static var regex :
	get():
		if regex == null: regex = Regex.new()
		return regex

# It's easier to duplicate here than it is to constantly call back to the plugin.
enum LogLevel {
	SILENT = 0,
	CRITICAL = 1,
	ERROR = 2,
	WARNING = 3,
	NOTICE = 4,
	DEBUG = 5,
	TRACE = 6,
}

func lpad( extra : int = 0 ) -> String:
	return "".lpad( stack.size() -1 + extra, '\t' )

func print_trace( message : String ):
	var colour = _plugin.colours[LogLevel.TRACE].to_html()
	print_rich( lpad() + "[color=%s]%s[/color]" % [colour, message] )

func print_log(level : LogLevel, message : String ) -> bool:
	if _plugin.verbosity < level: return false
	var colour = _plugin.colours[level].to_html()
	print_rich( "[color=%s]%s[/color]" % [colour, message] )
	return true

func log_level( level : LogLevel ) -> bool:
	return _plugin.verbosity >= level

# ██   ██ ██  ██████  ██   ██ ██      ██  ██████  ██   ██ ████████ ███████ ██████
# ██   ██ ██ ██       ██   ██ ██      ██ ██       ██   ██    ██    ██      ██   ██
# ███████ ██ ██   ███ ███████ ██      ██ ██   ███ ███████    ██    █████   ██████
# ██   ██ ██ ██    ██ ██   ██ ██      ██ ██    ██ ██   ██    ██    ██      ██   ██
# ██   ██ ██  ██████  ██   ██ ███████ ██  ██████  ██   ██    ██    ███████ ██   ██

## The current resource file
## FIXME There is no way to retrieve the current source file_name from a TextEdit.
#var resource : Resource

## The location of the current file
## FIXME There is no way to retrieve the current source file_name from a TextEdit.
#var file_location : String

## The main Reader object for this file.
var reader : Reader

## per line colour information, key is line number, value is a dictionary
var dict : Dictionary[int, Dictionary]

## current line dictionary, key is column number
var line_dict : Dictionary[int,Dictionary]

## This is to indicate not to save the stack to the next line
var error_flag : bool = false
var warning_flag : bool = false
var scan_flag : bool = false

## A block of false data which is used to expand on the stack index
var new_index_chunk : Array[bool]

## Where the Array index is the line_num, and stack_index[index] bool
## indicates whether the stack_list dictionary has an index saved.
## TODO They can probably be merged into the same field honestly.
var stack_index : Array[bool] = [false]

## The line number that the stack was restored from.
var prev_idx : int = 0

## saved stacks, key is line number
# TODO: I wonder if we can keep the stack in the highlight cache.
var stack_list : Dictionary[int, FrameStack] = {}


#           ██ ███    ██ ██ ████████
#           ██ ████   ██ ██    ██
#           ██ ██ ██  ██ ██    ██
#           ██ ██  ██ ██ ██    ██
#   ███████ ██ ██   ████ ██    ██

func _init( plugin : FlatBuffersPlugin = null ):
	if not _plugin and plugin:
		_plugin = plugin

	# Fix up the scalar types list
	scalar_types = integer_types + float_types + boolean_types

	if not regex: assert(false, "Unable to fetch regex class")

	new_index_chunk.resize(10)
	new_index_chunk.fill(false)

	reader = Reader.new(self)
	stack = FrameStack.new(20) # TODO evaluate: 20 should be enough for now?

	# This saves us from having to highlight everything manually.
	reader.new_token.connect(func( token : Reader.Token ):
		loop_detection = 0
		highlight( token )
		if log_level(LogLevel.TRACE):
			var colour = _plugin.colours[token.type].to_html()
			print_rich( lpad() + "\t[color=%s]%s[/color]" % [colour, token] )
	)
	reader.newline.connect( func(l,p):
		if error_flag: return
		save_stack(l, 0)
	)

	print_log(LogLevel.TRACE, "[b]FlatBuffersHighlighter._init() - Completed[/b]")


# Override methods for EditorSyntaxHighlighter
func _get_name ( ) -> String:
	return "FlatBuffersSchema"


func _get_supported_languages ( ) -> PackedStringArray:
	return ["FlatBuffersSchema", "fbs"]


# Override methods for Syntax Highlighter
func _clear_highlighting_cache ( ):
	#resource = get_edited_resource()
	# file_location = resource.resource_path.get_base_dir() + "/"
	# FIXME: This ^^ relies on a patch

	print_log(LogLevel.TRACE, "[b]_clear_highlighting_cache( )[/b]")

	dict.clear()
	error_flag = false
	warning_flag = false
	scan_flag = false
	for line_num in range( get_text_edit().get_line_count() ):
		get_text_edit().set_line_background_color(line_num, Color(0,0,0,0) )


	stack_list.clear()
	stack_index.resize( get_text_edit().text.length() + 10 )
	stack_index.fill(false)

	# clear types
	included_files.clear()
	struct_types.clear()
	table_types.clear()
	union_types.clear()
	enum_types.clear()


# This function runs on any change, with the line number that is edited.
# we can use it to update the highlighting.
func _get_line_syntax_highlighting ( line_num : int ) -> Dictionary:
	if log_level(LogLevel.TRACE):
		print()
		print_log(LogLevel.TRACE, "[b]_get_line_syntax_highlighting( line_num:%d )[/b]" % [line_num+1] )

	# Reset Variables
	line_dict = {}
	prev_stack = null
	prev_idx = 0
	stack.clear()
	dict[line_num] = line_dict
	# Clear highlighting
	get_text_edit().set_line_background_color(line_num, Color(0,0,0,0) )

	if not scan_flag:
		quick_scan_text( get_text_edit().text )

	# Stack_index.size() needs to be at least as large as the line number we are looking at.
	# Increasing it this way saves re-allocating all at once at the beginning.
	while stack_index.size() < line_num: stack_index.append_array(new_index_chunk)
	stack_index[line_num] = false

	# skip empty lines
	var line = get_text_edit().get_line( line_num )
	if line.is_empty(): return {}

	# reset the reader
	reader.reset( line, line_num )

	# easy tokens
	var token := reader.peek_token(false)
	print_log( LogLevel.TRACE, str(token) )
	match token.type:
		Token.Type.COMMENT:
			highlight(token)
			return line_dict
		Token.Type.EOL:
			return {}
		Token.Type.EOF:
			return {}

	## get the previous stack save, skip lines with empty stacks.
	prev_stack = get_prev_stack( line_num )

	if prev_stack:
		print_log( LogLevel.DEBUG, "Restoring stack from line %d" % [prev_idx + 1] )
		stack = prev_stack.duplicate(true)

	# Parse the line
	if stack.is_empty():
		stack.push( StackFrame.new(StackFrame.Type.SCHEMA) )

	print_log(LogLevel.TRACE, "Stack:%s\n" % stack )

	parse()

	return line_dict


func _update_cache ( ):
	# Get settings
	print_log(LogLevel.TRACE, "[b]_update_cache( )[/b]")
	quick_scan_text( get_text_edit().text )

	get_text_edit().set_tooltip_request_func( func( word ):
		var tip = Tips.keywords.get(word)
		return  tip if tip else ""
		)


func highlight( token : Reader.Token, override : Color = Color.ORANGE ):
	line_dict[token.col] = { 'color':_plugin.colours.get( token.type, override ) }
	if not (error_flag or warning_flag):
		get_text_edit().set_line_background_color(reader.line_n, Color(0,0,0,0) )


func syntax_warning( token : Reader.Token, reason = "" ):
	warning_flag = true
	var colour : Color = _plugin.colours[_plugin.LogLevel.WARNING]
	if _plugin.highlight_warning:
		get_text_edit().set_line_background_color(reader.line_n, colour.blend(Color(0,0,0,.5)) )
	else: line_dict[token.col] = { 'color':colour }
	if log_level(LogLevel.WARNING):
		var frame_type = '#' if stack.is_empty() else StackFrame.Type.find_key(stack.top().type)
		print_log( LogLevel.WARNING, "%s:Warning in: %s - %s" % [frame_type, token, reason] )
		print_log( LogLevel.DEBUG, str(stack) )


func syntax_error( token : Reader.Token, reason = "" ):
	error_flag = true
	var colour : Color = _plugin.colours[_plugin.LogLevel.ERROR]
	if _plugin.highlight_error:
		get_text_edit().set_line_background_color(reader.line_n, colour.blend(Color(0,0,0,.5)) )
	else: line_dict[token.col] = { 'color':colour }
	if log_level(LogLevel.ERROR):
		var frame_type = '#' if stack.is_empty() else StackFrame.Type.find_key(stack.top().type)
		print_log( LogLevel.ERROR, "%s:Error in: %s - %s" % [frame_type, token, reason] )
		print_log( LogLevel.DEBUG, str(stack) )

# ██████   █████  ██████  ███████ ███████ ██████
# ██   ██ ██   ██ ██   ██ ██      ██      ██   ██
# ██████  ███████ ██████  ███████ █████   ██████
# ██      ██   ██ ██   ██      ██ ██      ██   ██
# ██      ██   ██ ██   ██ ███████ ███████ ██   ██


var keywords : Array[StringName] = [
	&'include', &'namespace', &'table', &'struct', &'enum',
	&'union', &'root_type', &'file_extension', &'file_identifier', &'attribute',
	&'rpc_service']

var integer_types : Array[StringName] = [
	&"byte", &"ubyte", &"short", &"ushort", &"int", &"uint", &"long", &"ulong",
	&"int8", &"uint8", &"int16", &"uint16", &"int32", &"uint32", &"int64", &"uint64"]

var float_types : Array[StringName] = [&"float", &"double", &"float32", &"float64"]

var boolean_types : Array[StringName] = [&"bool"]

var array_types: Array[StringName] = [
	&"string",
	&"String",
	&"StringName",
	&"NodePath", ]

## NEEDS TO BE SET IN _INIT()
var scalar_types: Array[StringName] # integer_types + float_types + boolean_types

## Defined by the flatbuffer schemas as they are parsed.
var included_files : Array = []
var enum_types : Dictionary = {}
var union_types : Array[StringName] = []
var struct_types: Array[StringName] = []
var table_types: Array[StringName] = []


var parse_funcs : Dictionary = {
	StackFrame.Type.NONE : syntax_error,
	StackFrame.Type.SCHEMA : parse_schema,
	StackFrame.Type.INCLUDE : parse_include,
	StackFrame.Type.NAMESPACE_DECL : parse_namespace_decl,
	StackFrame.Type.ATTRIBUTE_DECL : parse_attribute_decl,
	StackFrame.Type.TYPE_DECL : parse_type_decl,
	StackFrame.Type.ENUM_DECL : parse_enum_decl,
	StackFrame.Type.ROOT_DECL : parse_root_decl,
	StackFrame.Type.FIELD_DECL : parse_field_decl,
	StackFrame.Type.RPC_DECL : parse_rpc_decl,
	StackFrame.Type.RPC_METHOD : parse_rpc_method,
	StackFrame.Type.TYPE : parse_type,
	StackFrame.Type.ENUMVAL_DECL : parse_enumval_decl,
	StackFrame.Type.METADATA : parse_metadata,
	StackFrame.Type.SCALAR : parse_scalar,
	StackFrame.Type.OBJECT : parse_object,
	StackFrame.Type.SINGLE_VALUE : parse_single_value,
	StackFrame.Type.VALUE : parse_value,
	StackFrame.Type.COMMASEP : parse_commasep,
	StackFrame.Type.FILE_EXTENSION_DECL : parse_file_extension_decl,
	StackFrame.Type.FILE_IDENTIFIER_DECL : parse_file_identifier_decl,
	StackFrame.Type.STRING_CONSTANT : parse_string_constant,
	StackFrame.Type.IDENT : parse_ident,
	#StackFrame.Type.DIGIT : parse_digit,
	#StackFrame.Type.XDIGIT : parse_xdigit,
	#StackFrame.Type.DEC_INTEGER_CONSTANT : parse_dec_integer_constant,
	#StackFrame.Type.HEX_INTEGER_CONSTANT : parse_hex_integer_constant,
	StackFrame.Type.INTEGER_CONSTANT : parse_integer_constant,
	#StackFrame.Type.DEC_FLOAT_CONSTANT : parse_dec_float_constant,
	#StackFrame.Type.HEX_FLOAT_CONSTANT : parse_hex_float_constant,
	#StackFrame.Type.SPECIAL_FLOAT_CONSTANT : parse_special_float_constant,
	#StackFrame.Type.FLOAT_CONSTANT : parse_float_constant,
	#StackFrame.Type.BOOLEAN_CONSTANT : parse_boolean_constant,
}

var kw_frame_map : Dictionary[StringName, StackFrame.Type] = {
	&'include' : StackFrame.Type.INCLUDE,
	&'namespace' : StackFrame.Type.NAMESPACE_DECL,
	&'table' : StackFrame.Type.TYPE_DECL,
	&'struct' : StackFrame.Type.TYPE_DECL,
	&'enum' : StackFrame.Type.ENUM_DECL,
	&'union' : StackFrame.Type.ENUM_DECL,
	&'root_type' : StackFrame.Type.ROOT_DECL,
	&'file_extension' : StackFrame.Type.FILE_EXTENSION_DECL,
	&'file_identifier' : StackFrame.Type.FILE_IDENTIFIER_DECL,
	&'attribute' : StackFrame.Type.ATTRIBUTE_DECL,
	&'rpc_service' : StackFrame.Type.RPC_DECL,
}

var prev_stack : FrameStack
var stack : FrameStack


## start_frame() runs the appropriate stack frame function
func start_frame( frame : StackFrame, args ):
	if log_level( LogLevel.TRACE ):
		var msg : Array = [
			"" if frame.data.is_empty() else "⮱Resume:",
			frame,
			JSON.stringify( args ) ]
		print_trace( " ".join(msg) )
	parse_funcs[ frame.type ].call( args )


## end_frame() pops the last stackframe from the stack
## if retval is not null, the top stack frame will have 'return' = retval added
func end_frame( retval = null ):
	print_trace( "⮶Return%s" % [" '%s'" % retval if retval else ""] )
	stack.pop()
	if not stack.is_empty() && retval: stack.top().data['return'] = retval


func save_stack( line_num : int, cursor_pos : int = 0 ):
	if prev_stack:
		if stack.size() == prev_stack.size():
			return
	## FIXME: why would it matter if the stack sizes are the same? what if they are uniquely different?
	##        I think perhaps I wasnt storing data in the stack before.
	## I'd rather have a modified flag to see if the stack is changed.

	if stack_index.size() < line_num: stack_index.append_array( new_index_chunk )
	stack_list[line_num] = stack.duplicate(true)
	stack_index[line_num] = true
	print_log( LogLevel.TRACE, "Stack saved to line %s" % [line_num+1] )
	print_log( LogLevel.TRACE, "Saved: %s" % [stack_list[line_num]] )


## get the previous stack save, skip lines with empty stacks.
func get_prev_stack( line_num : int ) -> FrameStack:
	prev_idx = line_num
	prev_stack = null
	while prev_idx > 0 and not prev_stack:
		prev_idx -= 1
		if not stack_index[prev_idx]: continue
		prev_stack = stack_list.get( prev_idx )

	return prev_stack

## returns true if token.t == t
func check_token_t( token : Reader.Token, t : StringName, msg : String = "" ) -> bool:
	if token.t == t: return true
	var error_msg = "'%s' != '%s'" % [ token.t, t ]
	syntax_error( token, error_msg )
	if not msg.is_empty(): print_log( LogLevel.ERROR, msg )
	return false

## returns true if token.type == type
func check_token_type( token : Reader.Token, type : Token.Type, msg : String = "" ) -> bool:
	if token.type == type: return true
	var error_msg = "'%s' != '%s'" % [
		Token.Type.find_key(token.type),
		Token.Type.find_key(type)
	]
	syntax_error( token, error_msg )
	if not msg.is_empty(): print_log( LogLevel.ERROR, msg )
	return false

#   ██████   █████  ██████  ███████ ███████
#   ██   ██ ██   ██ ██   ██ ██      ██
#   ██████  ███████ ██████  ███████ █████
#   ██      ██   ██ ██   ██      ██ ██
#   ██      ██   ██ ██   ██ ███████ ███████

var loop_detection : int = 0
func parse():
	if stack.is_empty(): return

	loop_detection = 0
	var end : bool = false # allow the end to be reached once so that EOF/EOL can be read by frames.
	while not stack.is_empty():
		# Loop detection is reset when reader.new_token is triggered
		loop_detection += 1
		assert(loop_detection < 10, "Loop Detected")

		# Break on end of file the second time,
		# the first time we let the EOF through.
		if reader.at_end():
			if end: break
			end = true

		start_frame( stack.top(), reader.peek_token() )

	print_log(LogLevel.TRACE, "")
	save_stack(reader.line_n, 0 )

# ███████  ██████ ██   ██ ███████ ███    ███  █████
# ██      ██      ██   ██ ██      ████  ████ ██   ██
# ███████ ██      ███████ █████   ██ ████ ██ ███████
#      ██ ██      ██   ██ ██      ██  ██  ██ ██   ██
# ███████  ██████ ██   ██ ███████ ██      ██ ██   ██

func parse_schema( p_token : Reader.Token ):
	#schema # = include* ( namespace_decl | type_decl | enum_decl | root_decl
	#					 | file_extension_decl | file_identifier_decl
	#					 | attribute_decl | rpc_decl | object )*
	var frame : StackFrame = stack.top()

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


# ██ ███    ██  ██████ ██      ██    ██ ██████  ███████
# ██ ████   ██ ██      ██      ██    ██ ██   ██ ██
# ██ ██ ██  ██ ██      ██      ██    ██ ██   ██ █████
# ██ ██  ██ ██ ██      ██      ██    ██ ██   ██ ██
# ██ ██   ████  ██████ ███████  ██████  ██████  ███████

func parse_include( p_token : Reader.Token ):
	# INCLUDE = include string_constant ;
	var frame : StackFrame = stack.top()

	var token : Reader.Token = reader.get_token()
	check_token_t(token, &'include')

	token = reader.get_token()
	if check_token_type(token, Token.Type.STRING ):
		var filename: String = token.t.substr(1, token.t.length() -2)

		if not using_file( filename ):
			syntax_error(token, "Unable to locate file: %s" % filename )

	token = reader.get_token()
	check_token_t(token, &";")
	return end_frame()


# ███    ██  █████  ███    ███ ███████ ███████ ██████   █████   ██████ ███████
# ████   ██ ██   ██ ████  ████ ██      ██      ██   ██ ██   ██ ██      ██
# ██ ██  ██ ███████ ██ ████ ██ █████   ███████ ██████  ███████ ██      █████
# ██  ██ ██ ██   ██ ██  ██  ██ ██           ██ ██      ██   ██ ██      ██
# ██   ████ ██   ██ ██      ██ ███████ ███████ ██      ██   ██  ██████ ███████

func parse_namespace_decl( p_token : Reader.Token ):
	#NAMESPACE_DECL = namespace ident ( . ident )* ;
	var frame : StackFrame = stack.top()

	var token : Reader.Token = reader.get_token()
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


#  █████  ████████ ████████ ██████  ██ ██████  ██    ██ ████████ ███████
# ██   ██    ██       ██    ██   ██ ██ ██   ██ ██    ██    ██    ██
# ███████    ██       ██    ██████  ██ ██████  ██    ██    ██    █████
# ██   ██    ██       ██    ██   ██ ██ ██   ██ ██    ██    ██    ██
# ██   ██    ██       ██    ██   ██ ██ ██████   ██████     ██    ███████

func parse_attribute_decl( p_token : Reader.Token ):
	# ATTRIBUTE_DECL = attribute ident | "</tt>ident<tt>" ;
	var frame : StackFrame = stack.top()

	var token : Reader.Token = reader.get_token()
	check_token_t(token, &"attribute")

	token = reader.get_token()
	match token.type:
		Token.Type.IDENT: pass
		Token.Type.STRING:pass
		_: syntax_error(token, "Wanted 'ident | string_constant'")

	token = reader.get_token()
	check_token_t(token, &";")
	return end_frame()


# ████████ ██    ██ ██████  ███████         ██████  ███████  ██████ ██
#    ██     ██  ██  ██   ██ ██              ██   ██ ██      ██      ██
#    ██      ████   ██████  █████           ██   ██ █████   ██      ██
#    ██       ██    ██      ██              ██   ██ ██      ██      ██
#    ██       ██    ██      ███████ ███████ ██████  ███████  ██████ ███████

func parse_type_decl( p_token : Reader.Token ):
	#type_decl = ( table | struct ) ident [metadata] { field_decl+ }\
	var frame : StackFrame = stack.top()

	var decl_type : StringName = frame.data.get(&"decl_type", StringName())

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
		if token.eof() : return
		check_token_t( token, &"{" )
		frame.data[&'next'] = &'field_decl'

		# update p_token to continue
		p_token = reader.peek_token()

	if frame.data.get(&'next') == &'field_decl':
		if p_token.eof() : return
		if p_token.t != &"}":
			stack.push( StackFrame.new( StackFrame.Type.FIELD_DECL, {&"decl_type":decl_type} ) )
			return
		reader.get_token() # Consume the }
		end_frame()
		return

	syntax_error(p_token, "reached end of parse_type_decl(...)")
	return end_frame()

# ███████ ███    ██ ██    ██ ███    ███         ██████  ███████  ██████ ██
# ██      ████   ██ ██    ██ ████  ████         ██   ██ ██      ██      ██
# █████   ██ ██  ██ ██    ██ ██ ████ ██         ██   ██ █████   ██      ██
# ██      ██  ██ ██ ██    ██ ██  ██  ██         ██   ██ ██      ██      ██
# ███████ ██   ████  ██████  ██      ██ ███████ ██████  ███████  ██████ ███████

func parse_enum_decl( p_token : Reader.Token ):
	#enum_decl = ( enum ident : type | union ident ) metadata { commasep( enumval_decl ) }
	var frame : StackFrame = stack.top()

	var decl_type : StringName = frame.data.get(&"decl_type", StringName())
	var decl_name : StringName = frame.data.get(&"decl_name", StringName())

	if frame.data.get(&"next") == null:
		frame.data[&'next'] = &'meta'

		var token : Reader.Token = reader.get_token()
		if not token.t in [&'union', &'enum']:
			syntax_error(token, "wanted ( enum | union )")
		else:
			decl_type = token.t
			frame.data[&"decl_type"] = decl_type

		# ident
		token = reader.get_token()
		if check_token_type(token, Token.Type.IDENT):
			match decl_type:
				&"union" : union_types.append(token.t)
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
		var token : Reader.Token = reader.get_token()
		if token.eof(): return
		frame.data[&'next'] = &'enumval_decl'
		check_token_t(token, &"{")
		p_token = reader.peek_token()

	if frame.data.get(&'next') == &'enumval_decl':
		# Newlines are ok at the beginning/end
		if p_token.eof() : return
		if p_token.t == &"}":
			reader.get_token() # Consume the }
			return end_frame()

		if check_token_type( p_token, Token.Type.IDENT ):
			frame.data[&"next"] = &"comma"
			match decl_type:
				&"union": stack.push( StackFrame.new( StackFrame.Type.ENUMVAL_DECL,
					{ &"decl_type":decl_type } ) )
				&"enum": stack.push( StackFrame.new( StackFrame.Type.ENUMVAL_DECL,
					{ &"decl_type":decl_type, &"decl_name":decl_name } ) )
			return

		reader.adv_token(p_token) # move on
		return

	if frame.data.get(&"next") == &"comma":

		var token : Reader.Token = reader.get_token()
		if token.eof() :return
		frame.data[&"next"] = &"enumval_decl"
		match p_token.t:
			&"}": return end_frame()
			&",": return
			_: syntax_error(token)

	syntax_error(p_token, "reached end of parse_enum_val( ... )" )
	return end_frame()


# ██████   ██████   ██████  ████████      ██████  ███████  ██████ ██
# ██   ██ ██    ██ ██    ██    ██         ██   ██ ██      ██      ██
# ██████  ██    ██ ██    ██    ██         ██   ██ █████   ██      ██
# ██   ██ ██    ██ ██    ██    ██         ██   ██ ██      ██      ██
# ██   ██  ██████   ██████     ██ ███████ ██████  ███████  ██████ ███████

func parse_root_decl( p_token : Reader.Token ):
	# ROOT_DECL = root_type ident ;
	var frame : StackFrame = stack.top()

	var token : Reader.Token = reader.get_token()
	check_token_t(token, &"root_type")

	token = reader.get_token()
	check_token_type(token, Token.Type.IDENT )

	token = reader.get_token()
	check_token_t(token, &";")
	return end_frame()

# ███████ ██ ███████ ██      ██████          ██████  ███████  ██████ ██
# ██      ██ ██      ██      ██   ██         ██   ██ ██      ██      ██
# █████   ██ █████   ██      ██   ██         ██   ██ █████   ██      ██
# ██      ██ ██      ██      ██   ██         ██   ██ ██      ██      ██
# ██      ██ ███████ ███████ ██████  ███████ ██████  ███████  ██████ ███████

func parse_field_decl( p_token : Reader.Token ):
	# field_decl = ident : type [ = scalar ] metadata;
	var frame : StackFrame = stack.top()

	# field_decl can start on a newline, so this function is called
	# even on empty lines.
	if p_token.eof(): return

	var decl_type : StringName = frame.bindings.get(&"decl_type", StringName())
	var field_name : StringName = frame.data.get(&"field_name", StringName())

	if frame.data.get(&"next") == null:
		var token : Reader.Token = reader.get_token()
		if check_token_type(token, Token.Type.IDENT):
			field_name = token.t
			frame.data[&"field_name"] = token.t

		# TODO is this token already named in the type_decl?
		# I would need to fetch the parent frame and check if it is in the named list.
		# and add the name to the list.

		token = reader.get_token()
		if token.eof() : return
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
			var token : Reader.Token = reader.get_token()
			var return_val : Dictionary = frame.data.get(&"return")
			frame.data.erase(&"return")
			if return_val.get(&"field_type") == &"enum":
				var enum_vals : Array[StringName] = enum_types.get(return_val.get(&"field_name"))
				if not token.t in enum_vals:
					syntax_error(token, "value not found in enum")
				else:
					highlight(token, _plugin.colours[Token.Type.SCALAR])
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
		var token : Reader.Token = reader.get_token()
		check_token_t(token, &";")
		return end_frame()

	syntax_error(p_token, "reached end of parse_type_decl(...)")
	return end_frame()

#   ██████  ██████   ██████         ██████  ███████  ██████ ██
#   ██   ██ ██   ██ ██              ██   ██ ██      ██      ██
#   ██████  ██████  ██              ██   ██ █████   ██      ██
#   ██   ██ ██      ██              ██   ██ ██      ██      ██
#   ██   ██ ██       ██████ ███████ ██████  ███████  ██████ ███████

func parse_rpc_decl( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.top()
	syntax_warning( p_token, &"Unimplemented")
	reader.adv_line()
	return end_frame()

#   ██████  ██████   ██████         ███    ███ ███████ ████████ ██   ██
#   ██   ██ ██   ██ ██              ████  ████ ██         ██    ██   ██
#   ██████  ██████  ██              ██ ████ ██ █████      ██    ███████
#   ██   ██ ██      ██              ██  ██  ██ ██         ██    ██   ██
#   ██   ██ ██       ██████ ███████ ██      ██ ███████    ██    ██   ██

func parse_rpc_method( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.top()
	syntax_warning( p_token, &"Unimplemented")
	reader.adv_line()
	return end_frame()

#   ████████ ██    ██ ██████  ███████
#      ██     ██  ██  ██   ██ ██
#      ██      ████   ██████  █████
#      ██       ██    ██      ██
#      ██       ██    ██      ███████

func parse_type( p_token : Reader.Token ):
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

	var frame : StackFrame = stack.top()

	# Find the type_decl frame and determine what we are parsing.
	var decl_type : StringName = frame.bindings.get(&"decl_type", StringName())

	# Simple parsing for enums
	if decl_type == &"enum":
		var token : Reader.Token = reader.get_token()
		if not token.t in integer_types:
			syntax_error( token, "Enum types must be an integral")
		else: highlight(token, _plugin.colours[Token.Type.TYPE])
		return end_frame()


	# compled parsing for structs and tables
	var has_bracket : bool = false
	var return_val : Dictionary = {
		&"field_type":StringName(),
		&"field_name":StringName()
	}

	var token : Reader.Token = reader.get_token()
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
		else: highlight(token, _plugin.colours[Token.Type.TYPE])
	elif decl_type == &"table":
		# Where table can contain vectors of any type
		if not token.t in (scalar_types + struct_types + table_types
								+ array_types + enum_types.keys() + union_types):
			syntax_error(token, "invalid type name")
		else: highlight(token, _plugin.colours[Token.Type.TYPE])

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


# ███████ ███    ██ ██    ██ ███    ███ ██    ██  █████  ██
# ██      ████   ██ ██    ██ ████  ████ ██    ██ ██   ██ ██
# █████   ██ ██  ██ ██    ██ ██ ████ ██ ██    ██ ███████ ██
# ██      ██  ██ ██ ██    ██ ██  ██  ██  ██  ██  ██   ██ ██
# ███████ ██   ████  ██████  ██      ██   ████   ██   ██ ███████

func parse_enumval_decl( p_token : Reader.Token ):
	# ENUMVAL_DECL = ident [ = integer_constant ]
	var frame : StackFrame = stack.top()

	var decl_name : String = frame.bindings.get(&"decl_name", StringName())
	var decl_type : String = frame.bindings.get(&"decl_type", StringName())

	var token : Reader.Token = reader.get_token()

	if check_token_type(token, Token.Type.IDENT ):
		if enum_types.has(decl_name):
			var enum_vals : Array[StringName] = enum_types.get(decl_name)
			enum_vals.append( token.t )
		elif decl_type == &"union":
			highlight(token, _plugin.colours[Token.Type.SCALAR])
		else: syntax_error( token )

	token = reader.peek_token()
	if token.t == &"=":
		reader.adv_token(token) # consume ='='
		token = reader.get_token()
		if not reader.is_integer(token.t):
			syntax_error(token, "enum values must be integer constants")

	return end_frame()

# ███    ███ ███████ ████████  █████  ██████   █████  ████████  █████
# ████  ████ ██         ██    ██   ██ ██   ██ ██   ██    ██    ██   ██
# ██ ████ ██ █████      ██    ███████ ██   ██ ███████    ██    ███████
# ██  ██  ██ ██         ██    ██   ██ ██   ██ ██   ██    ██    ██   ██
# ██      ██ ███████    ██    ██   ██ ██████  ██   ██    ██    ██   ██

func parse_metadata( p_token : Reader.Token ):
	#metadata = [ ( commasep( ident [ : single_value ] ) ) ]
	# single_value = scalar | string_constant
	var frame : StackFrame = stack.top()

	if frame.data.get(&"next") == null:
		var token : Reader.Token = reader.get_token()
		check_token_t( token, &"(" )
		frame.data[&"next"] = &"continue"

	if frame.data.get(&"next") == &"continue":
		var token : Reader.Token = reader.get_token()

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

#   ███████  ██████  █████  ██       █████  ██████
#   ██      ██      ██   ██ ██      ██   ██ ██   ██
#   ███████ ██      ███████ ██      ███████ ██████
#        ██ ██      ██   ██ ██      ██   ██ ██   ██
#   ███████  ██████ ██   ██ ███████ ██   ██ ██   ██

func parse_scalar( p_token : Reader.Token ):
	# SCALAR = boolean_constant | integer_constant | float_constant
	var this_frame : StackFrame = stack.top()

	var token : Reader.Token = reader.get_token()
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

#    ██████  ██████       ██ ███████  ██████ ████████
#   ██    ██ ██   ██      ██ ██      ██         ██
#   ██    ██ ██████       ██ █████   ██         ██
#   ██    ██ ██   ██ ██   ██ ██      ██         ██
#    ██████  ██████   █████  ███████  ██████    ██

func parse_object( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.top()
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()

#   ███████ ██ ███    ██  ██████  ██      ███████
#   ██      ██ ████   ██ ██       ██      ██
#   ███████ ██ ██ ██  ██ ██   ███ ██      █████
#        ██ ██ ██  ██ ██ ██    ██ ██      ██
#   ███████ ██ ██   ████  ██████  ███████ ███████

func parse_single_value( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.top()
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()

#   ██    ██  █████  ██      ██    ██ ███████
#   ██    ██ ██   ██ ██      ██    ██ ██
#   ██    ██ ███████ ██      ██    ██ █████
#    ██  ██  ██   ██ ██      ██    ██ ██
#     ████   ██   ██ ███████  ██████  ███████

func parse_value( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.top()
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()

#  ██████  ██████  ███    ███ ███    ███  █████  ███████ ███████ ██████
# ██      ██    ██ ████  ████ ████  ████ ██   ██ ██      ██      ██   ██
# ██      ██    ██ ██ ████ ██ ██ ████ ██ ███████ ███████ █████   ██████
# ██      ██    ██ ██  ██  ██ ██  ██  ██ ██   ██      ██ ██      ██
#  ██████  ██████  ██      ██ ██      ██ ██   ██ ███████ ███████ ██

func parse_commasep( p_token : Reader.Token ):
	# COMMASEP(x) = [ x ( , x )* ]
	var frame : StackFrame = stack.top()
	var arg_type : StackFrame.Type = frame.data.get(&"args")
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
		var token : Reader.Token = reader.get_token()
		frame.data.erase(&"return")
		if token.t != &",": return end_frame()
		frame.data.erase(&"next")
		return

	syntax_error(p_token, "Reached the end of parse_commasep(...)")
	return end_frame()

#   ███████ ██ ██      ███████    ███████ ██   ██ ████████
#   ██      ██ ██      ██         ██       ██ ██     ██
#   █████   ██ ██      █████      █████     ███      ██
#   ██      ██ ██      ██         ██       ██ ██     ██
#   ██      ██ ███████ ███████ ██ ███████ ██   ██    ██

func parse_file_extension_decl( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.top()
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()

#   ███████ ██ ██      ███████
#   ██      ██ ██      ██
#   █████   ██ ██      █████
#   ██      ██ ██      ██
#   ██      ██ ███████ ███████

func parse_file_identifier_decl( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.top()
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()

#   ███████ ████████ ██████  ██ ███    ██  ██████
#   ██         ██    ██   ██ ██ ████   ██ ██
#   ███████    ██    ██████  ██ ██ ██  ██ ██   ███
#        ██    ██    ██   ██ ██ ██  ██ ██ ██    ██
#   ███████    ██    ██   ██ ██ ██   ████  ██████

func parse_string_constant( p_token : Reader.Token ):
	var frame : StackFrame = stack.top()
	var token : Reader.Token = reader.get_token()

	check_token_type(token, Token.Type.STRING)

	end_frame()

#   ██ ██████  ███████ ███    ██ ████████
#   ██ ██   ██ ██      ████   ██    ██
#   ██ ██   ██ █████   ██ ██  ██    ██
#   ██ ██   ██ ██      ██  ██ ██    ██
#   ██ ██████  ███████ ██   ████    ██

func parse_ident( p_token : Reader.Token ):
	#ident = [a-zA-Z_][a-zA-Z0-9_]*
	#FIXME use regex?

	var token : Reader.Token = reader.get_token()
	check_token_type(token, Token.Type.IDENT )
	end_frame()

#   ██ ███    ██ ████████
#   ██ ████   ██    ██
#   ██ ██ ██  ██    ██
#   ██ ██  ██ ██    ██
#   ██ ██   ████    ██

func parse_integer_constant( p_token : Reader.Token ):
	# INTEGER_CONSTANT = dec_integer_constant | hex_integer_constant
	var frame : StackFrame = stack.top()

	var token : Reader.Token = reader.get_token()
	if reader.is_integer( token.t ):
		return end_frame()

	syntax_error( token, "Wanted ( dec_integer_constant | hex_integer_constant )" )
	return end_frame()


#  ██████  ██    ██ ██  ██████ ██   ██         ███████  ██████  █████  ███    ██
# ██    ██ ██    ██ ██ ██      ██  ██          ██      ██      ██   ██ ████   ██
# ██    ██ ██    ██ ██ ██      █████           ███████ ██      ███████ ██ ██  ██
# ██ ▄▄ ██ ██    ██ ██ ██      ██  ██               ██ ██      ██   ██ ██  ██ ██
#  ██████   ██████  ██  ██████ ██   ██ ███████ ███████  ██████ ██   ██ ██   ████

func using_file( file_path: String ) -> String:
	#if not file_path.is_valid_filename():
		#print_log(LogLevel.ERROR, "Invalid filename: '%s'" % file_path )
		#return ""

	# a shortcut for godot things.
	if file_path == "godot.fbs": file_path = 'res://addons/gdflatbuffers/godot.fbs'

	if FileAccess.file_exists( file_path ): return file_path
	# we can only transform relative paths.
	if file_path.is_absolute_path(): return ""

	for ipath : String in _plugin.include_paths:
		var try_path = ipath.path_join(file_path)
		if FileAccess.file_exists( try_path ):
			print_log(LogLevel.DEBUG, "Found: '%s'" % try_path)
			return try_path

	print_log( LogLevel.DEBUG, "Search Locations: %s" % [_plugin.include_paths])
	return ""

func quick_scan_file( filepath : String ) -> bool:
	print_log( LogLevel.DEBUG, "[b]quick_scan_file: '%s'[/b]" % filepath)

	if not FileAccess.file_exists( filepath ):
		if print_log( LogLevel.ERROR,"Unable to locate file for inclusion: %s" % filepath):
			if filepath.is_relative_path():
				print_log( LogLevel.WARNING, "Relative Paths are only relative to project root, not their own location.")
		return false

	if filepath in included_files:
		return true # Dont create a loop
	included_files.append( filepath )

	print_log( LogLevel.DEBUG, "Including file: %s" % filepath )
	var file = FileAccess.open( filepath, FileAccess.READ )
	var content = file.get_as_text()
	quick_scan_text( content )
	return true

func quick_scan_text( text : String ):
	print_log( LogLevel.DEBUG, "[b]quick_scan_text[/b]")
	scan_flag = true

	var qreader : Reader = Reader.new(self)
	qreader.reset( text )

	while not qreader.at_end():
		var token : Reader.Token = qreader.get_token()

		# We are only interested in keywords.
		if token.type != Token.Type.KEYWORD:
			qreader.adv_line()
			continue

		# we want to include other files.
		if token.t == 'include':
			token = qreader.get_token()
			qreader.adv_line()
			if token.type != Token.Type.STRING: continue
			print_log(LogLevel.TRACE, "include %s" % token.t)
			# Strip quotes from token
			var file_path = token.t.substr( 1, token.t.length() - 2 )
			# validate the file
			file_path = using_file( file_path )
			# Scan the file
			if file_path: quick_scan_file( file_path )
			else: print_log(LogLevel.ERROR, "Invalid path: %s" % file_path)
			continue

		if token.t in ['struct', 'table', 'union']:
			var ident = qreader.get_token()
			if ident.type != Token.Type.IDENT:
				qreader.adv_line()
				continue
			print_log(LogLevel.TRACE, "%s %s" % [token.t, ident.t])
			match token.t:
				&"struct": struct_types.append(ident.t)
				&"table": table_types.append(ident.t)
				&"union": union_types.append(ident.t)
			qreader.adv_line()
			continue

		if token.t == 'enum':
			var ident = qreader.get_token()
			if ident.type != Token.Type.IDENT:
				qreader.adv_line()
				continue
			print_log(LogLevel.TRACE, "%s %s" % [token.t, ident.t])
			var enum_vals = enum_types.get(ident.t)
			if not enum_vals:
				enum_vals = Array([], TYPE_STRING_NAME, "", null)
				enum_types[ident.t] = enum_vals
			while token.t != '}':
				token = qreader.get_token()
				if token.type == Token.Type.IDENT:
					enum_vals.append( token.t )
			print_log(LogLevel.TRACE, "enum %s %s" % [ident.t, enum_vals])

		qreader.adv_line()
	#print_log( LogLevel.TRACE, "Included files: %s" % [included_files] )

@tool
extends EditorSyntaxHighlighter

static var _plugin : FlatBuffersPlugin

const Reader = preload('res://addons/gdflatbuffers/scripts/reader.gd')
const Token = preload('res://addons/gdflatbuffers/scripts/token.gd')

const REGEX = preload('res://addons/gdflatbuffers/scripts/regex.gd')
static var Regex :
	get():
		if Regex == null: Regex = REGEX.new()
		return Regex

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

func print_log(level : LogLevel, message : String ) -> bool:
	if _plugin.verbosity < level: return false
	var colour = _plugin.colours[level].to_html()
	var padding = "".lpad(stack.size()-1, '\t') if level == LogLevel.TRACE else ""
	print_rich( padding + "[color=%s]%s[/color]" % [colour, message] )
	return true

func log_level( level : LogLevel ) -> bool:
	return _plugin.verbosity >= level

#  ██████  ██████   █████  ███    ███ ███    ███  █████  ██████
# ██       ██   ██ ██   ██ ████  ████ ████  ████ ██   ██ ██   ██
# ██   ███ ██████  ███████ ██ ████ ██ ██ ████ ██ ███████ ██████
# ██    ██ ██   ██ ██   ██ ██  ██  ██ ██  ██  ██ ██   ██ ██   ██
#  ██████  ██   ██ ██   ██ ██      ██ ██      ██ ██   ██ ██   ██

enum FrameType {
	NONE, # so that SCHEMA isnt at zero which is conflated with bool
	# schema grammer : https://flatbuffers.dev/flatbuffers_grammar.html
	SCHEMA, # = include ( namespace_decl
	#					| type_decl
	#					| enum_decl
	#					| root_decl
	#					| file_extension_decl
	#					| file_identifier_decl
	#					| attribute_decl
	#					| rpc_decl
	#					| object )*
	INCLUDE,# = include string_constant ;
	NAMESPACE_DECL, # = namespace ident ( . ident )* ;
	ATTRIBUTE_DECL, # = attribute ident | "</tt>ident<tt>" ;
	TYPE_DECL, # = ( table | struct ) ident metadata { field_decl+ }
	ENUM_DECL, # = ( enum ident : type | union ident ) metadata { commasep( enumval_decl ) }
	ROOT_DECL, # = root_type ident ;
	FIELD_DECL, # = ident : type [ = scalar ] metadata ;
	RPC_DECL, # = rpc_service ident { rpc_method+ }
	RPC_METHOD, # = ident ( ident ) : ident metadata ;
	TYPE, # = bool | byte | ubyte | short | ushort | int | uint | float | long | ulong | double | int8 | uint8 | int16 | uint16 | int32 | uint32| int64 | uint64 | float32 | float64 | string | [ type ] | ident
	ENUMVAL_DECL, # = ident [ = integer_constant ]
	METADATA, # = [ ( commasep( ident [ : single_value ] ) ) ]
	SCALAR, # = boolean_constant | integer_constant | float_constant
	OBJECT, # = { commasep( ident : value ) }
	SINGLE_VALUE, # = scalar | string_constant
	VALUE, # = single_value | object | [ commasep( value ) ]
	COMMASEP, #(x) = [ x ( , x )* ]
	FILE_EXTENSION_DECL, # = file_extension string_constant ;
	FILE_IDENTIFIER_DECL, # = file_identifier string_constant ;
	STRING_CONSTANT, # = \".*?\\"
	IDENT, # = [a-zA-Z_][a-zA-Z0-9_]*
	#DIGIT, # [:digit:] = [0-9]
	#XDIGIT, # [:xdigit:] = [0-9a-fA-F]
	#DEC_INTEGER_CONSTANT, # = [-+]?[:digit:]+
	#HEX_INTEGER_CONSTANT, # = [-+]?0[xX][:xdigit:]+
	INTEGER_CONSTANT, # = dec_integer_constant | hex_integer_constant
	#DEC_FLOAT_CONSTANT, # = [-+]?(([.][:digit:]+)|([:digit:]+[.][:digit:]*)|([:digit:]+))([eE][-+]?[:digit:]+)?
	#HEX_FLOAT_CONSTANT, # = [-+]?0[xX](([.][:xdigit:]+)|([:xdigit:]+[.][:xdigit:]*)|([:xdigit:]+))([pP][-+]?[:digit:]+)
	#SPECIAL_FLOAT_CONSTANT, # = [-+]?(nan|inf|infinity)
	#FLOAT_CONSTANT, # = dec_float_constant | hex_float_constant | special_float_constant
	#BOOLEAN_CONSTANT, # = true | false
}


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
var enum_types : Dictionary = {}
var union_types : Array[StringName] = []
var struct_types: Array[StringName] = []
var table_types: Array[StringName] = []

# ██   ██ ██  ██████  ██   ██ ██      ██  ██████  ██   ██ ████████ ███████ ██████
# ██   ██ ██ ██       ██   ██ ██      ██ ██       ██   ██    ██    ██      ██   ██
# ███████ ██ ██   ███ ███████ ██      ██ ██   ███ ███████    ██    █████   ██████
# ██   ██ ██ ██    ██ ██   ██ ██      ██ ██    ██ ██   ██    ██    ██      ██   ██
# ██   ██ ██  ██████  ██   ██ ███████ ██  ██████  ██   ██    ██    ███████ ██   ██

## The current resource file
## FIXME relies on patch and not used otherwise.
## There is no way to retrieve the current source file_name.
var resource : Resource

## The location of the file, only works for absolute names that are included
## FIXME relies on the resource patch
var file_location : String

## The main Reader object for this file.
var reader : Reader

## The Reader object when performing a quick scan through the file for identifiers
var qreader : Reader

## per line stack information, key is line number, value is line dictionary
var dict : Dictionary[int, Dictionary]

## current line dictionary, key is column number
var line_dict : Dictionary[int,Dictionary]

## This is to indicate not to save the stack to the next line
var error_flag : bool = false

## Dictionary of user types retrieved from scanning document.
var user_types : Dictionary[String, int] = {}

## Dictionary of user enum values, TODO might be useful to have them named
var user_enum_vals : Dictionary = {}

## A block of false data which is used to expand on the stack index
var new_index_chunk : Array[bool]

## array index = index in stack list
## for each line in the document a flag to tell if a stack exists.
var stack_index : Array[bool] = [false]

## saved stacks, key is line number
var stack_list : Dictionary[int, Array] = {}

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

	if not Regex: Regex = REGEX.new()
	new_index_chunk.resize(10)
	new_index_chunk.fill(false)

	reader = Reader.new(self)
	qreader = Reader.new(self)

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
	included_files.clear()
	user_enum_vals.clear()
	user_types.clear()
	dict.clear()
	error_flag = false
	stack_list.clear()
	stack_index.resize( get_text_edit().text.length() + 10)
	stack_index.fill(false)
	print_log( LogLevel.TRACE, "highlight dict: %s" % JSON.stringify(dict, '\t') )

# This function runs on any change, with the line number that is edited.
# we can use it to update the highlighting.
func _get_line_syntax_highlighting ( line_num : int ) -> Dictionary:
	# Reset Variables
	line_dict = {}
	dict[line_num] = line_dict
	stack_index[line_num] = false

	# skip empty lines
	var line = get_text_edit().get_line( line_num )
	if line.is_empty(): return {}

	print_log( LogLevel.TRACE, "\n[b]Line %s[/b]" % [line_num+1] )
	print_log( LogLevel.TRACE, "stack_index[%s]: %s" % [line_num+1, stack_index[line_num]] )

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

	# get the previous stack save, skip lines with empty stacks.
	# FIXME This part takes forever.
	# I wonder if we can keep the stack in the highlight cache.
	while stack_index.size() < line_num: stack_index.append_array(new_index_chunk)
	prev_stack = []

	var stack_line : int = line_num
	while not prev_stack and stack_line > 0:
		stack_line -= 1
		if not stack_index[stack_line]: continue
		if not stack_list.has( stack_line ): continue
		prev_stack = stack_list.get( stack_line )

	#-- dictionary code
	#prev_stack = []
	#var stack_line : int = line_num
	#while not prev_stack and stack_line:
		#stack_line -= 1
		#if not dict.has( stack_line ): continue
		#line_dict = dict.get( stack_line, {} )
		#if not line_dict.has('stack'): continue
		#prev_stack = line_dict.get( 'stack' )
#
	if prev_stack: stack = prev_stack.duplicate(true)
	else: stack = Array([], TYPE_OBJECT, &"RefCounted", StackFrame)

	if print_log(LogLevel.TRACE, "Using stack from line %s" % [stack_line+1] ):
		print_log(LogLevel.TRACE, stack_to_string() )

	parse()

	return line_dict


func _update_cache ( ):
	# Get settings
	print_log(LogLevel.TRACE, "[b]_update_cache( )[/b]")
	quick_scan_text( get_text_edit().text )

func highlight( token : Reader.Token, override : Color = Color.ORANGE ):
	line_dict[token.col] = { 'color':_plugin.colours.get( token.type, override ) }

func syntax_warning( token : Reader.Token, reason = "" ):
	var colour : Color = _plugin.colours[_plugin.LogLevel.WARNING]
	line_dict[token.col] = { 'color':colour }
	if log_level(LogLevel.WARNING):
		var frame_type = FrameType.find_key(stack.back().type) if stack.size() else '#'
		print_log( LogLevel.WARNING, "%s:Warning in: %s - %s" % [frame_type, token, reason] )
		print_log( LogLevel.DEBUG, stack_to_string() )

func syntax_error( token : Reader.Token, reason = "" ):
	error_flag = true
	var colour : Color = _plugin.colours[_plugin.LogLevel.ERROR]
	line_dict[token.col] = { 'color':colour }
	if log_level(LogLevel.ERROR):
		var frame_type = FrameType.find_key(stack.back().type) if stack.size() else '#'
		print_log( LogLevel.ERROR, "%s:Error in: %s - %s" % [frame_type, token, reason] )
		print_log( LogLevel.DEBUG, stack_to_string() )

# ██████   █████  ██████  ███████ ███████ ██████
# ██   ██ ██   ██ ██   ██ ██      ██      ██   ██
# ██████  ███████ ██████  ███████ █████   ██████
# ██      ██   ██ ██   ██      ██ ██      ██   ██
# ██      ██   ██ ██   ██ ███████ ███████ ██   ██

var parse_funcs : Dictionary = {
	FrameType.NONE : syntax_error,
	FrameType.SCHEMA : parse_schema,
	FrameType.INCLUDE : parse_include,
	FrameType.NAMESPACE_DECL : parse_namespace_decl,
	FrameType.ATTRIBUTE_DECL : parse_attribute_decl,
	FrameType.TYPE_DECL : parse_type_decl,
	FrameType.ENUM_DECL : parse_enum_decl,
	FrameType.ROOT_DECL : parse_root_decl,
	FrameType.FIELD_DECL : parse_field_decl,
	FrameType.RPC_DECL : parse_rpc_decl,
	FrameType.RPC_METHOD : parse_rpc_method,
	FrameType.TYPE : parse_type,
	FrameType.ENUMVAL_DECL : parse_enumval_decl,
	FrameType.METADATA : parse_metadata,
	FrameType.SCALAR : parse_scalar,
	FrameType.OBJECT : parse_object,
	FrameType.SINGLE_VALUE : parse_single_value,
	FrameType.VALUE : parse_value,
	FrameType.COMMASEP : parse_commasep,
	FrameType.FILE_EXTENSION_DECL : parse_file_extension_decl,
	FrameType.FILE_IDENTIFIER_DECL : parse_file_identifier_decl,
	FrameType.STRING_CONSTANT : parse_string_constant,
	FrameType.IDENT : parse_ident,
	#FrameType.DIGIT : parse_digit,
	#FrameType.XDIGIT : parse_xdigit,
	#FrameType.DEC_INTEGER_CONSTANT : parse_dec_integer_constant,
	#FrameType.HEX_INTEGER_CONSTANT : parse_hex_integer_constant,
	FrameType.INTEGER_CONSTANT : parse_integer_constant,
	#FrameType.DEC_FLOAT_CONSTANT : parse_dec_float_constant,
	#FrameType.HEX_FLOAT_CONSTANT : parse_hex_float_constant,
	#FrameType.SPECIAL_FLOAT_CONSTANT : parse_special_float_constant,
	#FrameType.FLOAT_CONSTANT : parse_float_constant,
	#FrameType.BOOLEAN_CONSTANT : parse_boolean_constant,
}

var kw_frame_map : Dictionary[StringName, FrameType] = {
	&'include' : FrameType.INCLUDE,
	&'namespace' : FrameType.NAMESPACE_DECL,
	&'table' : FrameType.TYPE_DECL,
	&'struct' : FrameType.TYPE_DECL,
	&'enum' : FrameType.ENUM_DECL,
	&'union' : FrameType.ENUM_DECL,
	&'root_type' : FrameType.ROOT_DECL,
	&'file_extension' : FrameType.FILE_EXTENSION_DECL,
	&'file_identifier' : FrameType.FILE_IDENTIFIER_DECL,
	&'attribute' : FrameType.ATTRIBUTE_DECL,
	&'rpc_service' : FrameType.RPC_DECL,
}

var prev_stack : Array[StackFrame] = []
var stack : Array[StackFrame] = []

class StackFrame:
	func _init( t : FrameType ) -> void: type = t
	var type : FrameType
	var bindings : Dictionary
	var data : Dictionary

	func _to_string() -> String:
		var parts : Array = [ '/',
			FrameType.find_key(type),
			JSON.stringify( bindings ),
			JSON.stringify( data ) ]
		return "".join(parts).replace(',',', ').replace('{','{ ').replace('}',' }')


func lpad( extra : int = 0 ) -> String:
	return "".lpad( stack.size() -1 + extra, '\t' )


func push_stack( type : FrameType, bindings : Dictionary = {} ):
	var new_frame = StackFrame.new( type )
	new_frame.bindings = bindings
	print_log(LogLevel.TRACE, "Push: %s" % new_frame)
	stack.append( new_frame )


## start_frame() runs the appropriate stack frame function
func start_frame( frame : StackFrame, args ):
	if log_level( LogLevel.TRACE ):
		var msg : Array = [
			"" if frame.data.is_empty() else "⮱Resume:",
			frame,
			JSON.stringify( args ) ]
		print_log( LogLevel.TRACE, " ".join(msg) )

	parse_funcs[ frame.type ].call( args )


## end_frame() pops the last stackframe from the stack
## if retval is not null, the top stack frame will have 'return' = retval added
func end_frame( retval = null ) -> bool:
	var frame = stack.back()
	print_log( LogLevel.TRACE, "⮶End %s.end_frame(%s)" % [FrameType.find_key(frame.type), retval] )
	stack.pop_back()
	if stack.size() && retval: stack.back().data['return'] = retval
	return true

func save_stack( line_num : int, cursor_pos : int = 0 ):
	if stack.size() == prev_stack.size(): return # FIXME
	print_log( LogLevel.TRACE, "Stack saved to line %s | %s" % [line_num+1, stack_to_string( stack )] )

	#var this_dict = dict.get( line_num, {} )
	#this_dict['stack'] = copy_stack( stack )
	#dict[line_num] = this_dict
	#if verbose > 1: print_rich( "[b]Line %s |Saved: %s[/b]" % [line_num+1, stack_to_string( dict.get(line_num, {'stack':[]})['stack'] )] )

	if stack_index.size() < line_num: stack_index.append_array( new_index_chunk )
	stack_list[line_num] = stack.duplicate(true)
	stack_index[line_num] = true

func stack_to_string( _stack : Array[StackFrame] = stack ):
	var strings : Array = ["Stack:"]
	for frame in _stack:
		var data = "" if frame.data.is_empty() else frame.data
		strings.append( "  /%s%s" % [ FrameType.keys()[frame.type], data ] )
	return "\n".join( strings )

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

var loop_detection : int = 0
func parse():
	if not stack.size(): push_stack(FrameType.SCHEMA)
	loop_detection = 0
	var end : bool = false # allow the end to be reached once so that EOF/EOL can be read by frames.
	while stack.size() > 0:
		# Loop detection is reset when reader.new_token is triggered
		loop_detection += 1
		assert(loop_detection < 10, "Loop Detected")

		# Break on end of file the second time,
		# the first time we let the EOF through.
		if reader.at_end():
			if end: break
			end = true

		start_frame( stack.back(), reader.peek_token() )

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
	var frame : StackFrame = stack.back()

	if p_token.eof(): return


	if p_token.type != Token.Type.KEYWORD:
		syntax_error( p_token, "Wanted Token.Type.KEYWORD" )
		reader.adv_line()
		return

	if p_token.t == &'include':
		if frame.data.has(&'no_includes'):
			syntax_error( p_token, "Trying to use include mid file" )
			reader.adv_line()
			return
		push_stack( FrameType.INCLUDE )
		return

	frame.data[&'no_includes'] = true
	push_stack( kw_frame_map.get( p_token.t ))

# ██ ███    ██  ██████ ██      ██    ██ ██████  ███████
# ██ ████   ██ ██      ██      ██    ██ ██   ██ ██
# ██ ██ ██  ██ ██      ██      ██    ██ ██   ██ █████
# ██ ██  ██ ██ ██      ██      ██    ██ ██   ██ ██
# ██ ██   ████  ██████ ███████  ██████  ██████  ███████

func parse_include( p_token : Reader.Token ):
	# INCLUDE = include string_constant ;
	var frame : StackFrame = stack.back()

	var token : Reader.Token = reader.get_token()
	check_token_t(token, &'include')

	token = reader.get_token()
	if check_token_type(token, Token.Type.STRING ):
		var filename: String = token.t.substr(1, token.t.length() -2)

		if not using_file( filename ):
			syntax_error(token, "Unable to locate file: %s" % filename )

	token = reader.get_token()
	check_token_t(token, &';')
	return end_frame()


# ███    ██  █████  ███    ███ ███████ ███████ ██████   █████   ██████ ███████
# ████   ██ ██   ██ ████  ████ ██      ██      ██   ██ ██   ██ ██      ██
# ██ ██  ██ ███████ ██ ████ ██ █████   ███████ ██████  ███████ ██      █████
# ██  ██ ██ ██   ██ ██  ██  ██ ██           ██ ██      ██   ██ ██      ██
# ██   ████ ██   ██ ██      ██ ███████ ███████ ██      ██   ██  ██████ ███████

func parse_namespace_decl( p_token : Reader.Token ):
	#NAMESPACE_DECL = namespace ident ( . ident )* ;
	var frame : StackFrame = stack.back()

	var token : Reader.Token = reader.get_token()
	check_token_t(token, &'namespace')

	while true:
		token = reader.get_token()
		check_token_type(token, Token.Type.IDENT)

		token = reader.peek_token()
		if token.t == &'.':
			reader.get_token()
			continue
		else: break

	token = reader.get_token()
	check_token_t(token, &';')
	return end_frame()


#  █████  ████████ ████████ ██████  ██ ██████  ██    ██ ████████ ███████
# ██   ██    ██       ██    ██   ██ ██ ██   ██ ██    ██    ██    ██
# ███████    ██       ██    ██████  ██ ██████  ██    ██    ██    █████
# ██   ██    ██       ██    ██   ██ ██ ██   ██ ██    ██    ██    ██
# ██   ██    ██       ██    ██   ██ ██ ██████   ██████     ██    ███████

func parse_attribute_decl( p_token : Reader.Token ):
	# ATTRIBUTE_DECL = attribute ident | "</tt>ident<tt>" ;
	var frame : StackFrame = stack.back()

	var token : Reader.Token = reader.get_token()
	check_token_t(token, &'attribute')

	token = reader.get_token()
	match token.type:
		Token.Type.IDENT: pass
		Token.Type.STRING:pass
		_: syntax_error(token, "Wanted 'ident | string_constant'")

	token = reader.get_token()
	check_token_t(token, &';')
	return end_frame()


# ████████ ██    ██ ██████  ███████         ██████  ███████  ██████ ██
#    ██     ██  ██  ██   ██ ██              ██   ██ ██      ██      ██
#    ██      ████   ██████  █████           ██   ██ █████   ██      ██
#    ██       ██    ██      ██              ██   ██ ██      ██      ██
#    ██       ██    ██      ███████ ███████ ██████  ███████  ██████ ███████

func parse_type_decl( p_token : Reader.Token ):
	#type_decl = ( table | struct ) ident [metadata] { field_decl+ }\
	var frame : StackFrame = stack.back()

	var decl_type : StringName = frame.data.get(&'decl_type', StringName())

	if frame.data.get(&'next') == null:
		var token = reader.get_token()
		if token.t not in [&'table',&'struct']:
			syntax_error(token, "wanted ( table | struct )")
		else:
			decl_type = token.t
			frame.data[&'decl_type'] = token.t

		token = reader.get_token()
		check_token_type(token, Token.Type.IDENT )
		# add token to appropriate array
		match decl_type:
			&"struct": struct_types.append(token.t)
			&"table": table_types.append(token.t)

		# We dont want to consume the next token.
		token = reader.peek_token()
		if token.t == &'(':
			frame.data[&'next'] = &'{'
			push_stack( FrameType.METADATA )
			return

		frame.data[&'next'] = &'{'
		# can immediately continue

	if frame.data.get(&'next') == &'{':
		var token = reader.get_token()
		if token.eof() : return
		check_token_t( token, &'{' )
		frame.data[&'next'] = &'field_decl'

		# update p_token to continue
		p_token = reader.peek_token()

	if frame.data.get(&'next') == &'field_decl':
		if p_token.eof() : return
		if p_token.t != &'}':
			push_stack( FrameType.FIELD_DECL, {&'decl_type':decl_type} )
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
	var frame : StackFrame = stack.back()

	var decl_type : StringName = frame.data.get(&'decl_type', StringName())
	var decl_name : StringName = frame.data.get(&'decl_name', StringName())

	if frame.data.get(&'next') == null:
		frame.data[&'next'] = &'meta'

		var token : Reader.Token = reader.get_token()
		if not token.t in [&'union', &'enum']:
			syntax_error(token, "wanted ( enum | union )")
		else:
			decl_type = token.t
			frame.data[&'decl_type'] = decl_type

		# ident
		token = reader.get_token()
		if check_token_type(token, Token.Type.IDENT):
			match decl_type:
				&"union" : union_types.append(token.t)
				&"enum" :
					decl_name = token.t
					frame.data[&'decl_name'] = decl_name
					enum_types[ decl_name ] = Array([], TYPE_STRING_NAME, "", null)

		token = reader.peek_token()
		if decl_type == &'enum':
			if token.t == &':':
				reader.get_token() # consume token.
				push_stack( FrameType.TYPE, { &'decl_type':decl_type } )
				return

	if frame.data.get(&'next') == &'meta':
		frame.data[&'next'] = &'{'
		if p_token.t == &'(':
			push_stack(FrameType.METADATA)
			return

	if frame.data.get(&'next') == &'{':
		var token : Reader.Token = reader.get_token()
		if token.eof(): return
		frame.data[&'next'] = &'enumval_decl'
		check_token_t(token, &'{')
		p_token = reader.peek_token()

	if frame.data.get(&'next') == &'enumval_decl':
		# Newlines are ok at the beginning/end
		if p_token.eof() : return
		if p_token.t == &'}':
			reader.get_token() # Consume the }
			return end_frame()

		if check_token_type( p_token, Token.Type.IDENT ):
			frame.data[&'next'] = &','
			match decl_type:
				&'union': push_stack( FrameType.ENUMVAL_DECL,
					{ &'decl_type':decl_type } )
				&'enum': push_stack( FrameType.ENUMVAL_DECL,
					{ &'decl_type':decl_type, &'decl_name':decl_name } )
			return

		reader.adv_token(p_token) # move on
		return

	if frame.data.get(&'next') == &',':
		var token : Reader.Token = reader.get_token()
		if token.eof() : return
		match p_token.t:
			&'}': return end_frame()
			&',': frame.data[&'next'] = &'enumval_decl'; return

	syntax_error(p_token, "reached end of parse_enum_val( ... )" )
	return end_frame()


# ██████   ██████   ██████  ████████      ██████  ███████  ██████ ██
# ██   ██ ██    ██ ██    ██    ██         ██   ██ ██      ██      ██
# ██████  ██    ██ ██    ██    ██         ██   ██ █████   ██      ██
# ██   ██ ██    ██ ██    ██    ██         ██   ██ ██      ██      ██
# ██   ██  ██████   ██████     ██ ███████ ██████  ███████  ██████ ███████

func parse_root_decl( p_token : Reader.Token ):
	# ROOT_DECL = root_type ident ;
	var frame : StackFrame = stack.back()

	var token : Reader.Token = reader.get_token()
	check_token_t(token, &'root_type')

	token = reader.get_token()
	check_token_type(token, Token.Type.IDENT )

	token = reader.get_token()
	check_token_t(token, &';')
	return end_frame()

# ███████ ██ ███████ ██      ██████          ██████  ███████  ██████ ██
# ██      ██ ██      ██      ██   ██         ██   ██ ██      ██      ██
# █████   ██ █████   ██      ██   ██         ██   ██ █████   ██      ██
# ██      ██ ██      ██      ██   ██         ██   ██ ██      ██      ██
# ██      ██ ███████ ███████ ██████  ███████ ██████  ███████  ██████ ███████

func parse_field_decl( p_token : Reader.Token ):
	# field_decl = ident : type [ = scalar ] metadata;
	var frame : StackFrame = stack.back()

	# field_decl can start on a newline, so this function is called
	# even on empty lines.
	if p_token.eof(): return

	var decl_type : StringName = frame.bindings.get(&'decl_type', StringName())
	var field_name : StringName = frame.data.get(&'field_name', StringName())

	if frame.data.get(&'next') == null:
		var token : Reader.Token = reader.get_token()
		if check_token_type(token, Token.Type.IDENT):
			field_name = token.t
			frame.data[&'field_name'] = token.t

		# TODO is this token already named in the type_decl?
		# I would need to fetch the parent frame and check if it is in the named list.
		# and add the name to the list.

		token = reader.get_token()
		if token.eof() : return
		check_token_t( token, &':')

		frame.data[&'next'] = &'default'
		push_stack( FrameType.TYPE, { &'decl_type':decl_type, &'field_name':field_name } )
		return

	# Handle defaults
	p_token = reader.peek_token()
	if frame.data.get(&'next') == &'default':
		frame.data[&'next'] = &'meta'
		if p_token.t == &'=':
			reader.get_token() # consume '='
			var token : Reader.Token = reader.get_token()
			var return_val : Dictionary = frame.data.get(&'return')
			frame.data.erase(&'return')
			if return_val.get(&'field_type') == &'enum':
				var enum_vals : Array[StringName] = enum_types.get(return_val.get(&'field_name'))
				if not token.t in enum_vals:
					syntax_error(token, "value not found in enum")
				else:
					highlight(token, _plugin.colours[Token.Type.SCALAR])
			elif not reader.is_scalar(token.t):
				syntax_error(token, "Only Scalar values can have defaults")

	# meta
	if frame.data.get(&'next') == &'meta':
		frame.data[&'next'] = &';'
		if p_token.t == &'(':
			push_stack( FrameType.METADATA )
			return

	# finish
	if frame.data.get(&'next') == &';':
		var token : Reader.Token = reader.get_token()
		check_token_t(token, &';')
		return end_frame()

	syntax_error(p_token, "reached end of parse_type_decl(...)")
	return end_frame()

#   ██████  ██████   ██████         ██████  ███████  ██████ ██
#   ██   ██ ██   ██ ██              ██   ██ ██      ██      ██
#   ██████  ██████  ██              ██   ██ █████   ██      ██
#   ██   ██ ██      ██              ██   ██ ██      ██      ██
#   ██   ██ ██       ██████ ███████ ██████  ███████  ██████ ███████

func parse_rpc_decl( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.back()
	syntax_warning( p_token, &"Unimplemented")
	reader.adv_line()
	return end_frame()

#   ██████  ██████   ██████         ███    ███ ███████ ████████ ██   ██
#   ██   ██ ██   ██ ██              ████  ████ ██         ██    ██   ██
#   ██████  ██████  ██              ██ ████ ██ █████      ██    ███████
#   ██   ██ ██      ██              ██  ██  ██ ██         ██    ██   ██
#   ██   ██ ██       ██████ ███████ ██      ██ ███████    ██    ██   ██

func parse_rpc_method( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.back()
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

	var frame : StackFrame = stack.back()

	# Find the type_decl frame and determine what we are parsing.
	var decl_type : StringName = frame.bindings.get(&'decl_type', StringName())

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
		&'field_type':StringName(),
		&'field_name':StringName()
	}

	var token : Reader.Token = reader.get_token()
	# for both table and struct decl '[' is allowed
	if token.t == &'[':
		# we have either vector or array syntax
		has_bracket = true
		token = reader.get_token()

	# we need to know if the field is scalar, for when we deal with defaults.
	if token.t in scalar_types: return_val[&'field_type'] = &'scalar'
	elif token.t in enum_types:
		return_val[&'field_type'] = &'enum'
		return_val[&'field_name'] = token.t

	if decl_type == &'struct':
		if not token.t in scalar_types + struct_types + enum_types.keys():
			syntax_error(token, "struct array/vector fields may only contain scalars or other structs")
		else: highlight(token, _plugin.colours[Token.Type.TYPE])
	elif decl_type == &'table':
		# Where table can contain vectors of any type
		if not token.t in (scalar_types + struct_types + table_types
								+ array_types + enum_types.keys() + union_types):
			syntax_error(token, "invalid type name")
		else: highlight(token, _plugin.colours[Token.Type.TYPE])

	# If we arent using brackets we can just end here
	if not has_bracket: return end_frame( return_val )

	token = reader.get_token()

	# Check for Array Syntax
	if decl_type == &'struct':
		if token.t == &':':
			token = reader.get_token()
			if not reader.is_integer(token.t):
				syntax_error(token, "Array Syntax count must be an integral value")
			token = reader.get_token()

	# Close out the brackets.
	check_token_t(token, &']')
	return end_frame()


# ███████ ███    ██ ██    ██ ███    ███ ██    ██  █████  ██
# ██      ████   ██ ██    ██ ████  ████ ██    ██ ██   ██ ██
# █████   ██ ██  ██ ██    ██ ██ ████ ██ ██    ██ ███████ ██
# ██      ██  ██ ██ ██    ██ ██  ██  ██  ██  ██  ██   ██ ██
# ███████ ██   ████  ██████  ██      ██   ████   ██   ██ ███████

func parse_enumval_decl( p_token : Reader.Token ):
	# ENUMVAL_DECL = ident [ = integer_constant ]
	var frame : StackFrame = stack.back()

	var decl_name : String = frame.bindings.get(&'decl_name', StringName())
	var decl_type : String = frame.bindings.get(&'decl_type', StringName())

	var token : Reader.Token = reader.get_token()

	if check_token_type(token, Token.Type.IDENT ):
		if enum_types.has(decl_name):
			var enum_vals : Array[StringName] = enum_types.get(decl_name)
			enum_vals.append( token.t )
		elif decl_type == &'union':
			highlight(token, _plugin.colours[Token.Type.SCALAR])
		else: syntax_error( token )

	token = reader.peek_token()
	if token.t == &'=':
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
	var frame : StackFrame = stack.back()

	if frame.data.get(&'next') == null:
		var token : Reader.Token = reader.get_token()
		check_token_t( token, &'(' )
		frame.data[&'next'] = &'continue'

	if frame.data.get(&'next') == &'continue':
		var token : Reader.Token = reader.get_token()

		if token.t == &')': return end_frame()
		check_token_type(token, Token.Type.IDENT )

		token = reader.get_token()
		if token.t == &':':
			token = reader.get_token()
			if not (token.type == Token.Type.SCALAR
				or token.type == Token.Type.STRING):
					syntax_error(token, "is not scalar or string constant")
		if token.t == &',': return
		if token.t == &')': return end_frame()

	syntax_error(p_token, "reached end of parse_metadata(...)")
	return end_frame()

#   ███████  ██████  █████  ██       █████  ██████
#   ██      ██      ██   ██ ██      ██   ██ ██   ██
#   ███████ ██      ███████ ██      ███████ ██████
#        ██ ██      ██   ██ ██      ██   ██ ██   ██
#   ███████  ██████ ██   ██ ███████ ██   ██ ██   ██

func parse_scalar( p_token : Reader.Token ):
	# SCALAR = boolean_constant | integer_constant | float_constant
	var this_frame : StackFrame = stack.back()

	var token : Reader.Token = reader.get_token()
	if token.type == Token.Type.SCALAR:
		reader.get_token()
		return end_frame()
	if token.t in user_enum_vals:
		token.type = Token.Type.SCALAR
		highlight( token )
		reader.get_token()
		return end_frame()
	syntax_error( token, "Wanted Token.Type.SCALAR" )
	reader.adv_line()
	end_frame()
	return false

#    ██████  ██████       ██ ███████  ██████ ████████
#   ██    ██ ██   ██      ██ ██      ██         ██
#   ██    ██ ██████       ██ █████   ██         ██
#   ██    ██ ██   ██ ██   ██ ██      ██         ██
#    ██████  ██████   █████  ███████  ██████    ██

func parse_object( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.back()
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()

#   ███████ ██ ███    ██  ██████  ██      ███████
#   ██      ██ ████   ██ ██       ██      ██
#   ███████ ██ ██ ██  ██ ██   ███ ██      █████
#        ██ ██ ██  ██ ██ ██    ██ ██      ██
#   ███████ ██ ██   ████  ██████  ███████ ███████

func parse_single_value( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.back()
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()

#   ██    ██  █████  ██      ██    ██ ███████
#   ██    ██ ██   ██ ██      ██    ██ ██
#   ██    ██ ███████ ██      ██    ██ █████
#    ██  ██  ██   ██ ██      ██    ██ ██
#     ████   ██   ██ ███████  ██████  ███████

func parse_value( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.back()
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
	var frame : StackFrame = stack.back()
	var arg_type : FrameType = frame.data.get(&'args')
	if arg_type == null:
		syntax_error(p_token, "commasep needs an argument")
		return end_frame()

	if not (p_token.type == Token.Type.IDENT || p_token.t == &','):
		return end_frame()

	if frame.data.get(&'next') == null:
		push_stack( arg_type )
		frame.data[&'next'] = &','
		return
	if frame.data.get(&'next') == &',':
		var token : Reader.Token = reader.get_token()
		frame.data.erase(&'return')
		if token.t != &',': return end_frame()
		frame.data.erase(&'next')
		return

	syntax_error(p_token, "Reached the end of parse_commasep(...)")
	return end_frame()

#   ███████ ██ ██      ███████    ███████ ██   ██ ████████
#   ██      ██ ██      ██         ██       ██ ██     ██
#   █████   ██ ██      █████      █████     ███      ██
#   ██      ██ ██      ██         ██       ██ ██     ██
#   ██      ██ ███████ ███████ ██ ███████ ██   ██    ██

func parse_file_extension_decl( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.back()
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()

#   ███████ ██ ██      ███████
#   ██      ██ ██      ██
#   █████   ██ ██      █████
#   ██      ██ ██      ██
#   ██      ██ ███████ ███████

func parse_file_identifier_decl( p_token : Reader.Token ):
	var this_frame : StackFrame = stack.back()
	syntax_warning( p_token, &"Unimplemented" )
	reader.adv_line()
	return end_frame()

#   ███████ ████████ ██████  ██ ███    ██  ██████
#   ██         ██    ██   ██ ██ ████   ██ ██
#   ███████    ██    ██████  ██ ██ ██  ██ ██   ███
#        ██    ██    ██   ██ ██ ██  ██ ██ ██    ██
#   ███████    ██    ██   ██ ██ ██   ████  ██████

func parse_string_constant( p_token : Reader.Token ):
	var frame : StackFrame = stack.back()
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
	var frame : StackFrame = stack.back()

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

var included_files : Array = []

func using_file( file_path: String ) -> String:
	if not file_path.is_valid_filename(): return ""

	if FileAccess.file_exists( file_path ): return file_path
	# we can only transform relative paths.
	if file_path.is_absolute_path(): return ""

	for ipath : String in _plugin.include_paths:
		var try_path = ipath.path_join(file_path)
		if FileAccess.file_exists( try_path ):
			print_log(LogLevel.NOTICE, "Including: '%s'" % try_path)
			return try_path

	return ""

func quick_scan_file( filepath : String ) -> bool:
	print_log( LogLevel.TRACE, "[b]quick_scan_file: '%s'[/b]" % filepath)
	if filepath.begins_with("res://"):
		print_log( LogLevel.ERROR, "paths starting with res:// or user:// are not supported: %s" % filepath)
		return false

	# a shortcut for godot things.
	if filepath == "godot.fbs": filepath = 'res://addons/gdflatbuffers/godot.fbs'
	#elif filepath.is_relative_path():

	if not FileAccess.file_exists( filepath ):
		if print_log( LogLevel.ERROR,"Unable to locate file for inclusion: %s" % filepath):
			if filepath.is_relative_path():
				print_log( LogLevel.WARNING, "Relative Paths are only relative to project root, not their own location.")
		return false

	if filepath in included_files: return true # Dont create a loop
	included_files.append( filepath )

	print_log( LogLevel.TRACE, "Including file: %s" % filepath )
	print_log( LogLevel.TRACE, "Included files: %s" % included_files )
	var file = FileAccess.open( filepath, FileAccess.READ )
	var content = file.get_as_text()
	quick_scan_text( content )
	return true

func quick_scan_text( text : String ):
	print_log( LogLevel.TRACE, "[b]quick_scan_text[/b]")
	# I need a function which scans the source fast to pick up names before the main scan happens.
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
			if token.type != Token.Type.STRING:
				qreader.adv_line()
				continue
			var file_path : String = token.t
			quick_scan_file( file_path.substr( 1, file_path.length() - 2 ) )
			qreader.adv_line()
			continue

		if token.t in ['struct', 'table', 'union']:
			var ident = qreader.get_token()
			if ident.type != Token.Type.IDENT:
				qreader.adv_line()
				continue
			match token.t:
				&'struct': struct_types.append(ident.t)
				&'table': table_types.append(ident.t)
				&'union': union_types.append(ident.t)
			qreader.adv_line()
			continue

		if token.t == 'enum':
			var ident = qreader.get_token()
			if ident.type != Token.Type.IDENT:
				qreader.adv_line()
				continue
			if not enum_types.has(ident.t):
				enum_types[ident.t] = Array([], TYPE_STRING_NAME, "", null)

		qreader.adv_line()

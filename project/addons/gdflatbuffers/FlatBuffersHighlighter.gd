@tool
extends EditorSyntaxHighlighter

const REGEX = preload('res://addons/gdflatbuffers/scripts/regex.gd')
static var Regex

const Reader = preload('res://addons/gdflatbuffers/scripts/reader.gd')

var editor_settings : EditorSettings
var verbose : int = 0

func print_bright( _value ):
	print_rich( "[b][color=yellow]%s[/color][/b]" % [_value] )

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

var keywords : Array = [
	'include', 'namespace', 'table', 'struct', 'enum',
	'union', 'root_type', 'file_extension', 'file_identifier', 'attribute',
	'rpc_service']

var integer_types : Array = [
	"byte", "ubyte", "short", "ushort", "int", "uint", "long", "ulong",
	"int8", "uint8", "int16", "uint16", "int32", "uint32", "int64", "uint64"]

var float_types : Array = ["float", "double", "float32", "float64"]

var boolean_types : Array = ["bool"]

## NEEDS TO BE SET IN _INIT()
var scalar_types: Array # integer_types + float_types + boolean_types

var enum_types : Dictionary = {}

var union_types : Array = []

var struct_types: Array = []
	#"Vector2",
	#"Vector2i",
	#"Rect2",
	#"Rect2i",
	#"Vector3",
	#"Vector3i",
	#"Transform2D",
	#"Vector4",
	#"Vector4i",
	#"Plane",
	#"Quaternion",
	#"AABB",
	#"Basis",
	#"Transform3D",
	#"Projection",
	#"Color", ]

var table_types: Array = []

var array_types: Array = [
	"string",
	"String",
	"StringName",
	"NodePath", ]


# ██   ██ ██  ██████  ██   ██ ██      ██  ██████  ██   ██ ████████ ███████ ██████
# ██   ██ ██ ██       ██   ██ ██      ██ ██       ██   ██    ██    ██      ██   ██
# ███████ ██ ██   ███ ███████ ██      ██ ██   ███ ███████    ██    █████   ██████
# ██   ██ ██ ██    ██ ██   ██ ██      ██ ██    ██ ██   ██    ██    ██      ██   ██
# ██   ██ ██  ██████  ██   ██ ███████ ██  ██████  ██   ██    ██    ███████ ██   ██

var colours : Dictionary = {
	Reader.TokenType.UNKNOWN : Color.GREEN,
	Reader.TokenType.COMMENT : Color.DIM_GRAY,
	Reader.TokenType.KEYWORD : Color.SALMON,
	Reader.TokenType.TYPE : Color.GREEN,
	Reader.TokenType.STRING : Color.GREEN,
	Reader.TokenType.PUNCT : Color.GREEN,
	Reader.TokenType.IDENT : Color.GREEN,
	Reader.TokenType.SCALAR : Color.GREEN,
}
var error_color : Color = Color.FIREBRICK

## The current resource file
## FIXME relies on patch and not used otherwise.
var resource : Resource

## The location of the file, only works for absolute names that are included
## FIXME relies on the resource patch
var file_location : String

## The main Reader object for this file.
var reader : Reader				# the main reader

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

func _init():
	scalar_types = integer_types + float_types + boolean_types

	if not Regex: Regex = REGEX.new()
	new_index_chunk.resize(10)
	new_index_chunk.fill(false)
	editor_settings = EditorInterface.get_editor_settings()
	error_color = Color.RED

	reader = Reader.new(self)
	qreader = Reader.new(self)

	# This saves us from having to highlight everything manually.
	reader.new_token.connect(func( token ):
		loop_detection = 0
		highlight( token )
		if verbose > 1:
			var colour : Color = colours.get(token.type, Color.YELLOW )
			if verbose > 1: print_rich( lpad() + "\t[color=%s]%s[/color]" % [colour.to_html(), token] )
	)
	reader.newline.connect( func(l,p):
		if error_flag: return
		save_stack(l, 0)
	)
	#FIXME reader.endfile.connect( save_stack )
	if editor_settings:
		colours[Reader.TokenType.UNKNOWN] = editor_settings.get_setting("text_editor/theme/highlighting/text_color")
		colours[Reader.TokenType.COMMENT] = editor_settings.get_setting("text_editor/theme/highlighting/comment_color")
		colours[Reader.TokenType.KEYWORD] = editor_settings.get_setting("text_editor/theme/highlighting/keyword_color")
		colours[Reader.TokenType.TYPE] = editor_settings.get_setting("text_editor/theme/highlighting/base_type_color")
		colours[Reader.TokenType.STRING] = editor_settings.get_setting("text_editor/theme/highlighting/string_color")
		colours[Reader.TokenType.PUNCT] = editor_settings.get_setting("text_editor/theme/highlighting/text_color")
		colours[Reader.TokenType.IDENT] = editor_settings.get_setting("text_editor/theme/highlighting/symbol_color")
		colours[Reader.TokenType.SCALAR] = editor_settings.get_setting("text_editor/theme/highlighting/number_color")
		colours[Reader.TokenType.META] = editor_settings.get_setting("text_editor/theme/highlighting/text_color")
		verbose = editor_settings.get_setting( FlatBuffersPlugin.debug_verbosity )

	if verbose > 1: print_rich("[b]FlatBuffersHighlighter._init() - Completed[/b]")

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

	if verbose > 2: print_rich("[b]_clear_highlighting_cache( )[/b]")
	included_files.clear()
	user_enum_vals.clear()
	user_types.clear()
	dict.clear()
	error_flag = false
	stack_list.clear()
	stack_index.resize( get_text_edit().text.length() + 10)
	stack_index.fill(false)
	if verbose > 2: print( "highlight dict: ", JSON.stringify(dict, '\t') )

# This function runs on any change, with the line number that is edited.
# we can use it to update the highlighting.
func _get_line_syntax_highlighting ( line_num : int ) -> Dictionary:
	# Very early out for an empty line
	var line = get_text_edit().get_line( line_num )
	dict.erase(line_num)
	line_dict = {}
	stack_index[line_num] = false
	if line.is_empty():
		return {}

	if verbose > 1:
		print_rich( "\n[b]Line %s[/b]" % [line_num+1] )
		print( "stack_index[%s]: %s" % [line_num+1, stack_index[line_num]] )

	# reset the reader
	reader.reset( line, line_num )

	# skip whitespace
	reader.adv_whitespace()

	# easy tokens
	var token := reader.peek_token(false)
	print(token)
	match token.type:
		Reader.TokenType.COMMENT:
			highlight(token)
			dict[line_num] = line_dict
			return line_dict
		Reader.TokenType.EOL:
			return {}
		Reader.TokenType.EOF:
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
	stack = prev_stack.duplicate(true) if prev_stack else []

	if verbose > 1:
		print( "Using stack from line %s" % [stack_line+1] )
		print( stack_to_string() )

	parse()

	dict[line_num] = line_dict
	return line_dict


func _update_cache ( ):
	# Get settings
	verbose = editor_settings.get_setting( FlatBuffersPlugin.debug_verbosity )
	if verbose > 2: print_rich("[b]_update_cache( )[/b]")
	quick_scan_text( get_text_edit().text )
	error_color = Color.RED

func highlight( token : Reader.Token, override : Reader.TokenType = 0 ):
	if token.type not in colours: return
	line_dict[token.col] = { 'color':colours[override if override else token.type] }

func syntax_warning( token : Reader.Token, reason = "" ):
	line_dict[token.col] = { 'color':colours[Reader.TokenType.COMMENT] }
	if verbose > 0:
		var padding = "".lpad(stack.size(), '\t') if verbose > 1 else ""
		var colour = Color.ORANGE.to_html()
		var frame_type = FrameType.keys()[stack.back().type] if stack.size() else '#'
		print_rich( "\n[color=%s]%s:Warning in: %s - %s[/color]" % [colour, frame_type, token, reason] )
		if verbose > 1: print( stack_to_string() )

func syntax_error( token : Reader.Token, reason = "" ):
	error_flag = true
	if line_dict.has(token.col): line_dict.erase(token.col)
	line_dict[token.col] = { 'color':error_color }
	if verbose > 0:
		var padding = "".lpad(stack.size(), '\t') if verbose > 1 else ""
		var colour = error_color.to_html()
		var frame_type = FrameType.keys()[stack.back().type] if stack.size() else '#'
		print_rich( "\n[color=%s]%s:Error in: %s - %s[/color]" % [colour, frame_type, token, reason] )
		if verbose > 1: print( stack_to_string() + "\n" )

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

var kw_frame_map : Dictionary = {
	'include' : FrameType.INCLUDE,
	'namespace' : FrameType.NAMESPACE_DECL,
	'table' : FrameType.TYPE_DECL,
	'struct' : FrameType.TYPE_DECL,
	'enum' : FrameType.ENUM_DECL,
	'union' : FrameType.ENUM_DECL,
	'root_type' : FrameType.ROOT_DECL,
	'file_extension' : FrameType.FILE_EXTENSION_DECL,
	'file_identifier' : FrameType.FILE_IDENTIFIER_DECL,
	'attribute' : FrameType.ATTRIBUTE_DECL,
	'rpc_service' : FrameType.RPC_DECL,
}

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

var prev_stack : Array = []
var stack : Array = []

func lpad( extra : int = 0 ) -> String:
	return "".lpad( stack.size() -1 + extra, '\t' )

func push_stack( type : FrameType, bindings : Dictionary = {} ):
	var new_frame = StackFrame.new( type )
	new_frame.bindings = bindings
	print( lpad(1), "Push: ", new_frame )
	stack.append( new_frame )

## start_frame() runs the appropriate stack frame function
func start_frame( frame : StackFrame, args ):
	if verbose > 1:
		var msg : Array = [
			"⮱Start:" if frame.data.is_empty() else "⮱Resume:",
			frame,
			JSON.stringify( args ) ]
		print( lpad(), " ".join(msg) )

	parse_funcs[ frame.type ].call( args )


## end_frame() pops the last stackframe from the stack
## if retval is not null, the top stack frame will have 'return' = retval added
func end_frame( retval = null ) -> bool:
	var frame = stack.back()
	if verbose > 1:
		var type_name : String = FrameType.find_key(frame.type)
		print( lpad() + "⮶End %s.end_frame(%s)" % [type_name, retval] )
	stack.pop_back()
	if stack.size() && retval: stack.back().data['return'] = retval
	return true

func save_stack( line_num : int, cursor_pos : int = 0 ):
	if stack.size() == prev_stack.size(): return # FIXME
	if verbose > 2: print( lpad(), "Stack saved to line %s | " % [line_num+1], stack_to_string( stack ) )

	#var this_dict = dict.get( line_num, {} )
	#this_dict['stack'] = copy_stack( stack )
	#dict[line_num] = this_dict
	#if verbose > 1: print_rich( "[b]Line %s |Saved: %s[/b]" % [line_num+1, stack_to_string( dict.get(line_num, {'stack':[]})['stack'] )] )

	if stack_index.size() < line_num: stack_index.append_array( new_index_chunk )
	stack_list[line_num] = stack.duplicate(true)
	stack_index[line_num] = true

func stack_to_string( _stack : Array = stack ):
	var strings : Array = ["Stack:"]
	for frame in _stack:
		var data = "" if frame.data.is_empty() else frame.data
		strings.append( "  /%s%s" % [ FrameType.keys()[frame.type], data ] )
	return "\n".join( strings )

## returns true if token.t == t
func check_token_t( token : Reader.Token, t : String, msg : String = "" ) -> bool:
	if token.get('t') == t: return true
	var error_msg = "'%s' != '%s'" % [ token.get('t'), t ]
	syntax_error( token, error_msg )
	if not msg.is_empty(): print( lpad() + msg )
	return false

## returns true if token.type == type
func check_token_type( token : Reader.Token, type : Reader.TokenType, msg : String = "" ) -> bool:
	if token.get('type') == type: return true
	var error_msg = "'%s' != '%s'" % [
		Reader.TokenType.find_key(token.get('type')),
		Reader.TokenType.find_key(type)
	]
	syntax_error( token, error_msg )
	if not msg.is_empty(): print( lpad() + msg )
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


	if p_token.type != Reader.TokenType.KEYWORD:
		syntax_error( p_token, "Wanted Reader.TokenType.KEYWORD" )
		reader.adv_line()
		return

	if p_token.t == 'include':
		if frame.data.has('no_includes'):
			syntax_error( p_token, "Trying to use include mid file" )
			reader.adv_line()
			return
		push_stack( FrameType.INCLUDE )
		return

	frame.data['no_includes'] = true
	push_stack( kw_frame_map.get( p_token.t ))

# ██ ███    ██  ██████ ██      ██    ██ ██████  ███████
# ██ ████   ██ ██      ██      ██    ██ ██   ██ ██
# ██ ██ ██  ██ ██      ██      ██    ██ ██   ██ █████
# ██ ██  ██ ██ ██      ██      ██    ██ ██   ██ ██
# ██ ██   ████  ██████ ███████  ██████  ██████  ███████

func parse_include( p_token : Reader.Token ):
	# INCLUDE = include string_constant ;
	var frame = stack.back()

	var token = reader.get_token()
	check_token_t(token, 'include')

	token = reader.get_token()
	if check_token_type(token, Reader.TokenType.STRING ):
		var filename = token.t.substr(1, token.t.length() -2)
		if not FileAccess.file_exists( filename ):
			syntax_error(token, "Unable to locate file: %s" % filename )

	token = reader.get_token()
	check_token_t(token, ';')
	return end_frame()


# ███    ██  █████  ███    ███ ███████ ███████ ██████   █████   ██████ ███████
# ████   ██ ██   ██ ████  ████ ██      ██      ██   ██ ██   ██ ██      ██
# ██ ██  ██ ███████ ██ ████ ██ █████   ███████ ██████  ███████ ██      █████
# ██  ██ ██ ██   ██ ██  ██  ██ ██           ██ ██      ██   ██ ██      ██
# ██   ████ ██   ██ ██      ██ ███████ ███████ ██      ██   ██  ██████ ███████

func parse_namespace_decl( p_token : Reader.Token ):
	#NAMESPACE_DECL = namespace ident ( . ident )* ;
	var frame = stack.back()

	if frame.data.get('next') == null:
		var token = reader.get_token()
		check_token_t(token, 'namespace')
		frame.data['next'] = 'ident'
		return
	if frame.data.get('next') == 'ident':
		var token = reader.get_token()
		check_token_type(token, Reader.TokenType.IDENT)

		token = reader.get_token()
		if token.t == '.': return
		check_token_t(token, ';')
		end_frame()
		return

	syntax_error(p_token, "reached end of parse_namespace_decl(...)")
	return end_frame()

#  █████  ████████ ████████ ██████  ██ ██████  ██    ██ ████████ ███████
# ██   ██    ██       ██    ██   ██ ██ ██   ██ ██    ██    ██    ██
# ███████    ██       ██    ██████  ██ ██████  ██    ██    ██    █████
# ██   ██    ██       ██    ██   ██ ██ ██   ██ ██    ██    ██    ██
# ██   ██    ██       ██    ██   ██ ██ ██████   ██████     ██    ███████

func parse_attribute_decl( p_token : Reader.Token ):
	# ATTRIBUTE_DECL = attribute ident | "</tt>ident<tt>" ;
	var frame = stack.back()

	var token = reader.get_token()
	check_token_t(token, 'attribute')

	token = reader.get_token()
	if token.type == Reader.TokenType.IDENT:
		pass
	elif token.type == Reader.TokenType.STRING:
		pass
	else:
		syntax_error(token, "Wanted 'ident | string_constant'")

	token = reader.get_token()
	check_token_t(token, ';')
	end_frame()

	syntax_error(p_token, "reached end of parse_attribute_decl( ... )")
	return end_frame()

# ████████ ██    ██ ██████  ███████         ██████  ███████  ██████ ██
#    ██     ██  ██  ██   ██ ██              ██   ██ ██      ██      ██
#    ██      ████   ██████  █████           ██   ██ █████   ██      ██
#    ██       ██    ██      ██              ██   ██ ██      ██      ██
#    ██       ██    ██      ███████ ███████ ██████  ███████  ██████ ███████

func parse_type_decl( p_token : Reader.Token ):
	#type_decl = ( table | struct ) ident [metadata] { field_decl+ }\
	var frame : StackFrame = stack.back()

	var decl_type : String = frame.data.get('decl_type', '')

	if frame.data.get('next') == null:
		var token = reader.get_token()
		if token.t not in ['table','struct']:
			syntax_error(token, "wanted ( table | struct )")
		else:
			decl_type = token.t
			frame.data['decl_type'] = token.t

		token = reader.get_token()
		check_token_type(token, Reader.TokenType.IDENT )
		# add token to appropriate array
		match decl_type:
			"struct": struct_types.append(token.t)
			"table": table_types.append(token.t)

		# We dont want to consume the next token.
		token = reader.peek_token()
		if token.t == '(':
			frame.data['next'] = '{'
			push_stack( FrameType.METADATA )
			return

		frame.data['next'] = '{'
		# can immediately continue

	if frame.data.get('next') == '{':
		var token = reader.get_token()
		if token.eof() : return
		check_token_t( token, '{' )
		frame.data['next'] = 'field_decl'

		# update p_token to continue
		p_token = reader.peek_token()

	if frame.data.get('next') == 'field_decl':
		if p_token.eof() : return
		if p_token.t != '}':
			push_stack( FrameType.FIELD_DECL, {'decl_type':decl_type} )
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

	var decl_type : String = frame.data.get('decl_type', '')
	var decl_name : String = frame.data.get('decl_name', '')

	if frame.data.get('next') == null:
		frame.data['next'] = 'meta'

		var token = reader.get_token()
		if not token.t in ['union', 'enum']:
			syntax_error(token, "wanted ( enum | union )")
		else:
			decl_type = token.t
			frame.data['decl_type'] = decl_type

		# ident
		token = reader.get_token()
		if check_token_type(token, Reader.TokenType.IDENT):
			match decl_type:
				"union" :
					union_types.append(token.t)
				"enum" :
					decl_name = token.t
					frame.data['decl_name'] = decl_name
					enum_types[ decl_name ] = Array()

		token = reader.peek_token()
		if decl_type == 'enum':
			if token.t == ':':
				reader.get_token() # consume token.
				push_stack( FrameType.TYPE, { 'decl_type':decl_type } )
				return

	if frame.data.get('next') == 'meta':
		frame.data['next'] = '{'
		if p_token.t == '(':
			push_stack(FrameType.METADATA)
			return

	if frame.data.get('next') == '{':
		frame.data['next'] = 'enumval_decl'
		var token : Reader.Token = reader.get_token()
		check_token_t(token, '{')
		p_token = reader.peek_token()

	if frame.data.get('next') == 'enumval_decl':
		# we might be here after a previous enumval_decl which returns the name
		# parsing of the original enum name might have failed, or we are a union.
		var val_name = frame.data.get('return')
		if decl_name and val_name:
			enum_types[decl_name].append( val_name )
			frame.data.erase( 'return' )

		if p_token.eof() : return
		if p_token.t == ',':
			reader.get_token() # consume comma
			return
		if p_token.t != '}':
			match decl_type:
				'union':
					push_stack( FrameType.ENUMVAL_DECL, { 'decl_type':decl_type } )
				'enum':
					push_stack( FrameType.ENUMVAL_DECL, { 'decl_type':decl_type, 'decl_name':decl_name } )
			return
		reader.get_token() # Consume the }
		return end_frame()

	syntax_error(p_token, "reached end of parse_enum_val( ... )" )
	return end_frame()


# ██████   ██████   ██████  ████████      ██████  ███████  ██████ ██
# ██   ██ ██    ██ ██    ██    ██         ██   ██ ██      ██      ██
# ██████  ██    ██ ██    ██    ██         ██   ██ █████   ██      ██
# ██   ██ ██    ██ ██    ██    ██         ██   ██ ██      ██      ██
# ██   ██  ██████   ██████     ██ ███████ ██████  ███████  ██████ ███████

func parse_root_decl( p_token : Reader.Token ):
	# ROOT_DECL = root_type ident ;
	var frame = stack.back()

	var token = reader.get_token()
	check_token_t(token, 'root_type', "token.t != 'root_type'" )

	token = reader.get_token()
	check_token_type(token, Reader.TokenType.IDENT,
		"token.type != 'Reader.TokenType.IDENT'" )

	token = reader.get_token()
	check_token_t(token, ';', "token.t != ';'" )
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

	var decl_type : String = frame.bindings.get('decl_type', '')
	var field_name : String = frame.data.get('field_name', '')

	if frame.data.get('next') == null:
		var token = reader.get_token()
		if check_token_type(token, Reader.TokenType.IDENT):
			field_name = token.t
			frame.data['field_name'] = token.t

		# TODO is this token already named in the type_decl?
		# I would need to fetch the parent frame and check if it is in the named list.
		# and add the name to the list.

		token = reader.get_token()
		if token.eof() : return
		check_token_t( token, ':')

		frame.data['next'] = 'default'
		push_stack( FrameType.TYPE, { 'decl_type':decl_type, 'field_name':field_name } )
		return

	# Handle defaults
	p_token = reader.peek_token()
	if frame.data.get('next') == 'default':
		frame.data['next'] = 'meta'
		if p_token.t == '=':
			reader.get_token() # consume '='
			var token = reader.get_token()
			var return_val : Dictionary = frame.data.get('return')
			frame.data.erase('return')
			if return_val.get('field_type') == 'enum':
				var enum_vals = enum_types.get(return_val.get('field_name'))
				if not token.t in enum_vals:
					syntax_error(token, "value not found in enum")
				else:
					highlight(token, Reader.TokenType.SCALAR)
			elif not reader.is_scalar(token.t):
				syntax_error(token, "Only Scalar values can have defaults")

	# meta
	if frame.data.get('next') == 'meta':
		frame.data['next'] = ';'
		if p_token.t == '(':
			push_stack( FrameType.METADATA )
			return

	# finish
	if frame.data.get('next') == ';':
		var token : Reader.Token = reader.get_token()
		check_token_t(token, ';')
		return end_frame()

	syntax_error(p_token, "reached end of parse_type_decl(...)")
	return end_frame()

#   ██████  ██████   ██████         ██████  ███████  ██████ ██
#   ██   ██ ██   ██ ██              ██   ██ ██      ██      ██
#   ██████  ██████  ██              ██   ██ █████   ██      ██
#   ██   ██ ██      ██              ██   ██ ██      ██      ██
#   ██   ██ ██       ██████ ███████ ██████  ███████  ██████ ███████

func parse_rpc_decl( p_token : Reader.Token ):
	var this_frame = stack.back()
	syntax_warning( p_token, "Unimplemented")
	reader.adv_line()
	return end_frame()

#   ██████  ██████   ██████         ███    ███ ███████ ████████ ██   ██
#   ██   ██ ██   ██ ██              ████  ████ ██         ██    ██   ██
#   ██████  ██████  ██              ██ ████ ██ █████      ██    ███████
#   ██   ██ ██      ██              ██  ██  ██ ██         ██    ██   ██
#   ██   ██ ██       ██████ ███████ ██      ██ ███████    ██    ██   ██

func parse_rpc_method( p_token : Reader.Token ):
	var this_frame = stack.back()
	syntax_warning( p_token, "Unimplemented")
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
	var decl_type = frame.bindings.get('decl_type', '')

	# Simple parsing for enums
	if decl_type == "enum":
		var token : Reader.Token = reader.get_token()
		if not token.t in integer_types:
			syntax_error( token, "Enum types must be an integral")
		else: highlight(token, Reader.TokenType.TYPE)
		return end_frame()


	# compled parsing for structs and tables
	var has_bracket : bool = false
	var return_val : Dictionary = {
		'field_type':'',
		'field_name':''
	}

	var token : Reader.Token = reader.get_token()
	# for both table and struct decl '[' is allowed
	if token.t == '[':
		# we have either vector or array syntax
		has_bracket = true
		token = reader.get_token()

	# we need to know if the field is scalar, for when we deal with defaults.
	if token.t in scalar_types: return_val['field_type'] = 'scalar'
	elif token.t in enum_types:
		return_val['field_type'] = 'enum'
		return_val['field_name'] = token.t

	if decl_type == 'struct':
		if not token.t in scalar_types + struct_types + enum_types.keys():
			syntax_error(token, "struct array/vector fields may only contain scalars or other structs")
		else: highlight(token, Reader.TokenType.TYPE)
	elif decl_type == 'table':
		# Where table can contain vectors of any type
		if not token.t in (scalar_types + struct_types + table_types
								+ array_types + enum_types.keys() + union_types):
			syntax_error(token, "invalid type name")
		else: highlight(token, Reader.TokenType.TYPE)

	# If we arent using brackets we can just end here
	if not has_bracket: return end_frame( return_val )

	token = reader.get_token()

	# Check for Array Syntax
	if decl_type == 'struct':
		if token.t == ':':
			token = reader.get_token()
			if not reader.is_integer(token.t):
				syntax_error(token, "Array Syntax count must be an integral value")
			token = reader.get_token()

	# Close out the brackets.
	check_token_t(token, ']')
	return end_frame()


# ███████ ███    ██ ██    ██ ███    ███ ██    ██  █████  ██
# ██      ████   ██ ██    ██ ████  ████ ██    ██ ██   ██ ██
# █████   ██ ██  ██ ██    ██ ██ ████ ██ ██    ██ ███████ ██
# ██      ██  ██ ██ ██    ██ ██  ██  ██  ██  ██  ██   ██ ██
# ███████ ██   ████  ██████  ██      ██   ████   ██   ██ ███████

func parse_enumval_decl( p_token : Reader.Token ):
	# ENUMVAL_DECL = ident [ = integer_constant ]
	var frame = stack.back()

	var decl_name : String = frame.bindings.get('decl_name', '')
	var decl_type : String = frame.bindings.get('decl_type', '')

	var token : Reader.Token = reader.get_token()

	if check_token_type(token, Reader.TokenType.IDENT ):
		match decl_type:
			'enum':
				pass
			'union':
				pass
		if enum_types.has(decl_name):
			var enum_vals = enum_types.get(decl_name)
			enum_vals.append( token.t )
		elif decl_type == 'union':
			highlight(token, Reader.TokenType.SCALAR)
		else:
			syntax_error( token )

	token = reader.peek_token()
	if token.t == '=':
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

	if frame.data.get('next') == null:
		var token : Reader.Token = reader.get_token()
		check_token_t( token, '(' )
		frame.data['next'] = 'continue'

	if frame.data.get('next') == 'continue':
		var token : Reader.Token = reader.get_token()

		if token.t == ')': return end_frame()
		check_token_type(token, Reader.TokenType.IDENT )

		token = reader.get_token()
		if token.t == ':':
			token = reader.get_token()
			if not (token.type == Reader.TokenType.SCALAR
				or token.type == Reader.TokenType.STRING):
					syntax_error(token, "is not scalar or string constant")
		if token.t == ',': return
		if token.t == ')': return end_frame()

	syntax_error(p_token, "reached end of parse_metadata(...)")
	return end_frame()

#   ███████  ██████  █████  ██       █████  ██████
#   ██      ██      ██   ██ ██      ██   ██ ██   ██
#   ███████ ██      ███████ ██      ███████ ██████
#        ██ ██      ██   ██ ██      ██   ██ ██   ██
#   ███████  ██████ ██   ██ ███████ ██   ██ ██   ██

func parse_scalar( p_token : Reader.Token ):
	# SCALAR = boolean_constant | integer_constant | float_constant
	var this_frame = stack.back()

	var token : Reader.Token = reader.get_token()
	if token.type == Reader.TokenType.SCALAR:
		reader.get_token()
		return end_frame()
	if token.t in user_enum_vals:
		token.type = Reader.TokenType.SCALAR
		highlight( token )
		reader.get_token()
		return end_frame()
	syntax_error( token, "Wanted Reader.TokenType.SCALAR" )
	reader.adv_line()
	end_frame()
	return false

#    ██████  ██████       ██ ███████  ██████ ████████
#   ██    ██ ██   ██      ██ ██      ██         ██
#   ██    ██ ██████       ██ █████   ██         ██
#   ██    ██ ██   ██ ██   ██ ██      ██         ██
#    ██████  ██████   █████  ███████  ██████    ██

func parse_object( p_token : Reader.Token ):
	var this_frame = stack.back()
	syntax_warning( p_token, "unimplemented" )
	reader.adv_line()
	return end_frame()

#   ███████ ██ ███    ██  ██████  ██      ███████
#   ██      ██ ████   ██ ██       ██      ██
#   ███████ ██ ██ ██  ██ ██   ███ ██      █████
#        ██ ██ ██  ██ ██ ██    ██ ██      ██
#   ███████ ██ ██   ████  ██████  ███████ ███████

func parse_single_value( p_token : Reader.Token ):
	var this_frame = stack.back()
	syntax_warning( p_token, "unimplemented" )
	reader.adv_line()
	end_frame()
	return false

#   ██    ██  █████  ██      ██    ██ ███████
#   ██    ██ ██   ██ ██      ██    ██ ██
#   ██    ██ ███████ ██      ██    ██ █████
#    ██  ██  ██   ██ ██      ██    ██ ██
#     ████   ██   ██ ███████  ██████  ███████

func parse_value( p_token : Reader.Token ):
	var this_frame = stack.back()
	syntax_warning( p_token, "unimplemented" )
	reader.adv_line()
	return end_frame()

#  ██████  ██████  ███    ███ ███    ███  █████  ███████ ███████ ██████
# ██      ██    ██ ████  ████ ████  ████ ██   ██ ██      ██      ██   ██
# ██      ██    ██ ██ ████ ██ ██ ████ ██ ███████ ███████ █████   ██████
# ██      ██    ██ ██  ██  ██ ██  ██  ██ ██   ██      ██ ██      ██
#  ██████  ██████  ██      ██ ██      ██ ██   ██ ███████ ███████ ██

func parse_commasep( p_token : Reader.Token ):
	# COMMASEP(x) = [ x ( , x )* ]
	var frame = stack.back()
	var arg_type = frame.data.get('args')
	if arg_type == null:
		syntax_error(p_token, "commasep needs an argument")
		return end_frame()

	if not (p_token.type == Reader.TokenType.IDENT || p_token.t == ','):
		return end_frame()

	if frame.data.get('next') == null:
		push_stack( arg_type )
		frame.data['next'] = ','
		return
	if frame.data.get('next') == ',':
		var token : Reader.Token = reader.get_token()
		frame.data.erase('return')
		if token.t != ',': return end_frame()
		frame.data['next'] = null
		return

	syntax_error(p_token, "Reached the end of parse_commasep(...)")
	return end_frame()

#   ███████ ██ ██      ███████    ███████ ██   ██ ████████
#   ██      ██ ██      ██         ██       ██ ██     ██
#   █████   ██ ██      █████      █████     ███      ██
#   ██      ██ ██      ██         ██       ██ ██     ██
#   ██      ██ ███████ ███████ ██ ███████ ██   ██    ██

func parse_file_extension_decl( p_token : Reader.Token ):
	var this_frame = stack.back()
	syntax_warning( p_token, "Unimplemented")
	reader.adv_line()
	return end_frame()

#   ███████ ██ ██      ███████
#   ██      ██ ██      ██
#   █████   ██ ██      █████
#   ██      ██ ██      ██
#   ██      ██ ███████ ███████

func parse_file_identifier_decl( p_token : Reader.Token ):
	var this_frame = stack.back()
	syntax_warning( p_token, "Unimplemented")
	reader.adv_line()
	return end_frame()

#   ███████ ████████ ██████  ██ ███    ██  ██████
#   ██         ██    ██   ██ ██ ████   ██ ██
#   ███████    ██    ██████  ██ ██ ██  ██ ██   ███
#        ██    ██    ██   ██ ██ ██  ██ ██ ██    ██
#   ███████    ██    ██   ██ ██ ██   ████  ██████

func parse_string_constant( p_token : Reader.Token ):
	var frame = stack.back()

	var token : Reader.Token = reader.get_token()

	if token.get('type') == Reader.TokenType.STRING:
		return end_frame( token )

	syntax_error(token, "wanted filename as string")
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

	var ident_start : String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
	var ident_end : String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

	var word : String = token.t
	var is_ident : bool = true
	while is_ident:
		# verify first character
		if not ident_start.contains(word[0]) : is_ident = false; break
		# verify the remaining
		for i in range( 1, word.length() ):
			if not ident_end.contains(word[i]): is_ident = false; break
		break

	if is_ident:
		token.type == Reader.TokenType.IDENT
		reader.get_token()
		return end_frame( token )

	syntax_error( token, "ident = [a-zA-Z_][a-zA-Z0-9_]*" )
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

	var ok : bool = true
	while true:
		if Regex.dec_integer_constant.search( token.t ): break
		if Regex.hex_integer_constant.search( token.t ): break
		ok = false; break
	if ok:
		return end_frame()
	syntax_error( token, "Wanted ( dec_integer_constant | hex_integer_constant )" )
	return end_frame()

#endregion Parser


#  ██████  ██    ██ ██  ██████ ██   ██         ███████  ██████  █████  ███    ██
# ██    ██ ██    ██ ██ ██      ██  ██          ██      ██      ██   ██ ████   ██
# ██    ██ ██    ██ ██ ██      █████           ███████ ██      ███████ ██ ██  ██
# ██ ▄▄ ██ ██    ██ ██ ██      ██  ██               ██ ██      ██   ██ ██  ██ ██
#  ██████   ██████  ██  ██████ ██   ██ ███████ ███████  ██████ ██   ██ ██   ████

var included_files : Array = []

func quick_scan_file( filename : String ) -> bool:
	if filename.begins_with("res://"):
		if verbose > 0: printerr("paths starting with res:// or user:// are not yet supported: ", filename)
		return false

	if filename == "godot.fbs":
		filename = 'res://addons/gdflatbuffers/godot.fbs'
	else:
		filename = file_location + filename

	if not FileAccess.file_exists( filename ):
		if verbose > 0: printerr("Enable to locate file for inclusion: ", filename)
		return false

	if filename in included_files: return true # Dont create a loop
	included_files.append( filename )
	if verbose > 1: print( "Including file: ", filename )
	if verbose > 1: print( "Included files: ", included_files )
	var file = FileAccess.open( filename, FileAccess.READ )
	var content = file.get_as_text()
	quick_scan_text( content )
	return true

func quick_scan_text( text : String ):
	if verbose > 1: print_rich( "[b]quick_scan_text( FIX GODOT, Unable to get filenames )[/b]")
	# I need a function which scans the source fast to pick up names before the main scan happens.
	qreader.reset( text )

	while not qreader.at_end():
		var token = qreader.get_token()

		if token.type != Reader.TokenType.KEYWORD:
			qreader.adv_line()
			continue

		if token.t == 'include':
			var filename : String = qreader.get_token().t
			if Regex.string_constant.search(filename):
				quick_scan_file( filename.substr( 1, filename.length() - 2 ) )
			qreader.adv_line()
			continue

		if token.t in ['struct', 'table', 'enum', 'union']:
			var ident = qreader.get_token()
			if Regex.ident.search(ident.t):
				print("Adding '%s' to user types" % ident.t)
				user_types[ident.t] = OK
				# FIXME, add to the different arrays.
			else:
				print("identity invalid '%s'" % ident.t)

		if token.t == 'enum':
			pass # TODO get the enum names

		qreader.adv_line()

	if verbose > 1: print( "user_types: ", user_types.keys())
	if verbose > 1: print( "user_enum_vals: ", user_enum_vals.keys())

## Token class helps with static typing to catch and fix bugs.

#  _____    _
# |_   _|__| |_____ _ _
#   | |/ _ \ / / -_) ' \
#   |_|\___/_\_\___|_||_|
# ------------------------

## Types of token that the reader knows about
enum Type {
	NULL = 100,
	COMMENT,
	KEYWORD,
	TYPE,
	STRING,
	PUNCT,
	IDENT,
	SCALAR,
	META,
	EOL,
	EOF,
	UNKNOWN,
}

## Default Values
static var defs : Dictionary = {
	&"line":0, &"col":0, &"type":Type.NULL, &"t":"String"
}

## properties
var line : int
var col : int
var type : Type
var t : String

func eof() -> bool: return type == Type.EOF
func eol() -> bool: return type == Type.EOL

## Constructor
func _init( line_or_dict = 0, _col : int = 0, _type : Type = Type.NULL, _t : String = "" ) -> void:
	if line_or_dict is int:
		line = line_or_dict; col = _col; type = _type; t = _t
	elif line_or_dict is Dictionary:
		from_dict( line_or_dict )
	else:
		var typename = type_string(typeof(line_or_dict))
		assert(false, "Token._init( '%s', ... ) is not an int or dict" % typename )

## assignment from dictionary
func from_dict( value : Dictionary ):
	# Validate and Assign
	for key in defs.keys():
		# Missing keys are not an error, assigning default
		if not key in value: set(key, defs[key])
		# different types is an error.
		if typeof(defs[key]) != typeof(value[key]):
			var typename = type_string(typeof(defs[key]))
			assert( false, "Invalid type '%s:%s' " % [key, typename ])
			set(key, defs[key])
		# value[key] passed validation.
		set(key, value[key])

## conversion to string
func _to_string() -> String:
	# Line numbers in the editor gutter start at 1
	return "Token{ line:%d, col:%d, type:%s, t:'%s' }" % [line+1, col+1, Type.find_key(type), t.c_escape()]

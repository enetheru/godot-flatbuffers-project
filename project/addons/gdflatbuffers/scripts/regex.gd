# ██████  ███████  ██████  ███████ ██   ██
# ██   ██ ██      ██       ██       ██ ██
# ██████  █████   ██   ███ █████     ███
# ██   ██ ██      ██    ██ ██       ██ ██
# ██   ██ ███████  ██████  ███████ ██   ██

static var string_constant : RegEx # = \".*?\\"
static var ident : RegEx # = [a-zA-Z_][a-zA-Z0-9_]*
static var digit : RegEx # [:digit:] = [0-9]
static var xdigit : RegEx # [:xdigit:] = [0-9a-fA-F]
static var dec_integer_constant : RegEx # = [-+]?[:digit:]+
static var hex_integer_constant : RegEx # = [-+]?0[xX][:xdigit:]+
static var dec_float_constant : RegEx # = [-+]?(([.][:digit:]+)|([:digit:]+[.][:digit:]*)|([:digit:]+))([eE][-+]?[:digit:]+)?
static var hex_float_constant : RegEx # = [-+]?0[xX](([.][:xdigit:]+)|([:xdigit:]+[.][:xdigit:]*)|([:xdigit:]+))([pP][-+]?[:digit:]+)
static var special_float_constant : RegEx # = [-+]?(nan|inf|infinity)
static var boolean_constant : RegEx # = true | false

func _init() -> void:
	#Regex Compilation
	# STRING_CONSTANT = \".*?\\"
	string_constant = RegEx.new()
	string_constant.compile("^\\\".*?\\\\\"$")

	# IDENT = [a-zA-Z_][a-zA-Z0-9_]*
	ident = RegEx.new()
	ident.compile("^[a-zA-Z_][a-zA-Z0-9_]*$")

	# DIGIT [:digit:] = [0-9]
	digit = RegEx.new()
	digit.compile("^[0-9]$")

	# XDIGIT [:xdigit:] = [0-9a-fA-F]
	xdigit = RegEx.new()
	xdigit.compile("^[0-9a-fA-F]$")

	# DEC_INTEGER_CONSTANT = [-+]?[:digit:]+
	dec_integer_constant = RegEx.new()
	dec_integer_constant.compile("^[-+]?[0-9]+$")

	# HEX_INTEGER_CONSTANT = [-+]?0[xX][:xdigit:]+
	hex_integer_constant = RegEx.new()
	hex_integer_constant.compile("^[-+]?0[xX][0-9a-fA-F]+$")

	# DEC_FLOAT_CONSTANT = [-+]?(([.][:digit:]+)|([:digit:]+[.][:digit:]*)|([:digit:]+))([eE][-+]?[:digit:]+)?
	dec_float_constant = RegEx.new()
	dec_float_constant.compile("^[-+]?(([.][0-9]+)|([0-9]+[.][0-9]*)|([0-9]+))([eE][-+]?[0-9]+)?$")

	# HEX_FLOAT_CONSTANT = [-+]?0[xX](([.][:xdigit:]+)|([:xdigit:]+[.][:xdigit:]*)|([:xdigit:]+))([pP][-+]?[:digit:]+)
	hex_float_constant = RegEx.new()
	hex_float_constant.compile("^[-+]?0[xX](([.][[+-]?[0-9a-fA-F]+]+)|([[+-]?[0-9a-fA-F]+]+[.][[+-]?[0-9a-fA-F]+]*)|([[+-]?[0-9a-fA-F]+]+))([pP][+-]?[0-9]+)$")

	# SPECIAL_FLOAT_CONSTANT = [-+]?(nan|inf|infinity)
	special_float_constant = RegEx.new()
	special_float_constant.compile("^[-+]?(nan|inf|infinity)$")

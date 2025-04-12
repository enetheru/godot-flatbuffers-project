# ██████  ███████  ██████  ███████ ██   ██
# ██   ██ ██      ██       ██       ██ ██
# ██████  █████   ██   ███ █████     ███
# ██   ██ ██      ██    ██ ██       ██ ██
# ██   ██ ███████  ██████  ███████ ██   ██

static var string_constant : RegEx
static var ident : RegEx
static var digit : RegEx
static var xdigit : RegEx
static var dec_integer_constant : RegEx
static var hex_integer_constant : RegEx
static var dec_float_constant : RegEx
static var hex_float_constant : RegEx
static var special_float_constant : RegEx
static var boolean_constant : RegEx

static var patterns : Dictionary = {}

func _init() -> void:
	## STRING_CONSTANT = \".*?\\"
	patterns["string_constant"] = "\\\".*?\\\\\""
	string_constant = RegEx.create_from_string("^{string_constant}$".format(patterns) , true)

	## IDENT = [a-zA-Z_][a-zA-Z0-9_]*
	patterns["ident"] = "[a-zA-Z_][a-zA-Z0-9_]*"
	ident = RegEx.create_from_string("^{ident}$".format(patterns), true)

	## DIGIT [:digit:] = [0-9]
	patterns["digit"] = "[0-9]"
	digit = RegEx.create_from_string("^{digit}$".format(patterns), true)

	## XDIGIT [:xdigit:] = [0-9a-fA-F]
	patterns["xdigit"] = "[0-9a-fA-F]"
	xdigit = RegEx.create_from_string("^{xdigit}$".format(patterns), true)

	## DEC_INTEGER_CONSTANT = [-+]?[:digit:]+
	patterns["dec_integer_constant"] = "[-+]?{digit}+".format(patterns)
	dec_integer_constant = RegEx.create_from_string("^{dec_integer_constant}$".format(patterns), true)

	## HEX_INTEGER_CONSTANT = [-+]?0[xX][:xdigit:]+
	patterns["hex_integer_constant"] = "[-+]?0[xX]{xdigit}+".format(patterns)
	hex_integer_constant = RegEx.create_from_string("^{hex_integer_constant}$".format(patterns), true)

	## DEC_FLOAT_CONSTANT = [-+]?(([.][:digit:]+)|([:digit:]+[.][:digit:]*)|([:digit:]+))([eE][-+]?[:digit:]+)?
	patterns["dec_float_constant"] = "[-+]?(([.]{digit}+)|({digit}+[.]{digit}*)|({digit}+))([eE][-+]?{digit}+)?".format(patterns)
	dec_float_constant = RegEx.create_from_string("^{dec_float_constant}$".format(patterns), true)

	## HEX_FLOAT_CONSTANT = [-+]?0[xX](([.][:xdigit:]+)|([:xdigit:]+[.][:xdigit:]*)|([:xdigit:]+))([pP][-+]?[:digit:]+)
	patterns["hex_float_constant"] = "[-+]?0[xX](([.]{xdigit}+)|({xdigit}+[.]{xdigit}*)|({xdigit}+))([pP][-+]?{digit}+)".format(patterns)
	hex_float_constant = RegEx.create_from_string("^{hex_float_constant}$".format(patterns), true)

	## SPECIAL_FLOAT_CONSTANT = [-+]?(nan|inf|infinity)
	patterns["special_float_constant"] = "[-+]?(nan|inf|infinity)"
	special_float_constant = RegEx.create_from_string("^{special_float_constant}$".format(patterns), true)

	## BOOLEAN_CONSTANT = true | false
	patterns["boolean_constant"] = "(true|false)"
	boolean_constant = RegEx.create_from_string("^{boolean_constant}$".format(patterns), true)

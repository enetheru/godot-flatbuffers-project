
const REGEX = preload('res://addons/gdflatbuffers/scripts/regex.gd')
static var Regex :
	get():
		if Regex == null: Regex = REGEX.new()
		return Regex

func print_bright( _value ):
	print_rich( "[b][color=yellow]%s[/color][/b]" % [_value] )

# ██████  ███████  █████  ██████  ███████ ██████
# ██   ██ ██      ██   ██ ██   ██ ██      ██   ██
# ██████  █████   ███████ ██   ██ █████   ██████
# ██   ██ ██      ██   ██ ██   ██ ██      ██   ██
# ██   ██ ███████ ██   ██ ██████  ███████ ██   ██

## The reader class steps through a string, pulling out tokens as it goes.

# MARK: Token
#  _____    _
# |_   _|__| |_____ _ _
#   | |/ _ \ / / -_) ' \
#   |_|\___/_\_\___|_||_|
# ------------------------

## Types of token that the reader knows about
enum TokenType {
	NULL,
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
	UNKNOWN
}

## Token class helps with static typing to catch and fix bugs.
class Token:
	## Default Values
	static var defs : Dictionary = {
		&"line":0, &"col":0, &"type":TokenType.NULL, &"t":"String"
	}
	## properties
	var line : int
	var col : int
	var type : TokenType
	var t : String

	func eof() -> bool: return type == TokenType.EOF
	func eol() -> bool: return type == TokenType.EOL

	## Constructor
	func _init( line_or_dict = 0, _col : int = 0, _type : TokenType = TokenType.NULL, _t : String = "" ) -> void:
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

	func _to_string() -> String:
		# Line numbers in the editor gutter start at 1
		return "Token{ line:%d, col:%d, type:%s, t:'%s' }" % [line+1, col+1, TokenType.keys()[type], t.c_escape()]

# MARK: Signals
#   ___ _                _
#  / __(_)__ _ _ _  __ _| |___
#  \__ \ / _` | ' \/ _` | (_-<
#  |___/_\__, |_||_\__,_|_/__/
# -------|___/-----------------

signal new_token( token : Token )
signal newline( ln, p )
signal endfile( ln, p )

# MARK: Properties
#   ___                       _   _
#  | _ \_ _ ___ _ __  ___ _ _| |_(_)___ ___
#  |  _/ '_/ _ \ '_ \/ -_) '_|  _| / -_|_-<
#  |_| |_| \___/ .__/\___|_|  \__|_\___/__/
# -------------|_|--------------------------

## The parent object is where the reader draws some information from
## If I can I should move as much out of the reader into the "parent" as possible
var parent

## A list of word separation characters
var word_separation : Array = [' ', '\t', '\n', '{','}', ':', ';', ',','=',
'(', ')', '[', ']' ]

## A list of whitespace characters
var whitespace : Array = [' ', '\t', '\n']

## A list of punctuation characters
var punc : Array = [',', '.', ':', ';', '[', ']', '{', '}', '(', ')', '=']

## The text to parse
var text : String

## cursor position for each line start
var line_index : Array[int] = [0]

## Cursor position in file
var cursor_p : int = 0

## Cursor position in line
var cursor_lp : int = 0

## Current line number
var line_n : int = 0

## When updating chunks of a larger source file, what line does this chunk start on.
var line_start : int

func _init( _parent ) -> void:
	parent = _parent
	if not Regex: Regex = REGEX.new()


func _to_string() -> String:
	return JSON.stringify({
		'text': text,
		'line_index':line_index,
		'cursor_p': cursor_p,
		'cursor_lp': cursor_lp,
		'line_n': line_n,
		'line_start': line_start,
		'token': str(peek_token()),
	},'\t', false)


func reset( text_ : String, line_i : int = 0 ):
	text = text_
	line_index = [0]
	cursor_p = 0
	cursor_lp = 0
	line_start = line_i
	line_n = line_i


# MARK: adv_
#           _
#   __ _ __| |_ __
#  / _` / _` \ V /
#  \__,_\__,_|\_/ ___
# ---------------|___|-

func adv( dist : int = 1 ) -> void:
	if cursor_p >= text.length(): return # dont advance further than length
	for i in dist:
		cursor_p += 1
		cursor_lp += 1
		if not cursor_p < text.length():
			endfile.emit( line_n + 1, cursor_p )
			return;
		if peek_char( ) != '\n': continue
		line_index.append( cursor_p )
		cursor_lp = 0
		line_n = line_index.size() -1
		newline.emit( line_n, cursor_p )
		break


func adv_line() -> void:
	adv( text.length() ) # adv automatically stops on a line break.


func adv_whitespace():
	while peek_char() in whitespace and not at_end():
		adv()

func adv_token( token : Token ):
	adv( token.t.length() )

# MARK: peek_
#                 _
#   _ __  ___ ___| |__
#  | '_ \/ -_) -_) / /
#  | .__/\___\___|_\_\ ___
# -|_|----------------|___|-

func peek_char( offset : int = 0 ) -> String:
	if cursor_p + offset < text.length():
		return text[cursor_p + offset]
	else:
		return '\n'


func peek_word() -> String:
	adv_whitespace()
	# include . if not starting with a number
	var separators = word_separation
	if not is_integer(peek_char()): separators = separators + ['.']

	var length : int = 0
	while not peek_char(length) in separators:
		length += 1
	return text.substr( cursor_p, length )


func peek_string() -> String:
	if peek_char() != '"': return '' # fail if not start with quotes.
	var length : int = 0
	while true:
		length += 1
		if peek_char(length) == '\n': return '"' # fail on eol or eof
		if (peek_char(length) == '"'
			and peek_char(length-1) != '\\'):
				length += 1
				break
	return text.substr( cursor_p, length )

	print_bright( peek_char() )
	return peek_line()

func peek_line( offset : int = 0 ) -> String:
	var eol = text.find('\n', cursor_p + offset)
	return text.substr(cursor_p, eol - cursor_p)


func peek_token( skip : bool = true ) -> Token:
	var p_token : Token
	while true:
		adv_whitespace()
		# end of file
		p_token = Token.new(line_n, cursor_lp, TokenType.EOF, peek_char() )
		if at_end(): break

		p_token.type = TokenType.UNKNOWN

		# char based tokens
		if p_token.t == '/' and peek_char(1) == '/':
			if skip: adv_line(); continue
			p_token.type = TokenType.COMMENT
			p_token.t = peek_line()
		elif p_token.t == '\n':
			p_token.type = TokenType.EOL
		elif p_token.t in punc:
			p_token.type = TokenType.PUNCT
		elif p_token.t == '"':
			p_token.t = peek_string()
			if p_token.t.length() > 2:
				p_token.type = TokenType.STRING


		if p_token.type != TokenType.UNKNOWN:
			break

		# word based token
		p_token.t = peek_word()
		if is_keyword(p_token.t): p_token.type = TokenType.KEYWORD
		elif is_scalar( p_token.t ): p_token.type = TokenType.SCALAR
		elif is_type( p_token.t ): p_token.type = TokenType.TYPE
		elif is_ident(p_token.t): p_token.type = TokenType.IDENT

		break

	return p_token

# MARK: get_
#            _
#   __ _ ___| |_
#  / _` / -_)  _|
#  \__, \___|\__| ___
# -|___/---------|___|-

# the set of get functions grabs the next item and moves the cursor forward.

func get_char() -> String:
	adv(); return text[cursor_p - 1]


func get_word() -> String:
	adv_whitespace()
	var word = peek_word()
	adv( word.length() )
	return word


func get_line( offset : int = 0 ) -> String:
	var start : int = cursor_p
	adv_line()
	return text.substr( start, cursor_p - start )


func get_token( skip : bool = true ) -> Token:
	var token = peek_token( skip )
	adv_token(token)
	new_token.emit( token )
	return token


func get_string() -> String:
	var string = peek_string()
	adv( string.length() )
	return string


func get_integer_constant() -> Token:
	# Verify Starting position.
	var p_token = peek_token()
	if p_token.type != TokenType.UNKNOWN:
		return p_token

	#INTEGER_CONSTANT, # = dec_integer_constant | hex_integer_constant

	#DEC_INTEGER_CONSTANT, # = [-+]?[:digit:]+
	#DIGIT, # [:digit:] = [0-9]

	#HEX_INTEGER_CONSTANT, # = [-+]?0[xX][:xdigit:]+
	#XDIGIT, # [:xdigit:] = [0-9a-fA-F]

	var first_char : String = "-+0123456789abcdefABCDEF"
	var valid_chars = "xX0123456789abcdefABCDEF"
	if peek_char() not in first_char: return p_token
	p_token.type = TokenType.SCALAR
	# seek to the end and return our valid integer constant
	var start : int = cursor_p
	while not at_end():
		adv()
		if peek_char() in valid_chars: continue
		break

	p_token.t = text.substr( start, cursor_p - start )
	new_token.emit( p_token )
	return p_token


# MARK: query
#   __ _ _  _ ___ _ _ _  _
#  / _` | || / -_) '_| || |
#  \__, |\_,_\___|_|  \_, |
# ----|_|-------------|__/--

func at_end() -> bool:
	if cursor_p >= text.length(): return true
	return false


func is_type( word : String )-> bool:
	return word in parent.scalar_types


func is_keyword( word : String ) -> bool:
	return word in parent.keywords


func is_ident( word : String ) -> bool:
	if Regex.ident.search(word):
		return true
	return false


#scalar = boolean_constant | integer_constant | float_constant
func is_scalar( word : String ) -> bool:
	return is_boolean( word ) or is_integer( word ) or is_float( word )


func is_boolean( word : String ) -> bool:
	return word in ['true', 'false']


# integer_constant = dec_integer_constant | hex_integer_constant
func is_integer( word : String ) -> bool:
	return (Regex.dec_integer_constant.search(word)
		or Regex.hex_integer_constant.search(word))


#float_constant = dec_float_constant | hex_float_constant | special_float_constant
func is_float( word : String ) -> bool:
	return (Regex.dec_float_constant.search( word )
		or Regex.hex_float_constant.search( word )
		or Regex.special_float_constant.search( word ))

@tool
class_name FlatBuffersParser
extends RefCounted

const Reader = preload('uid://cupdfm2aikswa')
const Token = preload('uid://cvcd6kyaa4f1a')
const Framestack = preload('uid://d3cyn1bbenwmo')

const LogLevel = FlatBuffersPlugin.LogLevel

# ── Dependencies ─────────────────────────────────────────────────────────────
var plugin: FlatBuffersPlugin           # temporary bridge
var reader: Reader             # we'll initialize it later

# ── Collected schema knowledge ───────────────────────────────────────────────
var struct_types: Array[StringName] = []
var table_types:  Array[StringName] = []
var union_types:  Array[StringName] = []
var enum_types:   Dictionary = {}       # StringName → Array[StringName]

# ── Settings mirrors (read-only copies for now) ──────────────────────────────
var scalar_types: Array[StringName] = []
var keywords:     Array[StringName] = []

# ── Include handling (will be improved later) ────────────────────────────────
var included_files: Array[String] = []

# ── Incremental parsing state (moved from highlighter) ────────────────────────
var stack : FrameStack = FrameStack.new(20)   # initial capacity, can tune later

# saved stacks per line (key: line number, value: FrameStack)
# TODO: I wonder if we can keep the stack in the highlight cache.
var stack_list : Dictionary = {}               # int → FrameStack

# indicates if we saved a stack for this line index
# Where the Array index is the line_num, and stack_index[index] bool
# indicates whether the stack_list dictionary has an index saved.
# TODO They can probably be merged into the same field honestly.
var stack_index : Array[bool] = [false]        # grows as needed

# flags that influence parsing behaviour / highlighting
# NOTE: if error or warning is set, do not to save the stack to the next line
var error_flag : bool = false
var warning_flag : bool = false

var is_quick_scan_in_progress: bool = false # re-entrancy guard + "behave in discovery mode"
var has_performed_quick_scan: bool = false  # "can I trust struct_types/table_types etc.?"

# The line number that the stack was restored from.
var prev_idx : int = 0

# per-line dictionaries for colours / regions (moved here if you want full encapsulation)
# for now we'll keep them in highlighter, but later we can return them from parse_line()




func _init(plugin_ref: FlatBuffersPlugin = null):
	if plugin_ref:
		plugin = plugin_ref
		_sync_constants_from_plugin()


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



func _sync_constants_from_plugin():
	# TODO: move these to a shared constants file later
	if "scalar_types" in plugin:
		scalar_types = plugin.scalar_types
	if "keywords" in plugin:
		keywords = plugin.keywords


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


# ── Helpers (copied from highlighter for now) ────────────────────────────────
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


# ── Grammar parsing helpers ──────────────────────────────────────────────────

#   ██ ██████  ███████ ███    ██ ████████
#   ██ ██   ██ ██      ████   ██    ██
#   ██ ██   ██ █████   ██ ██  ██    ██
#   ██ ██   ██ ██      ██  ██ ██    ██
#   ██ ██████  ███████ ██   ████    ██
func parse_ident(p_token: Token) -> void:
	# ident = [a-zA-Z_][a-zA-Z0-9_]*
	# FIXME use regex?

	var token: Token = reader.get_token()  # assuming reader is accessible
	#STUB check_token_type(token, Token.Type.IDENT)
	if token.type != Token.Type.IDENT:
		# For now: just log — later we'll collect proper errors
		print_rich("[color=orange]Expected IDENT, got %s '%s'[/color]" % [Token.Type.find_key(token.type), token.t])
	#STUB end_frame() yet — we'll move the stack later

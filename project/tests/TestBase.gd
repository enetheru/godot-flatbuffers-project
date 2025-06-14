@tool
class_name TestBase extends EditorScript

#region == Test Stuff ==
var _verbose : bool = false
var runcode : int = OK
var retcode : int = FAILED
var output : PackedStringArray = []

## Handy Constants
const u32 = 2083138172				# |**|
const u32_ = 2084585596				# |@@|
const u64 = 8947009970309311100		# |******|
const u64_ = 8953226703912583292	# |@@@@@@|

func _init() -> void:
	_verbose = FlatBuffersPlugin._prime.verbosity >= FlatBuffersPlugin.LogLevel.NOTICE

func logd( msg = "" ):
	if msg is Array: msg = '\n'.join(msg)
	if FlatBuffersPlugin._prime.debug:
		print_rich( msg )

func logp( msg ):
	if msg is Array: msg = '\n'.join(msg)
	output.append( msg )
	if not FlatBuffersPlugin._prime.debug:
		if _verbose: print_rich( msg )

func TEST_EQ( want_v, got_v, desc : String = "" ) -> bool:
	if want_v == got_v: return false
	runcode |= FAILED
	var msg = "[b][color=salmon]TEST_EQ Failed: '%s'[/color][/b]\nwanted: '%s'\n   got: '%s'" % [desc, want_v, got_v ]
	output.append( msg )
	if _verbose: print_rich( msg )
	return true

func TEST_APPROX( want_v, got_v, desc : String = "" ) -> bool:
	if is_equal_approx(want_v, got_v): return false
	runcode |= FAILED
	var msg = "[b][color=salmon]TEST_EQ Failed: '%s'[/color][/b]\nwanted: '%s'\n   got: '%s'" % [desc, want_v, got_v ]
	output.append( msg )
	if _verbose: print_rich( msg )
	return true

func TEST_TRUE( value, desc : String = "" ) -> bool:
	if value: return false
	runcode |= FAILED
	var msg = "[b][color=salmon]TEST_TRUE Failed: '%s'[/color][/b]\nwanted: true | value != (0 & null)\n   got: '%s'" % [desc, value ]
	output.append( msg )
	if _verbose: print_rich( msg )
	return true


func bytes_view( bytes : PackedByteArray, cols : int = 8 ) -> String:
	if bytes.is_empty(): return "Empty"
	var retval : Array = ["size: %d" % bytes.size()]
	var position = 0
	while true:
		var slice : PackedByteArray = bytes.slice(position, position + cols)
		if not slice.size(): break

		# new line
		var line : String = ""
		# Position
		line += "%08X: " % position
		# bytes as hex pairs
		for v in slice: line += "%02X " % v
		# pad to width
		line = line.rpad( 10 + cols*3, ' ')
		# ascii
		for v in slice: line += char(v) if v > 32 else '.'

		retval.append(line)
		position += cols
		if slice.size() < cols: break

	return '\n'.join( retval )

# ███████ ██   ██  █████  ███    ███ ██████  ██      ███████
# ██       ██ ██  ██   ██ ████  ████ ██   ██ ██      ██
# █████     ███   ███████ ██ ████ ██ ██████  ██      █████
# ██       ██ ██  ██   ██ ██  ██  ██ ██      ██      ██
# ███████ ██   ██ ██   ██ ██      ██ ██      ███████ ███████
#
#const schema = preload('./FBTest_test_generated.gd')
#
## Setup Persistent Variables
#var test_object
#
#func _run() -> void:
	## Setup Persistent data
	## ...
#
	## Generate the flatbuffer using the three methods of creation
	#reconstruct( manual() )
	#reconstruct( create() )
	#reconstruct( create2() )
	#if not verbose:
		#print_rich( "\n[b]== Monster ==[/b]\n" )
		#for o in output: print( o )
#
#func manual() -> PackedByteArray:
	## create new builder
	#var builder = FlatBufferBuilder.new()
#
	## create all the composite objects here
	## var offset : int = schema.Create<Type>( builder, element, ... )
	## ...
#
	## Start the root object builder
	#var root_builder = schema.RootTableBuilder.new( builder )
#
	## Add all the root object items
	## root_builder.add_<field_name>( inline object )
	## root_builder.add_<field_name>( offset )
	## ...
#
	## Finish the root builder
	#var root_offset = root_builder.finish()
#
	## Finalise the builder
	#builder.finish( root_offset )
#
	## export data
	#return builder.to_packed_byte_array()
#
#
#func create():
	## create new builder
	#var builder = FlatBufferBuilder.new()
#
	## create all the composite objects here
	## var offset : int = schema.Create<Type>( builder, element, ... )
	## ...
#
	##var offset : int = schema.CreateRootTable( builder, element, ... )
	#var offset : int
#
	## finalise flatbuffer builder
	#builder.finish( offset )
#
	## export data
	#return builder.to_packed_byte_array()
#
#
#func create2():
	## create new builder
	#var builder = FlatBufferBuilder.new()
#
	## This call generates the root table using test_object properties
	#var offset = schema.CreateRootTable2( builder, test_object )
#
	## Finalise flatbuffer builder
	#builder.finish( offset )
#
	## export data
	#return builder.to_packed_byte_array()
#
#
#func reconstruct( buffer : PackedByteArray ):
	#var root_table : FlatBuffer = schema.GetRoot( buffer )
	#output.append( "root_table: " + JSON.stringify( root_table.debug(), '\t', false ) )
#
	## Perform testing on the reconstructed flatbuffer.
	##TEST_EQ( <value>, <value>, "Test description if failed")

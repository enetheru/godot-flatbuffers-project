@tool
extends TestBase

## │ __  __ _      _            _    [br]
## │|  \/  (_)_ _ (_)_ __  __ _| |   [br]
## │| |\/| | | ' \| | '  \/ _` | |   [br]
## │|_|  |_|_|_||_|_|_|_|_\__,_|_|   [br]
## ╰──────────────────────────────── [br]
## Minimal test case.
##
## The smallest test case I can conceive that makes any sense is a single
## table with a single integer.[br]
## [code]simple.fbs[/code][br]
## [codeblock]table Minimum {
##   my_field : int;
## }
## root_type Minimum;
## [/codeblock]
## Steps:
## - schema parsing - Not relevant right now
## - code generation
## - encoding
## - verification
## - decoding
## - using

const schema_file = "res://tests/flatbuffers/schemas/minimum.fbs"
const Schema = preload("schemas/minimum_generated.gd")


func _run_test() -> int:
	
	if await generate_gdscript():
		logp("Failed to generate GDScript from FlatBuffers schema")
		return runcode
	
	var value : int = u32
	logd("starting value: %X" %value )

	var bytes:PackedByteArray = encode_a(value)
	if bytes.is_empty():
		logp("Failed to encode value")
		return runcode
	

	var rt:Schema.Minimum = Schema.get_Minimum(bytes)
	print("decoded: %X" %rt.my_field() )
	TEST_EQ(value, rt.my_field())

	return runcode

func generate_gdscript() -> bool:
	var run_dict:Dictionary = await FlatBuffersPlugin.generate(schema_file)
	return TEST_EQ_RET(0, run_dict.retcode, str(run_dict.output))


func encode_a( value:int ) -> PackedByteArray:
	var fbb := FlatBufferBuilder.new()
	var rt_offset:int = Schema.create_Minimum(fbb, value )
	fbb.finish( rt_offset )

	var bytes:PackedByteArray = fbb.to_packed_byte_array()
	logd("bytes: %s" % bytes_view(bytes) )
	return bytes

func encode_b( value:int ) -> PackedByteArray:
	var fbb := FlatBufferBuilder.new()
	var mbb := Schema.MinimumBuilder.new(fbb)
	mbb.add_my_field(value)
	var ofs:int = mbb.finish()
	fbb.finish(ofs)
	
	var bytes:PackedByteArray = fbb.to_packed_byte_array()
	logd("bytes: %s" % bytes_view(bytes) )
	return bytes

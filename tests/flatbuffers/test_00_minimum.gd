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
	logp("[b]== Generate GDScript ==[/b]")
	if not generate_gdscript():
		logp("Failed to generate GDScript from FlatBuffers schema")
		return runcode
	
	logp("[b]== Encoding ==[/b]")
	var value : int = u32
	logd("starting value: %X" %value )

	# We have multiple methods of encoding, so run the remainder of the test
	# for each one.
	for encoder:Callable in [encode_a, encode_b] :
		var bytes:PackedByteArray = encoder.call(value)
		if bytes.is_empty():
			logp("Failed to encode value")
			return runcode
	
		#logp("[b]== Verification ==[/b]")
		#var verifier := FlatBufferVerifier.new()
		#verifier.set_buffer(bytes)

		# TODO requires code generation changes
		# TEST_TRUE(fb_table.verify(verifier), "verifying fb_table")
		
		logp("[b]== Decoding ==[/b]")
		var decoded:Schema.Minimum = Schema.get_root(bytes)
		
		logp("[b]== Using ==[/b]")
		
		TEST_EQ(value, decoded.my_field(), "rt.my_field()")
		logd("decoded value: %X" % decoded.my_field() )

	return runcode

## Generate the GDScript from the flatbuffer schema file.
func generate_gdscript() -> bool:
	var run_dict:Dictionary = FlatBuffersPlugin.generate(schema_file)
	return TEST_EQ_RET(0, run_dict.retcode, str(run_dict.output))


## encoding method a, use the Schema.create_ function
func encode_a( value:int ) -> PackedByteArray:
	var fbb := FlatBufferBuilder.new()
	var rt_offset:int = Schema.create_Minimum(fbb, value )
	fbb.finish( rt_offset )

	var bytes:PackedByteArray = fbb.to_packed_byte_array()
	logd("bytes: %s" % bytes_view(bytes) )
	return bytes


## encoding method a, use the Schema.*Builder helper class
func encode_b( value:int ) -> PackedByteArray:
	var fbb := FlatBufferBuilder.new()
	var mbb := Schema.MinimumBuilder.new(fbb)
	mbb.add_my_field(value)
	var ofs:int = mbb.finish()
	fbb.finish(ofs)
	
	var bytes:PackedByteArray = fbb.to_packed_byte_array()
	logd("bytes: %s" % bytes_view(bytes) )
	return bytes

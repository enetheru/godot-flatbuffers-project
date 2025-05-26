@tool
extends TestBase

const schema = preload('./Reflection_generated.gd')
const Schema = schema.Schema

func _run() -> void:
	var filename : String = "res://tests/reflection/Reflection.bfbs"
	var bfbs : PackedByteArray = FileAccess.get_file_as_bytes( filename )
	if bfbs.is_empty():
		retcode = 1
		output.append("Unable to open file: 'res://tests/reflection/Reflection.bfbs'")
		output.append( error_string( FileAccess.get_open_error() ) )
		return

	var root_table : Schema = schema.get_root( bfbs )
	if root_table: return

	retcode = 1
	output.append_array( [
		"Failure to decode bfbs using Reflection.fbs"
	])

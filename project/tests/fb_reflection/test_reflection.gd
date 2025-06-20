@tool
extends TestBase

const schema = preload('Reflection_generated.gd')
const Schema = schema.Schema

func _run() -> void:

	var filename : String = "res://tests/fb_reflection/Reflection.bfbs"

	var bfbs : PackedByteArray = FileAccess.get_file_as_bytes( filename )
	if bfbs.is_empty():
		output.append("Unable to open file: " + filename)
		output.append( error_string( FileAccess.get_open_error() ) )
		return

	var root_table : Schema = schema.get_root( bfbs )
	if not root_table:
		output.append( "Failure to decode bfbs using Reflection.fbs")
		return

	retcode = runcode

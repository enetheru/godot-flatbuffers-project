@tool
extends TestBase

# ║  __      _               _     __   _        _        _    _
# ║ | _|  __| |_ _ _ _  _ __| |_  |_ | (_)_ _   | |_ __ _| |__| |___
# ║ | |  (_-<  _| '_| || / _|  _|  | | | | ' \  |  _/ _` | '_ \ / -_)
# ║ | |  /__/\__|_|  \_,_\__|\__|  | | |_|_||_|  \__\__,_|_.__/_\___|
# ╙─|__|──────────────────────────|__|───────────────────────────────
#
# table fb_table{
#   flatbuffer_defined_struct : [FlatbufferDefinedStruct];
#   builtin_basic_type : [BasicGodotVariant];
#   builtin_packed_type : [PackableGodotType];
# }
#
# Test usage for:
# * presence
# * accessor to full array
# * accessor for individual element '_at( index )'
# * use PackedArray types when appropriate:
#   - PackedColorArray
#   - PackedVector2Array
#   - PackedVector3Array
#   - PackedVector4Array
#
const fb = preload('struct_in_table_generated.gd')
var builtin_ := Vector3i(1,2,3)



func _run() -> void:
	# presence
	# accessor to full array
	# accessor for individual element '_at( index )'
	# use PackedArray types when appropriate:
	retcode = runcode
	pass

@tool
extends EditorScript

var PropertyHint = {
	PROPERTY_HINT_NONE : "PROPERTY_HINT_NONE", ## ///< no hint provided.
	PROPERTY_HINT_RANGE : "PROPERTY_HINT_RANGE", ## ///< hint_text = "min,max[,step][,or_greater][,or_less][,hide_slider][,radians_as_degrees][,degrees][,exp][,suffix:<keyword>] range.
	PROPERTY_HINT_ENUM : "PROPERTY_HINT_ENUM", ## ///< hint_text= "val1,val2,val3,etc"
	PROPERTY_HINT_ENUM_SUGGESTION : "PROPERTY_HINT_ENUM_SUGGESTION", ## ///< hint_text= "val1,val2,val3,etc"
	PROPERTY_HINT_EXP_EASING : "PROPERTY_HINT_EXP_EASING", ## /// exponential easing function (Math::ease) use "attenuation" hint string to revert (flip h), "positive_only" to exclude in-out and out-in. (ie: "attenuation,positive_only")
	PROPERTY_HINT_LINK : "PROPERTY_HINT_LINK", ##
	PROPERTY_HINT_FLAGS : "PROPERTY_HINT_FLAGS", ## ///< hint_text= "flag1,flag2,etc" (as bit flags)
	PROPERTY_HINT_LAYERS_2D_RENDER : "PROPERTY_HINT_LAYERS_2D_RENDER", ##
	PROPERTY_HINT_LAYERS_2D_PHYSICS : "PROPERTY_HINT_LAYERS_2D_PHYSICS", ##
	PROPERTY_HINT_LAYERS_2D_NAVIGATION : "PROPERTY_HINT_LAYERS_2D_NAVIGATION", ##
	PROPERTY_HINT_LAYERS_3D_RENDER : "PROPERTY_HINT_LAYERS_3D_RENDER", ##
	PROPERTY_HINT_LAYERS_3D_PHYSICS : "PROPERTY_HINT_LAYERS_3D_PHYSICS", ##
	PROPERTY_HINT_LAYERS_3D_NAVIGATION : "PROPERTY_HINT_LAYERS_3D_NAVIGATION", ##
	PROPERTY_HINT_FILE : "PROPERTY_HINT_FILE", ## ///< a file path must be passed, hint_text (optionally) is a filter "*.png,*.wav,*.doc,"
	PROPERTY_HINT_DIR : "PROPERTY_HINT_DIR", ## ///< a directory path must be passed
	PROPERTY_HINT_GLOBAL_FILE : "PROPERTY_HINT_GLOBAL_FILE", ## ///< a file path must be passed, hint_text (optionally) is a filter "*.png,*.wav,*.doc,"
	PROPERTY_HINT_GLOBAL_DIR : "PROPERTY_HINT_GLOBAL_DIR", ## ///< a directory path must be passed
	PROPERTY_HINT_RESOURCE_TYPE : "PROPERTY_HINT_RESOURCE_TYPE", ## ///< a comma-separated resource object type, e.g. "NoiseTexture,GradientTexture2D". Subclasses can be excluded with a "-" prefix if placed *after* the base class, e.g. "Texture2D,-MeshTexture".
	PROPERTY_HINT_MULTILINE_TEXT : "PROPERTY_HINT_MULTILINE_TEXT", ## ///< used for string properties that can contain multiple lines
	PROPERTY_HINT_EXPRESSION : "PROPERTY_HINT_EXPRESSION", ## ///< used for string properties that can contain multiple lines
	PROPERTY_HINT_PLACEHOLDER_TEXT : "PROPERTY_HINT_PLACEHOLDER_TEXT", ## ///< used to set a placeholder text for string properties
	PROPERTY_HINT_COLOR_NO_ALPHA : "PROPERTY_HINT_COLOR_NO_ALPHA", ## ///< used for ignoring alpha component when editing a color
	PROPERTY_HINT_OBJECT_ID : "PROPERTY_HINT_OBJECT_ID", ##
	PROPERTY_HINT_TYPE_STRING : "PROPERTY_HINT_TYPE_STRING", ## ///< a type string, the hint is the base type to choose
	PROPERTY_HINT_NODE_PATH_TO_EDITED_NODE : "PROPERTY_HINT_NODE_PATH_TO_EDITED_NODE", ## // Deprecated.
	PROPERTY_HINT_OBJECT_TOO_BIG : "PROPERTY_HINT_OBJECT_TOO_BIG", ## ///< object is too big to send
	PROPERTY_HINT_NODE_PATH_VALID_TYPES : "PROPERTY_HINT_NODE_PATH_VALID_TYPES", ##
	PROPERTY_HINT_SAVE_FILE : "PROPERTY_HINT_SAVE_FILE", ## ///< a file path must be passed, hint_text (optionally) is a filter "*.png,*.wav,*.doc,". This opens a save dialog
	PROPERTY_HINT_GLOBAL_SAVE_FILE : "PROPERTY_HINT_GLOBAL_SAVE_FILE", ## ///< a file path must be passed, hint_text (optionally) is a filter "*.png,*.wav,*.doc,". This opens a save dialog
	PROPERTY_HINT_INT_IS_OBJECTID : "PROPERTY_HINT_INT_IS_OBJECTID", ## // Deprecated.
	PROPERTY_HINT_INT_IS_POINTER : "PROPERTY_HINT_INT_IS_POINTER", ##
	PROPERTY_HINT_ARRAY_TYPE : "PROPERTY_HINT_ARRAY_TYPE", ##
	PROPERTY_HINT_LOCALE_ID : "PROPERTY_HINT_LOCALE_ID", ##
	PROPERTY_HINT_LOCALIZABLE_STRING : "PROPERTY_HINT_LOCALIZABLE_STRING", ##
	PROPERTY_HINT_NODE_TYPE : "PROPERTY_HINT_NODE_TYPE", ## ///< a node object type
	PROPERTY_HINT_HIDE_QUATERNION_EDIT : "PROPERTY_HINT_HIDE_QUATERNION_EDIT", ## /// Only Node3D::transform should hide the quaternion editor.
	PROPERTY_HINT_PASSWORD : "PROPERTY_HINT_PASSWORD", ##
	PROPERTY_HINT_LAYERS_AVOIDANCE : "PROPERTY_HINT_LAYERS_AVOIDANCE", ##
	PROPERTY_HINT_DICTIONARY_TYPE : "PROPERTY_HINT_DICTIONARY_TYPE", ##
	PROPERTY_HINT_TOOL_BUTTON : "PROPERTY_HINT_TOOL_BUTTON", ##
	PROPERTY_HINT_ONESHOT : "PROPERTY_HINT_ONESHOT", ## ///< the property will be changed by self after setting, such as AudioStreamPlayer.playing, Particles.emitting.
	#PROPERTY_HINT_NO_NODEPATH : "PROPERTY_HINT_NO_NODEPATH", ## /// < this property will not contain a NodePath, regardless of type (Array, Dictionary, List, etc.). Needed for SceneTreeDock.
	PROPERTY_HINT_MAX : "PROPERTY_HINT_MAX", ##
};

var PropertyUsageFlags = {
	PROPERTY_USAGE_NONE : "PROPERTY_USAGE_NONE", #  = 0,
	PROPERTY_USAGE_STORAGE : "PROPERTY_USAGE_STORAGE", #  = 1 << 1,
	PROPERTY_USAGE_EDITOR : "PROPERTY_USAGE_EDITOR", #  = 1 << 2,
	PROPERTY_USAGE_INTERNAL : "PROPERTY_USAGE_INTERNAL", #  = 1 << 3,
	PROPERTY_USAGE_CHECKABLE : "PROPERTY_USAGE_CHECKABLE", #  = 1 << 4, // Used for editing global variables.
	PROPERTY_USAGE_CHECKED : "PROPERTY_USAGE_CHECKED", #  = 1 << 5, // Used for editing global variables.
	PROPERTY_USAGE_GROUP : "PROPERTY_USAGE_GROUP", #  = 1 << 6, // Used for grouping props in the editor.
	PROPERTY_USAGE_CATEGORY : "PROPERTY_USAGE_CATEGORY", #  = 1 << 7,
	PROPERTY_USAGE_SUBGROUP : "PROPERTY_USAGE_SUBGROUP", #  = 1 << 8,
	PROPERTY_USAGE_CLASS_IS_BITFIELD : "PROPERTY_USAGE_CLASS_IS_BITFIELD", #  = 1 << 9,
	PROPERTY_USAGE_NO_INSTANCE_STATE : "PROPERTY_USAGE_NO_INSTANCE_STATE", #  = 1 << 10,
	PROPERTY_USAGE_RESTART_IF_CHANGED : "PROPERTY_USAGE_RESTART_IF_CHANGED", #  = 1 << 11,
	PROPERTY_USAGE_SCRIPT_VARIABLE : "PROPERTY_USAGE_SCRIPT_VARIABLE", #  = 1 << 12,
	PROPERTY_USAGE_STORE_IF_NULL : "PROPERTY_USAGE_STORE_IF_NULL", #  = 1 << 13,
	PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED : "PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED", #  = 1 << 14,
	PROPERTY_USAGE_SCRIPT_DEFAULT_VALUE : "PROPERTY_USAGE_SCRIPT_DEFAULT_VALUE", #  = 1 << 15, // Deprecated.
	PROPERTY_USAGE_CLASS_IS_ENUM : "PROPERTY_USAGE_CLASS_IS_ENUM", #  = 1 << 16,
	PROPERTY_USAGE_NIL_IS_VARIANT : "PROPERTY_USAGE_NIL_IS_VARIANT", #  = 1 << 17,
	PROPERTY_USAGE_ARRAY : "PROPERTY_USAGE_ARRAY", #  = 1 << 18, // Used in the inspector to group properties as elements of an array.
	PROPERTY_USAGE_ALWAYS_DUPLICATE : "PROPERTY_USAGE_ALWAYS_DUPLICATE", #  = 1 << 19, // When duplicating a resource, always duplicate, even with subresource duplication disabled.
	PROPERTY_USAGE_NEVER_DUPLICATE : "PROPERTY_USAGE_NEVER_DUPLICATE", #  = 1 << 20, // When duplicating a resource, never duplicate, even with subresource duplication enabled.
	PROPERTY_USAGE_HIGH_END_GFX : "PROPERTY_USAGE_HIGH_END_GFX", #  = 1 << 21,
	PROPERTY_USAGE_NODE_PATH_FROM_SCENE_ROOT : "PROPERTY_USAGE_NODE_PATH_FROM_SCENE_ROOT", #  = 1 << 22,
	PROPERTY_USAGE_RESOURCE_NOT_PERSISTENT : "PROPERTY_USAGE_RESOURCE_NOT_PERSISTENT", #  = 1 << 23,
	PROPERTY_USAGE_KEYING_INCREMENTS : "PROPERTY_USAGE_KEYING_INCREMENTS", #  = 1 << 24, // Used in inspector to increment property when keyed in animation player.
	PROPERTY_USAGE_DEFERRED_SET_RESOURCE : "PROPERTY_USAGE_DEFERRED_SET_RESOURCE", #  = 1 << 25, // Deprecated.
	PROPERTY_USAGE_EDITOR_INSTANTIATE_OBJECT : "PROPERTY_USAGE_EDITOR_INSTANTIATE_OBJECT", #  = 1 << 26, // For Object properties, instantiate them when creating in editor.
	PROPERTY_USAGE_EDITOR_BASIC_SETTING : "PROPERTY_USAGE_EDITOR_BASIC_SETTING", #  = 1 << 27, //for project or editor settings, show when basic settings are selected.
	PROPERTY_USAGE_READ_ONLY : "PROPERTY_USAGE_READ_ONLY", #  = 1 << 28, // Mark a property as read-only in the inspector.
	PROPERTY_USAGE_SECRET : "PROPERTY_USAGE_SECRET", #  = 1 << 29, // Export preset credentials that should be stored separately from the rest of the export config.
	#PROPERTY_USAGE_DEFAULT : "PROPERTY_USAGE_DEFAULT", #  = PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
	#PROPERTY_USAGE_NO_EDITOR : "PROPERTY_USAGE_NO_EDITOR", #  = PROPERTY_USAGE_STORAGE,
};

func get_property_info( property_name : StringName ) -> Dictionary:
	var prop_list := get_property_list()
	var prop_idx = prop_list.find_custom(
		func(info): return info.name == property_name )
	if prop_idx == -1: return {}
	return prop_list[prop_idx]

func nice_prop_info( prop_info : Dictionary ) -> Dictionary:
	var usage : Array = []
	for key in PropertyUsageFlags:
		if prop_info.get("usage", 0) & key:
			usage.append( PropertyUsageFlags[key] )

	var nice_info = {
		"class_name": prop_info.get("class_name"),
		"hint": PropertyHint.get(prop_info.get("hint")),
		"hint_string": prop_info.get("hint_string"),
		"name": prop_info.get("name"),
		"type": type_string(prop_info.get("type", 0)),
		"usage": " | ".join(usage)
	}
	return nice_info


class MyObject:
	var name : String = "my_0bject"
	@export
	var test : int = 5
	#var _variant : Variant
	#var _aabb : AABB
	#var _array : Array
	#var _basis : Basis
	#var _bool : bool
	#var _callable : Callable
	#var _color : Color
	#var _dictionary : Dictionary
	#var _float : float
	#var _int : int
	#var _nodepath : NodePath
	#var _object : Object
	#var _packedbytearray : PackedByteArray
	#var _packedcolorarray : PackedColorArray
	#var _packedfloat32array : PackedFloat32Array
	#var _packedfloat64array : PackedFloat64Array
	#var _packedint32array : PackedInt32Array
	#var _packedint64array : PackedInt64Array
	#var _packedstringarray : PackedStringArray
	#var _packedvector2array : PackedVector2Array
	#var _packedvector3array : PackedVector3Array
	#var _packedvector4array : PackedVector4Array
	#var _plane : Plane
	#var _projection : Projection
	#var _quaternion : Quaternion
	#var _rect2 : Rect2
	#var _rect2i : Rect2i
	#var _rid : RID
	#var _signal : Signal
	#var _string : String
	#var _stringname : StringName
	#var _transform2d : Transform2D
	#var _transform3d : Transform3D
	#var _vector2 : Vector2
	#var _vector2i : Vector2i
	#var _vector3 : Vector3
	#var _vector3i : Vector3i
	#var _vector4 : Vector4
	#var _vector4i : Vector4i

var scalar_types = [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]
var struct_types = []
var array_types = ["String"]

func _run() -> void:
	var object = MyObject.new()

	var prop_list = object.get_property_list()
	for prop_info in prop_list:
		if not (prop_info.usage & PROPERTY_USAGE_STORAGE): continue
		print()
		print_rich("[b]%s[/b]" % [prop_info.name])
		print( JSON.stringify( nice_prop_info( prop_info ), "  " ) )

	var object_table =  generate_table( "MyObject", object )
	print( generate_schema("MyObject", [object_table]))


func export_filter( prop_info : Dictionary ) -> bool:
	return (prop_info.type in scalar_types
		and prop_info.usage & PROPERTY_USAGE_STORAGE)

func generate_schema( root : String, chunks : Array[String] ) -> String:
	var lines = ["// Generated By gdflatbuffers"]
	for chunk : String in chunks:
		lines.append(chunk)
	lines.append_array(["", "root_type {root};".format({"root": root})])
	return "\n".join( lines )

func generate_table( type : String, object ) -> String:
	var lines : Array[String] = [""]
	var export_list : Array[Dictionary] = object.get_property_list().filter(export_filter)

	# TODO How to deal with includes?
	# TODO How to deal with namespaces?

	# table definition.
	lines.append("table {type} {".format( {"type":type} ) )

	for prop_info in export_list:
		var field : String = "  {name}: {type};".format( nice_prop_info( prop_info ) )
		lines.append( field )
		# I'm pretty sure we cant support defaults from generating it this way.

	lines.append("}")
	return "\n".join(lines)

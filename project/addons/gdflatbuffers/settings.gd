@tool

## │ ___      _   _   _                _  _     _                 [br]
## │/ __| ___| |_| |_(_)_ _  __ _ ___ | || |___| |_ __  ___ _ _   [br]
## │\__ \/ -_)  _|  _| | ' \/ _` (_-< | __ / -_) | '_ \/ -_) '_|  [br]
## │|___/\___|\__|\__|_|_||_\__, /__/ |_||_\___|_| .__/\___|_|    [br]
## ╰────────────────────────|___/────────────────|_|──────────────[br]
## This class saves me from writing so much boilerplate for creating editor
## settings for the editor plugins I wish to write.[br]
## [br]
## The class looks for custom exported properties with
## [code]PROPERTY_USAGE_EDITOR_BASIC_SETTING[/code] and exposes them as
## editor_settings.[br]
## [br]
## It is intended to be used in [EditorPlugin] singletons to transform exported
## properties into editor settings.[br]
## [br]
## [b]== Usage ==[/b][br]
## drop it into your plugin's folder and initialise it like so:
## [codeblock]
## func _enter_tree() -> void:
##     settings_mgr = SettingsHelper.new(self, "plugin/my_plugin_name")
## [/codeblock]
## [br]
## [b]== Examples ==[/b][br]
## [codeblock]
## @export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING)
## var example : bool
## [/codeblock]
## [br]
## To facilitate grouping of settings, add the [code]PROPERTY_USAGE_GROUP[/code]
## and [code]PROPERTY_USAGE_SUBGROUP[/code] bitflags to the export.[br]
## Underscores will be replaced with forward slashes.[br]
## Only two layers deep are supported.
## [codeblock]
## @export_custom( PROPERTY_HINT_NONE, "",
##	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
## var group_subgroup_example : bool
## [/codeblock]
## [br]
## Not all property hints work, as there is not a 1:1 relationship between the
## editor settings and the inspector.[br]
## [br]
## [b]== More ==[/b][br]
## The goal of this script is to provided a friendly way to define editor or project properties based on an object.
## Is used primarily for singletons like editor plugins, but if i finish it, it can be extended to project singletons too.
## Rather than manually setting them up one by one, it also provides a mechanism such that selecting the node shows the properties.
## [br]
## The idea is that we walk the property list of an object, and translate its properties into editor settings.
## [br]
## Object Property Dictionary.[br]
## Returns the object's property list as an Array of dictionaries. Each [Dictionary] contains the following entries:[br]
## - name is the property's name, as a [String];[br]
## - class_name is an empty [StringName], unless the property is [enum Variant.Type].[code]TYPE_OBJECT[/code] and it inherits from a class;[br]
## - type is the property's type, as an int (see [enum Variant.Type]);[br]
## - hint is how the property is meant to be edited (see [enum PropertyHint]);[br]
## - hint_string depends on the hint (see [enum PropertyHint]);[br]
## - usage is a combination of [enum PropertyUsageFlags].[br]
## [b]Note:[/b] In GDScript, all class members are treated as properties.
## In C# and GDExtension, it may be necessary to explicitly mark class members
## as Godot properties using decorators or attributes.
## [br]
## EditorSettings property.[br]
## [codeblock]
## settings.set("category/property_name", 0)
## var property_info = {
##	# - "name": "category/property_name",
##	# - "type": TYPE_INT,
##	# - "hint": PROPERTY_HINT_ENUM,
##	# - "hint_string": "one,two,three"
## }
## settings.add_property_info(property_info)
## [/codeblock]
## [br]
## 11/11/2025 10:41am ACT+930 - I guess Created[br]
## [br]
## 09/02/2026 12:58am ACT+930 - re-added the signal for when a
## setting changes and updated documentation[br]

# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var editor_settings : EditorSettings

var _prefix : String
var _target : EditorPlugin

signal settings_changed( setting_name:StringName, value:Variant )

#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_editor_settings_changed() -> void:

	for setting_name in editor_settings.get_changed_settings():
		if not setting_name.begins_with(_prefix): continue
		if setting_name.begins_with(_prefix.path_join(&"built-in")): continue
		var prop_val : Variant = editor_settings.get(setting_name)
		var prop_name : StringName = setting_name.trim_prefix(_prefix+ "/").replace('/', '_')
		# try to set the target object property value.
		if prop_name in _target.get_property_list().reduce(
			func( prop_names : Array, prop_dict : Dictionary ) -> Array:
				prop_names.append(prop_dict.name); return prop_names, [] ):
					_target.set( prop_name, prop_val )
		else:
			printerr("property(%s) invalid for target(%s)" % [
				prop_name, _target.name])
		settings_changed.emit( prop_name, prop_val )


func _on_target_tree_exiting() -> void:
	editor_settings.settings_changed.disconnect( _on_editor_settings_changed )
	var erase_when_exit := _prefix.path_join('erase_when_exit')
	if editor_settings.has_setting( erase_when_exit ) \
		and editor_settings.get_setting( erase_when_exit ):
			erase_settings_in_prefix()


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init( target : EditorPlugin, prefix : String = "" )-> void:
	print("Starting Settings Class")
	_prefix = prefix
	_target = target

	editor_settings = EditorInterface.get_editor_settings()

	@warning_ignore_start('return_value_discarded')
	_target.tree_exiting.connect( _on_target_tree_exiting, CONNECT_ONE_SHOT )
	editor_settings.settings_changed.connect( _on_editor_settings_changed )
	@warning_ignore_restore('return_value_discarded')


	add_properties_to_settings()
	add_builtin_settings()


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Add all the properties as settings
func add_properties_to_settings() -> void:
	for property : Dictionary in _target.get_property_list():
		if not (property.usage & PROPERTY_USAGE_EDITOR_BASIC_SETTING): continue

		var prop_name : StringName = property.get(&'name')
		var setting_name : StringName = _prefix

		# Split into groups
		if property.usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
			for segment : String in prop_name.split('_', false,
				2 if property.usage & PROPERTY_USAGE_SUBGROUP else 1):
				setting_name = setting_name.path_join(segment)
		else:
			setting_name = setting_name.path_join(prop_name)

		var setting : Dictionary = {
			&'name': setting_name,
			&'type': property.type,
			&'hint': property.hint,
			&'hint_string': property.hint_string
		}

		var initial_value : Variant = _target.get( prop_name )

		# update the settings.
		if not editor_settings.has_setting(setting_name):
			editor_settings.set_setting( setting_name, initial_value )
			editor_settings.set_initial_value(setting_name, initial_value, true)
			#editor_settings.mark_setting_changed(setting_info.name)
		# Incase our plugin has changed, update the setting
		editor_settings.set_initial_value(setting_name, initial_value, false)
		editor_settings.add_property_info(setting)

		var prop_val : Variant = editor_settings.get(setting_name)
		_target.set( prop_name, prop_val )


## Add some boilerplate settings.
func add_builtin_settings() -> void:
	# Add tool button to open object in the inspector.
	var open_inspector : Dictionary = {
		&'name': _prefix.path_join(&"built-in").path_join("inspect"),
		&'type': TYPE_CALLABLE,
		&'hint': PROPERTY_HINT_TOOL_BUTTON,
		&'hint_string': "Open Settings Object In Inspector"
	}
	var inspector_name : String = open_inspector.name
	editor_settings.set_setting( inspector_name, EditorInterface.inspect_object.bind(_target) )
	editor_settings.add_property_info(open_inspector)

	var rebuild : Dictionary = {
		&'name': _prefix.path_join(&"built-in").path_join("rebuild"),
		&'type': TYPE_CALLABLE,
		&'hint': PROPERTY_HINT_TOOL_BUTTON,
		&'hint_string': "Rebuild Settings"
	}
	var rebuild_name : String = rebuild.name
	editor_settings.set_setting( rebuild_name, rebuild_settings )
	editor_settings.add_property_info(rebuild)

	var erase_when_exit : Dictionary = {
		&'name': _prefix.path_join(&"built-in").path_join(&"erase_when_exit"),
		&'type': TYPE_BOOL,
		&'hint': PROPERTY_HINT_NONE,
		&'hint_string': ""
	}
	var erase_name : String = erase_when_exit.name
	editor_settings.set_setting( erase_name, false )
	editor_settings.add_property_info(erase_when_exit)


## Erase settings with _prefix
func erase_settings_in_prefix() -> void:
	print("Scrubbing '%s/*' from editor configuration." % _prefix )
	for property in editor_settings.get_property_list():
		var setting_name : String = property.get(&'name')
		if setting_name.begins_with(_prefix):
			editor_settings.erase(setting_name)


func rebuild_settings() -> void:
	erase_settings_in_prefix()
	add_properties_to_settings()
	add_builtin_settings()

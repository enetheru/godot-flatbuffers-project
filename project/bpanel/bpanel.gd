@tool
extends GridContainer

# Test Runner
# TODO - make the script names clickable to load them up in the editor.

# ████ ███    ███ ██████   █████  ██████  ██████ ██████
#  ██  ████  ████ ██   ██ ██   ██ ██   ██   ██   ██
#  ██  ██ ████ ██ ██████  ██   ██ ██████    ██   ██████
#  ██  ██  ██  ██ ██      ██   ██ ██   ██   ██       ██
# ████ ██      ██ ██       █████  ██   ██   ██   ██████

const Test = preload('res://tests/test.gd')

# █████  ██████ ██████ ████ ███   ██ ████ ██████ ████  █████  ███   ██ ██████
# ██  ██ ██     ██      ██  ████  ██  ██    ██    ██  ██   ██ ████  ██ ██
# ██  ██ ████   ████    ██  ██ ██ ██  ██    ██    ██  ██   ██ ██ ██ ██ ██████
# ██  ██ ██     ██      ██  ██  ████  ██    ██    ██  ██   ██ ██  ████     ██
# █████  ██████ ██     ████ ██   ███ ████   ██   ████  █████  ██   ███ ██████

class TestInfoBox extends PanelContainer:
	var label : Label
	var rtl : RichTextLabel
	var stylebox : StyleBox = preload('res://bpanel/info_style_box.tres').duplicate()

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		label = $Elements/Label
		rtl = $Elements/RichTextLabel
		add_theme_stylebox_override("panel", stylebox)
		focus_entered.connect(func():
			stylebox.bg_color = Color(0.275, 0.439, 0.584)
			)
		focus_exited.connect(func():
			stylebox.bg_color = Color(0.216, 0.31, 0.4)
			)

	func set_success( txt : String ):
		stylebox.border_color = Color.DARK_GREEN
		rtl.clear()
		rtl.append_text(txt)

	func set_fail( txt : String ):
		stylebox.border_color = Color.DARK_RED
		rtl.clear()
		rtl.push_color(Color.RED)
		rtl.append_text(txt)
		rtl.pop()


#var test_dict : Dictionary = {
	#"name": folder.to_pascal_case(),
	#"folder_path": folder_path,
	#"test_scripts": files.filter( test_script_filter ),
	#"schema_files": files.filter( schema_file_filter )
#}

#var test_schema_spec : Dictionary = {
	#"folder_path": "",
#
	#"schema_files" : [""],
	#"test_scripts" : [""],
	#"results": {  }
#}

# ██████  ██████   █████  ██████  ██████ ██████  ██████ ████ ██████ ██████
# ██   ██ ██   ██ ██   ██ ██   ██ ██     ██   ██   ██    ██  ██     ██
# ██████  ██████  ██   ██ ██████  ████   ██████    ██    ██  ████   ██████
# ██      ██   ██ ██   ██ ██      ██     ██   ██   ██    ██  ██         ██
# ██      ██   ██  █████  ██      ██████ ██   ██   ██   ████ ██████ ██████

var plugin : FlatBuffersPlugin = FlatBuffersPlugin._prime

@onready var test_runner = Test.new()

# Icons
@export var schema_icon: Texture2D

@onready var etheme : Theme = EditorInterface.get_editor_theme()
@onready var folder_icon: Texture2D = etheme.get_icon( "Folder", "EditorIcons" )
@onready var reload_icon: Texture2D = etheme.get_icon( "Reload", "EditorIcons" )
@onready var trash_icon: Texture2D = etheme.get_icon( "Remove", "EditorIcons" )
@onready var script_icon: Texture2D = etheme.get_icon( "GDScript", "EditorIcons" )
@onready var error_icon: Texture2D = etheme.get_icon( "StatusError", "EditorIcons" )
@onready var success_icon: Texture2D = etheme.get_icon( "StatusSuccess", "EditorIcons" )
@onready var warning_icon: Texture2D = etheme.get_icon( "StatusWarning", "EditorIcons" )

@onready var buttons : Dictionary[StringName, Button] = {
	&"Reload": $Buttons/Reload,
	&"Test" : $Buttons/Test,
}

@onready var clear_results: Button = $Buttons/ClearResults
@onready var help: Button = $Buttons/Help

# FIXME temporary for testing
@onready var reload_panel: Button = $Buttons/Reload_panel

# tree control
@onready var tree: Tree = $TestOutput/Tree
@onready var info_list: VBoxContainer = $TestOutput/InfoList
@onready var info_scroller: ScrollContainer = $TestOutput/InfoList/ScrollContainer
@onready var info_items: VBoxContainer = $TestOutput/InfoList/ScrollContainer/InfoItems
@onready var test_info: PanelContainer = $TestOutput/InfoList/ScrollContainer/InfoItems/TestInfo


@onready var rtl: RichTextLabel = $RichTextLabel

var test_list : Array[Dictionary]

var test_path : String = 'res://tests'

var test_selection : Dictionary = {}

# ██████ ████  █████  ███    ██  █████  ██     ██████
# ██      ██  ██      ████   ██ ██   ██ ██     ██
# ██████  ██  ██  ███ ██ ██  ██ ███████ ██     ██████
#     ██  ██  ██   ██ ██  ██ ██ ██   ██ ██         ██
# ██████ ████  █████  ██   ████ ██   ██ ██████ ██████

# ██████ ██    ██ ██████ ███    ██ ██████ ██████
# ██     ██    ██ ██     ████   ██   ██   ██
# ████   ██    ██ ████   ██ ██  ██   ██   ██████
# ██      ██  ██  ██     ██  ██ ██   ██       ██
# ██████   ████   ██████ ██   ████   ██   ██████

func _on_reload_pressed():
	tree.clear()
	regenerate_tree()

func _on_test_pressed():
	process_selection()

func _on_clear_pressed():
	for child in info_items.get_children():
		if child == test_info: continue
		child.call_deferred("queue_free")

func _on_multi_select( item : TreeItem, _column : int, is_selected : bool):
	if is_selected: test_selection[item] = true
	else: test_selection.erase(item)

func _on_item_button_clicked(file_item: TreeItem, _column: int, _id: int, _mouse_button_index: int):
	match file_item.get_metadata(1):
				&"schema": process_schema(file_item)
				&"test": process_test(file_item)

func _on_gui_input( event ):
	if not event is InputEventMouseButton: return
	var mb_event : InputEventMouseButton = event
	if not mb_event.pressed: return
	#var column = tree.get_column_at_position(mb_event.position)
	var item : TreeItem = tree.get_item_at_position(mb_event.position)
	var test_def : Dictionary = item.get_metadata(0)
	var test_file : String = item.get_text(0)

	# FIXME it would be nice if I could get the file open in the text editor
	var file_path : String = "/".join([test_def.folder_path, test_file])
	EditorInterface.get_file_system_dock().navigate_to_path(file_path)

	var results : Dictionary = test_def["results"].get(item, null)
	if results: results["latest"].call_deferred( "grab_focus")


#  █████  ██    ██ ██████ ██████  ██████  ████ ██████  ██████ ██████
# ██   ██ ██    ██ ██     ██   ██ ██   ██  ██  ██   ██ ██     ██
# ██   ██ ██    ██ ████   ██████  ██████   ██  ██   ██ ████   ██████
# ██   ██  ██  ██  ██     ██   ██ ██   ██  ██  ██   ██ ██         ██
#  █████    ████   ██████ ██   ██ ██   ██ ████ ██████  ██████ ██████

func _ready() -> void:
	test_info.set_script( TestInfoBox )
	# Icon helper snippet
	#for type_name in etheme.get_type_list():
		#for icon_name in etheme.get_icon_list(type_name):
			#rtl.add_image(etheme.get_icon(icon_name, type_name))
			#rtl.append_text("\t")
			#rtl.append_text("/".join([type_name,icon_name]))
			#rtl.newline()

	buttons[&"Reload"].pressed.connect( _on_reload_pressed )
	buttons[&"Reload"].icon = reload_icon
	buttons[&"Test"].pressed.connect( _on_test_pressed )

	clear_results.pressed.connect( _on_clear_pressed )
	#help.pressed.connect( )

	reload_panel.pressed.connect( plugin.bpanel_reload, CONNECT_DEFERRED )
	# TODO add a popup with information about recursive expansion
	# and contracting using the shift key.
	#info.pressed.connect( info_popup )

	tree.multi_selected.connect(_on_multi_select)
	tree.button_clicked.connect(_on_item_button_clicked)
	tree.gui_input.connect(_on_gui_input)

	_on_reload_pressed()


# ███    ███ ██████ ██████ ██   ██  █████  ██████  ██████
# ████  ████ ██       ██   ██   ██ ██   ██ ██   ██ ██
# ██ ████ ██ ████     ██   ███████ ██   ██ ██   ██ ██████
# ██  ██  ██ ██       ██   ██   ██ ██   ██ ██   ██     ██
# ██      ██ ██████   ██   ██   ██  █████  ██████  ██████

func create_info( file_item : TreeItem ) -> Control:
	print( "Create Info")
	var test_def : Dictionary = file_item.get_metadata(0)
	var file_name : String = file_item.get_text(0)

	var info_box : TestInfoBox = test_info.duplicate( DUPLICATE_SCRIPTS )
	info_items.add_child(info_box)
	info_box.show()
	if not info_box.is_node_ready(): await info_box.ready

	info_box.label.text = "/".join([test_def.name, file_name])

	return info_box


func process_selection( action_type : StringName = &"all"):
	var selection : Array
	if test_selection.is_empty():
		selection = tree.get_root().get_children()
	elif tree.get_root() in test_selection.keys():
		selection = tree.get_root().get_children()
	else:
		selection = test_selection.keys()

	for folder_item : TreeItem in selection:
		for file_item : TreeItem in folder_item.get_children():
			var _test_def : Dictionary = file_item.get_metadata(0)
			var _action_type : StringName = file_item.get_metadata(1)
			var process : bool = action_type == &"all"
			if _action_type == action_type: process = true
			if not process: continue
			match _action_type:
				&"schema": process_schema(file_item)
				&"test": process_test(file_item)


func process_schema( file_item : TreeItem ):
	var info_box : TestInfoBox = await create_info( file_item )
	info_box.call_deferred( "grab_focus")
	var test_def : Dictionary = file_item.get_metadata(0)
	var schema_file : String = file_item.get_text(0)
	var schema_path : String = "/".join([test_def.folder_path, schema_file])

	# Generate the script
	var results : Dictionary = plugin.flatc_generate( schema_path, ['--gdscript'] )

	results["latest"] = info_box
	test_def.get_or_add( "results", {} ).set( file_item, results )


	# Update the tree_item
	if results.get('retcode', 1):
		set_item_fail(file_item)
		info_box.set_fail("\n".join(results.output))
	else:
		set_item_success(file_item)
		info_box.set_success("\n".join(results.output))


func process_test( file_item : TreeItem ):
	var info_box : TestInfoBox = await create_info( file_item )
	info_box.call_deferred( "grab_focus")
	var test_def : Dictionary = file_item.get_metadata(0)
	var script_file : String = file_item.get_text(0)
	var script_path : String = "/".join([test_def.folder_path, script_file])

	var thread := Thread.new()
	thread.start( run_test_script.bind( script_path ) )
	var results : Dictionary = thread.wait_to_finish()

	results["latest"] = info_box
	test_def.get_or_add( "results", {} ).set( file_item, results )

	# Update the tree_item
	if results.get('retcode', 1):
		set_item_fail(file_item)
		info_box.set_fail("\n".join(results.output))
	else:
		set_item_success(file_item)
		info_box.set_success("\n".join(results.output))


func run_test_script( file_path : String ) -> Dictionary:
	var result : Dictionary = {'path':file_path}
	var script : GDScript = load( file_path )
	if not script.can_instantiate():
		result['retcode'] = FAILED
		result['output'] = ["Cannot instantiate '%s'" % file_path ]
		return result
	var instance = script.new()
	instance.silent = true
	instance._run()
	result['retcode'] = instance.retcode
	result['output'] = instance.output
	return result


#   ████████ ██████  ███████ ███████
#      ██    ██   ██ ██      ██
#      ██    ██████  █████   █████
#      ██    ██   ██ ██      ██
#      ██    ██   ██ ███████ ███████

func set_item_fail( item : TreeItem ):
	item.set_text(1, "FAILURE")
	item.set_custom_bg_color(0, Color.DARK_RED, false)
	item.set_custom_bg_color(1, Color.DARK_RED, false)


func set_item_success( item : TreeItem ):
	item.set_text(1, "OK")
	item.set_custom_bg_color(0, Color.DARK_GREEN, false)
	item.set_custom_bg_color(1, Color.DARK_GREEN, false)

func add_action_row( test_def : Dictionary, action_type : StringName,
		filename : String, parent_item : TreeItem ):
	var item = parent_item.create_child()
	item.set_selectable(0, false )
	item.set_metadata(0, test_def )
	item.set_text( 0, filename )
	# Result
	item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_CENTER)
	item.set_selectable(1, false )
	item.set_text(1, "PENDING")
	item.set_metadata(1, action_type )
	item.add_button(1, reload_icon, -1, false, "[Re]Run Test Action" )

	match action_type:
		&"test": item.set_icon(0, script_icon)
		&"schema": item.set_icon(0, schema_icon)

func regenerate_tree():
	tree.clear()

	# re-build the test dictionary
	test_list = test_runner.collect_tests( test_path )

	tree.set_column_title(0, "TestElement")
	tree.set_column_title(1, "  Result  ")
	tree.set_column_expand(1,false)
	var _top_item = tree.create_item()
	_top_item.set_text(0,"Tests")
	for test_def in test_list:
		# Add Folder name
		var folder_item = tree.create_item()
		folder_item.set_text( 0, test_def.name )
		folder_item.set_selectable(1, false )

		# Add schema items
		for file in test_def.schema_files:
			add_action_row( test_def, &"schema", file, folder_item )

		# Add script items
		for file in test_def.test_scripts:
			add_action_row( test_def, &"test", file, folder_item )

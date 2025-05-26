@tool
extends PanelContainer

const _script_parent = preload('bpanel.gd')

var title : String
var label : RichTextLabel
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

func set_warning( txt : String ):
	stylebox.border_color = Color.DARK_GREEN
	rtl.clear()
	rtl.append_text(txt)

func set_success( txt : String ):
	label.clear()

	stylebox.border_color = Color.DARK_GREEN
	rtl.clear()
	rtl.append_text(txt)

func set_fail( txt : String ):
	stylebox.border_color = Color.DARK_RED
	rtl.clear()
	rtl.push_color(Color.RED)
	rtl.append_text(txt)
	rtl.pop()

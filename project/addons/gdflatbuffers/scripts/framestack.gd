class_name FrameStack

const StackFrame = preload('res://addons/gdflatbuffers/scripts/stackframe.gd')

var _capacity : int
var _top : int = -1
var _data : Array[StackFrame]

func _init( capacity : int ) -> void:
	_capacity = capacity
	_data.resize(capacity)

##  to insert an element into the stack
func push( element : StackFrame ):
	if is_full(): assert( "stack overflow" )
	_top += 1
	_data[_top] = element


##  to remove an element from the stack
func pop():
	var element : StackFrame = _data[_top]
	_data[_top] = null
	_top -= 1
	return element


##  Returns the top element of the stack.
func top():
	return _data[_top]


##  returns true if stack is empty else false.
func is_empty():
	return _top == -1


##  returns true if the stack is full else false.
func is_full():
	return _top == _capacity -1


func duplicate( deep : bool ) -> FrameStack:
	var new_stack = new(_capacity)
	new_stack._top = _top
	for i in range(_top+1):
		var frame : StackFrame = _data[i]
		new_stack._data[i] = frame.duplicate(deep)
	return new_stack

func clear():
	_top = -1
	for i in range(_capacity):
		_data[i] = null

func size():
	return _top + 1

func _to_string():
	var strings : Array = ["(%d/%d)" % [_top+1, _capacity]]
	for i in range( _top + 1 ):
		strings.append( "\t" + str(_data[i]))
	return "\n".join( strings )

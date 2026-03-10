@abstract
@tool

# an attempt to make a multi-dimensional testing regime

# I wonder if I can make a situation where we can specify interdependence or not.

enum Flags {
	OK = 0,
	ERROR = 1,
}
var flags:int = 0

#       █████  ██████  ███████ ████████ ██████   █████   ██████ ████████       #
#      ██   ██ ██   ██ ██         ██    ██   ██ ██   ██ ██         ██          #
#      ███████ ██████  ███████    ██    ██████  ███████ ██         ██          #
#      ██   ██ ██   ██      ██    ██    ██   ██ ██   ██ ██         ██          #
#      ██   ██ ██████  ███████    ██    ██   ██ ██   ██  ██████    ██          #
func                        ________ABSTRACT_________              ()->void:pass

@abstract
func _get_phase_count() -> int

@abstract
func _get_phase_name(phase:int) -> String

@abstract
func _get_strategy_count(phase:int) -> int

@abstract
func _get_strategy(phase:int, strategy:int) -> Callable

@abstract
func _flow( selection:Array[int] ) -> void


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass


## Phase count is how many separate sections or phases in the testing sequence.
func get_phase_count() -> int:
	return _get_phase_count()

## Get the name of the phase indicated by [param phase]
func get_phase_name(phase:int) -> String:
	return _get_phase_name(phase)

## Return the number of strategies for the given [param phase]
func get_strategy_count(phase:int) -> int:
	return _get_strategy_count(phase)

## return the [Callable] representing the [param strategy] n of [param phase] k
func get_strategy(phase:int, strategy:int) -> Callable:
	return _get_strategy(phase, strategy)

## run the workfow
func flow( selection:Array[int] ) -> void: _flow(selection)

## Can be used in place of a valid strategy for error checking.
func null_strategy(...args:Array ) -> Variant:
	if args.is_empty():
		print("Null strategy called")
		return null
	print("Null strategy called with args:")
	for arg:Variant in args: print("\t", str(arg))
	return null

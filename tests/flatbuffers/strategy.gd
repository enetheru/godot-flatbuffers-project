@abstract
@tool

# an attempt to make a multi-dimensional testing regime

# I wonder if I can make a situation where we can specify interdependence or not.

enum Flags {
	OK = 0,
	ERROR = 1,
}
var flags:int = 0


@abstract
## Phase count is how many separate sections or phases in the testing sequence.
func get_phase_count() -> int


@abstract
## Get the name of the phase indicated by [param phase]
func get_phase_name(phase:int) -> String


@abstract
## Return the number of strategies for the given [param phase]
func get_strategy_count(phase:int) -> int


@abstract
## return the [Callable] representing the [param strategy] n of [param phase] k
func get_strategy(phase:int, strategy:int) -> Callable

@abstract
## run the workfow
func flow( selection:Array[int] ) -> void

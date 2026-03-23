@tool
extends TestStrategy

const Schema = preload("../schemas/attribute_generated.gd")

var test:TestBase

#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass


func _init(initiator:TestBase) -> void:
	test = initiator

func _get_phase_count() -> int: return 1

func _get_phase_name(_idx:int) -> String: return  'attribute'

func _get_strategy_count(_idx:int) -> int: return 1

func _get_strategy(_idx:int, _idx2:int) -> Callable:
	return null_strategy()

#                     ███████ ██       ██████  ██     ██                       #
#                     ██      ██      ██    ██ ██     ██                       #
#                     █████   ██      ██    ██ ██  █  ██                       #
#                     ██      ██      ██    ██ ██ ███ ██                       #
#                     ██      ███████  ██████   ███ ███                        #
func                        __________FLOW___________              ()->void:pass

## A selection is an array of strategies, one for each phase.
func _flow( _selection:Array[int] ) -> void:
	var test_object := Schema.Attribute.new()
	test.TEST_FALSE(test_object.has_method(&"deprecated_field"))

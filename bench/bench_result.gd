@tool
class_name BenchResult
extends Resource

## One benchmark measurement. Absent measurements stay nan, so a graph can skip them.

@export var timestamp_utc:String = ""
@export var unix_s:int = 0
@export var target:String = ""
@export var suite:String = ""
@export var benchmark:String = ""
@export var time_ns:float = NAN
@export var iterations:int = 0
@export var bytes:float = NAN
@export var bytes_per_s:float = NAN
@export var error:String = ""

@tool
class_name BenchHistory
extends Resource

## Append-only benchmark history. Each entry is a BenchResult.
## The array is typed as Resource so this script parses before that class is in the global cache.
@export var rows:Array[Resource] = []

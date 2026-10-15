# Benchmarking

[[lib/flatbuffers/docs/source/benchmarks]]

I went and build some dumb copy paste of the google test code so I could run the tests as they do in the main project.
pls don't hate on me, it was not a good week and it helped with my anxiety to manually process it(No AI).

Anyway, through that experience it drew my attention to the fact that my reproduction test cases weren't apples to apples comparisons, and that more could be achieved.

I also need to respect the existing benchmarks so that I can compare against them.

## Scenarios

I really want to emphasise a more real-world scenario's Which from my limited imagination mostly comes down to usage

Use the serialised data to:
- update
- create
- store
- load

The pipeline should somewhat look like:

For updating objects:
```
pre-existing-object | --(encoding)-> wire-format --(decoding)-> --(updating)-> | pre-existing-object
                   >|__________________________________________________________|<
                          The window we are interested in
```
For Spawning objects:
```
pre-existing-object | --(encoding)-> wire-format --(decoding)-> new-object |
                   >|______________________________________________________|<
                                 The window we are interested in
```
For Storage:
```
 | pre-existing-object | --(encoding)-> Storage |
>|_____________________________________________ |<
          The window we are interested in
```
For Loading:
```
 | wire-format --(decoding)-> new-object |
>|_______________________________________|<
     The window we are interested in
```

## Methods
And I want to be able to benchmark against alternate methods
- Godot Built-In with GDScript
- FlatBuffers with GDScript
- Godot Built-In with GDExtension
- FlatBuffers with GDExtension

> [!QUESTION] What about other languages like C# or Rust?

> [!QUESTION] What about using generated C++ godot class helpers underpinned with FlatBuffers?
> so fbs -> C++ in GDExtension registered classes.

## Scenario suite

`runner_scenario.gd` (`scenario` in `run.ps1`, Scenarios in the bench list) is the comparison suite. The construction lives in `compare_work.gd`. This section is the methodology those files implement. If the two disagree, the scripts are what ran.

`runner_suite.gd` is a separate test: the upstream 3-record sample. Its numbers are not this methodology.

### Payload

One container, 64 records. The schema is `fb_scripts/bench.fbs`. The field formulas are `CompareWork._apply`.

The container is `initialized = true`, fruit bananas (`2`), and location `http://google.com/flatbuffers/`. Record `i` from 0 through 63 is:

- `id = 0xBADCAFEABADCAFE + i` (fits a positive Godot int)
- `count = 10000 + i`, `prefix = ord("@") + i`, `length = 1000000 + i`
- `time = 123456 + i`, `ssize = 10000 + i`, `postfix = ord("!") + i`
- `ratio = 3.14159 + i`, `rating = 3.1415432432445543543 + i`
- `name = "Hello, World!"` on every record

`ratio` is a flatbuffer `float` (32-bit) and a Godot `float` (64-bit) on the dictionary and the objects. `rating` is a flatbuffer `double`. The other scalars fit the schema widths.

**Dictionary**
  One `Dictionary` passed to `var_to_bytes` / `bytes_to_var`. No objects, so the call is not `var_to_bytes_with_objects`. Keys are `location`, `fruit` (the int `2`), `initialized`, and `list`. Each list entry has `name`, `postfix`, `rating`, and `sibling`. `sibling` has `time`, `ratio`, `size` (the schema field `ssize`), and `parent`. `parent` has `id`, `count`, `prefix`, and `length`.

**Objects**
  `FooBarContainer`, `FooBar`, `Bar`, and `Foo`. Encoded with `var_to_bytes_with_objects`, which writes the script class as well as the fields. That is why this buffer is larger than the other two. The classes are not a stand-in for the dictionary.

**FlatBuffers**
  `FlatBufferBuilder.create(0)` (no initial capacity). Each record calls `create_variant` for `"Hello, World!"`, so the buffer holds 64 copies of that string, not one shared string. The location string is written once. `create_FBFoo` and `create_FBBar` allocate a struct object per record. The `FBFooBar` and `FBFooBarContainer` table builders are the generated static instances, reused across records and across iterations.

### Timer

gdsbench times the `for` loop only. `CompareWork.new()`, `make_dict()`, `make_objects()`, and the encode used to size the byte counter sit outside that loop. The scenario runner does not change the default minimum time of `0.5s` and does not set an iteration cap.

The byte counter is the encoded length of one buffer, marked iteration-invariant. `history.tres` stores that length in `bytes`. The console `bytes_size` column is the same counter after it has been multiplied by the iteration count, then shown in Mi. Divide by the iteration count before comparing it to `bytes`.

| Test | FlatBuffers, inside the loop | Dictionary, inside the loop | Objects, inside the loop | Dict from objects, inside the loop |
| --- | --- | --- | --- | --- |
| Store | `encode_flat()`: formulas, builder, 64 strings, `finish` | `var_to_bytes` of the dictionary built before the loop | `var_to_bytes_with_objects` of the object graph built before the loop | `dict_from_objects` of that same object graph, then `var_to_bytes` |
| Load | `get_FBFooBarContainer` plus `FlatBuffersBench.Use` | `bytes_to_var` plus `case_gd_dict.gd` `Use` | `bytes_to_var_with_objects` plus `BuiltInBench.Use` | the same `bytes_to_var` plus `Use`, on the buffer `dict_from_objects` encoded before the loop |
| Spawn | root view, then a new dictionary filled field by field | `bytes_to_var` | `bytes_to_var_with_objects` | `bytes_to_var` of that same buffer |
| Update | write accessors into the dictionary built before the loop | `bytes_to_var`, then copy fields onto the dictionary built before the loop | `bytes_to_var_with_objects`, then copy fields onto the objects built before the loop | `bytes_to_var`, then copy fields onto the dictionary `dict_from_objects` built before the loop |
| Peek | new root, then `list_at(32).rating()` | `bytes_to_var`, then the rating at index 32 | `bytes_to_var_with_objects`, then the rating at index 32 | `bytes_to_var`, then the rating at index 32, on that same buffer |

Load and Peek also compare the result to a value computed before the loop, and skip the run if it differs. Store adds `buf.size()` to the throughput counter. Spawn checks that the result is non-empty. Update does not checksum inside the loop.

### Where a comparison is fair

**Same logical values**
  The codecs start from `_apply`. Dict from objects is checked against the same sum: the dictionary built from the object graph, that dictionary after `var_to_bytes`, the spawned dictionary, the patched destination, and the peeked rating. A run is skipped unless the checksums match, including after `var_to_bytes` and `var_to_bytes_with_objects` round-trips.

**Checksum**
  `FlatBuffersBench.Use`, `BuiltInBench.Use`, and `case_gd_dict.gd` `Use` add the same terms: `int(initialized)`, location length, fruit as an int, then per record the name length, postfix, `int(rating)`, `int(ratio)`, size, time, count, id, length, and prefix. The sum is allowed to be negative. The large ids overflow an int64 add. Equality is the check. `int(ratio)` truncates, so a 32-bit versus 64-bit fraction on `ratio` does not fail the check.

**Codecs inside one process**
  Editor, template_debug, and template_release are separate processes. Compare the codecs inside one of those rows. Editor and template_debug print that the Godot binary is a debug build. template_release does not. That warning is the Godot binary, not a difference between the codecs.

### Where a comparison is not the same work

**Store**
  Dictionary and Objects time only the encoder. The value already exists. FlatBuffers has no existing buffer, so Store times building one from the formulas, including a new builder and 64 string copies. Dict from objects (`BM_DictFromObj_Store`) keeps the object graph outside the timer and, inside it, copies those fields into a new dictionary and then calls `var_to_bytes`. That is the send path when the fields live on objects. It still does not start FlatBuffers from those objects. The storage sketch above describes Dictionary, Objects, and Dict from objects. FlatBuffers remains the formula build.

**Load**
  Every codec reads every field inside the timer, and the checksum has to match. For the dictionary and the objects, `bytes_to_var` has already materialized those fields, and `Use` walks them again in GDScript. For FlatBuffers, `Use` is the walk that produces the values. Dict from objects (`BM_DictFromObj_Load`) uses the Dictionary window on the buffer `dict_from_objects` encoded before the loop. Building that dictionary is not inside this timer. Load is a fair "touch every field" test. It is a pessimistic "time until the data exists" test for the dictionary paths and the objects, by one extra walk.

**Spawn**
  FlatBuffers and Dictionary both end as a dictionary. FlatBuffers copies each field in GDScript. Dictionary returns the dictionary `bytes_to_var` already built. Dict from objects (`BM_DictFromObj_Spawn`) returns `bytes_to_var` of the buffer built from the object graph before the loop, so it ends as that same kind of dictionary. Objects ends as a `FooBarContainer` of script instances. Pair FlatBuffers Spawn with Dictionary Spawn. The Objects column is a different destination.

**Update**
  The destination exists before the loop. FlatBuffers writes fields from the buffer into that dictionary and does not allocate a second copy of the payload. Dictionary and Objects fully decode a temporary, then copy onto the existing value, because `bytes_to_var` cannot patch one field. Dict from objects (`BM_DictFromObj_Update`) decodes that dictionary buffer and copies onto a dictionary `dict_from_objects` built before the loop. FlatBuffers Update patches a dictionary, not `Foo` / `Bar` / `FooBar` instances. Pair it with Dictionary Update.

**Peek**
  Index 32, rating only. FlatBuffers builds a root and reads that field. Dictionary and Objects decode the whole buffer, then read the field. Dict from objects (`BM_DictFromObj_Peek`) does that Dictionary read on the buffer built from the object graph before the loop. Dictionary peek also narrows the decoded `Variant` with `is` before the `int` conversion. That check is small next to `bytes_to_var` and is not how a typed property read looks.

**FlatBuffers reader objects**
  A view is not free of GDScript allocations. `get_FBFooBarContainer` constructs a root. `list_at` without `into` constructs an `FBFooBar` per call. `sibling()` constructs an `FBBar`. The `parent` getter constructs an `FBFoo`. Load, Spawn, Update, and Peek pay those objects on top of the byte reads. The timed code does not pass `into`, so those readers are not reused.

**Update and Spawn are checked once, then timed**
  Before any benchmark, `check_payload` clears `location` on a destination, applies the buffer, and requires the checksum to return. A no-op apply fails there, and every benchmark in that process is skipped. The timed Update and Spawn loops do not repeat that checksum. A later break that still returns a non-empty value would still record a time.

## Reuse suite

`runner_reuse.gd` (`reuse` in `run.ps1`) registers `BM_Flatbuffers_StoreReuse`, `BM_Flatbuffers_LoadReuse`, `BM_Flatbuffers_SpawnReuse`, `BM_Flatbuffers_UpdateReuse`, and `BM_Flatbuffers_PeekReuse`. Each one is the scenario question with one allocation removed. The metric is the time difference from the scenario row of the same operation. These rows do not ask whether FlatBuffers beats Dictionary.

## Store with reused structs

`BM_Flatbuffers_StoreReuse` builds the same buffer as `encode_flat`. Scenario Store calls `create_FBFoo` and `create_FBBar` on every record. Each call constructs a struct and a `PackedByteArray`. StoreReuse writes those fields onto one `FBFoo` and one `FBBar` created before the loop. `FlatBufferBuilder.create(0)`, the 64 `create_variant` name copies, the location string, and `finish` stay inside the timer.

`BM_Flatbuffers_Store` minus `BM_Flatbuffers_StoreReuse` is the per-record struct allocation. Both timers still construct the buffer from the formulas.

Before the timed loop, the reused buffer has to equal `encode_flat`. A mismatch skips the run. The loop does not compare buffers again. It adds the encoded length to the throughput counter, the same counter as scenario Store.

The foo fields are written in the creator's order: length, prefix, count, id. The bar then writes ssize, ratio, time, and `parent`. `parent` copies the foo bytes into the bar. `create_FBFooBar` copies the bar into the builder before the next record overwrites those two structs.

## Load with reused readers

The payload and the checksum terms are the same as scenario Load. `CompareWork.flat_sum_reuse` adds the same values as `FlatBuffersBench.Use`, in the same order. Before the timed loop, and again on every iteration, that sum has to match `flat_sum`. A mismatch skips the run.

`Readers` is built once, before the loop: one `FBFooBarContainer`, one `FBFooBar`, one `FBBar`, and one `FBFoo`. Each iteration calls `assign_buffer` on that container with the root offset at byte 0. Each record calls `list_at(i, into)` with the same `FBFooBar`. The sibling view is `sibling(into)` on the same `FBBar`. The parent view is `parent_into` on the same `FBFoo` at the start of the bar, which is what the `parent` getter constructs. `name`, `postfix`, `rating`, `location`, `initialized`, and `fruit` are still one call each. The string objects those calls return are not reused.

## Spawn with reused readers

`BM_Flatbuffers_SpawnReuse` builds the same dictionary as `spawn_flat`. The timed loop calls `spawn_flat_reuse` and skips the run when that dictionary is empty. It does not repeat the checksum. Before the loop, `dict_sum` of the reused dictionary has to match `dict_sum` of `spawn_flat` on the same buffer. A mismatch skips the run.

The reused root, table, and both structs are the same `Readers` objects as Load. The new dictionaries for the container, each row, and each sibling are still allocated inside the timer. That is the Spawn result. Only the FlatBuffers reader objects are reused.

## Update with reused readers

`BM_Flatbuffers_UpdateReuse` patches a dictionary built before the timed loop, the same window as scenario Update. The loop calls `apply_flat_reuse` and does not repeat the checksum.

Before that loop, `location` is cleared on a separate dictionary, `apply_flat_reuse` writes it, and `dict_sum` has to match `apply_flat` on another cleared dictionary. A missing sibling or a mismatched sum skips the run. The timed destination is a fresh `make_dict()` and is not that probe.

The reused root, table, and both structs are the same `Readers` objects. The destination dictionary and its nested rows already exist. `name`, `location`, and the other field reads still return new values. Those reads are not reused.

## Peek with a reused table

`BM_Flatbuffers_PeekReuse` reads rating at index 32, the same field as scenario Peek. The timed loop calls `peek_flat_reuse` and skips the run when that rating differs from `peek_flat` on the same buffer.

The root is the reused `FBFooBarContainer`. The record is `list_at(32, into)` on the reused `FBFooBar`. Sibling and parent are not read, so the `FBBar` and `FBFoo` on `Readers` stay unused. `rating()` is still one call. That return is not reused.

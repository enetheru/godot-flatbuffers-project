@tool
extends EditorScript

var fs := EditorInterface.get_resource_filesystem()
var test_dir : EditorFileSystemDirectory = fs.get_filesystem_path( 'res://tests/' )
var fbs_dir : EditorFileSystemDirectory = fs.get_filesystem_path( 'res://fbs_files/tests/' )
var plugin : FlatBuffersPlugin

func test_script_filter( filename : String ) -> bool:
	return filename.begins_with("test") \
		and filename.ends_with(".gd") \
		and not filename.ends_with("_generated.gd")

func schema_file_filter( filename : String ) -> bool:
	return filename.ends_with(".fbs")

func folder_filter( folder_path : String ) -> bool:
	var files : Array = DirAccess.get_files_at( folder_path )
	return not files.filter( test_script_filter ).is_empty()


func collect_tests( test_path : String ) -> Array[Dictionary]:
	var tests : Array[Dictionary]

	var folders : Array = DirAccess.get_directories_at(test_path)
	var folder_paths = folders.map(func(folder : String): return "/".join([test_path,folder]))
	folder_paths.sort()
	for folder_path : String in folder_paths.filter( folder_filter ):
		var files : Array = DirAccess.get_files_at( folder_path )
		var folder = folder_path.get_file()

		var test_dict : Dictionary = {
			"name": folder.to_pascal_case(),
			"folder_path": folder_path,
			"test_scripts": files.filter( test_script_filter ),
			"schema_files": files.filter( schema_file_filter )
		}
		tests.append( test_dict )

	return tests

func _run() -> void:
	plugin = FlatBuffersPlugin._prime
	print_rich( "\n[b]== GDFlatbuffer Plugin Testing ==[/b]\n" )
	var def_list : Array = collect_tests('res://tests')

	print_rich( "\n[b]... Compiling Flatbuffer Schemas[/b]\n" )
	var compile_results : Dictionary = {}
	for test_def : Dictionary in def_list:
		for schema_file : String in test_def.get('schema_files', []):
			var category = test_def.get('name')
			var schema_path = '/'.join([test_def.get('folder_path'), schema_file])
			var key : String = '/'.join([category,schema_file])
			var result : Dictionary = plugin.flatc_generate( schema_path, ['--gdscript'] )
			if result.get('retcode'):
				print_rich("[b]# Error processing %s[/b]" % key )
				print_result_error( result )
			compile_results[key] = result

	print_compile_results( compile_results )

	print_rich( "\n[b]... Running %s Tests[/b]\n" )
	var test_results : Dictionary = {}
	for test_def : Dictionary in def_list:
		for script_file : String in test_def.get('test_scripts', []):
			var category = test_def.get('name')
			var script_path = '/'.join([test_def.get('folder_path'), script_file])
			var key : String = '/'.join([category,script_file])

			var thread := Thread.new()
			thread.start( run_test.bind( script_path ) )
			var result = thread.wait_to_finish()

			if result.get('retcode'):
				print_rich("[b]# Error running test %s[/b]" % key )
				print_result_error( result )
			test_results[key] = result

	print_test_results( test_results )


func run_test( file_path : String ) -> Dictionary:
	var result : Dictionary = {'path':file_path}
	var script : GDScript = load( file_path )
	if not script.can_instantiate():
		result['retcode'] = FAILED
		result['output'] = ["Cannot instantiate '%s'" % file_path ]
		return result
	var instance = script.new()
	instance._run()
	result['retcode'] = instance.retcode
	result['output'] = instance.output
	return result

func print_compile_results( results : Dictionary ):
	var rich_text : String = "\n[b]== Compile Results ==[/b]\n"
	rich_text += "[table=3]"
	for key in results:
		var result = results[key]
		print( key, result.get('path') )
		rich_text += "[cell]%s[/cell]" % [key]
		rich_text += "[cell]:[/cell]"
		rich_text += "[cell]%s[/cell]" % ("[color=red]Failure[/color]" if result['retcode'] else "[color=green]Success[/color]")
	rich_text += "[/table]"
	print_rich( rich_text )


func print_test_results( results : Dictionary ):
	var rich_text : String = "\n[b]== Test Results ==[/b]\n"
	var compilation : PackedStringArray = []
	for key in results:
		var result = results[key]
		compilation.push_back("[url=%s]%s[/url]" % [results.get('path'),key])
		compilation.push_back(":")
		compilation.push_back("[color=%s]%s[/color]" % (["red","Failure"] if result.retcode else ['green','Success']))
	rich_text += compile_rich_table( compilation, 3 )
	print_rich( rich_text )

func compile_rich_table( data : PackedStringArray, stride : int ):
	var rich_text : String = "[table=%s]" % stride
	for string in data:
		rich_text += "[cell]%s[/cell]" % string
	rich_text += "[/table]"
	return rich_text

func print_result_error( result : Dictionary ):
	var output = result.get('output')
	result.erase('output')
	printerr( "result: ", JSON.stringify( result, '\t', false ) )
	if output:
		for o in output: print_rich( o.indent('\t') )
	print("")

@tool
extends TestBase

const Schema = preload("uid://bhutniufto3o7")


func _run_test() -> int:
	var fbb := FlatBufferBuilder.new()
	
	var vos_ofs:int = fbb.create_PackedVector2Array([
		Vector2.ONE,
		Vector2.ZERO,
		#Vector2.ZERO,
		#Vector2.ZERO,
		])
	
	var final_ofs:int = Schema.create_Vost(fbb, vos_ofs)
	fbb.finish(final_ofs)
	
	var packed := fbb.to_packed_byte_array()
	print(sbytes(packed, 4))
	
	var vost := Schema.get_Vost(packed)
	
	# Root Table Offset
	var pos:int = 0
	var root_offset:int = packed.decode_u32(0)
	print("\npos %4d: " % pos, "RootOffset: %s %s" % [
			sbytes(packed.slice(0,4), 4),
			root_offset] )
	
	pos += root_offset
	
	# VTable Offset
	var table_offset:int = packed.decode_s32(pos)
	print("\npos %4d: " % pos, "VTableOffset: %s %s" % [
			sbytes(packed.slice(pos,pos+4), 4),
			table_offset] )
	
	pos -= table_offset
			
	#VTable Size
	var vtable_size:int = packed.decode_u16(pos)
	print("\npos %4d: " % pos, "VTable.size: %s %s" % [
			sbytes(packed.slice(pos,pos+2), 2),
			vtable_size] )
	
	pos += 2
	
	# Table Size
	var table_size:int = packed.decode_u16(pos)
	print("\npos %4d: " % pos, "Table.size: %s %s" % [
			sbytes(packed.slice(pos,pos+2), 2),
			table_size] )
	
	pos += 2
	
	# First Element offset
	var vtable_0:int = packed.decode_u16(pos)
	print("\npos %4d: " % pos, "VTable[0]: %s %s" % [
			sbytes(packed.slice(pos,pos+2), 2),
			vtable_0] )
	
	pos += vtable_0
	
	# First Element or Offset to first element.
	# If It was an the offset
	var field_0:int = packed.decode_u32(pos)
	print("\npos %4d: " % pos, "vost_size?: %s %s" % [
			sbytes(packed.slice(pos,pos+4), 4),
			field_0] )
	
	# First Element or Offset to first element.
	## if it is the first vector.(which it cant because its not serialised.) 
	var vec_0:Vector2 = vost.decode_Vector2(pos)
	print("\npos %4d: " % pos, "vost_size?: %s %s" % [
			sbytes(packed.slice(pos,pos+8), 8),
			vec_0] )
			
	# the size could be the size of the table in bytes. and since we
	# dont have any elements, then the size is 4, for the 32 bit integer
	# size
	var field_start:int = vost.get_field_start(Schema.Vost.vtable.VT_LIST)
	print("Field Start:",  field_start)
	print("list_size: ", packed.decode_u32(field_start) )
	
	print("First Element:", (field_start+4))
	print("Second Element:", vost.decode_Vector2(field_start+4+8))
	pos = field_start + 4
	var first:Vector2 = vost.decode_Vector2(pos)
	print("\npos %4d: " % pos, "%s %s" % [
			sbytes(packed.slice(pos,pos+8), 8),
			first] )
	pos += 8
	print("\npos %4d: " % pos, "%s %s" % [
			sbytes(packed.slice(pos,pos+8), 8),
			first] )
	
	return runcode

@tool
extends EditorScript

## │ __  __             _              [br]
## │|  \/  |___ _ _  __| |_ ___ _ _    [br]
## │| |\/| / _ \ ' \(_-<  _/ -_) '_|   [br]
## │|_|  |_\___/_||_/__/\__\___|_|     [br]
## ╰────────────────────────────────── [br]
## Quick Sanity Check.


const Print = preload("uid://cbluyr4ifn8g3")
const Schema = preload("uid://d08seaooakblg")

func _run() -> void:
	print("New Builder")
	var fbb := FlatBufferBuilder.new()
	
	print("Create String for name: \n\t'MonsterName'")
	var name_ofs:int = fbb.create_String("MonsterName")
	
	print("Create Inventory Array:")
	var treasure:PackedByteArray = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	print("\t", treasure)
	var inventory_ofs:int = fbb.create_vector_uint8( treasure )
	
	print("Creating Weapons List:")
	var weapons:Dictionary = {
		"Sword":3,
		"Axe":5
	}
	# Store the individual weapon offsets in here
	var weapon_ofs:Dictionary = {} 

	# Create offset to the list of offsets to the weapons.
	# ofs -> [ofs] -> weapon
	var weapons_ofs:int = fbb.create_vector_offset(
		weapons.keys().map(
			func(wname:String) -> int:
				var damage:int = weapons[wname]
				print( "\t%s:%s" % [wname, damage])
				var ofs:int = Schema.create_Weapon(fbb,
					fbb.create_String(wname), damage)
				weapon_ofs[wname] = ofs
				return ofs))
	
	
	var points:PackedVector3Array = [
		Vector3(1,2,3),
		Vector3(4,5,6)
	]
	print("Creating Path:\n\t", points)
	var points_ofs:int = fbb.create_PackedVector3Array(points)
	
	print("New Monster Builder")
	var mbb := Schema.MonsterBuilder.new(fbb)
	
	print("Add fields")
# table Monster {
#   pos:Vector3; // Struct.
	mbb.add_pos(Vector3(1,2,3))
#   mana:short = 150;
	mbb.add_mana(123)
#   hp:short = 100;
	mbb.add_hp(456)
#   name:string;
	mbb.add_name(name_ofs)
#   inventory:[ubyte];  // Vector of scalars.
	mbb.add_inventory(inventory_ofs)
#   color:Color = Blue; // Enum.
	mbb.add_color(Schema.Color_.RED)
#   weapons:[Weapon];   // Vector of tables.
	mbb.add_weapons(weapons_ofs)
#   equipped:Equipment; // Union.
	var axe_ofs:int = weapon_ofs['Axe']
	mbb.add_equipped_type(Schema.Equipment.WEAPON)
	mbb.add_equipped(axe_ofs)
#   path:[Vector3];     // Vector of structs.
	mbb.add_path(points_ofs)
# }
	
	print("Finish Monster")
	var final_ofs:int = mbb.finish()
	print("Finish Builder")
	fbb.finish(final_ofs)
	
	print("export to PackedByteArray")
	var packed := fbb.to_packed_byte_array()
	print( Enetheru.string.sbytes(packed) )
	
	print("get Monster")
	var mreader := Schema.get_Monster(packed)
	print( "pos      : ", mreader.pos() )
	print( "mana     : ", mreader.mana() )
	print( "hp       : ", mreader.hp() )
	print( "name     : ", mreader.name() )
	print( "inventory: ", mreader.inventory() )
	print( "color    : ", Schema.Color_.find_key(mreader.color()) )
	
	print( "weapons  : ", mreader.weapons_size() )
	for i in mreader.weapons_size():
		var weapon := mreader.weapons_at(i)
		print( "\t%s:%s" % [weapon.name(), weapon.damage()])
		
	print( "equippedT: ", Schema.Equipment.find_key(mreader.equipped_type()) )
	print( "equipped: ")
	match mreader.equipped_type():
		Schema.Equipment.NONE:
			print( "\tNothing Equipped")
		Schema.Equipment.WEAPON:
			var equipped:Schema.Weapon = mreader.equipped()
			print( "\t%s:%s" % [equipped.name(), equipped.damage()])
			
	print( "path.size:", mreader.path_size())
	print( "path_at(i):")
	for i in mreader.path_size():
		print( "\t%s:" % i, mreader.path_at(i))
	print( "path():")
	for p:Vector3 in mreader.path():
		print( "\t%s" % p)
	

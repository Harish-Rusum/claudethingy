class_name Upgrades
extends RefCounted

# rarity: 0 = common, 1 = rare, 2 = epic
# cost is how many seconds get taken off the level clock
const LIST := {
	&"haste": {
		"name": "haste",
		"desc": "run 25% faster",
		"flavor": "gotta go.",
		"cost": 4.0,
		"rarity": 0,
		"icon": preload("res://assets/ui/upgrades/haste.png"),
	},
	&"spring": {
		"name": "spring",
		"desc": "jump 30% higher",
		"flavor": "leg day paid off.",
		"cost": 4.0,
		"rarity": 0,
		"icon": preload("res://assets/ui/upgrades/spring.png"),
	},
	&"bubble": {
		"name": "bubble",
		"desc": "press E for 2s\nof not dying",
		"flavor": "it's a bubble. it pops.",
		"cost": 3.0,
		"rarity": 1,
		"key": "E",
		"icon": preload("res://assets/ui/upgrades/bubble.png"),
	},
	&"glide": {
		"name": "featherfall",
		"desc": "hold jump while\nfalling to float",
		"flavor": "the floor can wait.",
		"cost": 3.0,
		"rarity": 1,
		"icon": preload("res://assets/ui/upgrades/glide.png"),
	},
	&"double_jump": {
		"name": "double jump",
		"desc": "one more jump\nin midair",
		"flavor": "physics called.\nwe let it ring.",
		"cost": 6.0,
		"rarity": 2,
		"icon": preload("res://assets/ui/upgrades/double_jump.png"),
	},
	&"dash": {
		"name": "dash",
		"desc": "shift to zip forward.\nrecharges on landing",
		"flavor": "zoom.",
		"cost": 5.0,
		"rarity": 2,
		"key": "SHIFT",
		"icon": preload("res://assets/ui/upgrades/dash.png"),
	},
}

const RARITY_NAMES := ["common", "rare", "epic"]
const RARITY_COLORS := [Color("c596da"), Color("99c9b3"), Color("ff8e80")]
const RARITY_CARDS := [&"CardCommon", &"CardRare", &"CardEpic"]
const RARITY_WEIGHTS := [6, 4, 3]


static func get_info(id: StringName) -> Dictionary:
	return LIST.get(id, {})


# weighted pick without repeats
static func roll(count := 3) -> Array[StringName]:
	var pool: Array = LIST.keys()
	var picked: Array[StringName] = []
	while picked.size() < count and not pool.is_empty():
		var total := 0
		for id in pool:
			total += RARITY_WEIGHTS[LIST[id].rarity]
		var r := randi() % total
		for id in pool:
			r -= RARITY_WEIGHTS[LIST[id].rarity]
			if r < 0:
				picked.append(id)
				pool.erase(id)
				break
	return picked

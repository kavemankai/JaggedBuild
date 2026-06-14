class_name ShipClasses
# Static factory returning ShipClassData for each player class.

const ShipClassData := preload("res://scripts/ShipClassData.gd")
const ShipDials := preload("res://scripts/ShipDials.gd")


static func for_id(class_id: String) -> ShipClassData:
	match class_id:
		"heavy_fighter": return _heavy()
		"interceptor":   return _interceptor()
		"gunship":       return _gunship()
		_:               return _fighter()


static func player_class_ids() -> Array:
	return ["fighter", "heavy_fighter", "interceptor", "gunship"]


static func display_name(class_id: String) -> String:
	return for_id(class_id).class_name_display


# --- player classes ---

static func _fighter() -> ShipClassData:
	var c := ShipClassData.new()
	c.class_name_display = "Fighter"
	c.faction = "player"
	c.attack = 2; c.defence = 2; c.shields = 2; c.hull = 3
	c.firing_arc_degrees = 90.0
	c.dial = ShipDials.fighter()
	c.primary_weapon_options = ["CANNONS", "BURST", "HEAVY", "ION"]
	c.upgrade_slots = 1
	return c


static func _heavy() -> ShipClassData:
	var c := ShipClassData.new()
	c.class_name_display = "Heavy Fighter"
	c.faction = "player"
	c.attack = 3; c.defence = 1; c.shields = 3; c.hull = 4
	c.firing_arc_degrees = 70.0
	c.dial = ShipDials.heavy()
	c.primary_weapon_options = ["HEAVY", "CANNONS", "MISSILES"]
	c.upgrade_slots = 1
	return c


static func _interceptor() -> ShipClassData:
	var c := ShipClassData.new()
	c.class_name_display = "Interceptor"
	c.faction = "player"
	c.attack = 1; c.defence = 3; c.shields = 1; c.hull = 2
	c.firing_arc_degrees = 110.0
	c.dial = ShipDials.interceptor()
	c.primary_weapon_options = ["BURST", "CANNONS", "ION"]
	c.upgrade_slots = 1
	return c


static func _gunship() -> ShipClassData:
	var c := ShipClassData.new()
	c.class_name_display = "Gunship"
	c.faction = "player"
	c.attack = 2; c.defence = 2; c.shields = 3; c.hull = 4
	c.firing_arc_degrees = 90.0
	c.dial = ShipDials.gunship()
	c.primary_weapon_options = ["CANNONS", "HEAVY", "ION"]
	c.upgrade_slots = 1
	return c

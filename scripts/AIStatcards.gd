extends Node  # not an autoload — static factory only

# HOTAC-style maneuver tables. Keys: range band × bearing zone → bearing choices.
# Range bands: CLOSE / MEDIUM / LONG / OUT
# Bearing zones: BULLSEYE / FRONT / FRONT_SIDE / REAR_SIDE / REAR

static func enemy_fighter() -> AIStatcard:
	var s := AIStatcard.new()
	s.ship_class_id = "enemy_fighter"
	s.target_priority = ["nearest_enemy"]
	s.action_priority = ["TARGET_LOCK", "FOCUS"]
	s.target_mode = "ATTACK"
	s.maneuver_table = {
		"CLOSE": {
			"BULLSEYE":   ["BANK_LEFT", "BANK_RIGHT"],
			"FRONT":      ["TURN_LEFT", "TURN_RIGHT"],
			"FRONT_SIDE": ["K_TURN"],
			"REAR_SIDE":  ["BANK_LEFT", "BANK_RIGHT"],
			"REAR":       ["STRAIGHT"],
		},
		"MEDIUM": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["BANK_LEFT", "BANK_RIGHT"],
			"FRONT_SIDE": ["TURN_LEFT", "TURN_RIGHT"],
			"REAR_SIDE":  ["BANK_LEFT", "BANK_RIGHT"],
			"REAR":       ["K_TURN"],
		},
		"LONG": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT"],
			"FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"],
			"REAR_SIDE":  ["TURN_LEFT", "TURN_RIGHT"],
			"REAR":       ["K_TURN"],
		},
		"OUT": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["STRAIGHT"],
			"FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"],
			"REAR_SIDE":  ["BANK_LEFT", "BANK_RIGHT"],
			"REAR":       ["K_TURN"],
		},
	}
	s.stress_maneuver_table = {
		"CLOSE": { "BULLSEYE": ["BANK_LEFT", "BANK_RIGHT"], "FRONT": ["BANK_LEFT", "BANK_RIGHT"], "FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"], "REAR_SIDE": ["STRAIGHT"], "REAR": ["STRAIGHT"] },
		"MEDIUM": { "BULLSEYE": ["STRAIGHT"], "FRONT": ["BANK_LEFT", "BANK_RIGHT"], "FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"], "REAR_SIDE": ["BANK_LEFT", "BANK_RIGHT"], "REAR": ["STRAIGHT"] },
		"LONG": { "BULLSEYE": ["STRAIGHT"], "FRONT": ["STRAIGHT"], "FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"], "REAR_SIDE": ["BANK_LEFT", "BANK_RIGHT"], "REAR": ["STRAIGHT"] },
		"OUT": { "BULLSEYE": ["STRAIGHT"], "FRONT": ["STRAIGHT"], "FRONT_SIDE": ["STRAIGHT"], "REAR_SIDE": ["STRAIGHT"], "REAR": ["STRAIGHT"] },
	}
	return s


static func enemy_scout() -> AIStatcard:
	var s := AIStatcard.new()
	s.ship_class_id = "enemy_scout"
	s.target_priority = ["nearest_enemy"]
	s.action_priority = ["EVADE", "FOCUS"]
	s.target_mode = "ATTACK"
	s.maneuver_table = {
		"CLOSE": {
			"BULLSEYE":   ["BANK_LEFT", "BANK_RIGHT"],
			"FRONT":      ["K_TURN"],
			"FRONT_SIDE": ["K_TURN"],
			"REAR_SIDE":  ["STRAIGHT"],
			"REAR":       ["STRAIGHT"],
		},
		"MEDIUM": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["BANK_LEFT", "BANK_RIGHT"],
			"FRONT_SIDE": ["TURN_LEFT", "TURN_RIGHT"],
			"REAR_SIDE":  ["BANK_LEFT", "BANK_RIGHT"],
			"REAR":       ["K_TURN"],
		},
		"LONG": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["STRAIGHT"],
			"FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"],
			"REAR_SIDE":  ["TURN_LEFT", "TURN_RIGHT"],
			"REAR":       ["K_TURN"],
		},
		"OUT": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["STRAIGHT"],
			"FRONT_SIDE": ["STRAIGHT"],
			"REAR_SIDE":  ["BANK_LEFT", "BANK_RIGHT"],
			"REAR":       ["K_TURN"],
		},
	}
	s.stress_maneuver_table = {
		"CLOSE": { "BULLSEYE": ["BANK_LEFT", "BANK_RIGHT"], "FRONT": ["BANK_LEFT", "BANK_RIGHT"], "FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"], "REAR_SIDE": ["STRAIGHT"], "REAR": ["STRAIGHT"] },
		"MEDIUM": { "BULLSEYE": ["STRAIGHT"], "FRONT": ["BANK_LEFT", "BANK_RIGHT"], "FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"], "REAR_SIDE": ["BANK_LEFT", "BANK_RIGHT"], "REAR": ["STRAIGHT"] },
		"LONG": { "BULLSEYE": ["STRAIGHT"], "FRONT": ["STRAIGHT"], "FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"], "REAR_SIDE": ["BANK_LEFT", "BANK_RIGHT"], "REAR": ["STRAIGHT"] },
		"OUT": { "BULLSEYE": ["STRAIGHT"], "FRONT": ["STRAIGHT"], "FRONT_SIDE": ["STRAIGHT"], "REAR_SIDE": ["STRAIGHT"], "REAR": ["STRAIGHT"] },
	}
	return s


static func enemy_assault() -> AIStatcard:
	var s := AIStatcard.new()
	s.ship_class_id = "enemy_assault"
	s.target_priority = ["lowest_hull"]
	s.action_priority = ["TARGET_LOCK", "FOCUS"]
	s.target_mode = "ATTACK"
	s.maneuver_table = {
		"CLOSE": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["BANK_LEFT", "BANK_RIGHT"],
			"FRONT_SIDE": ["TURN_LEFT", "TURN_RIGHT"],
			"REAR_SIDE":  ["BANK_LEFT", "BANK_RIGHT"],
			"REAR":       ["STRAIGHT"],
		},
		"MEDIUM": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["STRAIGHT"],
			"FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"],
			"REAR_SIDE":  ["BANK_LEFT", "BANK_RIGHT"],
			"REAR":       ["STRAIGHT"],
		},
		"LONG": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["STRAIGHT"],
			"FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"],
			"REAR_SIDE":  ["BANK_LEFT", "BANK_RIGHT"],
			"REAR":       ["STRAIGHT"],
		},
		"OUT": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["STRAIGHT"],
			"FRONT_SIDE": ["STRAIGHT"],
			"REAR_SIDE":  ["STRAIGHT"],
			"REAR":       ["STRAIGHT"],
		},
	}
	s.stress_maneuver_table = s.maneuver_table.duplicate(true)  # assault is slow, same under stress
	return s


static func bulk_cruiser() -> AIStatcard:
	var s := AIStatcard.new()
	s.ship_class_id = "enemy_large"
	s.target_priority = ["objective", "nearest_enemy"]
	s.action_priority = ["FOCUS"]
	s.target_mode = "STRIKE"  # relentlessly pursue the convoy
	s.maneuver_table = {
		# Large hull: only STRAIGHT and gentle banks. No turns, no K-turn.
		"CLOSE": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["BANK_LEFT", "BANK_RIGHT"],
			"FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"],
			"REAR_SIDE":  ["STRAIGHT"],
			"REAR":       ["STRAIGHT"],
		},
		"MEDIUM": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["STRAIGHT"],
			"FRONT_SIDE": ["BANK_LEFT", "BANK_RIGHT"],
			"REAR_SIDE":  ["BANK_LEFT", "BANK_RIGHT"],
			"REAR":       ["STRAIGHT"],
		},
		"LONG": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["STRAIGHT"],
			"FRONT_SIDE": ["STRAIGHT"],
			"REAR_SIDE":  ["BANK_LEFT", "BANK_RIGHT"],
			"REAR":       ["STRAIGHT"],
		},
		"OUT": {
			"BULLSEYE":   ["STRAIGHT"],
			"FRONT":      ["STRAIGHT"],
			"FRONT_SIDE": ["STRAIGHT"],
			"REAR_SIDE":  ["STRAIGHT"],
			"REAR":       ["STRAIGHT"],
		},
	}
	s.stress_maneuver_table = s.maneuver_table.duplicate(true)
	return s


static func for_class(class_id: String) -> AIStatcard:
	match class_id:
		"enemy_scout":   return enemy_scout()
		"enemy_assault": return enemy_assault()
		"enemy_large":   return bulk_cruiser()
		_:               return enemy_fighter()

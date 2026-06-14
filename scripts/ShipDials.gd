class_name ShipDials
# Static factory — call as ShipDials.fighter() etc.
# Gate 17 will add heavy(), interceptor(), gunship(), and enemy variants.


static func fighter() -> DialData:
	var d := DialData.new()
	# Section 2.1 — Wraith-class Fighter dial.
	# Speed 1 banks and turns are GREEN (clear 1 stress). Speed 3 turns cost stress.
	# Speed 4 is red-straight or K-Turn only.
	d.dial = {
		"STRAIGHT":   {1: "WHITE", 2: "WHITE", 3: "WHITE", 4: "RED"},
		"BANK_LEFT":  {1: "GREEN", 2: "WHITE", 3: "WHITE"},
		"BANK_RIGHT": {1: "GREEN", 2: "WHITE", 3: "WHITE"},
		"TURN_LEFT":  {1: "GREEN", 2: "WHITE", 3: "RED"},
		"TURN_RIGHT": {1: "GREEN", 2: "WHITE", 3: "RED"},
		"K_TURN":     {4: "RED"},
	}
	return d

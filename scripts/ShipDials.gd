class_name ShipDials
# Static dial factory. Each function returns a configured DialData instance.
# Dial keys: bearing (String) → speed (int) → color ("GREEN"|"WHITE"|"RED").
# Absent speed keys mean that maneuver does not exist on this dial.

const DialData := preload("res://scripts/DialData.gd")


# ── PLAYER CLASSES ──────────────────────────────────────────────────────────

# Section 2.1 — Wraith-class Fighter
# Speed 1 banks/turns are green. Speed 3 turns cost stress. Speed 4 = red sprint or K-Turn.
static func fighter() -> DialData:
	var d := DialData.new()
	d.dial = {
		"STRAIGHT":   {1: "WHITE", 2: "WHITE", 3: "WHITE", 4: "RED"},
		"BANK_LEFT":  {1: "GREEN", 2: "WHITE", 3: "WHITE"},
		"BANK_RIGHT": {1: "GREEN", 2: "WHITE", 3: "WHITE"},
		"TURN_LEFT":  {1: "GREEN", 2: "WHITE", 3: "RED"},
		"TURN_RIGHT": {1: "GREEN", 2: "WHITE", 3: "RED"},
		"K_TURN":     {4: "RED"},
	}
	return d


# Section 2.2 — Bastion-class Heavy Fighter
# Extremely forgiving at speed 1 (straight AND banks clear stress). No K-Turn.
static func heavy() -> DialData:
	var d := DialData.new()
	d.dial = {
		"STRAIGHT":   {1: "GREEN", 2: "WHITE", 3: "WHITE"},
		"BANK_LEFT":  {1: "GREEN", 2: "WHITE", 3: "RED"},
		"BANK_RIGHT": {1: "GREEN", 2: "WHITE", 3: "RED"},
		"TURN_LEFT":  {1: "WHITE", 2: "WHITE", 3: "RED"},
		"TURN_RIGHT": {1: "WHITE", 2: "WHITE", 3: "RED"},
	}
	return d


# Section 2.3 — Razor-class Interceptor
# Speed 1 banks free; speed 2 all-white; speed 4-5 = committed passes at stress cost.
static func interceptor() -> DialData:
	var d := DialData.new()
	d.dial = {
		"STRAIGHT":   {1: "WHITE", 2: "WHITE", 3: "WHITE", 4: "WHITE", 5: "RED"},
		"BANK_LEFT":  {1: "GREEN", 2: "WHITE", 3: "WHITE", 4: "RED"},
		"BANK_RIGHT": {1: "GREEN", 2: "WHITE", 3: "WHITE", 4: "RED"},
		"TURN_LEFT":  {1: "WHITE", 2: "WHITE", 3: "RED"},
		"TURN_RIGHT": {1: "WHITE", 2: "WHITE", 3: "RED"},
		"K_TURN":     {3: "RED"},
	}
	return d


# Section 2.4 — Anchor-class Gunship
# No red maneuvers at all. Speed 3 simply has no turn option (absent, not red).
static func gunship() -> DialData:
	var d := DialData.new()
	d.dial = {
		"STRAIGHT":   {1: "GREEN", 2: "WHITE", 3: "WHITE"},
		"BANK_LEFT":  {1: "WHITE", 2: "WHITE", 3: "WHITE"},
		"BANK_RIGHT": {1: "WHITE", 2: "WHITE", 3: "WHITE"},
		"TURN_LEFT":  {1: "GREEN", 2: "WHITE"},
		"TURN_RIGHT": {1: "GREEN", 2: "WHITE"},
	}
	return d


# ── ENEMY CLASSES ────────────────────────────────────────────────────────────

# Section 3.1 — Enemy Fighter (mirrors player Fighter but capped at speed 3, no K-Turn)
static func enemy_fighter() -> DialData:
	var d := DialData.new()
	d.dial = {
		"STRAIGHT":   {1: "WHITE", 2: "WHITE", 3: "WHITE"},
		"BANK_LEFT":  {1: "GREEN", 2: "WHITE", 3: "WHITE"},
		"BANK_RIGHT": {1: "GREEN", 2: "WHITE", 3: "WHITE"},
		"TURN_LEFT":  {1: "GREEN", 2: "WHITE", 3: "RED"},
		"TURN_RIGHT": {1: "GREEN", 2: "WHITE", 3: "RED"},
	}
	return d


# Section 3.2 — Enemy Scout
# Aggressive and fast; banks cost stress at speed 3; K-Turn at speed 3.
static func enemy_scout() -> DialData:
	var d := DialData.new()
	d.dial = {
		"STRAIGHT":   {1: "WHITE", 2: "WHITE", 3: "WHITE", 4: "RED"},
		"BANK_LEFT":  {1: "GREEN", 2: "WHITE", 3: "RED"},
		"BANK_RIGHT": {1: "GREEN", 2: "WHITE", 3: "RED"},
		"TURN_LEFT":  {1: "WHITE", 2: "WHITE", 3: "RED"},
		"TURN_RIGHT": {1: "WHITE", 2: "WHITE", 3: "RED"},
		"K_TURN":     {3: "RED"},
	}
	return d


# Section 3.3 — Enemy Assault
# Forward brawler; stable at speeds 1-2; K-Turn available for head-on commitment.
static func enemy_assault() -> DialData:
	var d := DialData.new()
	d.dial = {
		"STRAIGHT":   {1: "WHITE", 2: "WHITE", 3: "WHITE"},
		"BANK_LEFT":  {1: "GREEN", 2: "WHITE", 3: "WHITE"},
		"BANK_RIGHT": {1: "GREEN", 2: "WHITE", 3: "WHITE"},
		"TURN_LEFT":  {1: "WHITE", 2: "WHITE", 3: "RED"},
		"TURN_RIGHT": {1: "WHITE", 2: "WHITE", 3: "RED"},
		"K_TURN":     {3: "RED"},
	}
	return d

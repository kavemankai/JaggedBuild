class_name DialData
extends Resource

# dial[bearing][speed] = "GREEN" | "WHITE" | "RED"
# Absence of a speed key for a bearing means that maneuver is not on this dial.
@export var dial: Dictionary = {}


func get_color(bearing: String, speed: int) -> String:
	if not dial.has(bearing):
		return ""
	var speeds: Dictionary = dial[bearing] as Dictionary
	if not speeds.has(speed):
		return ""
	return speeds[speed] as String


func is_available(bearing: String, speed: int) -> bool:
	return get_color(bearing, speed) != ""


# Returns Array[{bearing, speed, color}] for populating the ManeuverSelector.
func get_all_options() -> Array:
	var options: Array = []
	for bearing in dial.keys():
		var speeds: Dictionary = dial[bearing] as Dictionary
		for speed in speeds.keys():
			options.append({
				"bearing": bearing as String,
				"speed": int(speed),
				"color": speeds[speed] as String,
			})
	return options

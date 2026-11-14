extends RefCounted
class_name EnemyAI

var rng: RandomNumberGenerator


func configure(random_source: RandomNumberGenerator) -> void:
	rng = random_source


func choose_move(enemy: Unit, navigator) -> Dictionary:
	if enemy == null or navigator == null:
		return {}

	var reach: Dictionary = navigator.reachable_destinations(enemy)
	var destinations: Array[Vector2i] = reach["dests"]
	if destinations.is_empty():
		return {}

	var index: int = rng.randi_range(0, destinations.size() - 1) if rng != null else 0
	var destination: Vector2i = destinations[index]
	var path: Array[Vector2i] = navigator.shortest_path(enemy, enemy.cell, destination)
	if path.is_empty():
		path = navigator.reconstruct_path(reach["prev"], enemy.cell, destination)
	return {"destination": destination, "path": path}

extends Camera2D
class_name CameraController

@export var board_path: NodePath
@export var min_zoom: float = 0.6
@export var max_zoom: float = 2.0
@export var zoom_step: float = 0.1
@export var pan_mouse_button: MouseButton = MOUSE_BUTTON_MIDDLE

var board: Board = null
var is_panning: bool = false

func _ready() -> void:
	enabled = true
	call_deferred("_center_on_map")

func _center_on_map() -> void:
	board = get_node_or_null(board_path) as Board
	if board == null:
		push_warning("CameraController: board_path is not set to a Board node.")
		return
	global_position = board.get_map_center_world()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		if mb.button_index == pan_mouse_button:
			is_panning = mb.pressed
			if is_panning:
				get_viewport().set_input_as_handled()
			return

		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var factor: float = (1.0 + zoom_step) if mb.button_index == MOUSE_BUTTON_WHEEL_UP else (1.0 - zoom_step)
			var new_zoom: float = clampf(zoom.x * factor, min_zoom, max_zoom)
			zoom = Vector2(new_zoom, new_zoom)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and is_panning:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		global_position -= mm.relative * zoom.x
		get_viewport().set_input_as_handled()

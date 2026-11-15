extends Resource
class_name FE8MapSpriteAnimation

## Runtime representation of one Fire Emblem 8 map-sprite class.
##
## The compact texture is produced in memory by FE8MapSpriteImporter. Each row
## contains the three unique frames for one FE8 animation. Godot repeats the
## middle frame to reproduce the original 1-2-3-2 loop.

const FRAME_SIZE: Vector2i = Vector2i(32, 32)

const IDLE_PRIMARY: StringName = &"idle_primary"
const IDLE_SECONDARY: StringName = &"idle_secondary"
const WALK_LEFT: StringName = &"walk_left"
const WALK_DOWN: StringName = &"walk_down"
const WALK_UP: StringName = &"walk_up"
const WALK_RIGHT: StringName = &"walk_right"

@export var fe8_class_name: String = ""
@export var faction_palette: String = "ally"

var compact_texture: Texture2D
var sprite_frames: SpriteFrames


func configure(class_name_value: String, palette_value: String, texture: Texture2D) -> FE8MapSpriteAnimation:
	fe8_class_name = class_name_value
	faction_palette = palette_value
	compact_texture = texture
	sprite_frames = _build_sprite_frames()
	return self


func is_valid() -> bool:
	return compact_texture != null and sprite_frames != null


func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	_add_ping_pong_animation(frames, IDLE_PRIMARY, 0, 3.0)
	_add_ping_pong_animation(frames, IDLE_SECONDARY, 1, 6.0)
	_add_ping_pong_animation(frames, WALK_LEFT, 2, 10.0)
	_add_ping_pong_animation(frames, WALK_DOWN, 3, 10.0)
	_add_ping_pong_animation(frames, WALK_UP, 4, 10.0)
	# FE8 stores one side-movement sequence. Unit mirrors it when moving right.
	_add_ping_pong_animation(frames, WALK_RIGHT, 2, 10.0)
	return frames


func _add_ping_pong_animation(frames: SpriteFrames, animation_name: StringName, row: int, fps: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, fps)
	for frame_index in [0, 1, 2, 1]:
		frames.add_frame(animation_name, _atlas_frame(frame_index, row))


func _atlas_frame(column: int, row: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = compact_texture
	atlas.region = Rect2(
		Vector2(column * FRAME_SIZE.x, row * FRAME_SIZE.y),
		Vector2(FRAME_SIZE)
	)
	return atlas

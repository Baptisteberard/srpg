extends RefCounted
class_name FE8MapSpriteImporter

## Reads the labelled FE8 sheet locally and builds transparent animation data.
## The source PNG remains optional so public clones can keep using circle units.

const SOURCE_PATH: String = "res://assets/fire_emblem_sacred_stones/map_sprites.png"
const EXPECTED_SOURCE_SIZE: Vector2i = Vector2i(360, 7538)
const FRAME_SIZE: Vector2i = FE8MapSpriteAnimation.FRAME_SIZE
const CELL_STRIDE: int = 33
const COMPACT_COLUMNS: int = 5
const COMPACT_ROWS: int = 6

const PALETTE_X: int = 53
const PALETTE_STRIDE: int = 8
const PALETTE_LENGTH: int = 16
const PALETTE_ROWS: Dictionary = {
	"ally": 7382,
	"enemy": 7397,
	"neutral": 7412,
	"used": 7427,
	"arena_grey": 7442,
}

const SHEET_BACKGROUND: Color = Color8(0, 128, 64, 255)

const CLASS_LAYOUTS: Dictionary = {
	"recruit": {
		"display_name": "Recruit",
		"standing_origin": Vector2i(49, 297),
		"moving_origin": Vector2i(16, 330),
	},
	"brigand": {
		"display_name": "Brigand",
		"standing_origin": Vector2i(215, 4057),
		"moving_origin": Vector2i(182, 4090),
	},
}

static var _source_image: Image
static var _animation_cache: Dictionary = {}


static func source_available() -> bool:
	return FileAccess.file_exists(SOURCE_PATH)


static func load_animation(fe8_class_name: String, palette_name: String) -> FE8MapSpriteAnimation:
	var class_key := fe8_class_name.to_lower()
	var palette_key := palette_name.to_lower()
	if not CLASS_LAYOUTS.has(class_key) or not PALETTE_ROWS.has(palette_key):
		return null

	var cache_key := "%s:%s" % [class_key, palette_key]
	if _animation_cache.has(cache_key):
		return _animation_cache[cache_key] as FE8MapSpriteAnimation

	var source := _load_source_image()
	if source == null:
		return null

	var layout: Dictionary = CLASS_LAYOUTS[class_key]
	var compact := _extract_compact_sheet(source, layout, palette_key)
	if compact == null:
		return null

	var texture := ImageTexture.create_from_image(compact)
	var animation := FE8MapSpriteAnimation.new().configure(
		str(layout["display_name"]),
		palette_key,
		texture
	)
	_animation_cache[cache_key] = animation
	return animation


static func _load_source_image() -> Image:
	if _source_image != null and not _source_image.is_empty():
		return _source_image
	if not source_available():
		return null

	var source_texture := load(SOURCE_PATH) as Texture2D
	if source_texture == null:
		return null
	var image := source_texture.get_image()
	if image == null or image.get_size() != EXPECTED_SOURCE_SIZE:
		return null
	image.convert(Image.FORMAT_RGBA8)
	_source_image = image
	return _source_image


static func _extract_compact_sheet(source: Image, layout: Dictionary, palette_name: String) -> Image:
	var ally_palette := _read_palette(source, "ally")
	var target_palette := _read_palette(source, palette_name)
	if ally_palette.size() != PALETTE_LENGTH or target_palette.size() != PALETTE_LENGTH:
		return null

	var palette_map: Dictionary = {}
	for index in range(PALETTE_LENGTH):
		var ally_color: Color = ally_palette[index]
		var target_color: Color = target_palette[index]
		palette_map[ally_color.to_rgba32()] = target_color

	var transparent_palette_color: Color = ally_palette[0]
	var transparent_colors: Dictionary = {
		SHEET_BACKGROUND.to_rgba32(): true,
		transparent_palette_color.to_rgba32(): true,
	}
	var output := Image.create(
		COMPACT_COLUMNS * FRAME_SIZE.x,
		COMPACT_ROWS * FRAME_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	output.fill(Color(0.0, 0.0, 0.0, 0.0))

	var standing_origin: Vector2i = layout["standing_origin"]
	for frame_index in range(3):
		var source_pos := standing_origin + Vector2i(frame_index * CELL_STRIDE, 0)
		_blit_processed_frame(source, output, source_pos, Vector2i(frame_index * FRAME_SIZE.x, 0), palette_map, transparent_colors)

	# FE8's moving block is five animation columns by three unique frames:
	# selected/action, left, down, up, and right.
	var moving_origin: Vector2i = layout["moving_origin"]
	for animation_column in range(5):
		for frame_index in range(3):
			var source_pos := moving_origin + Vector2i(animation_column * CELL_STRIDE, frame_index * CELL_STRIDE)
			var destination := Vector2i(frame_index * FRAME_SIZE.x, (animation_column + 1) * FRAME_SIZE.y)
			_blit_processed_frame(source, output, source_pos, destination, palette_map, transparent_colors)

	return output


static func _read_palette(source: Image, palette_name: String) -> Array[Color]:
	var colors: Array[Color] = []
	var y: int = int(PALETTE_ROWS[palette_name])
	for index in range(PALETTE_LENGTH):
		colors.append(source.get_pixel(PALETTE_X + index * PALETTE_STRIDE, y))
	return colors


static func _blit_processed_frame(
	source: Image,
	destination: Image,
	source_position: Vector2i,
	destination_position: Vector2i,
	palette_map: Dictionary,
	transparent_colors: Dictionary
) -> void:
	var frame := source.get_region(Rect2i(source_position, FRAME_SIZE))
	for y in range(FRAME_SIZE.y):
		for x in range(FRAME_SIZE.x):
			var pixel := frame.get_pixel(x, y)
			var color_key := pixel.to_rgba32()
			if transparent_colors.has(color_key):
				frame.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			elif palette_map.has(color_key):
				var replacement: Color = palette_map[color_key]
				frame.set_pixel(x, y, replacement)
	destination.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME_SIZE), destination_position)

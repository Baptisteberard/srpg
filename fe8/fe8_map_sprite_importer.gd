extends RefCounted
class_name FE8MapSpriteImporter

## Reads the labelled FE8 sheet locally and builds transparent animation data.
## The source PNG remains optional so public clones can keep using circle units.

const SOURCE_PATH: String = "res://assets/fire_emblem_sacred_stones/map_sprites.png"
const EXPECTED_SOURCE_SIZE: Vector2i = Vector2i(360, 7538)
const FRAME_SIZE: Vector2i = FE8MapSpriteAnimation.FRAME_SIZE
const CELL_STRIDE: int = 33
const COMPACT_COLUMNS: int = 4
const COMPACT_ROWS: int = 5

# Source columns are idle 1, side movement, down movement, up movement, idle 2.
# Compact rows put the two idle sequences first for FE8MapSpriteAnimation.
const SOURCE_COLUMN_BY_COMPACT_ROW: Array[int] = [0, 4, 1, 2, 3]
const IDLE_SOURCE_ROW_OFFSETS: Array[int] = [0, 1, 2]
const MOVEMENT_SOURCE_ROW_OFFSETS: Array[int] = [0, 1, 2, -1]

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
		"moving_origin": Vector2i(16, 330),
	},
	"brigand": {
		"display_name": "Brigand",
		"moving_origin": Vector2i(182, 4090),
	},
	"soldier": {
		"display_name": "Soldier",
		"moving_origin": Vector2i(16, 4090),
	},
	"archer m": {
		"display_name": "Archer M",
		"moving_origin": Vector2i(16, 765),
	},
	"thief": {
		"display_name": "Thief",
		"moving_origin": Vector2i(16, 2060),
	},
	"fighter": {
		"display_name": "Fighter",
		"moving_origin": Vector2i(182, 1341),
	},
	"knight": {
		"display_name": "Knight",
		"moving_origin": Vector2i(182, 330),
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

	# Idles occupy the three main rows. Movement has those same three rows, but
	# its fourth frame is stored one cell above them—not one cell below.
	var moving_origin: Vector2i = layout["moving_origin"]
	for output_row in range(SOURCE_COLUMN_BY_COMPACT_ROW.size()):
		var source_column: int = SOURCE_COLUMN_BY_COMPACT_ROW[output_row]
		var source_row_offsets: Array[int] = (
			IDLE_SOURCE_ROW_OFFSETS if output_row < 2 else MOVEMENT_SOURCE_ROW_OFFSETS
		)
		for frame_index in range(source_row_offsets.size()):
			var source_row: int = source_row_offsets[frame_index]
			var source_pos := moving_origin + Vector2i(source_column * CELL_STRIDE, source_row * CELL_STRIDE)
			var destination := Vector2i(frame_index * FRAME_SIZE.x, output_row * FRAME_SIZE.y)
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

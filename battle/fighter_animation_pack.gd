extends RefCounted

const TICKS_PER_SECOND := 60.0
const FLETCHLING_SCRIPT := "res://assets/fan_battle_reference/fletchling_bow/Bow.txt"

var frames: Dictionary = {}
var modes: Dictionary = {}

static func load_fletchling() -> RefCounted:
	var pack := new()
	if not pack._read_script(FLETCHLING_SCRIPT):
		return null
	return pack

func _read_script(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var mode_pattern := RegEx.create_from_string("^/// - Mode (\\d+)")
	var frame_pattern := RegEx.create_from_string("^(\\d+)\\s+p-\\s+(.+?\\.png)(?:\\s|$)")
	var mode := -1
	var released := false
	for raw_line in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw_line.strip_edges()
		var heading := mode_pattern.search(line)
		if heading != null:
			mode = int(heading.get_string(1))
			modes[mode] = {"windup": [], "recovery": []}
			released = false
		elif line.begins_with("C05") or line.begins_with("C06"):
			released = true
		elif mode >= 0:
			var entry := frame_pattern.search(line)
			if entry == null:
				continue
			var filename := entry.get_string(2)
			if not frames.has(filename):
				var texture := _load_frame(path.get_base_dir().path_join(filename))
				if texture == null:
					return false
				frames[filename] = texture
			var phase := "recovery" if released else "windup"
			modes[mode][phase].append([frames[filename], int(entry.get_string(1)) / TICKS_PER_SECOND])
	return modes.has(5) and modes.has(6) and modes.has(10) \
		and not modes[5]["windup"].is_empty() and not modes[5]["recovery"].is_empty() \
		and not modes[6]["windup"].is_empty() and not modes[6]["recovery"].is_empty() \
		and not modes[10]["windup"].is_empty()

func _load_frame(path: String) -> Texture2D:
	var source := load(path) as Texture2D
	if source == null:
		return null
	var pixels := source.get_image()
	pixels.convert(Image.FORMAT_RGBA8)
	var background := pixels.get_pixel(0, 0)
	# Preserve each full canvas so the feet stay anchored between poses.
	# The top edge includes palette metadata outside the playable image.
	for y in range(pixels.get_height()):
		for x in range(pixels.get_width()):
			if y < 4 or pixels.get_pixel(x, y) == background:
				pixels.set_pixel(x, y, Color.TRANSPARENT)
	return ImageTexture.create_from_image(pixels)

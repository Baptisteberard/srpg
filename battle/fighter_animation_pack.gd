extends RefCounted

const TICKS_PER_SECOND := 60.0
const PACK_ROOT := "res://assets/fan_battle_reference/"

var frames: Dictionary = {}
var modes: Dictionary = {}
var feet: Vector2

static func load_pack(script_path: String, anchor: Vector2, attack_modes: Array) -> RefCounted:
	var pack := new()
	if not pack._read_script(PACK_ROOT.path_join(script_path), attack_modes):
		return null
	pack.feet = anchor
	return pack

func _read_script(path: String, attack_modes: Array) -> bool:
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
		elif line.begins_with("C06") or (mode in [1, 3] and line.begins_with("C04")) \
		or (mode in [5, 6] and line.begins_with("C05")):
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
	for attack_mode in attack_modes:
		if not modes.has(attack_mode) or modes[attack_mode]["windup"].is_empty() or modes[attack_mode]["recovery"].is_empty():
			return false
	return modes.has(10) and not modes[10]["windup"].is_empty()

func _load_frame(path: String) -> Texture2D:
	var source := load(path) as Texture2D
	if source == null:
		return null
	var pixels := source.get_image()
	pixels.convert(Image.FORMAT_RGBA8)
	var background := pixels.get_pixel(0, 0)
	if pixels.get_width() == 488:
		# The actor occupies the left 240 pixels; the extra plane is an effect overlay.
		pixels = pixels.get_region(Rect2i(0, 0, 240, pixels.get_height()))
	# Preserve each full canvas so the feet stay anchored between poses.
	# The top edge includes palette metadata outside the playable image.
	for y in range(pixels.get_height()):
		for x in range(pixels.get_width()):
			if y < 4 or pixels.get_pixel(x, y) == background:
				pixels.set_pixel(x, y, Color.TRANSPARENT)
	return ImageTexture.create_from_image(pixels)

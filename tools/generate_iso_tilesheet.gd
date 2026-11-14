@tool
extends EditorScript

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tiles")

	var tile_w: int = 128
	var tile_h: int = 128

	var sheet: Image = Image.create(tile_w * 2, tile_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(0, 0, 0, 0))

	_draw_square(sheet, Rect2i(0, 0, tile_w, tile_h), Color8(26, 153, 26, 255))      # ground
	_draw_square(sheet, Rect2i(tile_w, 0, tile_w, tile_h), Color8(89, 89, 89, 255))  # wall

	var out_path: String = "res://tiles/topdown_tilesheet.png"
	var err: Error = sheet.save_png(out_path)

	if err != OK:
		push_error("Failed to save tilesheet: %s" % out_path)
	else:
		print("Saved: ", out_path)

func _draw_square(img: Image, rect: Rect2i, col: Color) -> void:
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			img.set_pixel(x, y, col)

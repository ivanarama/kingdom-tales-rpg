extends RefCounted
## Спрайты отрядов импортируются не больше 512 px и с mipmaps: сборка легче, а уменьшенный в бою спрайт не рябит.
## Новый файл в assets/art/units/ без этих настроек импорта этот набор и поймает.

const TITLE := "Testing Unit Sprite Import (512 px, mipmaps)"
const DIR := "res://assets/art/units"


func run(_t: Node) -> void:
	var checked := 0
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".png"):
			continue
		var path := DIR.path_join(f)
		var tex: Texture2D = load(path)
		assert(tex.get_width() <= 512 and tex.get_height() <= 512, "%s: set process/size_limit=512 in its .import" % path)
		assert(tex.get_image().has_mipmaps(), "%s: set mipmaps/generate=true in its .import" % path)
		checked += 1
	assert(checked >= 15, "Unit sprites must be found in %s (checked %d)" % [DIR, checked])
	print("  -> %d unit sprites are imported at 512 px with mipmaps!" % checked)

extends SceneTree

var frames := 0
var lvl: Node = null
var out_dir := "C:/Users/Administrator/AppData/Local/Temp/opencode/scp_shots"

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn")
	lvl = ps.instantiate()
	root.add_child(lvl)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 25:
		_snap("menu")
		if lvl.has_method("start_game"):
			lvl.start_game()
	elif frames == 70:
		_snap("game")
		return true
	return false

func _snap(name: String) -> void:
	var img := root.get_texture().get_image()
	var err := img.save_png(out_dir + "/" + name + ".png")
	print("SNAP ", name, " err=", err, " size=", img.get_width(), "x", img.get_height())

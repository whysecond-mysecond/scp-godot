extends Node3D

const TS = 2.0
const MW = 40
const MH = 28
const WH = 3.2
const SPEED = 3.4
const SPRINT_MULT = 1.55
const PRAD = 0.42

var grid : Array = []
var rooms : Array = [
	{"x":2,"y":2,"w":9, "h":7, "name":"ЗОНА СОДЕРЖАНИЯ"},
	{"x":14,"y":2,"w":10,"h":6, "name":"ОФИСЫ"},
	{"x":28,"y":2,"w":9,  "h":8, "name":"ЛАБОРАТОРИЯ"},
	{"x":2, "y":13,"w":10,"h":7, "name":"КПП / ГАРАЖ"},
	{"x":15,"y":11,"w":8, "h":7, "name":"СТОЛОВАЯ"},
	{"x":28,"y":14,"w":9,  "h":9, "name":"РЕАКТОР"},
	{"x":15,"y":21,"w":8,  "h":5, "name":"ШЛЮЗ"},
]

var spawn_pos = Vector3(6.5*TS,0.0,16.5*TS)
var scp173s = Vector3(6.5*TS,0.0,4.3*TS)
var scp096s = Vector3(31.5*TS,0.0,18.5*TS)
var cardpos : Array = [Vector3(9.4*TS,1.15,3.4*TS), Vector3(21.5*TS,1.15,3.4*TS), Vector3(34.4*TS,1.15,7.3*TS)]
var exit_c = Vector3(19.0*TS,0.0,23.0*TS)
var exit_h = Vector2(4.0,2.0)
var doors : Array = []
var cards : Array = [false, false, false, false]
var scp096_on = false

var M_wall
var M_floor
var M_ceiling
var M_concrete
var M_eye
var M_card : Array = []
var M_exit
var M_096b
var M_096e

var player : CharacterBody3D
var scp173 : Node3D
var scp096 : Node3D

var phase = "menu"
var rtime = 0.0
var toast_s = ""
var toast_t = 0.0
var threat = 0.0
var blink_t = 6.5
var blink_l = 6.5
var blink_a = 0.0
var stamina_f = 100.0
var battery_f = 100.0
var flash_on = true
var yaw_f = 0.0
var pitch_f = 0.0
var step_cd = 0.28
var hbeat_cd = 1.0
var dead_reason = ""
var win_t = 0.0
var ui_canvas : CanvasLayer
var obj_lbl : Label
var timer_lbl : Label
var sector_lbl : Label
var toast_lbl : Label
var warn_lbl : Label
var cardlbls : Array = []
var danger_rect : ColorRect
var blink_rect : ColorRect
var menu_scr : Control
var pause_scr : Control
var dead_scr : Control
var won_scr : Control
var reason_lbl : Label
var last_step_pos = Vector2.ZERO

func _ready() -> void:
	make_materials()
	build_map()
	build_level()
	make_player()
	make_scp173()
	make_scp096()
	make_cards()
	make_exit()
	make_doors()
	make_ui()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ═══════════════════════ MATERIAL HELPERS ═══════════════════════

static func sm(col : Color, met : float, rough : float) -> Material:
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col; m.metallic = met; m.roughness = rough
	m.emission_enabled = true
	return m

func make_materials() -> void:
	M_wall = sm(Color(0.19,0.22,0.26), 0.0, 0.92)
	M_floor = sm(Color(0.11,0.13,0.16), 0.0, 0.85)
	M_ceiling = sm(Color(0.05,0.06,0.08), 0.0, 1.0)
	M_concrete = sm(Color(0.62,0.61,0.56), 0.0, 0.95)
	M_eye = sm(Color(0.9,0.25,0.2), 0.0, 1.0)
	M_eye.emission = Color(0.9,0.25,0.2); M_eye.emission_energy_multiplier = 5.0
	for i in 3:
		var c : Color = [Color(0.35,0.7,1.0), Color(1.0,0.78,0.3), Color(1.0,0.28,0.24)][i]
		var m : StandardMaterial3D = sm(c, 0.0, 1.0)
		m.emission = c; m.emission_energy_multiplier = 3.0
		M_card.append(m)
	M_exit = sm(Color(0.25,1.0,0.35), 0.0, 1.0)
	M_exit.emission = Color(0.25,1.0,0.35); M_exit.emission_energy_multiplier = 2.0
	M_096b = sm(Color(0.82,0.78,0.75), 0.0, 0.75)
	M_096e = sm(Color(0.9,0.15,0.1), 0.0, 1.0)
	M_096e.emission = Color(0.9,0.15,0.1); M_096e.emission_energy_multiplier = 5.0


# ═══════════════════════ GRID UTILS ═══════════════════════

func tile_of(p : Vector3) -> Vector2i:
	return Vector2i(int(p.x/TS), int(p.z/TS))

func is_wall(tx : int, ty : int) -> bool:
	if tx < 0 or ty < 0 or tx >= MW or ty >= MH: return true
	return grid[ty][tx] == 1

func walkable(tx : int, ty : int) -> bool:
	if not is_wall(tx, ty):
		for d in doors:
			if d["open"] == false and d["tx"] == tx and d["ty"] == ty: return false
		return true
	return false

func carve(x0 : int, y0 : int, x1 : int, y1 : int) -> void:
	var sx : int = mini(x0,x1)
	var ex : int = maxi(x0,x1)
	var sy : int = mini(y0,y1)
	var ey : int = maxi(y0,y1)
	for y in range(sy, ey+1):
		for x in range(sx, ex+1):
			if 0 <= x and x < MW and 0 <= y and y < MH: grid[y][x] = 0

func build_map() -> void:
	grid.resize(MH)
	for y in range(MH):
		var row := PackedInt32Array()
		for _x in range(MW): row.append(1)
		grid[y] = row
	for r in rooms:
		for y in range(r.y, r.y+r.h):
			for x in range(r.x, r.x+r.w):
				if 0<=x and x<MW and 0<=y and y<MH: grid[y][x]=0
	carve(10,5,14,5); carve(23,5,28,5); carve(6,8,6,13)
	carve(11,16,15,16); carve(18,7,18,11); carve(32,9,32,14)
	carve(22,14,28,14); carve(18,17,18,21)


# ═══════════════════════ PATHFINDING ═══════════════════════

func bfs(start : Vector2i, goal : Vector2i) -> PackedVector2Array:
	if start == goal:
		var p : PackedVector2Array = PackedVector2Array()
		p.append(goal); return p
	if not walkable(goal.x, goal.y): return PackedVector2Array()
	var prev : Dictionary = {}
	var seen : Dictionary = {start: true}
	var q : Array = [start]
	while q.size() > 0:
		var cur : Vector2i = q.pop_front()
		if cur == goal:
			var path : PackedVector2Array = PackedVector2Array()
			var c : Vector2i = goal
			while c != start:
				path.append(c)
				c = prev[c]
			path.append(start)
			path.reverse()
			return path
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var nxt : Vector2i = cur + dir
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= MW or nxt.y >= MH: continue
			if nxt in seen: continue
			if not walkable(nxt.x, nxt.y): continue
			seen[nxt] = true
			prev[nxt] = cur
			q.append(nxt)
	return PackedVector2Array()

func has_los(a : Vector3, b : Vector3) -> bool:
	var d : Vector2 = Vector2(b.x-a.x, b.z-a.z)
	var dist : float = d.length()
	if dist < 0.01: return true
	var steps : float = ceili(dist / 0.25)
	for i in range(1, int(steps)):
		var t : float = float(i) / float(steps)
		var tx : int = int((a.x + d.x*t)/TS)
		var ty : int = int((a.z + d.y*t)/TS)
		if is_wall(tx, ty): return false
		for door in doors:
			if door["open"] == false and door["tx"] == tx and door["ty"] == ty: return false
	return true

func circle_solid(pos : Vector3, r : float) -> bool:
	var x0 : int = int((pos.x-r)/TS)
	var x1 : int = int((pos.x+r)/TS)
	var y0 : int = int((pos.z-r)/TS)
	var y1 : int = int((pos.z+r)/TS)
	for ty in range(y0, y1+1):
		for tx in range(x0, x1+1):
			if not is_wall(tx, ty): continue
			var mnx : float = tx*TS
			var mnz : float = ty*TS
			var nx : float = clamp(pos.x, mnx, mnx+TS)
			var nz : float = clamp(pos.z, mnz, mnz+TS)
			if (pos.x-nx)*(pos.x-nx)+(pos.z-nz)*(pos.z-nz) < r*r: return true
			for door in doors:
				if door["open"] == false and door["tx"]==tx and door["ty"]==ty: return true
	return false


# ═══════════════════════ LEVEL BUILDING ═══════════════════════

func build_level() -> void:
	var big : BoxMesh = BoxMesh.new()
	big.size = Vector3(float(MW)*TS, 0.1, float(MH)*TS)
	var fl : MeshInstance3D = MeshInstance3D.new()
	fl.mesh = big; fl.material_override = M_floor
	fl.position = Vector3(float(MW)*TS*0.5, -0.05, float(MH)*TS*0.5)
	add_child(fl)
	var cl : MeshInstance3D = MeshInstance3D.new()
	cl.mesh = big; cl.material_override = M_ceiling
	cl.position = Vector3(float(MW)*TS*0.5, WH+0.05, float(MH)*TS*0.5)
	add_child(cl)
	var wm : BoxMesh = BoxMesh.new()
	wm.size = Vector3(TS, WH, TS)
	for ty in range(MH):
		for tx in range(MW):
			if grid[ty][tx] != 1: continue
			var near : bool = false
			for dd in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
				var nnx : int = tx+dd.x
				var nny : int = ty+dd.y
				if 0<=nnx and nnx<MW and 0<=nny and nny<MH and grid[nny][nnx]==0: near = true
			if not near: continue
			var mi : MeshInstance3D = MeshInstance3D.new()
			mi.mesh = wm; mi.material_override = M_wall
			mi.position = Vector3(tx*TS+TS*0.5, WH*0.5, ty*TS+TS*0.5)
			add_child(mi)

	for ri in rooms.size():
		var rm : Dictionary = rooms[ri]
		var cx : float = (rm["x"]+rm["w"]*0.5)*TS
		var cz : float = (rm["y"]+rm["h"]*0.5)*TS
		var lc : Color = Color(1.0,0.88,0.72)
		match str(rm["name"]):
			"РЕАКТОР": lc = Color(1.0,0.72,0.45)
			"ЗОНА СОДЕРЖАНИЯ": lc = Color(0.65,0.82,1.0)
			"ЛАБОРАТОРИЯ": lc = Color(0.75,0.95,0.85)
		var nl : int = 2 if rm["w"] >= 8 else 1
		for k in nl:
			var xs : float = (-0.25 if k == 0 else 0.25) if rm["w"] >= 8 else 0.0
			var pl = SpotLight3D.new()
			pl.position = Vector3(cx+xs*float(rm["w"])*TS, 2.75, cz)
			pl.light_color = lc
			pl.light_energy = 6.0
			pl.rotation_degrees = Vector3(-90, 0, 0)
			pl.spot_range = 22.0
			add_child(pl)
		var lm : BoxMesh = BoxMesh.new()
		lm.size = Vector3(1.2,0.06,0.35)
		var lmat : StandardMaterial3D = sm(Color(1.0,0.95,0.85),0.0,0.3)
		lmat.emission = Color(1.0,0.95,0.85); lmat.emission_energy_multiplier = 4.0
		var lamp : MeshInstance3D = MeshInstance3D.new()
		lamp.mesh = lm; lamp.material_override = lmat
		lamp.position = Vector3(cx, 3.06, cz)
		add_child(lamp)

	# Emergency red lights at corridor intersections
	for p_idx in 4:
		var pvals : Array = [[13.0,21.0],[24.0,11.0],[51.0,11.0],[64.0,24.0]]
		var pp : Array = pvals[p_idx]
		var rl = SpotLight3D.new()
		rl.position = Vector3(pp[0]*TS, 2.9, pp[1]*TS)
		rl.light_color = Color(1.0,0.12,0.08)
		rl.light_energy = 1.6; rl.spot_range = 9.0
		rl.rotation_degrees = Vector3(-90,0,0)
		add_child(rl)

	# World environment with fog
	var env := WorldEnvironment.new()
	add_child(env)
	var ge := Environment.new()
	ge.background_mode = Environment.BG_CLEAR_COLOR
	ge.background_color = Color(0.02, 0.03, 0.045)
	ge.fog_enabled = true
	ge.fog_light_color = Color(0.03, 0.04, 0.055)
	ge.fog_depth_begin = 18.0
	ge.fog_depth_end = 62.0
	ge.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ge.ambient_light_color = Color(0.30, 0.37, 0.48)
	ge.ambient_light_energy = 1.0
	env.environment = ge


# ═══════════════════════ PLAYER ═══════════════════════

func make_player() -> void:
	player = ClassDB.instantiate("CharacterBody3D")
	player.name = "Player"
	player.position = spawn_pos
	add_child(player)
	var pivot : Node3D = ClassDB.instantiate("Node3D")
	pivot.name = "Pivot"
	player.add_child(pivot)
	var cam : Camera3D = ClassDB.instantiate("Camera3D")
	cam.name = "Camera3D"
	cam.position = Vector3(0, 1.65, 0)
	cam.fov = 78
	pivot.add_child(cam)
	var fl : SpotLight3D = ClassDB.instantiate("SpotLight3D")
	fl.name = "Flashlight"
	fl.position = Vector3(0.18, -0.18, 0)
	fl.rotation_degrees = Vector3(-15,0,0)
	fl.light_energy = 6.0; fl.spot_range = 45.0
	fl.spot_angle = 32.0; fl.spot_angle_attenuation = 0.5
	pivot.add_child(fl)
	player.set_meta("flash", fl)
	player.add_to_group("player")


# ═══════════════════════ SCP-173 ═══════════════════════

func make_scp173() -> void:
	scp173 = ClassDB.instantiate("Node3D")
	scp173.name = "SCP173"
	scp173.position = scp173s
	scp173.rotation.y = PI
	scp173.add_to_group("scps")
	var capsule = ClassDB.instantiate("CylinderMesh")
	capsule.set("top_radius", 0.42)
	capsule.set("bottom_radius", 0.42)
	capsule.set("height", 1.15)
	var sphere = ClassDB.instantiate("SphereMesh")
	sphere.set("radius", 0.31)
	var arm_m = ClassDB.instantiate("CylinderMesh")
	arm_m.set("top_radius", 0.1)
	arm_m.set("bottom_radius", 0.1)
	arm_m.set("height", 0.95)
	var eye_m = ClassDB.instantiate("SphereMesh")
	eye_m.set("radius", 0.055)
	var body : MeshInstance3D = ClassDB.instantiate("MeshInstance3D")
	body.mesh=capsule; body.material_override=M_concrete
	body.position=Vector3(0,1.3,0)
	scp173.add_child(body)
	var head : MeshInstance3D = ClassDB.instantiate("MeshInstance3D")
	head.mesh=sphere; head.material_override=M_concrete
	head.position=Vector3(0,2.25,0.06)
	scp173.add_child(head)
	for side in [-1.0, 1.0]:
		var arm : MeshInstance3D = ClassDB.instantiate("MeshInstance3D")
		arm.mesh=arm_m; arm.material_override=M_concrete
		arm.position=Vector3(side*0.5,1.25,0.0)
		arm.rotation.z=side*0.12
		scp173.add_child(arm)
		var eye : MeshInstance3D = ClassDB.instantiate("MeshInstance3D")
		eye.mesh=eye_m; eye.material_override=M_eye
		eye.position=Vector3(side*0.11,2.28,0.30)
		scp173.add_child(eye)
	add_child(scp173)


# ═══════════════════════ SCP-096 (GLTF MODEL) ═══════════════════════

func make_scp096() -> void:
	scp096 = ClassDB.instantiate("Node3D")
	scp096.name = "SCP096"
	scp096.position = scp096s
	scp096.rotation.y = -PI/4.0
	scp096.visible = false
	scp096.add_to_group("scps")

	# Load GLTF model via Godot's resource import system
	var model_res = load("res://assets/models/scp-096/scene.gltf")
	if model_res != null and model_res is PackedScene:
		var model_node : Node3D = model_res.instantiate()
		if model_node:
			model_node.name = "SCP096_Model"
			var sf := 120.0
			model_node.scale = Vector3(sf, sf, sf)
			scp096.add_child(model_node)
	else:
		# Fallback placeholder if model fails to load
		var fb := BoxMesh.new()
		fb.size = Vector3(1.0, 2.0, 0.8)
		var fb_mi := MeshInstance3D.new()
		fb_mi.mesh = fb; fb_mi.material_override = M_096b
		fb_mi.position = Vector3(0, 1.0, 0)
		scp096.add_child(fb_mi)
	add_child(scp096)


# ═══════════════════════ CARDS ═══════════════════════

func make_cards() -> void:
	for i in 3:
		var m : BoxMesh = ClassDB.instantiate("BoxMesh")
		m.size = Vector3(0.36, 0.5, 0.05)
		var mi : MeshInstance3D = ClassDB.instantiate("MeshInstance3D")
		mi.mesh=m; mi.material_override=M_card[i]
		mi.position=cardpos[i]
		mi.add_to_group("cards")
		mi.set_meta("lvl", i+1)
		add_child(mi)
		var pl = SpotLight3D.new()
		pl.position=cardpos[i]+Vector3(0,0.15,0)
		pl.light_color = M_card[i].albedo_color
		pl.light_energy = 1.0
		pl.spot_range = 3.5
		pl.rotation_degrees = Vector3(-90,0,0)
		add_child(pl)


# ═══════════════════════ EXIT PAD ═══════════════════════

func make_exit() -> void:
	var m : BoxMesh = ClassDB.instantiate("BoxMesh")
	m.size = Vector3(exit_h.x*2.0, 0.06, exit_h.y*2.0)
	var mi : MeshInstance3D = ClassDB.instantiate("MeshInstance3D")
	mi.mesh=m; mi.material_override=M_exit
	mi.position=exit_c+Vector3(0,0.03,0)
	add_child(mi)
	var pl = SpotLight3D.new()
	pl.position=exit_c+Vector3(0,2.4,0)
	pl.light_color = Color(0.3,1.0,0.4)
	pl.light_energy = 2.5
	pl.spot_range = 10.0
	pl.rotation_degrees = Vector3(-90,0,0)
	add_child(pl)


# ═══════════════════════ DOORS ═══════════════════════

func make_doors() -> void:
	var defs : Array = [
		{"tx":12,"ty":5,"need":1}, {"tx":25,"ty":5,"need":2},
		{"tx":32,"ty":11,"need":2}, {"tx":18,"ty":19,"need":3},
	]
	for d in defs:
		var col : Color = Color(0.35,0.7,1.0)
		if d["need"]==2: col=Color(1.0,0.78,0.3)
		elif d["need"]==3: col=Color(1.0,0.28,0.24)
		var mat : StandardMaterial3D = sm(col, 0.4, 0.6)
		mat.emission = col; mat.emission_energy_multiplier = 0.6
		var dm : BoxMesh = ClassDB.instantiate("BoxMesh")
		dm.size = Vector3(0.18, WH, TS*0.98)
		var mi : MeshInstance3D = ClassDB.instantiate("MeshInstance3D")
		mi.mesh=dm; mi.material_override=mat
		mi.position=Vector3(d["tx"]*TS+TS*0.5, WH*0.5, d["ty"]*TS+TS*0.5)
		add_child(mi)
		doors.append({"tx":d["tx"],"ty":d["ty"],"need":d["need"],
					  "open":false,"anim":0.0,"msg_cd":0.0,"mesh":mi})
		mi.add_to_group("doors")


# ═══════════════════════ AUDIO ═══════════════════════

func play_sound(name : String) -> void:
	var buf : PackedByteArray = gen_wav(name)
	if buf.is_empty(): return
	var stream : AudioStreamWAV = ClassDB.instantiate("AudioStreamWAV")
	stream.data = buf
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var ap : AudioStreamPlayer = ClassDB.instantiate("AudioStreamPlayer")
	ap.stream = stream
	ap.bus = "Master"
	ap.volume_db = -18.0  # потише
	get_tree().root.add_child(ap)
	ap.play()
	ap.finished.connect(func() -> void: ap.queue_free())

func gen_wav(name : String) -> PackedByteArray:
	var pcm : PackedByteArray = PackedByteArray()
	match name:
		"step":    gen_step_pcm(pcm)
		"siren":   gen_siren_pcm(pcm)
		"heartbeat": gen_beat_pcm(pcm, 0.5)
		"door":    gen_door_pcm(pcm)
		"096_cry": gen_096_pcm(pcm)
	if pcm.is_empty(): return PackedByteArray()
	return wrap_wav(pcm)

func gen_step_pcm(out : PackedByteArray) -> void:
	for i in 5512:
		var t : float = float(i)/22050.0
		var env : float = pow(max(1.0-t/0.16,0.0), 2.5)
		var thud : float = sin(t*85.0*TAU)*0.5 + sin(t*42.0*TAU)*0.2
		var n : float = (float(((i*0x6C622729)>>8))/32767.0)*2.0-1.0
		out.append(int(clamp((thud + n*0.08)*env,-1.0,1.0)*32767.0))

func gen_siren_pcm(out : PackedByteArray) -> void:
	for i in 44100:
		var t : float = float(i)/22050.0
		var freq : float = 95.0 + 20.0*sin(t*TAU*0.33)
		var pulse : float = 0.7 + 0.3*sin(t*TAU*0.5)
		var env : float = clamp(t/0.15,0.0,1.0)
		if t > 1.7: env = clamp((2.0-t)/0.3,0.0,1.0)
		var tone : float = sin(t*freq*TAU)*0.45 + sin(t*freq*1.5*TAU)*0.15
		out.append(int(clamp(tone*pulse*env,-1.0,1.0)*32767.0))

func gen_beat_pcm(out : PackedByteArray, ratio : float) -> void:
	var bpm : float = 60.0+ratio*90.0
	var bd : float = 60.0/bpm
	var sd : float = bd*0.20
	var n : int = int(22050.0*bd*2.0)
	for i in n:
		var t : float = float(i)/22050.0
		var ct : float = fmod(t,bd)
		var env : float = 0.0
		if ct < sd: env = 1.0 - pow(1.0-ct/sd, 3.0)
		elif ct < sd*2.0: env = (1.0-(ct-sd)/sd)*0.6
		var thump : float = sin(t*48.0*TAU)*0.5 + sin(t*96.0*TAU)*0.25 + sin(t*144.0*TAU)*0.1
		out.append(int(clamp(thump*env,-1.0,1.0)*32767.0))

func gen_door_pcm(out : PackedByteArray) -> void:
	for i in 33075:
		var t : float = float(i)/22050.0
		if t > 1.5: break
		var env : float = pow(max(1.0-t/1.4,0.0), 1.8)
		var sweep : float = 400.0 - t*200.0
		var hum : float = sin(t*sweep*TAU)*0.3 + sin(t*sweep*0.5*TAU)*0.15
		var clunk : float = sin(t*55.0*TAU*3.0)*0.4 * pow(max(1.0-t/0.08,0.0), 2.0)
		out.append(int(clamp((hum+clunk)*env,-1.0,1.0)*32767.0))

func gen_096_pcm(out : PackedByteArray) -> void:
	for i in 33075:
		var t : float = float(i)/22050.0
		if t > 1.5: break
		var env : float = clamp(t/0.08,0.0,1.0)
		if t > 1.2: env = clamp((1.5-t)/0.3,0.0,1.0)
		var n : float = (float(((i*0xDEADBEEF)>>8))/32767.0)*2.0-1.0
		var low : float = sin(t*75.0*TAU)*0.4 + sin(t*150.0*TAU)*0.25
		var mid : float = sin(t*320.0*TAU)*0.15
		out.append(int(clamp((low+mid+n*0.15)*env,-1.0,1.0)*32767.0))

func wrap_wav(pcm : PackedByteArray) -> PackedByteArray:
	var dl : int = pcm.size()
	var r : PackedByteArray = PackedByteArray()
	r.append_array("RIFF".to_ascii_buffer())
	put_u32(r, 36+dl)
	r.append_array("WAVE".to_ascii_buffer())
	r.append_array("fmt ".to_ascii_buffer())
	put_u32(r, 16); put_u16(r, 1); put_u16(r, 1)
	put_u32(r, 22050); put_u32(r, 44100); put_u16(r, 2); put_u16(r, 16)
	r.append_array("data".to_ascii_buffer())
	put_u32(r, dl)
	r.append_array(pcm)
	return r

static func put_u32(buf : PackedByteArray, v : int) -> void:
	buf.append(v & 0xFF); buf.append((v>>8)&0xFF)
	buf.append((v>>16)&0xFF); buf.append((v>>24)&0xFF)

static func put_u16(buf : PackedByteArray, v : int) -> void:
	buf.append(v & 0xFF); buf.append((v>>8)&0xFF)


# ═══════════════════════ UI ═══════════════════════

func make_ui() -> void:
	ui_canvas = ClassDB.instantiate("CanvasLayer")
	ui_canvas.name = "UI"
	add_child(ui_canvas)
	var font = ThemeDB.fallback_font
	var theme : Theme = Theme.new()
	theme.default_font = font

	menu_scr = mk_screen(theme)
	var vb : VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	menu_scr.add_child(vb)
	v_add(vb,"SCP: SECRET LABORATORY",Color(0.92,0.95,0.98),48)
	v_add(vb,"3D-прототип · GDScript",Color(0.5,0.56,0.62),16)
	v_add(vb,"",Color(0.68,0.74,0.8),14)
	v_add(vb,"Вы - сотрудник класса D. Комплекс потерял контроль.",Color(0.68,0.74,0.8),14)
	v_add(vb,"Соберите карты доступа 1-3 и доберитесь до шлюза.",Color(0.68,0.74,0.8),14)
	v_add(vb,"SCP-173 замирает пока вы смотрите. Моргнете - ударит.",Color(0.68,0.74,0.8),14)
	v_add(vb,"SCP-096 спит в Реакторе. Смотри >2сек - бежит.",Color(0.68,0.74,0.8),14)
	v_add(vb,"",Color(0.68,0.74,0.8),14)
	v_add(vb,"WASD - движение | Shift - бег | F - фонарь",Color(0.68,0.74,0.8),14)
	v_add(vb,"Мышь - взгляд | Esc - пауза | R - заново",Color(0.68,0.74,0.8),14)
	v_add(vb,"ENTER - НАЧАТЬ",Color(0.85,0.9,0.94),24)
	v_add(vb,"Фанатский прототип. Не связан с Northwood Studios.",Color(0.3,0.34,0.38),11)
	center(vb)
	menu_scr.visible = true

	var hud : Control = Control.new()
	hud.name = "HUD"
	fr(hud)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	ui_canvas.add_child(hud)

	obj_lbl = l_add(hud, Vector2(32,20), "Найти карту уровня 1", Color(0.85,0.9,0.94), 17)
	l_add(hud, Vector2(32,6), "ЗАДАЧА", Color(0.5,0.56,0.62), 11)
	var obg : ColorRect = ColorRect.new()
	obg.color = Color(0.03,0.05,0.07,0.82)
	obg.position = Vector2(20,16); obg.size = Vector2(430,54)
	hud.add_child(obg); hud.move_child(obg,0)

	timer_lbl = l_add(hud, Vector2(766,16), "00:00", Color(0.85,0.9,0.94), 26)
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sector_lbl = l_add(hud, Vector2(22,507), "КПП / ГАРАЖ", Color(0.85,0.9,0.94), 14)

	cardlbls = []
	for lvl in [1,2,3]:
		var l : Label = l_add(hud, Vector2(22+lvl*44, 462), "[ ]", Color(0.25,0.3,0.36), 20)
		cardlbls.append(l)
	l_add(hud, Vector2(22,436), "УРОВЕНЬ ДОСТУПА", Color(0.5,0.56,0.62), 11)

	bar_add(hud, Vector2(776,558), "ВЫНОСЛИВОСТЬ", Color(0.55,0.75,0.2))
	bar_add(hud, Vector2(776,542), "ФОНАРЬ", Color(0.9,0.72,0.25))
	bar_add(hud, Vector2(776,526), "МОРГАНИЕ", Color(0.35,0.65,0.9))

	toast_lbl = l_add(hud, Vector2(0,395), "", Color(0.85,0.9,0.94), 15)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_lbl = l_add(hud, Vector2(0,70), "", Color(0.9,0.25,0.2), 16)
	warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	danger_rect = ColorRect.new()
	fr(danger_rect)
	danger_rect.color = Color(0.7,0.02,0.02,0.1)
	hud.add_child(danger_rect)

	blink_rect = ColorRect.new()
	fr(blink_rect)
	blink_rect.color = Color(0,0,0,0.985)
	blink_rect.visible = false
	hud.add_child(blink_rect)

	l_add(hud, Vector2(22,558), "WASD - движение | Shift - бег | F - фонарь | Esc - пауза", Color(0.32,0.38,0.44), 11)

	pause_scr = mk_screen(theme)
	var pvb : VBoxContainer = VBoxContainer.new()
	pvb.add_theme_constant_override("separation", 10)
	pause_scr.add_child(pvb)
	v_add(pvb,"ПАУЗА",Color(0.85,0.9,0.94),50)
	v_add(pvb,"Esc - продолжить | Backspace - в меню",Color(0.5,0.56,0.62),16)
	center(pvb)
	pause_scr.visible = false

	dead_scr = mk_screen(theme)
	var dvb : VBoxContainer = VBoxContainer.new()
	dvb.add_theme_constant_override("separation", 10)
	dead_scr.add_child(dvb)
	var dt : Label = v_add(dvb,"ШЕЯ СЛОМАНА",Color(0.9,0.25,0.2),50)
	dt.name = "DeadTitle"
	reason_lbl = v_add(dvb,"",Color(0.9,0.25,0.2),22)
	v_add(dvb,"R - попробовать снова | Esc - меню",Color(0.5,0.56,0.62),16)
	center(dvb)
	dead_scr.visible = false

	won_scr = mk_screen(theme)
	var wvb : VBoxContainer = VBoxContainer.new()
	wvb.add_theme_constant_override("separation", 10)
	won_scr.add_child(wvb)
	v_add(wvb,"ПОБЕГ УСПЕШЕН",Color(0.55,0.95,0.5),50)
	var wt : Label = v_add(wvb,"Время: 00:00",Color(0.85,0.9,0.94),24)
	wt.name = "TimeText"
	v_add(wvb,"R - ещё раз | Esc - меню",Color(0.5,0.56,0.62),16)
	center(wvb)
	won_scr.visible = false

func mk_screen(theme : Theme) -> Control:
	var s : Control = ClassDB.instantiate("Control")
	ui_canvas.add_child(s)
	fr(s)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg : ColorRect = ClassDB.instantiate("ColorRect")
	fr(bg)
	bg.color = Color(0.02,0.03,0.045,0.85)
	s.add_child(bg)
	s.theme = theme
	return s

static func fr(c : Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0

static func center(c : Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

static func v_add(parent : VBoxContainer, text : String, color : Color, size : int) -> Label:
	var l : Label = ClassDB.instantiate("Label")
	l.text = text; l.self_modulate = color
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

static func l_add(parent : Control, pos : Vector2, text : String, color : Color, size : int, align : int=HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l : Label = ClassDB.instantiate("Label")
	l.position = pos; l.text = text; l.self_modulate = color
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = align
	parent.add_child(l)
	return l

static func bar_add(parent : Control, pos : Vector2, label : String, col : Color) -> void:
	var row : Control = ClassDB.instantiate("Control")
	row.position = pos; row.size = Vector2(340, 20)
	parent.add_child(row)
	l_add(row, Vector2(0,3), label, Color(0.5,0.56,0.62), 10)
	var bg : ColorRect = ColorRect.new()
	bg.position=Vector2(90,3); bg.size=Vector2(240,12)
	bg.color=Color(0.06,0.08,0.1); row.add_child(bg)
	var fill : ColorRect = ColorRect.new()
	fill.position=Vector2(90,3); fill.size=Vector2(240,12)
	fill.color=col
	fill.name = label + "_fill"
	row.add_child(fill)


# ═══════════════════════ GAME LOOP ═══════════════════════

func _process(delta : float) -> void:
	if phase == "playing":
		rtime += delta
		toast_t = max(0.0, toast_t - delta)
		hbeat_cd -= delta
		step_cd -= delta

		blink_t -= delta
		if blink_t <= 0.0:
			blink_a = 0.22
			blink_l = 5.5 + randf()*2.5
			blink_t = blink_l
		blink_a = max(0.0, blink_a - delta)
		if blink_rect: blink_rect.visible = blink_a > 0.0

		if Input.is_action_just_pressed("flashlight"):
			if battery_f > 0.0:
				flash_on = not flash_on
				toast("ФОНАРЬ " + ("ВКЛ" if flash_on else "ВЫКЛ"))
			else:
				toast("БАТАРЕЯ ПУСТА")
		var fflash = player.get_meta("flash")
		if fflash:
			if flash_on and battery_f > 0.0:
				fflash.light_energy = 6.0
			else:
				fflash.light_energy = 0.0
		if flash_on and battery_f > 0.0:
			battery_f = max(0.0, battery_f - 2.0*delta)
		elif not flash_on:
			battery_f = min(100.0, battery_f + 0.7*delta)

		for dd in doors:
			var dx : float = float(dd["tx"])*TS+TS*0.5
			var dz : float = float(dd["ty"])*TS+TS*0.5
			if Vector2(dx-player.position.x, dz-player.position.z).length() < 2.0:
				if dd["open"] == false:
					var best : int = 0
					for lv in [3,2,1]:
						if cards[lv]: best = lv
					if best >= dd["need"]:
						dd["open"] = true
						toast("ДВЕРЬ ОТКРЫТА (уровень %d)" % dd["need"])
						play_sound("door")
					elif dd["msg_cd"] <= 0.0:
						dd["msg_cd"] = 1.8
						toast("ТРЕБУЕТСЯ КАРТА УРОВНЯ %d" % dd["need"])
			if dd["msg_cd"] > 0.0: dd["msg_cd"] -= delta
			if dd["open"] and dd["anim"] < 1.0: dd["anim"] = min(1.0, dd["anim"]+delta*2.2)
			elif dd["anim"] > 0.0: dd["anim"] = max(0.0, dd["anim"]-delta*2.2)
			if dd["mesh"]: dd["mesh"].position.y = WH*0.5 + dd["anim"]*(WH+0.2)

		for cn in get_tree().get_nodes_in_group("cards"):
			if cn.visible and player.position.distance_to(cn.global_position) < 1.35:
				cn.visible = false
				var lv : int = cn.get_meta("lvl")
				cards[lv] = true
				toast("КАРТА УРОВНЯ %d ПОЛУЧЕНА" % lv)
				if lv == 1:
					toast("ВНИМАНИЕ: SCP-173 ПОКИНУЛ КАМЕРУ")
					scp096_on = true
					if scp096: scp096.visible = true
					play_sound("siren")

		var gate_open : bool = false
		for dd in doors:
			if dd["tx"]==18 and dd["ty"]==19 and dd["open"]: gate_open = true
		if abs(player.position.x-exit_c.x)<exit_h.x and abs(player.position.z-exit_c.z)<exit_h.y and gate_open:
			phase = "won"; win_t = rtime
			won_scr.visible = true; ui_canvas.get_node("HUD").visible = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var ttl : Node = won_scr.get_node_or_null("TimeText")
			if ttl: ttl.text = "Время: "+fmt(win_t)

		if scp173 and scp173.has_meta("active") and scp173.get_meta("active"):
			if player.position.distance_to(scp173.global_position) < 1.45: kill("ШЕЯ СЛОМАНА")
		if scp096 and scp096.has_meta("active") and scp096.get_meta("active"):
			if player.position.distance_to(scp096.global_position) < 1.4: kill("СКРОМНИК ДОБРАЛСЯ")

		update_hud()
		update_threat(delta)
	elif phase == "dead" and reason_lbl:
		reason_lbl.text = dead_reason

func update_hud() -> void:
	var obj : String = ""
	if not cards[1]: obj="Найти карту ур.1 в Зоне содержания"
	elif not cards[2]: obj="Найти карту ур.2 в Офисах"
	elif not cards[3]: obj="Найти карту ур.3 в Лаборатории"
	else: obj="Добраться до шлюза"
	if obj_lbl: obj_lbl.text = obj
	if timer_lbl: timer_lbl.text = fmt(rtime)
	var t : Vector2i = tile_of(player.position)
	var sec : String = "КОРИДОР"
	for r in rooms:
		if t.x>=r["x"] and t.x<r["x"]+r["w"] and t.y>=r["y"] and t.y<r["y"]+r["h"]: sec=r["name"]
	if sector_lbl: sector_lbl.text = sec
	if toast_lbl: toast_lbl.text = toast_s if toast_t>0.0 else ""
	for i in 3:
		var lbl : Label = cardlbls[i]
		if lbl:
			lbl.text = "[ ]" if not cards[i+1] else "[%d]"%(i+1)
			match i+1:
				1: lbl.self_modulate = Color(0.35,0.7,1.0) if cards[1] else Color(0.25,0.3,0.36)
				2: lbl.self_modulate = Color(1.0,0.78,0.3) if cards[2] else Color(0.25,0.3,0.36)
				3: lbl.self_modulate = Color(1.0,0.28,0.24) if cards[3] else Color(0.25,0.3,0.36)
	for fname in ["ВЫНОСЛИВОСТЬ","ФОНАРЬ","МОРГАНИЕ"]:
		var fn : Node = ui_canvas.get_node_or_null("HUD/"+fname+"_fill")
		if fn:
			var ff : ColorRect = fn
			match fname:
				"ВЫНОСЛИВОСТЬ": ff.size.x = 240.0 * (stamina_f/100.0)
				"ФОНАРЬ": ff.size.x = 240.0 * (battery_f/100.0)
				"МОРГАНИЕ":
					var bp : float = (1.0-blink_t/max(blink_l,0.01))*100.0
					ff.size.x = 240.0 * clamp(bp,0.0,100.0)
	var wn : String = "SCP-173 ВНЕ ПОЛЯ ЗРЕНИЯ" if threat>0.55 else ""
	if warn_lbl:
		warn_lbl.text = wn
		warn_lbl.modulate.a = 0.8 if threat>0.55 else 0.0
	if danger_rect:
		danger_rect.color.a = 0.12 * clamp(threat*2.5-0.5, 0.0, 1.0)

func update_threat(delta : float) -> void:
	var tgt : float = 0.0
	if scp173 and scp173.has_meta("active"):
		var d : float = player.position.distance_to(scp173.global_position)
		if d < 18.0: tgt = max(tgt, 1.0-d/18.0)
	if scp096 and scp096.has_meta("active"):
		var d : float = player.position.distance_to(scp096.global_position)
		if d < 20.0: tgt = max(tgt, 1.0-d/20.0)
	threat = lerp(threat, tgt, delta*4.0)
	if threat > 0.35 and hbeat_cd <= 0.0:
		hbeat_cd = 60.0/(60.0+threat*90.0)
		play_sound("heartbeat")

func _input(event) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER and phase=="menu": start_game()
		elif event.keycode == KEY_ESCAPE: toggle_pause()
		elif event.keycode == KEY_BACKSPACE and phase=="paused":
			phase="menu"; pause_scr.visible=false; menu_scr.visible=true
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_R and (phase=="dead" or phase=="won"): start_game()
	elif event is InputEventMouseMotion and phase=="playing":
		yaw_f += event.relative.x * 0.0022
		pitch_f = clamp(pitch_f + event.relative.y*0.0022, -1.45, 1.45)

func _physics_process(delta : float) -> void:
	if phase != "playing": return
	handle_move(delta)
	update_scps(delta)
	player.rotation_degrees.y = yaw_f*180.0/PI
	player.get_node("Pivot/Camera3D").rotation_degrees.x = pitch_f

func handle_move(delta : float) -> void:
	var id : Vector2 = Vector2(Input.get_axis("move_left","move_right"),
	                           Input.get_axis("move_back","move_forward"))
	var moving : bool = id.length_squared() > 0.0
	var sprinting : bool = Input.is_key_pressed(KEY_SHIFT) and stamina_f>1.0 and moving
	var spd : float = SPEED*(SPRINT_MULT if sprinting else 1.0)
	if sprinting: stamina_f=max(0.0,stamina_f-24.0*delta)
	else: stamina_f=min(100.0,stamina_f+14.0*delta)
	if moving:
		id = id.normalized()
		# Standard FPS: forward=-Z, right=+X when yaw=0
		var fwd : Vector3 = Vector3(-sin(yaw_f),0.0,-cos(yaw_f))
		var rt  : Vector3 = Vector3(cos(yaw_f),0.0,-sin(yaw_f))
		var mv : Vector3 = (fwd*id.y + rt*id.x)*spd*delta
		var nx : float = player.position.x+mv.x
		var nz : float = player.position.z+mv.z
		if not circle_solid(Vector3(nx,0.0,player.position.z), PRAD):
			player.position.x=nx
		if not circle_solid(Vector3(player.position.x,0.0,nz), PRAD):
			player.position.z=nz
		if step_cd <= 0.0:
			step_cd = 0.28+randf()*0.12
			last_step_pos = Vector2(player.position.x, player.position.z)
			play_sound("step")

func update_scps(delta : float) -> void:
	if scp173:
		scp173.set_meta("active", cards[1])
		if scp173.get_meta("active"):
			var dist : float = scp173.global_position.distance_to(player.position)
			var vis : bool = false
			if not (blink_a > 0.0) and dist < 32.0:
				var tm : Vector3 = scp173.global_position-player.position; tm.y=0
				var fwd : Vector3 = Vector3(sin(yaw_f),0.0,-cos(yaw_f))
				var dir : Vector3 = tm.normalized()
				var half : float = 0.45 if flash_on and battery_f>0.0 else 0.95
				if fwd.dot(dir) > cos(half) and has_los(player.position,scp173.global_position):
					vis = true
			var clos : bool = dist<3.2 and has_los(player.position,scp173.global_position)
			scp173.set_meta("frozen", vis or clos)
			if dist<1.45 and not scp173.get_meta("frozen"): kill("ШЕЯ СЛОМАНА"); return
			if not scp173.get_meta("frozen"):
				if not scp173.has_meta("_pt"): scp173.set_meta("_pt",0.0)
				scp173.set_meta("_pt", scp173.get_meta("_pt") - delta)
				if scp173.get_meta("_pt") <= 0.0:
					scp173.set_meta("_pt", 0.4)
					scp173.set_meta("_path", bfs(tile_of(scp173.global_position), tile_of(player.position)))
				var path_arr : PackedVector2Array = scp173.get_meta("_path")
				while path_arr.size()>0:
					var nxt : Vector2i = path_arr[0]
					var tgt : Vector3 = Vector3(nxt.x*TS+TS*0.5,0.0,nxt.y*TS+TS*0.5)
					if scp173.global_position.distance_to(tgt)<0.35:
						path_arr.remove_at(0)
						scp173.set_meta("_path", path_arr)
					else: break
				var sp : float = 3.9
				var gl : Vector3 = player.position
				if path_arr.size()>0:
					var pp : Vector2i = path_arr[0]
					gl = Vector3(pp.x*TS+TS*0.5,0.0,pp.y*TS+TS*0.5)
				var dr : Vector3 = (gl-scp173.global_position); dr.y=0
				if dr.length_squared()>0.0001:
					dr = dr.normalized()
					var nnx : float = scp173.global_position.x+dr.x*sp*delta
					var nnz : float = scp173.global_position.z+dr.z*sp*delta
					var mtx : int = int(nnx/TS)
					var mtz : int = int(scp173.global_position.z/TS)
					if not is_wall(mtx,mtz): scp173.global_position.x=nnx
					mtx = int(scp173.global_position.x/TS)
					mtz = int(nnz/TS)
					if not is_wall(mtx,mtz): scp173.global_position.z=nnz
				scp173.rotation.y = atan2(dr.x, dr.z)

	if scp096:
		if not scp096.has_meta("_act"): scp096.set_meta("_act",false)
		if not scp096.has_meta("_angry"): scp096.set_meta("_angry",false)
		if not scp096.has_meta("_stare"): scp096.set_meta("_stare",0.0)
		if not scp096.has_meta("_ret"): scp096.set_meta("_ret",0.0)
		if not scp096.has_meta("_pt"): scp096.set_meta("_pt",0.0)
		if not scp096.has_meta("_path"): scp096.set_meta("_path",PackedVector2Array())

		if not scp096.get_meta("_act") and cards[1]:
			scp096.set_meta("_act",true); scp096.visible = true; scp096.set_meta("frozen",false)
		scp096.set_meta("active", scp096.get_meta("_act"))
		if not scp096.get_meta("active"):
			scp096.set_meta("frozen",true); return
		var dist : float = scp096.global_position.distance_to(player.position)
		var vf : bool = false
		if not (blink_a > 0.0) and dist<30.0:
			var tm : Vector3 = scp096.global_position-player.position; tm.y=0
			var fwd : Vector3 = Vector3(sin(yaw_f),0.0,-cos(yaw_f))
			var dir : Vector3 = tm.normalized()
			var half : float = 0.35 if flash_on and battery_f>0.0 else 0.90
			if fwd.dot(dir) > cos(half) and has_los(player.position, scp096.global_position):
				vf = true
		if vf:
			scp096.set_meta("_stare", scp096.get_meta("_stare") + delta)
			if scp096.get_meta("_stare") >= 2.0 and not scp096.get_meta("_angry"):
				scp096.set_meta("_angry",true); scp096.set_meta("_stare",0.0); scp096.set_meta("_ret",0.0)
				toast("ОН УВИДЕЛ ТЕБЯ!")
				threat = 1.0
				play_sound("096_cry")
		else:
			scp096.set_meta("_stare", 0.0)
		if not scp096.get_meta("_angry"):
			scp096.set_meta("frozen",vf); return
		scp096.set_meta("frozen",false)
		if dist<1.4: kill("СКРОМНИК ДОБРАЛСЯ"); return
		if not vf:
			scp096.set_meta("_ret", scp096.get_meta("_ret") + delta)
			if scp096.get_meta("_ret") >= 3.0:
				scp096.set_meta("_angry",false); scp096.set_meta("frozen",true); scp096.set_meta("_ret",0.0)
				scp096.set_meta("_path",PackedVector2Array())
				scp096.global_position=scp096s
				threat=0.0
				toast("ОН УШЁЛ НАЗАД В РЕАКТОР")
				return
		else:
			scp096.set_meta("_ret", 0.0)
		var tg : float = 0.15 if dist>20.0 else (1.0-dist/20.0)
		threat=lerp(threat,max(tg,0.0),delta*5.0)
		scp096.set_meta("_pt", scp096.get_meta("_pt") - delta)
		if scp096.get_meta("_pt") <= 0.0:
			scp096.set_meta("_pt", 0.4)
			scp096.set_meta("_path", bfs(tile_of(scp096.global_position), tile_of(player.position)))
		var path_arr2 : PackedVector2Array = scp096.get_meta("_path")
		while path_arr2.size()>0:
			var nxt : Vector2i = path_arr2[0]
			var tgt : Vector3 = Vector3(nxt.x*TS+TS*0.5,0.0,nxt.y*TS+TS*0.5)
			if scp096.global_position.distance_to(tgt)<0.35:
				path_arr2.remove_at(0)
				scp096.set_meta("_path", path_arr2)
			else: break
		var sp : float = 2.0 if vf else 3.2
		var gl : Vector3 = player.position
		if path_arr2.size()>0:
			var pp : Vector2i = path_arr2[0]
			gl = Vector3(pp.x*TS+TS*0.5,0.0,pp.y*TS+TS*0.5)
		var dr : Vector3 = (gl-scp096.global_position); dr.y=0
		if dr.length_squared()>0.0001:
			dr = dr.normalized()
			var nnx : float = scp096.global_position.x+dr.x*sp*delta
			var nnz : float = scp096.global_position.z+dr.z*sp*delta
			var mtx : int = int(nnx/TS)
			var mtz : int = int(scp096.global_position.z/TS)
			if not is_wall(mtx,mtz): scp096.global_position.x=nnx
			mtx = int(scp096.global_position.x/TS)
			mtz = int(nnz/TS)
			if not is_wall(mtx,mtz): scp096.global_position.z=nnz
		scp096.rotation.y = atan2(dr.x, dr.z)

func toast(msg : String) -> void:
	toast_s=msg; toast_t=2.4

func kill(reason : String) -> void:
	phase="dead"; dead_reason=reason
	dead_scr.visible=true; ui_canvas.get_node("HUD").visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func start_game() -> void:
	phase="playing"
	player.position=spawn_pos; player.rotation_degrees=Vector3(0,0,0)
	yaw_f=0.0; pitch_f=0.0
	stamina_f=100.0; battery_f=100.0; flash_on=true
	cards=[false,false,false,false]
	blink_t=6.5; blink_l=6.5; blink_a=0.0
	rtime=0.0; toast_s=""; toast_t=0.0; threat=0.0
	step_cd=0.28; last_step_pos=Vector2.ZERO; hbeat_cd=1.0
	scp096_on=false
	if scp096: scp096.visible=false; scp096.set_meta("_act",false); scp096.set_meta("frozen",true)
	if scp173: scp173.set_meta("active",false); scp173.set_meta("frozen",true); scp173.set_meta("_pt",0.0); scp173.set_meta("_path",PackedVector2Array())
	for dd in doors:
		dd["open"]=false; dd["anim"]=0.0; dd["msg_cd"]=0.0
		if dd["mesh"]: dd["mesh"].position.y=WH*0.5
	for cn in get_tree().get_nodes_in_group("cards"): cn.visible=true
	menu_scr.visible=false; ui_canvas.get_node("HUD").visible=true
	pause_scr.visible=false; dead_scr.visible=false; won_scr.visible=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func toggle_pause() -> void:
	if phase=="playing":
		phase="paused"; Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		pause_scr.visible=true
	elif phase=="paused":
		phase="playing"; Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		pause_scr.visible=false

static func fmt(t : float) -> String:
	var m : int = int(t / 60)
	var s : int = int(t) % 60
	return "%02d:%02d" % [m, s]

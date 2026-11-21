extends SceneTree

func _initialize() -> void:
	var out: Array[String] = []
	for cls in ["SpotLight3D", "Light3D", "AudioStreamWAV", "AudioStreamPlayer"]:
		out.append("### " + cls)
		for p in ClassDB.class_get_property_list(cls):
			out.append("  " + str(p["name"]))
	out.append("### FogMode enum")
	for e in ClassDB.class_get_enum_constants("Environment", "FogMode"):
		out.append("  " + str(e) + " = " + str(Environment.FOG_MODE_EXPONENTIAL if e == "FOG_MODE_EXPONENTIAL" else "?"))
	out.append("### BGMode constants present:")
	for e in ["BG_CLEAR_COLOR", "BG_COLOR", "BG_SKY", "BG_CANVAS"]:
		out.append("  " + e + "=" + str(ClassDB.class_get_integer_constant("Environment", e)))
	out.append("### Control methods (anchor/preset)")
	for m in ClassDB.class_get_method_list("Control"):
		var n: String = str(m["name"])
		if "anchor" in n or "preset" in n or "offset" in n:
			out.append("  " + n)
	print("\n".join(out))
	quit()

import os
os.chdir(r'C:\Users\Administrator\Desktop\zapret-discord-youtube-1.10.3\scp_godot')

with open('scripts/level_builder.gd', 'r', encoding='utf-8') as f:
    c = f.read()

print(f'Read {len(c)} chars')

# 1) mouse yaw/pitch
c = c.replace(
    '\t\tyaw_f -= event.relative.x * 0.0022\n\t\tpitch_f = clamp(pitch_f - event.relative.y*0.0022, -1.45, 1.45)',
    '\t\tyaw_f += event.relative.x * 0.0022\n\t\tpitch_f = clamp(pitch_f + event.relative.y*0.0022, -1.45, 1.45)'
)

# 2) fwd+rt in handle_move
c = c.replace(
    '\t\tvar fwd : Vector3 = Vector3(-sin(yaw_f),0.0,-cos(yaw_f))\n\t\tvar rt : Vector3 = Vector3(cos(yaw_f),0.0,-sin(yaw_f))',
    '\t\tvar fwd : Vector3 = Vector3(sin(yaw_f),0.0,-cos(yaw_f))\n\t\tvar rt : Vector3 = Vector3(cos(yaw_f),0.0,sin(yaw_f))'
)

# 3) fwd in SCP-173 FOV
c = c.replace(
    '\t\t\t\tvar fwd : Vector3 = Vector3(-sin(yaw_f),0.0,-cos(yaw_f))\n\t\t\t\tvar dir : Vector3 = tm.normalized()\n\t\t\t\tvar half : float = 0.45 if flash_on and battery_f>0.0 else 0.95\n\t\t\t\tif fwd.dot(dir) > cos(half) and has_los(player.position,scp173.global_position):',
    '\t\t\t\tvar fwd : Vector3 = Vector3(sin(yaw_f),0.0,-cos(yaw_f))\n\t\t\t\tvar dir : Vector3 = tm.normalized()\n\t\t\t\tvar half : float = 0.45 if flash_on and battery_f>0.0 else 0.95\n\t\t\t\tif fwd.dot(dir) > cos(half) and has_los(player.position,scp173.global_position):'
)

# 4) fwd in SCP-096 FOV
c = c.replace(
    '\t\t\tvar fwd : Vector3 = Vector3(-sin(yaw_f),0.0,-cos(yaw_f))\n\t\t\tvar dir : Vector3 = tm.normalized()\n\t\t\tvar half : float = 0.35 if flash_on and battery_f>0.0 else 0.90\n\t\t\tif fwd.dot(dir) > cos(half) and has_los(player.position, scp096.global_position):',
    '\t\t\tvar fwd : Vector3 = Vector3(sin(yaw_f),0.0,-cos(yaw_f))\n\t\t\tvar dir : Vector3 = tm.normalized()\n\t\t\tvar half : float = 0.35 if flash_on and battery_f>0.0 else 0.90\n\t\t\tif fwd.dot(dir) > cos(half) and has_los(player.position, scp096.global_position):'
)

# 5) STEP sound - deeper footstep with low thud
os_step = ('func gen_step_pcm(out : PackedByteArray) -> void:\n'
    '\tfor i in 3675:\n'
    '\t\tvar t : float = float(i)/22050.0\n'
    '\t\tvar env : float = pow(max(1.0-t/0.04,0.0), 3.0)\n'
    '\t\tvar n : float = (float(((i*0x6C622729)>>8))/32767.0)*2.0-1.0\n'
    '\t\tout.append(int(clamp(n*0.5*env,-1.0,1.0)*32767.0))')
ns_step = ('func gen_step_pcm(out : PackedByteArray) -> void:\n'
    '\tfor i in 5512:\n'
    '\t\tvar t : float = float(i)/22050.0\n'
    '\t\tvar env : float = pow(max(1.0-t/0.16,0.0), 2.5)\n'
    '\t\tvar thud : float = sin(t*85.0*TAU)*0.5 + sin(t*42.0*TAU)*0.2\n'
    '\t\tvar n : float = (float(((i*0x6C622729)>>8))/32767.0)*2.0-1.0\n'
    '\t\tout.append(int(clamp((thud + n*0.08)*env,-1.0,1.0)*32767.0))')
c = c.replace(os_step, ns_step)

# 6) SIREN sound - deep atmospheric foghorn-like alarm
os_siren = ('func gen_siren_pcm(out : PackedByteArray) -> void:\n'
    '\tfor i in 44100:\n'
    '\t\tvar t : float = float(i)/22050.0\n'
    '\t\tvar freq : float = 160.0+70.0*sin(t*2.5*TAU)\n'
    '\t\tvar env : float = clamp(t/0.05,0.0,1.0)\n'
    '\t\tif t > 1.8: env = clamp((2.0-t)/0.2,0.0,1.0)\n'
    '\t\tout.append(int(clamp(sin(t*freq*TAU)*0.4*env,-1.0,1.0)*32767.0))')
ns_siren = ('func gen_siren_pcm(out : PackedByteArray) -> void:\n'
    '\tfor i in 44100:\n'
    '\t\tvar t : float = float(i)/22050.0\n'
    '\t\tvar freq : float = 95.0 + 20.0*sin(t*TAU*0.33)\n'
    '\t\tvar pulse : float = 0.7 + 0.3*sin(t*TAU*0.5)\n'
    '\t\tvar env : float = clamp(t/0.15,0.0,1.0)\n'
    '\t\tif t > 1.7: env = clamp((2.0-t)/0.3,0.0,1.0)\n'
    '\t\tvar tone : float = sin(t*freq*TAU)*0.45 + sin(t*freq*1.5*TAU)*0.15\n'
    '\t\tout.append(int(clamp(tone*pulse*env,-1.0,1.0)*32767.0))')
c = c.replace(os_siren, ns_siren)

# 7) HEARTBEAT sound - deep resonant fuller thump
os_beat = ('func gen_beat_pcm(out : PackedByteArray, ratio : float) -> void:\n'
    '\tvar bpm : float = 60.0+ratio*90.0\n'
    '\tvar bd : float = 60.0/bpm\n'
    '\tvar sd : float = bd*0.18\n'
    '\tvar n : int = int(22050.0*bd*1.5)\n'
    '\tfor i in n:\n'
    '\t\tvar t : float = float(i)/22050.0\n'
    '\t\tvar ct : float = fmod(t,bd)\n'
    '\t\tvar env : float = 0.0\n'
    '\t\tif ct < sd: env = sqrt(ct/sd)*pow(1.0-ct/sd,2.0)\n'
    '\t\telif ct < sd*2.0: env = sqrt((ct-sd)/sd)*pow(1.0-(ct-sd)/sd,2.0)\n'
    '\t\tout.append(int(clamp(sin(t*55.0*TAU)*0.5*env,-1.0,1.0)*32767.0))')
ns_beat = ('func gen_beat_pcm(out : PackedByteArray, ratio : float) -> void:\n'
    '\tvar bpm : float = 60.0+ratio*90.0\n'
    '\tvar bd : float = 60.0/bpm\n'
    '\tvar sd : float = bd*0.20\n'
    '\tvar n : int = int(22050.0*bd*2.0)\n'
    '\tfor i in n:\n'
    '\t\tvar t : float = float(i)/22050.0\n'
    '\t\tvar ct : float = fmod(t,bd)\n'
    '\t\tvar env : float = 0.0\n'
    '\t\tif ct < sd: env = 1.0 - pow(1.0-ct/sd, 3.0)\n'
    '\t\telif ct < sd*2.0: env = (1.0-(ct-sd)/sd)*0.6\n'
    '\t\tvar thump : float = sin(t*48.0*TAU)*0.5 + sin(t*96.0*TAU)*0.25 + sin(t*144.0*TAU)*0.1\n'
    '\t\tout.append(int(clamp(thump*env,-1.0,1.0)*32767.0))')
c = c.replace(os_beat, ns_beat)

# 8) DOOR sound - smooth mechanical servo/hum
os_door = ('func gen_door_pcm(out : PackedByteArray) -> void:\n'
    '\tfor i in 33075:\n'
    '\t\tvar t : float = float(i)/22050.0\n'
    '\t\tif t > 1.5: break\n'
    '\t\tvar env : float = pow(1.0-t/1.5, 2.0)\n'
    '\t\tvar n : float = (float(((i*0xA3D1E5F9)>>8))/32767.0)*2.0-1.0\n'
    '\t\tvar h : float = sin(t*1600.0*TAU)*0.15+sin(t*2400.0*TAU)*0.08\n'
    '\t\tout.append(int(clamp((n*0.25+h)*env,-1.0,1.0)*32767.0))')
ns_door = ('func gen_door_pcm(out : PackedByteArray) -> void:\n'
    '\tfor i in 33075:\n'
    '\t\tvar t : float = float(i)/22050.0\n'
    '\t\tif t > 1.5: break\n'
    '\t\tvar env : float = pow(max(1.0-t/1.4,0.0), 1.8)\n'
    '\t\tvar sweep : float = 400.0 - t*200.0\n'
    '\t\tvar hum : float = sin(t*sweep*TAU)*0.3 + sin(t*sweep*0.5*TAU)*0.15\n'
    '\t\tvar clunk : float = sin(t*55.0*TAU*3.0)*0.4 * pow(max(1.0-t/0.08,0.0), 2.0)\n'
    '\t\tout.append(int(clamp((hum+clunk)*env,-1.0,1.0)*32767.0))')
c = c.replace(os_door, ns_door)

# 9) 096 CRY sound - deep distorted low roar
os_096 = ('func gen_096_pcm(out : PackedByteArray) -> void:\n'
    '\tfor i in 33075:\n'
    '\t\tvar t : float = float(i)/22050.0\n'
    '\t\tif t > 1.5: break\n'
    '\t\tvar env : float = clamp(t/0.03,0.0,1.0)\n'
    '\t\tif t > 1.2: env = clamp((1.5-t)/0.3,0.0,1.0)\n'
    '\t\tvar n : float = (float(((i*0xDEADBEEF)>>8))/32767.0)*2.0-1.0\n'
    '\t\tvar sc : float = sin(t*950.0*TAU)*0.3+sin(t*1400.0*TAU)*0.18\n'
    '\t\tout.append(int(clamp((n*0.2+sc)*env,-1.0,1.0)*32767.0))')
ns_096 = ('func gen_096_pcm(out : PackedByteArray) -> void:\n'
    '\tfor i in 33075:\n'
    '\t\tvar t : float = float(i)/22050.0\n'
    '\t\tif t > 1.5: break\n'
    '\t\tvar env : float = clamp(t/0.08,0.0,1.0)\n'
    '\t\tif t > 1.2: env = clamp((1.5-t)/0.3,0.0,1.0)\n'
    '\t\tvar n : float = (float(((i*0xDEADBEEF)>>8))/32767.0)*2.0-1.0\n'
    '\t\tvar low : float = sin(t*75.0*TAU)*0.4 + sin(t*150.0*TAU)*0.25\n'
    '\t\tvar mid : float = sin(t*320.0*TAU)*0.15\n'
    '\t\tout.append(int(clamp((low+mid+n*0.15)*env,-1.0,1.0)*32767.0))')
c = c.replace(os_096, ns_096)

# 10) Flashlight fix
c = c.replace(
    'fl.light_energy = 3_000_000.0; fl.set("range", 45.0)\n\t\tfl.set("cone_angle", 32.0); fl.set("inner_cone_angle", 25.0)',
    'fl.light_energy = 6.0; fl.spot_range = 45.0\n\t\tfl.spot_angle = 32.0; fl.spot_angle_attenuation = 0.5'
)

# === VERIFY ===
results = {
    'mouse yaw +=': 'yaw_f += event.relative.x' in c,
    'pitch_f +=': 'pitch_f + event.relative.y' in c,
    'fwd=sin(yaw)': 'Vector3(sin(yaw_f),0.0,-cos(yaw_f))' in c,
    'rt=cos,0,sin': 'Vector3(cos(yaw_f),0.0,sin(yaw_f))' in c,
    'step thud 85Hz': 'sin(t*85.0' in c,
    'siren foghorn': 'sin(t*TAU*0.33)' in c,
    'beat thump 48Hz': 'sin(t*48.0' in c,
    'door sweep 400': 'sweep : float = 400.0' in c,
    '096 low 75Hz': 'sin(t*75.0' in c,
    'flashlight 6.0': 'light_energy = 6.0' in c,
    'fl.spot_range': 'fl.spot_range = 45.0' in c,
    'fl.spot_angle': 'fl.spot_angle = 32.0' in c,
    'fl.angle_atten': 'spot_angle_attenuation = 0.5' in c,
    'NO old -sin': '(-sin(yaw_f)' not in c,
    'NO old 3M': '3_000_000.0' not in c,
    'NO old .set(range)': '.set("range"' not in c,
    'NO old step noise': 'pow(max(1.0-t/0.04,0.0), 3.0)' not in c,
    'NO old siren 160': '160.0+70.0*sin(t*2.5*TAU)' not in c,
    'NO old beat sqrt': 'sqrt(ct/sd)*pow(1.0-ct/sd,2.0)' not in c,
    'NO old door 1600': 'sin(t*1600.0*TAU)' not in c,
    'NO old 096 950': 'sin(t*950.0*TAU)' not in c,
}
all_ok = all(v for k,v in results.items())
print(f'All checks pass: {all_ok}')
for k,v in results.items():
    label = 'OK' if v else 'FAIL'
    if k.startswith('NO '):
        label = 'GONE' if v else 'STILL_PRESENT'
    print(f'  {k}: {label}')

if all_ok:
    with open('scripts/level_builder.gd', 'w', encoding='utf-8') as f:
        f.write(c)
    print('\nWRITTEN OK')
else:
    print('\nERROR: checks failed, NOT writing')
    import sys; sys.exit(1)
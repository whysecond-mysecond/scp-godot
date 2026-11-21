import os
os.chdir(r'C:\Users\Administrator\Desktop\zapret-discord-youtube-1.10.3\scp_godot')

with open('scripts/level_builder.gd', 'r', encoding='utf-8') as f:
    c = f.read()

# Fix flashlight - file uses single tab at line start
old = '\tfl.light_energy = 3_000_000.0; fl.set("range", 45.0)\n\tfl.set("cone_angle", 32.0); fl.set("inner_cone_angle", 25.0)'
new = '\tfl.light_energy = 6.0; fl.spot_range = 45.0\n\tfl.spot_angle = 32.0; fl.spot_angle_attenuation = 0.5'

if old in c:
    c = c.replace(old, new)
    ok = new in c and 'light_energy = 6.0' in c and 'fl.spot_range = 45.0' in c
    if ok:
        with open('scripts/level_builder.gd', 'w', encoding='utf-8') as f:
            f.write(c)
        print('Flashlight fixed OK')
    else:
        print('Flashlight fix FAILED')
else:
    print('Old pattern NOT found in file')
    idx = c.find('light_energy = 3_000_000')
    if idx >= 0:
        print('Found at index', idx)
        print(repr(c[idx:idx+80]))
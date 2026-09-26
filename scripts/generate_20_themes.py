import wave
import struct
import math
import os

SAMPLE_RATE = 44100

def write_wav(filename, duration, func):
    num_samples = int(SAMPLE_RATE * duration)
    l_arr = [0.0] * num_samples
    r_arr = [0.0] * num_samples
    for i in range(num_samples):
        t = float(i) / SAMPLE_RATE
        l, r = func(t, duration)
        l_arr[i] = max(-0.95, min(0.95, l))
        r_arr[i] = max(-0.95, min(0.95, r))
    
    # Seamless loop boundary crossfade (50ms)
    xfade = int(SAMPLE_RATE * 0.05)
    for i in range(xfade):
        fade_in = float(i) / xfade
        fade_out = 1.0 - fade_in
        # Blend tail into head
        tail_idx = num_samples - xfade + i
        l_arr[i] = l_arr[i] * fade_in + l_arr[tail_idx] * fade_out
        r_arr[i] = r_arr[i] * fade_in + r_arr[tail_idx] * fade_out
        l_arr[tail_idx] = l_arr[i]
        r_arr[tail_idx] = r_arr[i]

    with wave.open(filename, 'w') as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for i in range(num_samples):
            frames.extend(struct.pack('<hh', int(l_arr[i] * 32767.0), int(r_arr[i] * 32767.0)))
        wav.writeframes(frames)
    print(f"Created: {filename}")

# Synthesizer building blocks
def note_freq(semitones_from_a4):
    return 440.0 * (2.0 ** (semitones_from_a4 / 12.0))

# Notes relative to A4 (0)
# C4 = -9, D4 = -7, E4 = -5, F4 = -4, G4 = -2, A4 = 0, B4 = 2, C5 = 3, D5 = 5, E5 = 7, G5 = 10, A5 = 12

def sine(f, t, phase=0.0):
    return math.sin(2.0 * math.pi * f * t + phase)

def saw(f, t):
    p = (t * f) - math.floor(t * f)
    return 2.0 * p - 1.0

def triangle(f, t):
    p = (t * f) - math.floor(t * f)
    return 4.0 * abs(p - 0.5) - 1.0

def flute(f, t, vibrato=4.0):
    vib = 1.0 + 0.008 * math.sin(2.0 * math.pi * 5.0 * t)
    return (sine(f * vib, t) * 0.7 + 
            sine(f * vib * 2.0, t) * 0.2 + 
            sine(f * vib * 3.0, t) * 0.1)

def harp(f, t_hit):
    if t_hit < 0: return 0.0
    env = math.exp(-3.5 * t_hit)
    return (sine(f, t_hit) + 0.4 * sine(f * 2.0, t_hit) + 0.15 * sine(f * 3.0, t_hit)) * env

def bell(f, t_hit):
    if t_hit < 0: return 0.0
    env = math.exp(-2.2 * t_hit)
    return (sine(f, t_hit) + 0.5 * sine(f * 2.76, t_hit) + 0.25 * sine(f * 5.4, t_hit)) * env

def brass(f, t):
    return (saw(f, t) * 0.5 + saw(f * 1.002, t) * 0.5 + 0.3 * sine(f * 2.0, t)) * 0.6

def lute(f, t_hit):
    if t_hit < 0: return 0.0
    env = math.exp(-4.5 * t_hit)
    return (triangle(f, t_hit) + 0.5 * triangle(f * 2.0, t_hit) + 0.2 * saw(f, t_hit)) * env

# 1. Fairy Forest (Зачарованный Лес) - D major gentle flutes & harp
def t01(t, dur):
    bpm = 100.0
    beat = t * (bpm / 60.0)
    # Arpeggio (D, F#, A, D5)
    arp_notes = [-7, -3, 0, 5]
    step = int(beat * 2) % 16
    n = arp_notes[step % 4]
    t_hit = (beat * 2 - math.floor(beat * 2)) / (bpm / 30.0)
    h = harp(note_freq(n), t_hit) * 0.4
    # Flute melody
    fl_notes = [5, 7, 9, 7, 5, 2, 5, 7]
    fl_idx = int(beat / 2) % 8
    f_val = flute(note_freq(fl_notes[fl_idx]), t) * 0.35
    # Soft warm bass
    b_val = sine(note_freq(-19), t) * 0.3
    return h * 0.7 + f_val * 0.8 + b_val, h * 0.9 + f_val * 0.6 + b_val

# 2. Royal March (Королевский Марш) - Bb major brass & snare
def t02(t, dur):
    bpm = 116.0
    beat = t * (bpm / 60.0)
    # Drum pulse on beat
    p = beat - math.floor(beat)
    sn = math.exp(-15.0 * p) * (math.sin(t * 8421.0) * math.cos(t * 3141.0)) * 0.25
    kick = math.exp(-8.0 * p) * math.sin(2.0 * math.pi * 70.0 * (1.0 + math.exp(-10.0 * p)) * t) * 0.45
    # Fanfare chords: Bb -> F -> Gm -> Eb
    ch_idx = int(beat / 4) % 4
    chords = [[-10, -6, -3], [-5, -1, 2], [-14, -10, -7], [-7, -3, 0]]
    br = 0.0
    for n in chords[ch_idx]:
        br += brass(note_freq(n + 12), t) * 0.18
    return kick + sn * 0.8 + br * 0.9, kick + sn * 1.1 + br * 1.05

# 3. Cozy Tavern (Уютная Лесная Таверна) - G major bouncing lute & tambourine
def t03(t, dur):
    bpm = 132.0
    beat = t * (bpm / 60.0)
    step = int(beat * 2) % 16
    lute_notes = [-14, -10, -7, -2, -10, -7, -2, 2, -14, -10, -7, -2, -5, -2, 2, 5]
    t_hit = (beat * 2 - math.floor(beat * 2)) / (bpm / 30.0)
    lt = lute(note_freq(lute_notes[step]), t_hit) * 0.5
    # Tambourine rattle on upbeats
    tb = math.exp(-18.0 * (beat - math.floor(beat))) * math.sin(t * 12345.0) * 0.15 if int(beat * 2) % 2 == 1 else 0.0
    return lt * 0.9 + tb * 0.7, lt * 1.05 + tb * 1.1

# 4. Mystic Sanctuary (Тайное Святилище) - E minor deep resonant pads & bells
def t04(t, dur):
    drone = (sine(note_freq(-17), t) * 0.35 + 
             sine(note_freq(-5), t) * 0.25 * (0.6 + 0.4 * sine(0.2, t)) + 
             sine(note_freq(2), t) * 0.15)
    # Bell every 3 seconds
    b_cycle = t % 3.0
    b_notes = [7, 10, 14, 12]
    b_idx = int(t / 3.0) % 4
    bl = bell(note_freq(b_notes[b_idx]), b_cycle) * 0.4
    return drone * 0.9 + bl * 0.7, drone * 0.9 + bl * 1.1

# 5. Wanderer Ballad (Баллада Странника) - A minor melodic flute & gentle guitar
def t05(t, dur):
    bpm = 92.0
    beat = t * (bpm / 60.0)
    # Acoustic guitar arpeggio (Am: A, C, E, A5)
    am_notes = [-12, -9, -5, 0]
    step = int(beat * 2) % 16
    t_hit = (beat * 2 - math.floor(beat * 2)) / (bpm / 30.0)
    gt = harp(note_freq(am_notes[step % 4]), t_hit) * 0.4
    # Melodic flute line
    m_notes = [0, 2, 3, 5, 7, 5, 3, 2]
    m_idx = int(beat / 2) % 8
    fl = flute(note_freq(m_notes[m_idx]), t) * 0.38
    return gt * 0.8 + fl * 0.9, gt * 1.0 + fl * 0.75

# 6. Knights Honor (Рыцарская Честь) - C major noble french horns
def t06(t, dur):
    bpm = 84.0
    beat = t * (bpm / 60.0)
    ch_idx = int(beat / 4) % 4
    # C -> G -> Am -> F
    roots = [-9, -14, -12, -16]
    r = roots[ch_idx]
    horn = (sine(note_freq(r + 12), t) * 0.35 + 
            sine(note_freq(r + 16), t) * 0.25 + 
            sine(note_freq(r + 19), t) * 0.2)
    # Warm strings accompaniment
    pad = (sine(note_freq(r), t) * 0.3 + sine(note_freq(r + 7), t) * 0.2)
    return horn * 0.9 + pad * 0.85, horn * 1.0 + pad * 0.85

# 7. Crystal Stream (Хрустальный Источник) - F major sparkling glockenspiel
def t07(t, dur):
    # Shimmering high bells cascading
    cycle = (t * 4.0) % 8
    step = int(cycle)
    scale = [5, 7, 9, 10, 12, 14, 16, 17]
    t_hit = (cycle - math.floor(cycle)) * 0.25
    gl = bell(note_freq(scale[step]), t_hit) * 0.35
    water = math.sin(t * 3141.0) * math.cos(t * 1592.0) * 0.03 * (0.7 + 0.3 * sine(0.5, t))
    pad = sine(note_freq(-4), t) * 0.25
    return gl * 0.8 + water + pad, gl * 1.1 + water + pad

# 8. HoMM3 Nostalgia (Ностальгия Героев) - Harpsichord & strings in classic HoMM style
def t08(t, dur):
    bpm = 108.0
    beat = t * (bpm / 60.0)
    step = int(beat * 4) % 16
    # Harpsichord pattern (D minor: D, F, A, D, C#, E, G...)
    h_notes = [-7, -4, 0, 5, -8, -5, -2, 4, -7, -4, 0, 5, -10, -7, -3, 2]
    f = note_freq(h_notes[step])
    t_hit = (beat * 4 - math.floor(beat * 4)) / (bpm / 15.0)
    env = math.exp(-7.0 * t_hit)
    harpsi = (saw(f, t_hit) + 0.5 * saw(f * 2.0, t_hit)) * env * 0.35
    # Low cello
    bass = sine(note_freq(-19), t) * 0.3
    return harpsi * 0.8 + bass, harpsi * 1.05 + bass

# 9. Ancient Ruins (Древние Руины) - Mystical vocal chorus and slow gong
def t09(t, dur):
    # Choir formant pad
    f_choir = note_freq(-14) # G2
    v1 = sine(f_choir, t) + 0.5 * sine(f_choir * 2.0, t) + 0.3 * sine(f_choir * 3.0, t)
    v2 = sine(f_choir * 1.5, t) + 0.4 * sine(f_choir * 3.0, t)
    lfo = 0.5 + 0.5 * sine(0.3, t)
    choir = (v1 + v2) * lfo * 0.3
    # Low gong every 6 seconds
    gong_t = t % 6.0
    gong = bell(note_freq(-21), gong_t) * 0.5
    return choir * 0.85 + gong * 0.9, choir * 1.05 + gong * 0.9

# 10. Morning Meadow (Утренний Луг) - Pastoral pipe & birdsong chirps
def t10(t, dur):
    bpm = 96.0
    beat = t * (bpm / 60.0)
    # Warm pasture chords (G, C, D)
    ch_idx = int(beat / 4) % 4
    roots = [-14, -9, -7, -14]
    base = sine(note_freq(roots[ch_idx]), t) * 0.25
    # Pipe melody
    p_notes = [-2, 0, 2, 5, 7, 5, 2, 0]
    p_idx = int(beat / 2) % 8
    pipe = flute(note_freq(p_notes[p_idx]), t) * 0.38
    # Bird chirp
    b_trig = t % 2.7
    bird = sine(2400.0 + 800.0 * sine(25.0, b_trig), b_trig) * math.exp(-14.0 * b_trig) * 0.1 if b_trig < 0.25 else 0.0
    return base + pipe * 0.9 + bird * 0.7, base + pipe * 0.8 + bird * 1.1

# 11. Celtic Dance (Кельтский Праздник) - Fast upbeat jig (6/8 rhythm)
def t11(t, dur):
    bpm = 144.0
    beat = t * (bpm / 60.0)
    step = int(beat * 3) % 12
    jig_notes = [-7, -5, -3, 0, 2, 5, 7, 5, 2, 0, -3, -5]
    t_hit = (beat * 3 - math.floor(beat * 3)) / (bpm / 20.0)
    whistle = flute(note_freq(jig_notes[step]), t) * 0.4
    bodhran = math.exp(-8.0 * (beat - math.floor(beat))) * sine(65.0, t) * 0.4 if int(beat) % 2 == 0 else 0.0
    return whistle * 0.85 + bodhran, whistle * 1.05 + bodhran

# 12. Foggy Swamp (Туманные Топи) - Eerie water ripples & dark ambiance
def t12(t, dur):
    rumble = sine(55.0 + 5.0 * sine(0.2, t), t) * 0.35
    whisper = math.sin(t * 1948.0) * math.cos(t * 921.0) * (0.04 + 0.03 * sine(0.4, t))
    drip_t = t % 1.9
    drip = bell(1200.0 * (1.0 - drip_t * 0.3), drip_t) * 0.2 if drip_t < 0.15 else 0.0
    return rumble * 0.9 + whisper + drip * 0.6, rumble * 0.9 + whisper + drip * 1.2

# 13. Glory Triumph (Триумф Королевства) - Victorious fanfare & timpani
def t13(t, dur):
    bpm = 112.0
    beat = t * (bpm / 60.0)
    p = beat - math.floor(beat)
    timp = math.exp(-6.0 * p) * sine(85.0 * (1.0 + math.exp(-12.0 * p)), t) * 0.45 if int(beat) % 2 == 0 else 0.0
    # Trumpet fanfare: D, F#, A, D5
    f_step = int(beat) % 4
    notes = [-7, -3, 0, 5]
    tp = brass(note_freq(notes[f_step] + 12), t) * 0.35
    return timp + tp * 0.9, timp + tp * 1.1

# 14. Moonlight Grove (Лунная Роща) - Celesta & piano dreamscape
def t14(t, dur):
    bpm = 76.0
    beat = t * (bpm / 60.0)
    step = int(beat * 2) % 16
    cel_notes = [0, 4, 7, 11, 12, 11, 7, 4, -1, 4, 7, 11, 12, 11, 7, 4]
    t_hit = (beat * 2 - math.floor(beat * 2)) / (bpm / 30.0)
    cel = bell(note_freq(cel_notes[step]), t_hit) * 0.35
    pad = (sine(note_freq(-12), t) + sine(note_freq(-5), t)) * 0.2
    return cel * 0.8 + pad, cel * 1.1 + pad

# 15. Battle Call (Зов Битвы) - Driving martial pulse & aggressive saw
def t15(t, dur):
    bpm = 128.0
    beat = t * (bpm / 60.0)
    p = beat - math.floor(beat)
    bass = math.exp(-4.0 * p) * (saw(note_freq(-19), t) * 0.3 + sine(note_freq(-19), t) * 0.3)
    hat = math.exp(-18.0 * (p if beat * 2 % 1 < 0.5 else p - 0.5)) * math.sin(t * 14521.0) * 0.12
    ch_idx = int(beat / 4) % 2
    f_hit = note_freq(-7 if ch_idx == 0 else -10)
    stab = brass(f_hit, t) * math.exp(-5.0 * p) * 0.3
    return bass * 0.9 + hat + stab * 0.85, bass * 0.9 + hat + stab * 1.05

# 16. Fairy Lullaby (Колыбельная Фей) - Slow soothing music box
def t16(t, dur):
    bpm = 70.0
    beat = t * (bpm / 60.0)
    step = int(beat) % 8
    mb_notes = [2, 5, 7, 9, 7, 5, 2, 0]
    t_hit = (beat - math.floor(beat)) / (bpm / 60.0)
    mb = bell(note_freq(mb_notes[step] + 12), t_hit) * 0.4
    pad = sine(note_freq(-10), t) * 0.22
    return mb * 0.75 + pad, mb * 1.05 + pad

# 17. Dragon Peak (Пики Дракона) - Huge epic brass swells & deep brass
def t17(t, dur):
    bpm = 68.0
    beat = t * (bpm / 60.0)
    p = beat - math.floor(beat)
    swell = 0.5 + 0.5 * sine(0.25, t)
    f_horn = note_freq(-17) # E2
    epic = (saw(f_horn, t) * 0.4 + saw(f_horn * 1.5, t) * 0.3 + sine(f_horn * 2.0, t) * 0.25) * swell * 0.5
    drum = math.exp(-5.0 * p) * sine(50.0, t) * 0.5 if int(beat) % 4 == 0 else 0.0
    return epic * 0.85 + drum, epic * 1.05 + drum

# 18. Minstrel Song (Песнь Менестреля) - Renaissance lute melody
def t18(t, dur):
    bpm = 120.0
    beat = t * (bpm / 60.0)
    step = int(beat * 2) % 16
    m_notes = [-12, -5, 0, 3, 2, 0, -2, -5, -12, -5, 0, 3, 5, 3, 2, 0]
    t_hit = (beat * 2 - math.floor(beat * 2)) / (bpm / 30.0)
    lt = lute(note_freq(m_notes[step]), t_hit) * 0.55
    tamb = math.exp(-12.0 * (beat - math.floor(beat))) * math.sin(t * 8888.0) * 0.08
    return lt * 0.9 + tamb, lt * 1.05 + tamb

# 19. Cathedral Light (Храм Света) - Pipe organ & sacred counterpoint
def t19(t, dur):
    bpm = 72.0
    beat = t * (bpm / 60.0)
    ch_idx = int(beat / 4) % 4
    chords = [[-9, -5, -2], [-5, -2, 2], [-12, -9, -5], [-14, -10, -7]]
    organ = 0.0
    for n in chords[ch_idx]:
        f = note_freq(n)
        organ += (sine(f, t) * 0.3 + sine(f * 2.0, t) * 0.2 + sine(f * 4.0, t) * 0.1) * 0.35
    pedal = sine(note_freq(chords[ch_idx][0] - 12), t) * 0.35
    return organ * 0.9 + pedal, organ * 1.05 + pedal

# 20. Epic Fairytale (Великая Сказочная Симфония) - Full orchestral theme
def t20(t, dur):
    bpm = 104.0
    beat = t * (bpm / 60.0)
    # Rhythmic timpani & snare
    p = beat - math.floor(beat)
    timp = math.exp(-6.0 * p) * sine(75.0, t) * 0.35 if int(beat) % 2 == 0 else 0.0
    # Symphonic strings & brass chords
    ch_idx = int(beat / 4) % 4
    chords = [[-7, -3, 0], [-10, -7, -3], [-5, -2, 2], [-7, -3, 0]]
    orch = 0.0
    for n in chords[ch_idx]:
        f = note_freq(n)
        orch += (saw(f, t) * 0.25 + saw(f * 1.003, t) * 0.25 + sine(f * 2.0, t) * 0.2) * 0.35
    # Lead flute on top
    fl_step = int(beat) % 8
    fl_notes = [5, 9, 12, 9, 5, 2, 5, 7]
    lead = flute(note_freq(fl_notes[fl_step]), t) * 0.3
    return timp + orch * 0.85 + lead * 0.9, timp + orch * 1.05 + lead * 0.8

THEMES = [
    ("theme_01_fairy_forest.wav", t01),
    ("theme_02_royal_march.wav", t02),
    ("theme_03_cozy_tavern.wav", t03),
    ("theme_04_mystic_sanctuary.wav", t04),
    ("theme_05_wanderer_ballad.wav", t05),
    ("theme_06_knights_honor.wav", t06),
    ("theme_07_crystal_spring.wav", t07),
    ("theme_08_homm_nostalgia.wav", t08),
    ("theme_09_ancient_ruins.wav", t09),
    ("theme_10_morning_meadow.wav", t10),
    ("theme_11_celtic_dance.wav", t11),
    ("theme_12_foggy_swamp.wav", t12),
    ("theme_13_glory_triumph.wav", t13),
    ("theme_14_moonlight_grove.wav", t14),
    ("theme_15_battle_call.wav", t15),
    ("theme_16_fairy_lullaby.wav", t16),
    ("theme_17_dragon_peak.wav", t17),
    ("theme_18_minstrel_song.wav", t18),
    ("theme_19_cathedral_light.wav", t19),
    ("theme_20_epic_fairytale.wav", t20)
]

def process_theme(item):
    filename, func = item
    out_dir = "assets/audio/music/themes"
    filepath = os.path.join(out_dir, filename)
    write_wav(filepath, 12.0, func)
    return filename

if __name__ == "__main__":
    from multiprocessing import Pool
    out_dir = "assets/audio/music/themes"
    os.makedirs(out_dir, exist_ok=True)
    with Pool() as pool:
        pool.map(process_theme, THEMES)
    print("All 20 musical themes generated successfully!")

import wave
import struct
import math
import os

SAMPLE_RATE = 44100

def generate_wav(path, duration, generator_func):
    num_samples = int(SAMPLE_RATE * duration)
    with wave.open(path, 'w') as wav_file:
        wav_file.setnchannels(2) # Stereo
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(SAMPLE_RATE)
        
        frames = bytearray()
        for i in range(num_samples):
            t = float(i) / SAMPLE_RATE
            left, right = generator_func(t, duration)
            
            # Master soft limiting
            left = max(-0.95, min(0.95, left))
            right = max(-0.95, min(0.95, right))
            
            l_int = int(left * 32767.0)
            r_int = int(right * 32767.0)
            frames.extend(struct.pack('<hh', l_int, r_int))
            
        wav_file.writeframes(frames)
    print(f"Generated: {path} ({duration:.1f}s)")

# 1. Battle Theme: Driving 120 BPM martial cadence with snare, timpani, brass chords
def battle_theme(t, dur):
    bpm = 124.0
    beat = t * (bpm / 60.0)
    bar = beat / 4.0
    phase_in_beat = beat - math.floor(beat)
    
    # Bassline (D minor ostinato: D - F - G - A)
    step = int(beat * 2) % 16
    bass_notes = [73.42, 73.42, 87.31, 73.42, 98.00, 87.31, 110.0, 98.00,
                  73.42, 73.42, 87.31, 73.42, 65.41, 73.42, 82.41, 73.42]
    f_bass = bass_notes[step]
    bass_env = math.exp(-6.0 * (phase_in_beat if step % 2 == 0 else (phase_in_beat * 2 - math.floor(phase_in_beat * 2))))
    bass = math.sin(2.0 * math.pi * f_bass * t) + 0.3 * math.sin(4.0 * math.pi * f_bass * t)
    bass *= bass_env * 0.4
    
    # Timpani on beat 1 and 3
    timp_env = math.exp(-5.0 * phase_in_beat) if (int(beat) % 2 == 0) else 0.0
    f_timp = 82.0 * (1.0 + 0.5 * timp_env)
    timpani = math.sin(2.0 * math.pi * f_timp * t) * timp_env * 0.5
    
    # Snare roll noise
    snare_env = 0.0
    if int(beat * 4) % 4 in [1, 2, 3]:
        sub_p = (beat * 4) - math.floor(beat * 4)
        snare_env = math.exp(-12.0 * sub_p) * 0.25
    # High-pitched noise seed
    noise = math.sin(t * 19283.123) * math.cos(t * 8329.84)
    snare = noise * snare_env
    
    # Brass Fanfare (Chords: Dm -> Bb -> C -> Dm)
    chord_idx = int(bar) % 4
    chords = [
        [293.66, 349.23, 440.0], # Dm
        [233.08, 293.66, 349.23], # Bb
        [261.63, 329.63, 392.0], # C
        [293.66, 440.0, 587.33]   # Dm high
    ]
    cur_chord = chords[chord_idx]
    brass = 0.0
    for idx, f in enumerate(cur_chord):
        detune = 1.0 + 0.0015 * (idx - 1)
        saw = (math.sin(2.0 * math.pi * f * detune * t) 
               + 0.5 * math.sin(4.0 * math.pi * f * detune * t) 
               + 0.25 * math.sin(6.0 * math.pi * f * detune * t))
        brass += saw * 0.12
    
    left = bass + timpani * 0.9 + snare * 0.7 + brass * 0.95
    right = bass + timpani * 0.9 + snare * 0.8 + brass * 1.05
    return left, right

# 2. Swamp Theme: Eerie eerie ambient pads with slow resonant water droplets
def swamp_theme(t, dur):
    # Deep drone (C minor / G)
    f1 = 65.41 # C2
    f2 = 98.00 # G2
    lfo1 = 0.5 + 0.5 * math.sin(2.0 * math.pi * 0.15 * t)
    lfo2 = 0.5 + 0.5 * math.sin(2.0 * math.pi * 0.08 * t + 1.2)
    
    drone = (math.sin(2.0 * math.pi * f1 * t) * lfo1 * 0.35 +
             math.sin(2.0 * math.pi * f2 * t) * lfo2 * 0.25 +
             math.sin(2.0 * math.pi * 155.56 * t) * 0.15) # Eb3
             
    # Mystical resonant bell chime every 4 seconds
    bell_cycle = t % 4.5
    bell_env = math.exp(-2.2 * bell_cycle) if bell_cycle < 3.0 else 0.0
    bell_f = 622.25 if int(t / 4.5) % 2 == 0 else 523.25
    bell = (math.sin(2.0 * math.pi * bell_f * t) + 
            0.5 * math.sin(2.0 * math.pi * bell_f * 2.76 * t)) * bell_env * 0.3
            
    # Swamp breeze noise
    breeze = math.sin(t * 4321.1) * math.cos(t * 1234.5) * (0.04 + 0.03 * math.sin(t * 0.5))
    
    left = drone * 0.85 + bell * 0.7 + breeze
    right = drone * 0.85 + bell * 1.1 + breeze
    return left, right

# 3. Volcano Theme: Deep rumble with crackling embers and powerful brass swells
def volcano_theme(t, dur):
    # Volcanic rumble (35 - 55 Hz)
    f_rumble = 42.0 + 8.0 * math.sin(2.0 * math.pi * 0.2 * t)
    rumble = (math.sin(2.0 * math.pi * f_rumble * t) * 0.45 +
              math.sin(2.0 * math.pi * (f_rumble * 1.5) * t) * 0.25)
              
    # Brass swell
    swell_t = t % 6.0
    swell_env = math.sin(swell_t / 6.0 * math.pi)
    f_brass = 116.54 # Bb2
    brass = (math.sin(2.0 * math.pi * f_brass * t) + 
             0.4 * math.sin(4.0 * math.pi * f_brass * t)) * swell_env * 0.28
             
    # Crackling noise
    crackle = math.sin(t * 18765.4) * math.cos(t * 9345.1) * 0.05
    
    left = rumble * 0.9 + brass * 0.8 + crackle
    right = rumble * 0.9 + brass * 1.0 + crackle
    return left, right

if __name__ == "__main__":
    os.makedirs("assets/audio/music", exist_ok=True)
    generate_wav("assets/audio/music/battle_theme.wav", 16.0, battle_theme)
    generate_wav("assets/audio/music/swamp_theme.wav", 18.0, swamp_theme)
    generate_wav("assets/audio/music/volcano_theme.wav", 18.0, volcano_theme)

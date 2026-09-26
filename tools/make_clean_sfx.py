import os
import math
import random
import wave
import struct

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SFX_DIR = os.path.join(BASE_DIR, "assets", "audio", "sfx")

def write_wav(filename, samples, sample_rate=44100):
    path = os.path.join(SFX_DIR, filename)
    with wave.open(path, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        raw = b"".join(struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples)
        wav_file.writeframes(raw)
    print(f"Generated {filename}")

def generate_clean_sfx():
    sample_rate = 44100
    
    # 1. Warm Muffled Horse Gallop (soft turf thuds, never harsh)
    samples = [0.0] * int(sample_rate * 0.45)
    # Gentle low-thud beats: 0.02s, 0.13s, 0.23s
    beats = [(0.02, 180, 0.55), (0.13, 160, 0.45), (0.24, 140, 0.6)]
    for b_time, freq, amp in beats:
        s_idx = int(b_time * sample_rate)
        dur_samples = int(0.08 * sample_rate)
        for i in range(min(dur_samples, len(samples) - s_idx)):
            t = i / sample_rate
            # Heavy damped low-pass thud
            env = math.exp(-t * 45.0)
            s = (math.sin(2 * math.pi * freq * (1.0 - t * 4.0) * t) +
                 0.3 * math.sin(2 * math.pi * (freq * 1.8) * t) * math.exp(-t * 90.0) +
                 random.uniform(-0.04, 0.04) * math.exp(-t * 60.0))
            samples[s_idx + i] += s * env * amp
    write_wav("horse_gallop.wav", samples)
    
    # 2. Bow shot (bowstring snap & arrow whoosh)
    samples = []
    dur = 0.28
    tot = int(sample_rate * dur)
    for i in range(tot):
        t = i / sample_rate
        # String twang (damped sine at 420 Hz with quick pitch drop)
        twang_f = 460.0 * (1.0 - t * 1.5)
        twang = math.sin(2 * math.pi * twang_f * t) * math.exp(-t * 32.0)
        # Air whoosh noise
        whoosh = random.uniform(-0.15, 0.15) * math.sin(math.pi * (t / dur))
        samples.append((0.7 * twang + 0.3 * whoosh) * 0.75)
    write_wav("bow_shot.wav", samples)
    
    # 3. Arrow impact (wooden thud on armor)
    samples = []
    dur = 0.22
    tot = int(sample_rate * dur)
    for i in range(tot):
        t = i / sample_rate
        env = math.exp(-t * 38.0)
        thud = math.sin(2 * math.pi * 210.0 * t) + 0.4 * math.sin(2 * math.pi * 480.0 * t)
        noise = random.uniform(-0.2, 0.2) * math.exp(-t * 50.0)
        samples.append((thud + noise) * env * 0.7)
    write_wav("arrow_hit.wav", samples)
    
    # 4. Sword clash (clean resonant steel)
    samples = []
    dur = 0.35
    tot = int(sample_rate * dur)
    for i in range(tot):
        t = i / sample_rate
        env = math.exp(-t * 12.0)
        # Metallic overtone series
        s = (0.45 * math.sin(2 * math.pi * 1240.0 * t) +
             0.35 * math.sin(2 * math.pi * 1860.0 * t) +
             0.20 * math.sin(2 * math.pi * 2480.0 * t) +
             0.25 * math.sin(2 * math.pi * 320.0 * t) * math.exp(-t * 25.0))
        samples.append(s * env * 0.65)
    write_wav("sword_hit.wav", samples)
    
    # 5. Coin (soft golden jingle)
    samples = []
    dur = 0.4
    tot = int(sample_rate * dur)
    for i in range(tot):
        t = i / sample_rate
        env1 = math.exp(-t * 14.0)
        env2 = math.exp(-(t - 0.08) * 16.0) if t > 0.08 else 0.0
        s = (0.5 * math.sin(2 * math.pi * 2093.0 * t) * env1 +  # C7
             0.4 * math.sin(2 * math.pi * 2637.0 * (t - 0.08)) * env2 + # E7
             0.3 * math.sin(2 * math.pi * 3136.0 * (t - 0.04)) * env1)  # G7
        samples.append(s * 0.5)
    write_wav("coin.wav", samples)
    
    # 6. Spell cast (magical chime glissando)
    samples = []
    dur = 0.7
    tot = int(sample_rate * dur)
    for i in range(tot):
        t = i / sample_rate
        env = math.exp(-t * 4.5)
        f = 523.25 * (1.0 + t * 2.2) # Rising pitch
        shimmer = math.sin(2 * math.pi * 14.0 * t) * 0.15
        s = (0.4 * math.sin(2 * math.pi * f * (1.0 + shimmer) * t) +
             0.3 * math.sin(2 * math.pi * (f * 1.5) * t) +
             0.25 * math.sin(2 * math.pi * (f * 2.0) * t))
        samples.append(s * env * 0.6)
    write_wav("spell_cast.wav", samples)

if __name__ == "__main__":
    generate_clean_sfx()

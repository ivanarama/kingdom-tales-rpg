import os
import math
import random
import wave
import struct

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SFX_DIR = os.path.join(BASE_DIR, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(BASE_DIR, "assets", "audio", "music")

def write_wav(path, samples, sample_rate=44100):
    with wave.open(path, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        raw = b"".join(struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples)
        wav_file.writeframes(raw)
    print(f"Generated {os.path.basename(path)} ({len(samples)} samples)")

def make_hoof_impact(sample_rate, freq1, freq2, click_freq=1800.0, volume=0.85):
    dur = 0.075
    n_samples = int(sample_rate * dur)
    res = [0.0] * n_samples
    for i in range(n_samples):
        t = i / sample_rate
        # 1. High frequency click transient (the edge of the horseshoe / coconut shell)
        click_env = math.exp(-t * 220.0)
        click = (math.sin(2 * math.pi * click_freq * t) + random.uniform(-0.35, 0.35)) * click_env * 0.45
        
        # 2. Hollow acoustic cavity body resonance (the hollow clop)
        body_env = math.exp(-t * 65.0)
        body = (math.sin(2 * math.pi * freq1 * (1.0 - t * 2.0) * t) * 0.65 +
                math.sin(2 * math.pi * freq2 * t) * 0.35) * body_env
        
        # 3. Low dirt thud
        thud_env = math.exp(-t * 85.0)
        thud = math.sin(2 * math.pi * (freq1 * 0.5) * t) * thud_env * 0.4
        
        res[i] = (click + body + thud) * volume
    return res

def generate_homm_sfx():
    sample_rate = 44100
    
    # 1. HoMM3-style Horse Gallop (Two rhythmic hoof clops: "clop-clack")
    total_dur = 0.32
    samples = [0.0] * int(sample_rate * total_dur)
    
    # First hoof (Forefoot: crisper, 360 Hz)
    hoof1 = make_hoof_impact(sample_rate, freq1=360, freq2=520, click_freq=1900, volume=0.9)
    # Second hoof (Hindfoot: slightly delayed 0.08s later, deeper, 300 Hz)
    hoof2 = make_hoof_impact(sample_rate, freq1=290, freq2=430, click_freq=1600, volume=0.75)
    
    # Place hoof 1 at 0.01s
    idx1 = int(0.01 * sample_rate)
    for i, s in enumerate(hoof1):
        if idx1 + i < len(samples):
            samples[idx1 + i] += s
            
    # Place hoof 2 at 0.09s
    idx2 = int(0.09 * sample_rate)
    for i, s in enumerate(hoof2):
        if idx2 + i < len(samples):
            samples[idx2 + i] += s
            
    write_wav(os.path.join(SFX_DIR, "horse_gallop.wav"), samples, sample_rate)

    # 2. Bow shot (clean bowstring snap + brief arrow hiss)
    samples = []
    dur = 0.22
    tot = int(sample_rate * dur)
    for i in range(tot):
        t = i / sample_rate
        # String snap: 480Hz dropping rapidly
        snap_env = math.exp(-t * 40.0)
        snap = math.sin(2 * math.pi * 480.0 * (1.0 - t * 3.0) * t) * snap_env
        # Air hiss
        hiss_env = math.sin(math.pi * min(1.0, t / dur)) * math.exp(-t * 8.0)
        hiss = random.uniform(-0.18, 0.18) * hiss_env
        samples.append((snap * 0.7 + hiss * 0.3) * 0.85)
    write_wav(os.path.join(SFX_DIR, "bow_shot.wav"), samples, sample_rate)

    # 3. Arrow hit (wooden arrow striking shield/armor)
    samples = []
    dur = 0.18
    tot = int(sample_rate * dur)
    for i in range(tot):
        t = i / sample_rate
        env = math.exp(-t * 45.0)
        strike = math.sin(2 * math.pi * 280.0 * t) + 0.4 * math.sin(2 * math.pi * 560.0 * t)
        wood_crack = random.uniform(-0.25, 0.25) * math.exp(-t * 90.0)
        samples.append((strike * 0.6 + wood_crack * 0.4) * env * 0.85)
    write_wav(os.path.join(SFX_DIR, "arrow_hit.wav"), samples, sample_rate)

    # 4. Sword hit (clean metallic ringing steel)
    samples = []
    dur = 0.32
    tot = int(sample_rate * dur)
    for i in range(tot):
        t = i / sample_rate
        env = math.exp(-t * 14.0)
        clash = (0.5 * math.sin(2 * math.pi * 1150.0 * t) +
                 0.35 * math.sin(2 * math.pi * 1720.0 * t) +
                 0.25 * math.sin(2 * math.pi * 2300.0 * t) +
                 0.3 * math.sin(2 * math.pi * 310.0 * t) * math.exp(-t * 30.0))
        samples.append(clash * env * 0.75)
    write_wav(os.path.join(SFX_DIR, "sword_hit.wav"), samples, sample_rate)

    # 5. Coin pickup (warm golden bells)
    samples = []
    dur = 0.35
    tot = int(sample_rate * dur)
    for i in range(tot):
        t = i / sample_rate
        env1 = math.exp(-t * 16.0)
        env2 = math.exp(-(t - 0.06) * 18.0) if t > 0.06 else 0.0
        c = (0.5 * math.sin(2 * math.pi * 2093.0 * t) * env1 +
             0.45 * math.sin(2 * math.pi * 2637.0 * max(0.0, t - 0.06)) * env2 +
             0.3 * math.sin(2 * math.pi * 3136.0 * t) * env1)
        samples.append(c * 0.6)
    write_wav(os.path.join(SFX_DIR, "coin.wav"), samples, sample_rate)

    # 6. Spell cast (celestial chime glissando)
    samples = []
    dur = 0.65
    tot = int(sample_rate * dur)
    for i in range(tot):
        t = i / sample_rate
        env = math.exp(-t * 5.0)
        freq = 600.0 + 800.0 * (t / dur) + 40.0 * math.sin(2 * math.pi * 12.0 * t)
        s = (0.5 * math.sin(2 * math.pi * freq * t) +
             0.3 * math.sin(2 * math.pi * (freq * 1.5) * t) +
             0.2 * math.sin(2 * math.pi * (freq * 2.0) * t))
        samples.append(s * env * 0.7)
    write_wav(os.path.join(SFX_DIR, "spell_cast.wav"), samples, sample_rate)

if __name__ == "__main__":
    generate_homm_sfx()

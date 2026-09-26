import os
import math
import random
import wave
import struct

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SFX_DIR = os.path.join(BASE_DIR, "assets", "audio", "sfx")

def generate_horse_gallop():
    sample_rate = 44100
    dur = 0.45
    total = int(sample_rate * dur)
    samples = [0.0] * total
    
    # 3 quick hoofbeats per stride: at 0.0s, 0.12s, 0.22s
    beats = [(0.02, 620, 0.8), (0.13, 560, 0.7), (0.23, 440, 0.9)]
    
    for b_time, freq, amp in beats:
        start_idx = int(b_time * sample_rate)
        beat_len = int(0.06 * sample_rate)
        for i in range(min(beat_len, total - start_idx)):
            t = i / sample_rate
            env = math.exp(-t * 85.0)
            noise = random.uniform(-0.15, 0.15)
            s = (math.sin(2 * math.pi * freq * t) + 0.4 * math.sin(2 * math.pi * freq * 2.2 * t) + noise) * env * amp
            samples[start_idx + i] += s
            
    out_path = os.path.join(SFX_DIR, "horse_gallop.wav")
    with wave.open(out_path, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        raw = b"".join(struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples)
        wav_file.writeframes(raw)
        
    print(f"Generated horse gallop sound: {out_path}")

if __name__ == "__main__":
    generate_horse_gallop()

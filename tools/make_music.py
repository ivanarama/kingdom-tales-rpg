import os
import math
import wave
import struct

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MUSIC_PATH = os.path.join(BASE_DIR, "assets", "audio", "music", "fairy_tale_theme.wav")

def note_freq(midi_note):
    return 440.0 * (2.0 ** ((midi_note - 69) / 12.0))

def generate_music():
    sample_rate = 44100
    bpm = 84
    beat_dur = 60.0 / bpm
    total_beats = 32  # 8 bars of 4/4
    total_time = total_beats * beat_dur
    total_samples = int(sample_rate * total_time)
    
    # Chord progression: Am -> F -> C -> G (repeated twice, 4 beats each)
    # MIDI chords
    chords = [
        # Bar 1-2: Am
        [57, 60, 64, 69], [57, 60, 64, 69],
        # Bar 3-4: F
        [53, 57, 60, 65], [53, 57, 60, 65],
        # Bar 5-6: C
        [48, 55, 60, 64], [48, 55, 60, 64],
        # Bar 7-8: G
        [55, 59, 62, 67], [55, 59, 62, 67],
        
        # Second cycle with variation
        [57, 60, 64, 69], [57, 60, 64, 72],
        [53, 57, 60, 65], [53, 57, 60, 69],
        [48, 55, 60, 64], [48, 55, 60, 67],
        [55, 59, 62, 67], [55, 59, 62, 71]
    ]
    
    melody_notes = [
        # (beat_start, beat_length, midi_note, velocity)
        (0, 1.5, 69, 0.4), (1.5, 0.5, 71, 0.35), (2, 1.0, 72, 0.45), (3, 1.0, 71, 0.35),
        (4, 2.0, 65, 0.4), (6, 1.0, 67, 0.35), (7, 1.0, 69, 0.4),
        (8, 2.0, 67, 0.45), (10, 1.0, 64, 0.35), (11, 1.0, 65, 0.35),
        (12, 3.0, 62, 0.4), (15, 1.0, 64, 0.3),
        
        (16, 1.5, 69, 0.45), (17.5, 0.5, 72, 0.4), (18, 1.0, 76, 0.5), (19, 1.0, 74, 0.4),
        (20, 2.0, 72, 0.45), (22, 1.0, 71, 0.35), (23, 1.0, 69, 0.4),
        (24, 2.0, 67, 0.45), (26, 1.0, 69, 0.4), (27, 1.0, 71, 0.35),
        (28, 3.0, 69, 0.45), (31, 1.0, 64, 0.3)
    ]
    
    samples = [0.0] * total_samples
    
    # 1. Synthesize lute/harp arpeggio
    for bar_idx, chord in enumerate(chords):
        bar_start_beat = bar_idx * 2
        for step in range(4): # 8th notes
            beat = bar_start_beat + step * 0.5
            start_s = int(beat * beat_dur * sample_rate)
            note = chord[step % len(chord)]
            freq = note_freq(note)
            note_dur = beat_dur * 1.8
            n_samples = int(note_dur * sample_rate)
            
            for i in range(min(n_samples, total_samples - start_s)):
                t = i / sample_rate
                # Plucked string harmonic decay
                env = math.exp(-t * 4.5)
                val = (0.5 * math.sin(2 * math.pi * freq * t) +
                       0.3 * math.sin(2 * math.pi * freq * 2 * t) * math.exp(-t * 8.0) +
                       0.15 * math.sin(2 * math.pi * freq * 3 * t) * math.exp(-t * 12.0))
                samples[start_s + i] += val * env * 0.22
                
    # 2. Synthesize gentle flute melody
    for beat_start, beat_len, note, vel in melody_notes:
        start_s = int(beat_start * beat_dur * sample_rate)
        freq = note_freq(note)
        dur = beat_len * beat_dur
        n_samples = int(dur * sample_rate)
        
        for i in range(min(n_samples, total_samples - start_s)):
            t = i / sample_rate
            # Flute envelope: soft attack, steady sustain with gentle vibrato, soft release
            if t < 0.08:
                env = t / 0.08
            elif t > dur - 0.1:
                env = max(0.0, (dur - t) / 0.1)
            else:
                env = 1.0
            
            # 5 Hz vibrato
            vib = 1.0 + 0.008 * math.sin(2 * math.pi * 5.0 * t)
            f = freq * vib
            
            val = (math.sin(2 * math.pi * f * t) +
                   0.15 * math.sin(2 * math.pi * f * 2 * t) +
                   0.05 * math.sin(2 * math.pi * f * 3 * t))
            samples[start_s + i] += val * env * vel * 0.26
            
    # Write WAV
    with wave.open(MUSIC_PATH, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        raw = b"".join(struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples)
        wav_file.writeframes(raw)
        
    print(f"Generated music: {MUSIC_PATH} ({total_time:.1f}s)")

if __name__ == "__main__":
    generate_music()

import os
import math
import random
import wave
import struct

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MUSIC_PATH = os.path.join(BASE_DIR, "assets", "audio", "music", "fairy_tale_theme.wav")

def note_freq(midi_note):
    return 440.0 * (2.0 ** ((midi_note - 69) / 12.0))

def generate_harpsichord():
    sample_rate = 44100
    bpm = 104
    beat_dur = 60.0 / bpm
    
    # 16 bars of 4/4 in D minor / F major (Classic HoMM2 Sorceress / HoMM3 Grass style)
    total_beats = 64
    total_time = total_beats * beat_dur
    total_samples = int(sample_rate * total_time)
    samples = [0.0] * total_samples
    
    # Bass / accompaniment notes: (beat_start, beat_len, midi_note, vel)
    bass_notes = []
    # D minor (bars 1-2): D3, A3, F3, A3, D3, F3, A3, F3...
    dm_arpeggio = [50, 57, 53, 57, 50, 53, 57, 53]
    # Bb major (bars 3-4): Bb2, F3, D3, F3...
    bb_arpeggio = [46, 53, 50, 53, 46, 50, 53, 50]
    # C major (bars 5-6): C3, G3, E3, G3...
    c_arpeggio = [48, 55, 52, 55, 48, 52, 55, 52]
    # F major (bars 7-8): F3, C3, A3, C3...
    f_arpeggio = [41, 48, 45, 48, 41, 45, 48, 45]
    
    # Gm (bars 9-10)
    gm_arpeggio = [43, 50, 46, 50, 43, 46, 50, 46]
    # A major / dominant (bars 11-12)
    a_arpeggio = [45, 52, 49, 52, 45, 49, 52, 49]
    # D minor return (bars 13-16)
    dm_end1 = [50, 57, 53, 57, 46, 53, 50, 53]
    dm_end2 = [45, 52, 49, 52, 50, 57, 62, 57]
    
    all_arpeggios = [
        dm_arpeggio, dm_arpeggio,
        bb_arpeggio, bb_arpeggio,
        c_arpeggio, c_arpeggio,
        f_arpeggio, f_arpeggio,
        gm_arpeggio, gm_arpeggio,
        a_arpeggio, a_arpeggio,
        dm_end1, dm_end1,
        dm_end2, [50, 57, 62, 65, 50, 57, 62, 69]
    ]
    
    for bar_idx, arp in enumerate(all_arpeggios):
        bar_beat = bar_idx * 4.0
        for step_idx, note in enumerate(arp):
            beat = bar_beat + step_idx * 0.5
            bass_notes.append((beat, 0.5, note, 0.38))
            
    # Right hand baroque melody with elegant ornaments and turns
    melody = [
        # Bar 1: Dm
        (0.0, 1.0, 74, 0.6), (1.0, 0.5, 76, 0.55), (1.5, 0.5, 77, 0.65),
        (2.0, 1.0, 76, 0.55), (3.0, 1.0, 74, 0.6),
        # Bar 2:
        (4.0, 1.5, 77, 0.65), (5.5, 0.5, 76, 0.5), (6.0, 1.0, 74, 0.55), (7.0, 1.0, 73, 0.6),
        # Bar 3: Bb
        (8.0, 1.0, 74, 0.6), (9.0, 0.5, 72, 0.5), (9.5, 0.5, 70, 0.55),
        (10.0, 1.0, 69, 0.5), (11.0, 1.0, 70, 0.55),
        # Bar 4:
        (12.0, 2.0, 72, 0.65), (14.0, 1.0, 74, 0.6), (15.0, 1.0, 72, 0.55),
        # Bar 5: C
        (16.0, 1.0, 72, 0.6), (17.0, 0.5, 74, 0.55), (17.5, 0.5, 76, 0.65),
        (18.0, 1.0, 77, 0.7), (19.0, 1.0, 76, 0.6),
        # Bar 6:
        (20.0, 1.5, 76, 0.6), (21.5, 0.5, 74, 0.55), (22.0, 1.0, 72, 0.6), (23.0, 1.0, 71, 0.5),
        # Bar 7: F
        (24.0, 2.0, 72, 0.7), (26.0, 1.0, 69, 0.6), (27.0, 1.0, 65, 0.55),
        # Bar 8:
        (28.0, 3.0, 69, 0.65), (31.0, 1.0, 70, 0.55),
        
        # Bar 9: Gm
        (32.0, 1.0, 70, 0.65), (33.0, 0.5, 72, 0.6), (33.5, 0.5, 74, 0.7),
        (34.0, 1.0, 76, 0.65), (35.0, 1.0, 74, 0.6),
        # Bar 10:
        (36.0, 1.5, 72, 0.6), (37.5, 0.5, 70, 0.55), (38.0, 1.0, 69, 0.6), (39.0, 1.0, 67, 0.55),
        # Bar 11: A major
        (40.0, 1.0, 69, 0.65), (41.0, 0.5, 70, 0.6), (41.5, 0.5, 73, 0.7),
        (42.0, 1.0, 74, 0.75), (43.0, 1.0, 73, 0.65),
        # Bar 12:
        (44.0, 2.0, 76, 0.8), (46.0, 1.0, 74, 0.65), (47.0, 1.0, 73, 0.6),
        # Bar 13: Dm climax
        (48.0, 1.0, 74, 0.8), (49.0, 0.5, 77, 0.75), (49.5, 0.5, 81, 0.85),
        (50.0, 1.0, 79, 0.75), (51.0, 1.0, 77, 0.7),
        # Bar 14:
        (52.0, 1.5, 77, 0.75), (53.5, 0.5, 76, 0.65), (54.0, 1.0, 74, 0.7), (55.0, 1.0, 73, 0.65),
        # Bar 15:
        (56.0, 1.0, 74, 0.7), (57.0, 1.0, 76, 0.7), (58.0, 1.0, 77, 0.75), (59.0, 1.0, 76, 0.65),
        # Bar 16: Final resolution chord
        (60.0, 3.5, 74, 0.8), (60.0, 3.5, 69, 0.65), (60.0, 3.5, 62, 0.6)
    ]
    
    # Harpsichord synthesizer: plucked string with rich metallic brightness
    def synthesize_harpsichord_note(freq, vel, dur):
        n_samples = int(dur * sample_rate)
        res = [0.0] * n_samples
        # Harpsichord harmonics (prominent 1st to 7th harmonics with fast attack and crisp decay)
        for i in range(n_samples):
            t = i / sample_rate
            env = math.exp(-t * 5.2) * (1.0 - math.exp(-t * 300.0))
            # Pluck overtone ringing
            s = (1.00 * math.sin(2 * math.pi * freq * t) +
                 0.65 * math.sin(2 * math.pi * freq * 2 * t) * math.exp(-t * 3.0) +
                 0.45 * math.sin(2 * math.pi * freq * 3 * t) * math.exp(-t * 5.0) +
                 0.30 * math.sin(2 * math.pi * freq * 4 * t) * math.exp(-t * 7.0) +
                 0.18 * math.sin(2 * math.pi * freq * 5 * t) * math.exp(-t * 9.0) +
                 0.10 * math.sin(2 * math.pi * freq * 6 * t) * math.exp(-t * 11.0))
            res[i] = s * env * vel * 0.28
        return res

    # Render bass
    for b_start, b_dur, midi, vel in bass_notes:
        freq = note_freq(midi)
        s_idx = int(b_start * beat_dur * sample_rate)
        note_samples = synthesize_harpsichord_note(freq, vel, b_dur * beat_dur * 1.5)
        for i in range(min(len(note_samples), total_samples - s_idx)):
            samples[s_idx + i] += note_samples[i]

    # Render melody
    for m_start, m_dur, midi, vel in melody:
        freq = note_freq(midi)
        s_idx = int(m_start * beat_dur * sample_rate)
        note_samples = synthesize_harpsichord_note(freq, vel, m_dur * beat_dur * 1.6)
        for i in range(min(len(note_samples), total_samples - s_idx)):
            samples[s_idx + i] += note_samples[i]

    # Write WAV
    with wave.open(MUSIC_PATH, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        raw = b"".join(struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples)
        wav_file.writeframes(raw)
        
    print(f"Generated HoMM style harpsichord music: {MUSIC_PATH} ({total_time:.1f}s)")

if __name__ == "__main__":
    generate_harpsichord()

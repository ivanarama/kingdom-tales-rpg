import os
import math
import struct
import wave
import numpy as np
from multiprocessing import Pool

SAMPLE_RATE = 44100

def note_freq(semitones_from_a4):
    return 440.0 * (2.0 ** (semitones_from_a4 / 12.0))

# Notes from A4 (0)
# C3: -21, D3: -19, E3: -17, F3: -16, G3: -14, A3: -12, B3: -10
# C4: -9,  D4: -7,  E4: -5,  F4: -4,  G4: -2,  A4: 0,   B4: 2
# C5: 3,   D5: 5,   E5: 7,   F5: 8,   G5: 10,  A5: 12,  B5: 14
# C6: 15,  D6: 17,  E6: 19,  F6: 20,  G6: 22,  A6: 24

# Instrument generators (return 1D float32 numpy array)
def synth_harpsichord(f, dur_sec, vel=1.0):
    n = int(dur_sec * SAMPLE_RATE)
    t = np.linspace(0, dur_sec, n, endpoint=False, dtype=np.float32)
    # Plectrum attack puck
    puck = np.exp(-120.0 * t) * np.sin(2 * np.pi * f * 7.5 * t) * 0.15
    env1 = np.exp(-3.5 * t)
    env2 = np.exp(-6.5 * t)
    env3 = np.exp(-10.0 * t)
    # Bright baroque harpsichord harmonic series
    sig = (
        np.sin(2 * np.pi * f * t) * 0.45 * env1 +
        np.sin(2 * np.pi * f * 2 * t) * 0.32 * env1 +
        np.sin(2 * np.pi * f * 3 * t) * 0.22 * env2 +
        np.sin(2 * np.pi * f * 4 * t) * 0.16 * env2 +
        np.sin(2 * np.pi * f * 5 * t) * 0.11 * env3 +
        np.sin(2 * np.pi * f * 6 * t) * 0.08 * env3 +
        puck
    ) * vel
    return sig.astype(np.float32)

def synth_flute(f, dur_sec, vel=1.0):
    n = int(dur_sec * SAMPLE_RATE)
    t = np.linspace(0, dur_sec, n, endpoint=False, dtype=np.float32)
    att = np.minimum(1.0, t / 0.04)
    rel = np.minimum(1.0, (dur_sec - t) / 0.06)
    env = att * rel
    vib = 1.0 + 0.007 * np.sin(2 * np.pi * 5.5 * t)
    sig = (
        np.sin(2 * np.pi * f * vib * t) * 0.75 +
        np.sin(2 * np.pi * f * vib * 2 * t) * 0.22 +
        np.sin(2 * np.pi * f * vib * 3 * t) * 0.08
    ) * env * vel
    return sig.astype(np.float32)

def synth_lute(f, dur_sec, vel=1.0):
    n = int(dur_sec * SAMPLE_RATE)
    t = np.linspace(0, dur_sec, n, endpoint=False, dtype=np.float32)
    env = np.exp(-4.2 * t)
    sig = (
        np.sin(2 * np.pi * f * t) * 0.60 +
        np.sin(2 * np.pi * f * 2 * t) * 0.25 +
        np.sin(2 * np.pi * f * 3 * t) * 0.15
    ) * env * vel
    return sig.astype(np.float32)

def synth_pizz_bass(f, dur_sec, vel=1.0):
    n = int(dur_sec * SAMPLE_RATE)
    t = np.linspace(0, dur_sec, n, endpoint=False, dtype=np.float32)
    env = np.exp(-4.5 * t)
    sig = (
        np.sin(2 * np.pi * f * t) * 0.70 +
        np.sin(2 * np.pi * f * 2 * t) * 0.25 +
        np.sin(2 * np.pi * f * 3 * t) * 0.10
    ) * env * vel
    return sig.astype(np.float32)

def synth_fairy_bells(f, dur_sec, vel=1.0):
    n = int(dur_sec * SAMPLE_RATE)
    t = np.linspace(0, dur_sec, n, endpoint=False, dtype=np.float32)
    env = np.exp(-2.2 * t)
    sig = (
        np.sin(2 * np.pi * f * t) * 0.50 +
        np.sin(2 * np.pi * f * 2.76 * t) * 0.30 +
        np.sin(2 * np.pi * f * 5.4 * t) * 0.20
    ) * env * vel
    return sig.astype(np.float32)

def synth_spinet(f, dur_sec, vel=1.0):
    n = int(dur_sec * SAMPLE_RATE)
    t = np.linspace(0, dur_sec, n, endpoint=False, dtype=np.float32)
    env1 = np.exp(-4.8 * t)
    env2 = np.exp(-8.5 * t)
    sig = (
        np.sin(2 * np.pi * f * t) * 0.40 * env1 +
        np.sin(2 * np.pi * f * 2 * t) * 0.35 * env1 +
        np.sin(2 * np.pi * f * 3 * t) * 0.25 * env2
    ) * vel
    return sig.astype(np.float32)

def synth_organ(f, dur_sec, vel=1.0):
    n = int(dur_sec * SAMPLE_RATE)
    t = np.linspace(0, dur_sec, n, endpoint=False, dtype=np.float32)
    att = np.minimum(1.0, t / 0.05)
    rel = np.minimum(1.0, (dur_sec - t) / 0.08)
    env = att * rel
    sig = (
        np.sin(2 * np.pi * f * t) * 0.50 +
        np.sin(2 * np.pi * f * 2 * t) * 0.30 +
        np.sin(2 * np.pi * f * 4 * t) * 0.20
    ) * env * vel
    return sig.astype(np.float32)

INSTRUMENTS = {
    'harpsichord': synth_harpsichord,
    'flute': synth_flute,
    'lute': synth_lute,
    'pizz_bass': synth_pizz_bass,
    'fairy_bells': synth_fairy_bells,
    'spinet': synth_spinet,
    'organ': synth_organ,
}

class Score:
    def __init__(self, bpm, beats_total):
        self.bpm = bpm
        self.beats_total = beats_total
        self.duration = beats_total * (60.0 / bpm)
        self.total_samples = int(self.duration * SAMPLE_RATE)
        self.events = [] # (beat, inst_name, pitch_semitones, dur_beats, vel, pan)

    def add(self, beat, inst, semitones, dur_beats=1.0, vel=1.0, pan=0.5):
        self.events.append((beat, inst, semitones, dur_beats, vel, pan))

    def add_arpeggio(self, start_beat, inst, notes, step_beats=0.25, dur_beats=0.5, vel=0.7, pan=0.5):
        for idx, n in enumerate(notes):
            self.add(start_beat + idx * step_beats, inst, n, dur_beats, vel, pan)

    def render(self):
        buf_l = np.zeros(self.total_samples, dtype=np.float32)
        buf_r = np.zeros(self.total_samples, dtype=np.float32)
        sec_per_beat = 60.0 / self.bpm

        for beat, inst_name, pitch, dur_beats, vel, pan in self.events:
            dur_sec = dur_beats * sec_per_beat
            if inst_name in ['harpsichord', 'lute', 'pizz_bass', 'fairy_bells', 'spinet']:
                # Decaying instruments ring longer than note step
                render_dur = max(dur_sec, 1.6)
            else:
                render_dur = dur_sec

            f = note_freq(pitch)
            generator = INSTRUMENTS[inst_name]
            sig = generator(f, render_dur, vel)

            start_sec = beat * sec_per_beat
            start_sample = int(start_sec * SAMPLE_RATE)
            note_len = len(sig)

            # Circular buffer wrapping ensures 100% gapless seamless loop
            indices = (start_sample + np.arange(note_len)) % self.total_samples
            pan_l = math.cos(pan * math.pi * 0.5)
            pan_r = math.sin(pan * math.pi * 0.5)
            buf_l[indices] += sig * pan_l
            buf_r[indices] += sig * pan_r

        # Normalization and soft limiting
        peak = max(np.max(np.abs(buf_l)), np.max(np.abs(buf_r)), 0.001)
        if peak > 0.85:
            buf_l = (buf_l / peak) * 0.85
            buf_r = (buf_r / peak) * 0.85

        return buf_l, buf_r

def write_stereo_wav(filepath, buf_l, buf_r):
    num_samples = len(buf_l)
    frames = bytearray()
    # Convert float32 [-1.0, 1.0] to 16-bit PCM
    l_16 = np.clip(buf_l * 32767.0, -32767.0, 32767.0).astype(np.int16)
    r_16 = np.clip(buf_r * 32767.0, -32767.0, 32767.0).astype(np.int16)
    interleaved = np.empty((num_samples * 2,), dtype=np.int16)
    interleaved[0::2] = l_16
    interleaved[1::2] = r_16

    with wave.open(filepath, 'w') as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(interleaved.tobytes())
    print(f"Created WAV: {filepath}")

# ==========================================
# 20 HoMM 2 Baroque Harpsichord Compositions
# ==========================================

# 1. Sorceress Garden (Сад Волшебницы)
def comp_homm2_01():
    # 4 bars, 16 beats, BPM 104. D minor -> Gm -> C -> F -> Bb -> Gm -> A7 -> Dm
    s = Score(bpm=104.0, beats_total=16.0)
    chords = [
        ([-7, -3, 0, 5], -19),    # Dm (D, F, A, D) bass D
        ([-5, -2, 2, 7], -17),    # Gm (G, Bb, D, G) bass G
        ([-9, -5, -2, 3], -21),   # C (C, E, G, C) bass C
        ([-4, 0, 3, 8], -16),     # F (F, A, C, F) bass F
        ([-7, -2, 2, 5], -19),    # Bb bass Bb
        ([-5, -2, 2, 7], -17),    # Gm
        ([-8, -5, -1, 4], -12),   # A7 bass A
        ([-7, -3, 0, 5], -19)     # Dm
    ]
    for bar_idx, (arp, bass_note) in enumerate(chords):
        base_b = bar_idx * 2.0
        # Harpsichord 16th arpeggios
        for step in range(8):
            n = arp[step % len(arp)]
            s.add(base_b + step * 0.25, 'harpsichord', n, dur_beats=0.4, vel=0.65, pan=0.6)
        # Pizzicato bass
        s.add(base_b, 'pizz_bass', bass_note, dur_beats=1.5, vel=0.8, pan=0.4)
        s.add(base_b + 1.0, 'pizz_bass', bass_note + 7, dur_beats=0.8, vel=0.6, pan=0.4)
        # Fairy bells on bar start
        s.add(base_b, 'fairy_bells', arp[-1] + 12, dur_beats=1.5, vel=0.4, pan=0.7)

    # Pastoral flute singing melody
    flute_notes = [
        (0.0, 5, 1.5), (1.5, 7, 0.5), (2.0, 10, 1.5), (3.5, 8, 0.5),
        (4.0, 7, 1.0), (5.0, 5, 1.0), (6.0, 8, 2.0),
        (8.0, 10, 1.5), (9.5, 8, 0.5), (10.0, 7, 1.5), (11.5, 5, 0.5),
        (12.0, 4, 1.5), (13.5, 2, 0.5), (14.0, 5, 2.0)
    ]
    for b, p, d in flute_notes:
        s.add(b, 'flute', p, dur_beats=d, vel=0.85, pan=0.45)
    return s

# 2. Knight Castle (Замок Рыцаря)
def comp_homm2_02():
    # 4 bars, 16 beats, BPM 112. C -> G -> Am -> Em -> F -> C -> G -> C
    s = Score(bpm=112.0, beats_total=16.0)
    chords = [
        ([-9, -5, -2, 3], -21), ([-14, -10, -7, -2], -14),
        ([-12, -9, -5, 0], -12), ([-17, -14, -10, -5], -17),
        ([-16, -12, -9, -4], -16), ([-9, -5, -2, 3], -21),
        ([-14, -10, -7, -2], -14), ([-9, -5, -2, 3], -21)
    ]
    for i, (notes, bass) in enumerate(chords):
        b = i * 2.0
        # Stately harpsichord 8th notes with mordents
        s.add(b, 'harpsichord', notes[0] + 12, dur_beats=0.5, vel=0.8, pan=0.6)
        s.add(b + 0.5, 'harpsichord', notes[1] + 12, dur_beats=0.5, vel=0.7, pan=0.65)
        s.add(b + 1.0, 'harpsichord', notes[2] + 12, dur_beats=0.5, vel=0.75, pan=0.6)
        s.add(b + 1.5, 'harpsichord', notes[3] + 12, dur_beats=0.5, vel=0.7, pan=0.65)
        # Lute accompaniment
        s.add(b + 0.5, 'lute', notes[1], dur_beats=0.8, vel=0.6, pan=0.35)
        s.add(b + 1.5, 'lute', notes[2], dur_beats=0.8, vel=0.6, pan=0.35)
        # Basso continuo
        s.add(b, 'pizz_bass', bass, dur_beats=1.8, vel=0.85, pan=0.5)

    # Regal flute fanfare
    fanfare = [
        (0.0, 3, 0.75), (0.75, 7, 0.75), (1.5, 12, 1.5),
        (4.0, 10, 0.75), (4.75, 7, 0.75), (5.5, 8, 1.5),
        (8.0, 5, 0.75), (8.75, 8, 0.75), (9.5, 12, 1.5),
        (12.0, 10, 1.0), (13.0, 7, 1.0), (14.0, 15, 2.0)
    ]
    for b, p, d in fanfare:
        s.add(b, 'flute', p, dur_beats=d, vel=0.85, pan=0.4)
    return s

# 3. Warlock Dungeon (Башня Чернокнижника)
def comp_homm2_03():
    # E minor, BPM 96, 16 beats. Fast cascades & deep pizzicato
    s = Score(bpm=96.0, beats_total=16.0)
    chords = [
        ([-17, -14, -10, -5], -17), ([-12, -9, -5, 0], -12),
        ([-10, -7, -3, 2], -10), ([-17, -14, -10, -5], -17),
        ([-16, -12, -9, -4], -16), ([-12, -9, -5, 0], -12),
        ([-10, -7, -3, 2], -10), ([-17, -14, -10, -5], -17)
    ]
    for bar_idx, (arp, bass) in enumerate(chords):
        base_b = bar_idx * 2.0
        # Descending fast harpsichord 16ths
        desc = list(reversed(arp)) + arp
        for step in range(8):
            n = desc[step % len(desc)] + 12
            s.add(base_b + step * 0.25, 'harpsichord', n, dur_beats=0.35, vel=0.7, pan=0.6)
        s.add(base_b, 'pizz_bass', bass, dur_beats=1.8, vel=0.9, pan=0.45)
        # Chime on downbeat
        s.add(base_b, 'fairy_bells', bass + 36, dur_beats=2.0, vel=0.6, pan=0.3)
    return s

# 4. Wizard Academy (Академия Магов)
def comp_homm2_04():
    # 3/4 time, 8 bars = 24 beats, BPM 120. Am -> G -> F -> E7 passacaglia
    s = Score(bpm=120.0, beats_total=24.0)
    prog = [
        ([-12, -9, -5, 0], -12), ([-14, -10, -7, -2], -14),
        ([-16, -12, -9, -4], -16), ([-17, -14, -10, -5], -17),
        ([-12, -9, -5, 0], -12), ([-9, -5, -2, 3], -9),
        ([-10, -7, -3, 2], -10), ([-12, -9, -5, 0], -12)
    ]
    for i, (arp, bass) in enumerate(prog):
        b = i * 3.0
        # Flowing 3-beat arpeggiation (6 eighth notes)
        for step in range(6):
            n = arp[step % len(arp)] + 12
            s.add(b + step * 0.5, 'harpsichord', n, dur_beats=0.6, vel=0.7, pan=0.55)
        s.add(b, 'pizz_bass', bass, dur_beats=2.5, vel=0.8, pan=0.45)
        # Music box bells
        s.add(b, 'fairy_bells', arp[2] + 24, dur_beats=1.5, vel=0.5, pan=0.7)
    return s

# 5. Baroque Gavotte (Придворный Гавот)
def comp_homm2_05():
    # D major, BPM 114, 16 beats. Crisp bouncy dance
    s = Score(bpm=114.0, beats_total=16.0)
    d_major_chords = [
        ([-7, -3, 0, 5], -19), ([-14, -10, -7, -2], -14),
        ([-10, -7, -3, 2], -10), ([-16, -12, -9, -4], -16),
        ([-14, -10, -7, -2], -14), ([-7, -3, 0, 5], -19),
        ([-12, -9, -5, 0], -12), ([-7, -3, 0, 5], -19)
    ]
    for i, (notes, bass) in enumerate(d_major_chords):
        b = i * 2.0
        # Staccato gavotte jump
        s.add(b, 'harpsichord', notes[0] + 12, dur_beats=0.35, vel=0.75, pan=0.6)
        s.add(b + 0.5, 'harpsichord', notes[2] + 12, dur_beats=0.35, vel=0.75, pan=0.6)
        s.add(b + 1.0, 'harpsichord', notes[1] + 12, dur_beats=0.35, vel=0.75, pan=0.6)
        s.add(b + 1.5, 'harpsichord', notes[3] + 12, dur_beats=0.35, vel=0.75, pan=0.6)
        s.add(b, 'pizz_bass', bass, dur_beats=0.8, vel=0.8, pan=0.4)
        s.add(b + 1.0, 'pizz_bass', bass + 7, dur_beats=0.8, vel=0.7, pan=0.4)
    # Flute playful answers
    fl_notes = [(0.0, 5, 0.8), (1.0, 9, 0.8), (2.0, 7, 1.5), (4.0, 9, 0.8), (5.0, 12, 0.8), (6.0, 10, 1.5),
                (8.0, 12, 0.8), (9.0, 10, 0.8), (10.0, 9, 0.8), (11.0, 7, 0.8), (12.0, 5, 1.0), (14.0, 5, 2.0)]
    for b, p, d in fl_notes:
        s.add(b, 'flute', p, dur_beats=d, vel=0.8, pan=0.45)
    return s

# 6. Fairytale Minuet (Сказочный Менуэт)
def comp_homm2_06():
    # G major, 3/4 time, 8 bars = 24 beats, BPM 116
    s = Score(bpm=116.0, beats_total=24.0)
    chords = [
        ([-14, -10, -7, -2], -14), ([-7, -3, 0, 5], -19),
        ([-17, -14, -10, -5], -17), ([-10, -7, -3, 2], -10),
        ([-9, -5, -2, 3], -21), ([-14, -10, -7, -2], -14),
        ([-7, -3, 0, 5], -19), ([-14, -10, -7, -2], -14)
    ]
    for i, (arp, bass) in enumerate(chords):
        b = i * 3.0
        # Beat 1 bass, beats 2 and 3 chords
        s.add(b, 'pizz_bass', bass, dur_beats=2.0, vel=0.85, pan=0.5)
        s.add(b + 1.0, 'harpsichord', arp[1] + 12, dur_beats=0.8, vel=0.65, pan=0.6)
        s.add(b + 2.0, 'harpsichord', arp[2] + 12, dur_beats=0.8, vel=0.65, pan=0.65)
        # Lute gentle pluck
        s.add(b + 1.0, 'lute', arp[0], dur_beats=1.2, vel=0.6, pan=0.35)
    # Singing melody
    m_notes = [
        (0.0, 10, 1.8), (2.0, 12, 0.8), (3.0, 14, 1.8), (5.0, 10, 0.8),
        (6.0, 7, 1.8), (8.0, 9, 0.8), (9.0, 10, 2.8),
        (12.0, 12, 1.8), (14.0, 14, 0.8), (15.0, 15, 1.8), (17.0, 14, 0.8),
        (18.0, 12, 1.0), (19.0, 10, 1.0), (20.0, 9, 1.0), (21.0, 10, 2.5)
    ]
    for b, p, d in m_notes:
        s.add(b, 'harpsichord', p, dur_beats=d, vel=0.85, pan=0.5)
        s.add(b, 'fairy_bells', p + 12, dur_beats=d, vel=0.35, pan=0.7)
    return s

# 7. Enchanted Fountain (Зачарованный Фонтан)
def comp_homm2_07():
    # Bb major, BPM 122, 16 beats. Flowing 16th-note cascades
    s = Score(bpm=122.0, beats_total=16.0)
    chords = [
        ([-7, -2, 2, 5], -19), ([-4, 0, 3, 8], -16),
        ([-5, -2, 2, 7], -17), ([-7, -3, 0, 5], -19),
        ([-8, -3, 0, 5], -20), ([-7, -2, 2, 5], -19),
        ([-4, 0, 3, 8], -16), ([-7, -2, 2, 5], -19)
    ]
    for i, (arp, bass) in enumerate(chords):
        b = i * 2.0
        # Continuous rolling 16ths
        for step in range(8):
            n = arp[step % len(arp)] + 12
            s.add(b + step * 0.25, 'harpsichord', n, dur_beats=0.35, vel=0.65, pan=0.55 + 0.15 * math.sin(step))
        s.add(b, 'pizz_bass', bass, dur_beats=1.8, vel=0.8, pan=0.45)
        s.add(b, 'fairy_bells', arp[0] + 24, dur_beats=1.5, vel=0.5, pan=0.75)
    return s

# 8. Harpsichord Invention (Двухголосная Инвенция)
def comp_homm2_08():
    # D minor, BPM 108, 16 beats. Pure 2-voice Bach counterpoint
    s = Score(bpm=108.0, beats_total=16.0)
    # Right hand subject
    rh = [
        (0.0, 5), (0.5, 7), (1.0, 8), (1.5, 10), (2.0, 12), (2.5, 8), (3.0, 5), (3.5, 4),
        (4.0, 5), (4.5, 8), (5.0, 12), (5.5, 10), (6.0, 8), (6.5, 7), (7.0, 5), (7.5, 4),
        (8.0, 8), (8.5, 10), (9.0, 12), (9.5, 14), (10.0, 15), (10.5, 12), (11.0, 8), (11.5, 7),
        (12.0, 8), (12.5, 5), (13.0, 4), (13.5, 5), (14.0, 7), (14.5, 4), (15.0, 5), (15.5, 5)
    ]
    for b, p in rh:
        s.add(b, 'harpsichord', p, dur_beats=0.5, vel=0.75, pan=0.65)

    # Left hand answer (entered 2 beats later at lower octave)
    lh = [
        (2.0, -7), (2.5, -5), (3.0, -4), (3.5, -2), (4.0, 0), (4.5, -4), (5.0, -7), (5.5, -8),
        (6.0, -7), (6.5, -4), (7.0, 0), (7.5, -2), (8.0, -4), (8.5, -5), (9.0, -7), (9.5, -8),
        (10.0, -4), (10.5, -2), (11.0, 0), (11.5, 2), (12.0, 3), (12.5, 0), (13.0, -4), (13.5, -5),
        (14.0, -7), (14.5, -12), (15.0, -7), (15.5, -7)
    ]
    for b, p in lh:
        s.add(b, 'harpsichord', p, dur_beats=0.5, vel=0.75, pan=0.35)
        s.add(b, 'pizz_bass', p - 12, dur_beats=0.6, vel=0.5, pan=0.35)
    return s

# 9. Court Jester Gigue (Шут при Дворе — Жига)
def comp_homm2_09():
    # 6/8 meter, BPM 132, 16 beats. Playful leaping dance
    s = Score(bpm=132.0, beats_total=16.0)
    chords = [
        ([-4, 0, 3, 8], -16), ([-9, -5, -2, 3], -21),
        ([-7, -3, 0, 5], -19), ([-7, -2, 2, 5], -19),
        ([-4, 0, 3, 8], -16), ([-9, -5, -2, 3], -21),
        ([-7, -2, 2, 5], -19), ([-4, 0, 3, 8], -16)
    ]
    for i, (notes, bass) in enumerate(chords):
        b = i * 2.0
        # Triplet 8ths
        s.add(b, 'harpsichord', notes[0] + 12, dur_beats=0.3, vel=0.8, pan=0.6)
        s.add(b + 0.33, 'harpsichord', notes[2] + 12, dur_beats=0.3, vel=0.7, pan=0.65)
        s.add(b + 0.66, 'harpsichord', notes[1] + 12, dur_beats=0.3, vel=0.7, pan=0.6)
        s.add(b + 1.0, 'harpsichord', notes[3] + 12, dur_beats=0.3, vel=0.8, pan=0.65)
        s.add(b + 1.33, 'harpsichord', notes[2] + 12, dur_beats=0.3, vel=0.7, pan=0.6)
        s.add(b + 1.66, 'harpsichord', notes[1] + 12, dur_beats=0.3, vel=0.7, pan=0.65)
        s.add(b, 'pizz_bass', bass, dur_beats=0.9, vel=0.85, pan=0.45)
        s.add(b + 1.0, 'lute', notes[0], dur_beats=0.8, vel=0.7, pan=0.35)
    return s

# 10. Princess Pavane (Павана Принцессы)
def comp_homm2_10():
    # F major, BPM 84, 16 beats. Stately, elegant processional
    s = Score(bpm=84.0, beats_total=16.0)
    chords = [
        ([-4, 0, 3, 8], -16), ([-7, -2, 2, 5], -19),
        ([-9, -5, -2, 3], -21), ([-7, -3, 0, 5], -19),
        ([-5, -2, 2, 7], -17), ([-9, -5, -2, 3], -21),
        ([-7, -2, 2, 5], -19), ([-4, 0, 3, 8], -16)
    ]
    for i, (notes, bass) in enumerate(chords):
        b = i * 2.0
        s.add(b, 'pizz_bass', bass, dur_beats=1.8, vel=0.8, pan=0.5)
        s.add(b + 0.5, 'lute', notes[1], dur_beats=1.0, vel=0.65, pan=0.35)
        s.add(b + 1.0, 'harpsichord', notes[2] + 12, dur_beats=0.8, vel=0.7, pan=0.6)
        s.add(b + 1.5, 'harpsichord', notes[0] + 12, dur_beats=0.8, vel=0.65, pan=0.65)
    # Flute melody
    fl_notes = [(0.0, 8, 1.8), (2.0, 10, 1.8), (4.0, 12, 1.8), (6.0, 10, 1.8),
                (8.0, 7, 1.8), (10.0, 8, 1.8), (12.0, 10, 1.8), (14.0, 8, 2.0)]
    for b, p, d in fl_notes:
        s.add(b, 'flute', p, dur_beats=d, vel=0.85, pan=0.45)
    return s

# 11. Alchemist Laboratory (Лаборатория Алхимика)
def comp_homm2_11():
    # B minor, BPM 96, 16 beats. Mysterious chromatic motifs & bells
    s = Score(bpm=96.0, beats_total=16.0)
    chords = [
        ([-10, -7, -3, 2], -10), ([-11, -7, -4, 1], -11),
        ([-12, -8, -5, 0], -12), ([-10, -7, -3, 2], -10),
        ([-14, -10, -7, -2], -14), ([-12, -8, -5, 0], -12),
        ([-11, -7, -4, 1], -11), ([-10, -7, -3, 2], -10)
    ]
    for i, (notes, bass) in enumerate(chords):
        b = i * 2.0
        for step in range(8):
            n = notes[step % len(notes)] + 12
            s.add(b + step * 0.25, 'harpsichord', n, dur_beats=0.35, vel=0.65, pan=0.6)
        s.add(b, 'organ', bass, dur_beats=1.8, vel=0.6, pan=0.4)
        s.add(b, 'fairy_bells', notes[-1] + 24, dur_beats=1.8, vel=0.55, pan=0.7)
    return s

# 12. Druid Grove (Священная Роща Друидов)
def comp_homm2_12():
    # E Dorian, BPM 108, 16 beats. Ancient Celtic pastoral
    s = Score(bpm=108.0, beats_total=16.0)
    chords = [
        ([-17, -14, -10, -5], -17), ([-14, -10, -7, -2], -14),
        ([-12, -9, -5, 0], -12), ([-10, -7, -3, 2], -10),
        ([-17, -14, -10, -5], -17), ([-12, -9, -5, 0], -12),
        ([-10, -7, -3, 2], -10), ([-17, -14, -10, -5], -17)
    ]
    for i, (notes, bass) in enumerate(chords):
        b = i * 2.0
        for step in range(4):
            s.add(b + step * 0.5, 'harpsichord', notes[step] + 12, dur_beats=0.6, vel=0.7, pan=0.55)
        s.add(b, 'pizz_bass', bass, dur_beats=1.8, vel=0.8, pan=0.4)
    # Lyrical flute
    fl_notes = [(0.0, 7, 1.5), (1.5, 9, 0.5), (2.0, 10, 1.5), (3.5, 12, 0.5),
                (4.0, 14, 1.5), (5.5, 12, 0.5), (6.0, 10, 2.0),
                (8.0, 7, 1.5), (9.5, 9, 0.5), (10.0, 10, 1.5), (11.5, 7, 0.5),
                (12.0, 5, 1.5), (13.5, 2, 0.5), (14.0, 7, 2.0)]
    for b, p, d in fl_notes:
        s.add(b, 'flute', p, dur_beats=d, vel=0.85, pan=0.45)
    return s

# 13. Troubadour Serenade (Серенада Трубадура)
def comp_homm2_13():
    # A major, 3/4 time, 24 beats, BPM 116. Plucked romantic melody
    s = Score(bpm=116.0, beats_total=24.0)
    chords = [
        ([-12, -8, -5, 0], -12), ([-17, -13, -10, -5], -17),
        ([-15, -12, -8, -3], -15), ([-19, -16, -12, -7], -19),
        ([-16, -12, -9, -4], -16), ([-12, -8, -5, 0], -12),
        ([-17, -13, -10, -5], -17), ([-12, -8, -5, 0], -12)
    ]
    for i, (notes, bass) in enumerate(chords):
        b = i * 3.0
        s.add(b, 'lute', bass, dur_beats=2.5, vel=0.85, pan=0.4)
        s.add(b + 1.0, 'harpsichord', notes[1] + 12, dur_beats=0.8, vel=0.65, pan=0.6)
        s.add(b + 2.0, 'harpsichord', notes[2] + 12, dur_beats=0.8, vel=0.65, pan=0.65)
    # Melodic voice
    melody = [(0.0, 12, 1.8), (2.0, 14, 0.8), (3.0, 16, 1.8), (5.0, 12, 0.8),
              (6.0, 9, 1.8), (8.0, 11, 0.8), (9.0, 12, 2.8),
              (12.0, 14, 1.8), (14.0, 16, 0.8), (15.0, 17, 1.8), (17.0, 16, 0.8),
              (18.0, 14, 1.0), (19.0, 12, 1.0), (20.0, 11, 1.0), (21.0, 12, 2.5)]
    for b, p, d in melody:
        s.add(b, 'harpsichord', p, dur_beats=d, vel=0.85, pan=0.55)
    return s

# 14. Magic Music Box (Волшебная Шкатулка)
def comp_homm2_14():
    # C major, 3/4 time, 24 beats, BPM 138. Spinet & celesta
    s = Score(bpm=138.0, beats_total=24.0)
    chords = [
        ([-9, -5, -2, 3], -21), ([-14, -10, -7, -2], -14),
        ([-12, -9, -5, 0], -12), ([-17, -14, -10, -5], -17),
        ([-16, -12, -9, -4], -16), ([-9, -5, -2, 3], -21),
        ([-14, -10, -7, -2], -14), ([-9, -5, -2, 3], -21)
    ]
    for i, (notes, bass) in enumerate(chords):
        b = i * 3.0
        for step in range(3):
            s.add(b + step, 'spinet', notes[step] + 24, dur_beats=0.6, vel=0.7, pan=0.55 + 0.15 * math.sin(step))
            s.add(b + step, 'fairy_bells', notes[step] + 24, dur_beats=0.6, vel=0.45, pan=0.65)
        s.add(b, 'pizz_bass', bass + 12, dur_beats=2.0, vel=0.7, pan=0.4)
    return s

# 15. Royal Cembalo March (Королевский Чембало-Марш)
def comp_homm2_15():
    # D major, BPM 112, 16 beats. Festive full chords & fanfares
    s = Score(bpm=112.0, beats_total=16.0)
    chords = [
        ([-7, -3, 0, 5], -19), ([-14, -10, -7, -2], -14),
        ([-12, -8, -5, 0], -12), ([-7, -3, 0, 5], -19),
        ([-10, -7, -3, 2], -10), ([-17, -14, -10, -5], -17),
        ([-12, -8, -5, 0], -12), ([-7, -3, 0, 5], -19)
    ]
    for i, (notes, bass) in enumerate(chords):
        b = i * 2.0
        # Rolled full chord on beat 1
        s.add(b, 'harpsichord', notes[0] + 12, dur_beats=0.8, vel=0.85, pan=0.5)
        s.add(b + 0.05, 'harpsichord', notes[1] + 12, dur_beats=0.8, vel=0.8, pan=0.55)
        s.add(b + 0.10, 'harpsichord', notes[2] + 12, dur_beats=0.8, vel=0.8, pan=0.6)
        s.add(b + 0.15, 'harpsichord', notes[3] + 12, dur_beats=0.8, vel=0.85, pan=0.65)
        # Rhythmic 8ths
        s.add(b + 1.0, 'harpsichord', notes[1] + 12, dur_beats=0.4, vel=0.75, pan=0.6)
        s.add(b + 1.5, 'harpsichord', notes[2] + 12, dur_beats=0.4, vel=0.75, pan=0.65)
        s.add(b, 'pizz_bass', bass, dur_beats=1.8, vel=0.9, pan=0.4)
    return s

# 16. Pastoral Dawn (Пасторальный Рассвет)
def comp_homm2_16():
    # G major, BPM 92, 16 beats. Awakening morning birdsong & harpsichord
    s = Score(bpm=92.0, beats_total=16.0)
    chords = [
        ([-14, -10, -7, -2], -14), ([-9, -5, -2, 3], -21),
        ([-7, -3, 0, 5], -19), ([-17, -14, -10, -5], -17),
        ([-9, -5, -2, 3], -21), ([-12, -9, -5, 0], -12),
        ([-7, -3, 0, 5], -19), ([-14, -10, -7, -2], -14)
    ]
    for i, (notes, bass) in enumerate(chords):
        b = i * 2.0
        for step in range(4):
            s.add(b + step * 0.5, 'harpsichord', notes[step] + 12, dur_beats=0.6, vel=0.65, pan=0.6)
        s.add(b, 'lute', bass, dur_beats=1.8, vel=0.75, pan=0.4)
    # Bird trills on flute
    trills = [(0.0, 10, 0.8), (0.8, 12, 0.4), (1.2, 10, 0.4), (1.6, 14, 1.2),
              (4.0, 12, 0.8), (4.8, 14, 0.4), (5.2, 12, 0.4), (5.6, 15, 1.2),
              (8.0, 14, 0.8), (8.8, 12, 0.4), (9.2, 10, 0.4), (9.6, 9, 1.2),
              (12.0, 10, 1.0), (13.0, 7, 1.0), (14.0, 10, 2.0)]
    for b, p, d in trills:
        s.add(b, 'flute', p, dur_beats=d, vel=0.8, pan=0.45)
    return s

# 17. Clavier Fughetta (Клавирная Фугетта)
def comp_homm2_17():
    # C minor, BPM 100, 16 beats. Solemn classical counterpoint
    s = Score(bpm=100.0, beats_total=16.0)
    # Subject: C - Eb - G - F - Eb - D - C - B
    # Voice 1 enters at 0
    v1 = [(0.0, 3), (0.5, 6), (1.0, 10), (1.5, 8), (2.0, 6), (2.5, 5), (3.0, 3), (3.5, 2),
          (4.0, 3), (4.5, 6), (5.0, 10), (5.5, 8), (6.0, 6), (6.5, 5), (7.0, 3), (7.5, 2),
          (8.0, 6), (8.5, 8), (9.0, 10), (9.5, 11), (10.0, 13), (10.5, 10), (11.0, 6), (11.5, 5),
          (12.0, 6), (12.5, 3), (13.0, 2), (13.5, 3), (14.0, 5), (14.5, 2), (15.0, 3), (15.5, 3)]
    for b, p in v1:
        s.add(b, 'harpsichord', p, dur_beats=0.5, vel=0.75, pan=0.65)
    # Voice 2 enters at 2
    v2 = [(2.0, -9), (2.5, -6), (3.0, -2), (3.5, -4), (4.0, -6), (4.5, -7), (5.0, -9), (5.5, -10),
          (6.0, -9), (6.5, -6), (7.0, -2), (7.5, -4), (8.0, -6), (8.5, -7), (9.0, -9), (9.5, -10),
          (10.0, -6), (10.5, -4), (11.0, -2), (11.5, -1), (12.0, 1), (12.5, -2), (13.0, -6), (13.5, -7),
          (14.0, -9), (14.5, -14), (15.0, -9), (15.5, -9)]
    for b, p in v2:
        s.add(b, 'harpsichord', p, dur_beats=0.5, vel=0.75, pan=0.35)
        s.add(b, 'pizz_bass', p - 12, dur_beats=0.6, vel=0.5, pan=0.35)
    return s

# 18. Crystal Spinet (Хрустальный Спинет)
def comp_homm2_18():
    # E major, BPM 128, 16 beats. Fast Scarlatti toccata
    s = Score(bpm=128.0, beats_total=16.0)
    chords = [
        ([-17, -13, -10, -5], -17), ([-12, -8, -5, 0], -12),
        ([-10, -6, -3, 2], -10), ([-17, -13, -10, -5], -17),
        ([-15, -12, -8, -3], -15), ([-13, -10, -6, -1], -13),
        ([-10, -6, -3, 2], -10), ([-17, -13, -10, -5], -17)
    ]
    for i, (notes, bass) in enumerate(chords):
        b = i * 2.0
        # Rapid 16th toccata repeated notes
        for step in range(8):
            n = notes[step % len(notes)] + 12
            s.add(b + step * 0.25, 'spinet', n, dur_beats=0.35, vel=0.7, pan=0.6)
        s.add(b, 'pizz_bass', bass, dur_beats=1.8, vel=0.8, pan=0.4)
        s.add(b, 'fairy_bells', notes[0] + 24, dur_beats=1.5, vel=0.45, pan=0.75)
    return s

# 19. Archers Pavilion (Шатёр Лесных Лучников)
def comp_homm2_19():
    # A minor, BPM 114, 16 beats. Agile staccato rhythms
    s = Score(bpm=114.0, beats_total=16.0)
    chords = [
        ([-12, -9, -5, 0], -12), ([-14, -10, -7, -2], -14),
        ([-16, -12, -9, -4], -16), ([-17, -13, -10, -5], -17),
        ([-12, -9, -5, 0], -12), ([-16, -12, -9, -4], -16),
        ([-17, -13, -10, -5], -17), ([-12, -9, -5, 0], -12)
    ]
    for i, (notes, bass) in enumerate(chords):
        b = i * 2.0
        # Snappy staccato chords
        s.add(b, 'harpsichord', notes[0] + 12, dur_beats=0.4, vel=0.75, pan=0.6)
        s.add(b + 0.5, 'harpsichord', notes[1] + 12, dur_beats=0.4, vel=0.75, pan=0.6)
        s.add(b + 1.0, 'harpsichord', notes[2] + 12, dur_beats=0.4, vel=0.75, pan=0.6)
        s.add(b + 1.5, 'harpsichord', notes[3] + 12, dur_beats=0.4, vel=0.75, pan=0.6)
        s.add(b, 'pizz_bass', bass, dur_beats=0.9, vel=0.85, pan=0.45)
        s.add(b + 1.0, 'pizz_bass', bass + 7, dur_beats=0.9, vel=0.75, pan=0.45)
    # Nimble flute
    fl = [(0.0, 12, 0.5), (0.5, 14, 0.5), (1.0, 15, 0.5), (1.5, 12, 0.5), (2.0, 10, 1.5),
          (4.0, 8, 0.5), (4.5, 10, 0.5), (5.0, 12, 0.5), (5.5, 8, 0.5), (6.0, 7, 1.5),
          (8.0, 12, 0.5), (8.5, 14, 0.5), (9.0, 15, 0.5), (9.5, 12, 0.5), (10.0, 10, 1.5),
          (12.0, 8, 0.5), (12.5, 7, 0.5), (13.0, 5, 0.5), (13.5, 4, 0.5), (14.0, 0, 2.0)]
    for b, p, d in fl:
        s.add(b, 'flute', p, dur_beats=d, vel=0.85, pan=0.4)
    return s

# 20. Archmage Fantasia (Фантазия Верховного Мага)
def comp_homm2_20():
    # D minor, BPM 96, 16 beats. Dramatic Baroque climax with Picardy 3rd
    s = Score(bpm=96.0, beats_total=16.0)
    chords = [
        ([-7, -3, 0, 5], -19),    # Dm
        ([-8, -5, -1, 4], -12),   # A7
        ([-7, -3, 0, 5], -19),    # Dm
        ([-5, -2, 2, 7], -17),    # Gm
        ([-9, -5, -2, 3], -21),   # C
        ([-4, 0, 3, 8], -16),     # F
        ([-8, -5, -1, 4], -12),   # A7
        ([-7, -2, 2, 5], -19)     # D major (Picardy Third! F# = -2)
    ]
    for i, (arp, bass) in enumerate(chords):
        b = i * 2.0
        for step in range(8):
            n = arp[step % len(arp)] + 12
            s.add(b + step * 0.25, 'harpsichord', n, dur_beats=0.35, vel=0.75, pan=0.55 + 0.15 * math.sin(step))
        s.add(b, 'organ', bass, dur_beats=1.8, vel=0.7, pan=0.45)
        s.add(b, 'pizz_bass', bass, dur_beats=1.5, vel=0.85, pan=0.45)
    return s

HOMM2_COMPOSITIONS = [
    ("homm2_01_sorceress_garden.wav", comp_homm2_01),
    ("homm2_02_knight_castle.wav", comp_homm2_02),
    ("homm2_03_warlock_dungeon.wav", comp_homm2_03),
    ("homm2_04_wizard_academy.wav", comp_homm2_04),
    ("homm2_05_baroque_gavotte.wav", comp_homm2_05),
    ("homm2_06_fairytale_minuet.wav", comp_homm2_06),
    ("homm2_07_enchanted_fountain.wav", comp_homm2_07),
    ("homm2_08_harpsichord_invention.wav", comp_homm2_08),
    ("homm2_09_court_jester_gigue.wav", comp_homm2_09),
    ("homm2_10_princess_pavane.wav", comp_homm2_10),
    ("homm2_11_alchemist_laboratory.wav", comp_homm2_11),
    ("homm2_12_druid_grove.wav", comp_homm2_12),
    ("homm2_13_troubadour_serenade.wav", comp_homm2_13),
    ("homm2_14_magic_music_box.wav", comp_homm2_14),
    ("homm2_15_royal_cembalo_march.wav", comp_homm2_15),
    ("homm2_16_pastoral_dawn.wav", comp_homm2_16),
    ("homm2_17_clavier_fughetta.wav", comp_homm2_17),
    ("homm2_18_crystal_spinet.wav", comp_homm2_18),
    ("homm2_19_archers_pavilion.wav", comp_homm2_19),
    ("homm2_20_archmage_fantasia.wav", comp_homm2_20)
]

def render_worker(item):
    filename, comp_func = item
    out_dir = "assets/audio/music/themes"
    filepath = os.path.join(out_dir, filename)
    score = comp_func()
    buf_l, buf_r = score.render()
    write_stereo_wav(filepath, buf_l, buf_r)
    return filename

if __name__ == '__main__':
    out_dir = "assets/audio/music/themes"
    os.makedirs(out_dir, exist_ok=True)
    with Pool() as pool:
        results = pool.map(render_worker, HOMM2_COMPOSITIONS)
    print(f"Successfully generated all {len(results)} HoMM 2 themes!")

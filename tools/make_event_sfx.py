"""Звуки событий и стихий заклинаний: поражение, новый уровень, огонь, молния,
исцеление, мороз, защита, скорость. Чистый Python (как make_clean_sfx.py),
фиксированный seed — повторный запуск даёт те же файлы.

    python tools/make_event_sfx.py
"""
import math
import os
import random
import struct
import wave

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SFX_DIR = os.path.join(BASE_DIR, "assets", "audio", "sfx")
SR = 44100


def write_wav(filename, samples, peak=0.8):
    # без постоянной составляющей и щелчка на обрыве: DC-фильтр и затухание последних 30 мс
    y_prev = x_prev = 0.0
    clean = []
    for x in samples:
        y_prev = x - x_prev + 0.995 * y_prev
        x_prev = x
        clean.append(y_prev)
    tail = int(SR * 0.03)
    for i in range(min(tail, len(clean))):
        clean[-1 - i] *= i / tail
    samples = clean
    top = max(1e-9, max(abs(s) for s in samples))
    k = peak / top
    path = os.path.join(SFX_DIR, filename)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * k)) * 32767)) for s in samples))
    print("Generated", filename, "%.2fs" % (len(samples) / SR))


def silence(seconds):
    return [0.0] * int(SR * seconds)


def mix_in(buf, start_sec, part, gain=1.0):
    i0 = int(start_sec * SR)
    for i, s in enumerate(part):
        if i0 + i < len(buf):
            buf[i0 + i] += s * gain


def pluck(freq, seconds, damping=0.996, brightness=0.5):
    """Щипок струны (Карплус-Стронг): лютня/клавесин."""
    period = max(2, int(SR / freq))
    line = [random.uniform(-1.0, 1.0) for _ in range(period)]
    mean = sum(line) / period
    line = [v - mean for v in line]  # возбуждение без постоянной составляющей
    out = []
    prev = 0.0
    for i in range(int(SR * seconds)):
        cur = line[i % period]
        avg = damping * (brightness * cur + (1.0 - brightness) * prev)
        line[i % period] = avg
        prev = cur
        out.append(cur)
    # мягкая атака, чтобы не щёлкало
    for i in range(min(200, len(out))):
        out[i] *= i / 200.0
    return out


def bell(freq, seconds, decay=4.0, partials=((1.0, 1.0), (2.76, 0.45), (5.4, 0.2), (8.93, 0.08))):
    """Колокольчик: неровные обертоны с экспоненциальным затуханием."""
    out = []
    for i in range(int(SR * seconds)):
        t = i / SR
        s = 0.0
        for ratio, amp in partials:
            s += amp * math.sin(2 * math.pi * freq * ratio * t) * math.exp(-t * decay * ratio ** 0.5)
        out.append(s * min(1.0, t / 0.004))
    return out


def lowpass(samples, cutoffs):
    """Однополюсный фильтр нижних частот; cutoffs — частота среза для каждого сэмпла."""
    out = []
    y = 0.0
    for s, fc in zip(samples, cutoffs):
        a = 1.0 - math.exp(-2 * math.pi * fc / SR)
        y += a * (s - y)
        out.append(y)
    return out


def noise(seconds):
    return [random.uniform(-1.0, 1.0) for _ in range(int(SR * seconds))]


def defeat():
    # Грустная, но уютная нисходящая фраза лютни: без мрака
    random.seed(11)
    buf = silence(1.9)
    for start, f, dur, g in [(0.0, 440.0, 0.8, 0.9), (0.26, 349.23, 0.8, 0.85), (0.52, 293.66, 0.9, 0.85), (0.86, 220.0, 1.0, 1.0)]:
        mix_in(buf, start, pluck(f, dur, damping=0.995, brightness=0.45), g)
    # тихий бас под последней нотой
    for i in range(int(SR * 1.0)):
        t = i / SR
        buf[int(0.86 * SR) + i] += 0.25 * math.sin(2 * math.pi * 110.0 * t) * math.exp(-t * 2.5) * min(1.0, t / 0.05)
    write_wav("defeat.wav", buf, peak=0.7)


def level_up():
    random.seed(12)
    buf = silence(1.4)
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        mix_in(buf, 0.09 * k, bell(f, 1.0, decay=3.2), 0.5)
    # искорки сверху
    for k in range(6):
        f = random.uniform(2200.0, 3600.0)
        mix_in(buf, 0.3 + 0.07 * k, bell(f, 0.25, decay=14.0, partials=((1.0, 1.0),)), 0.12)
    write_wav("level_up.wav", buf, peak=0.7)


def fire_whoosh():
    random.seed(13)
    dur = 0.9
    n = noise(dur)
    cut = []
    for i in range(len(n)):
        t = i / SR
        # раскрытие пламени и затухание
        cut.append(300.0 + 2600.0 * math.sin(math.pi * min(1.0, t / dur)) ** 1.5)
    body = lowpass(n, cut)
    out = []
    for i, s in enumerate(body):
        t = i / SR
        env = min(1.0, t / 0.08) * math.exp(-max(0.0, t - 0.15) * 3.5)
        rumble = 0.35 * math.sin(2 * math.pi * (70.0 + 30.0 * t) * t)
        out.append((s * 1.6 + rumble) * env)
    write_wav("fire_whoosh.wav", out, peak=0.75)


def lightning():
    random.seed(14)
    dur = 1.2
    n = noise(dur)
    out = []
    prev = 0.0
    rumble_src = lowpass(noise(dur), [180.0] * int(SR * dur))
    for i in range(len(n)):
        t = i / SR
        # треск: высокочастотная разность шума в первые миллисекунды
        crack = (n[i] - prev) * math.exp(-t * 40.0)
        prev = n[i]
        rumble = rumble_src[i] * 6.0 * min(1.0, t / 0.04) * math.exp(-t * 2.2)
        low = 0.3 * math.sin(2 * math.pi * 48.0 * t) * math.exp(-t * 2.5)
        out.append(0.6 * crack + rumble + low)
    write_wav("lightning.wav", out, peak=0.8)


def heal_chime():
    random.seed(15)
    buf = silence(1.1)
    for k, f in enumerate([1318.5, 987.77, 1567.98]):
        mix_in(buf, 0.07 * k, bell(f, 0.9, decay=3.8), 0.4)
    # мягкое мерцание
    for i in range(len(buf)):
        t = i / SR
        buf[i] *= 0.85 + 0.15 * math.sin(2 * math.pi * 9.0 * t)
    write_wav("heal_chime.wav", buf, peak=0.6)


def frost():
    random.seed(16)
    buf = silence(0.8)
    for k in range(9):
        f = random.uniform(2500.0, 5200.0)
        mix_in(buf, random.uniform(0.0, 0.35), bell(f, 0.35, decay=9.0, partials=((1.0, 1.0), (2.4, 0.3))), 0.25)
    hiss = lowpass(noise(0.8), [5000.0] * int(SR * 0.8))
    for i in range(len(buf)):
        t = i / SR
        buf[i] += 0.12 * hiss[i] * math.exp(-t * 5.0)
    write_wav("frost.wav", buf, peak=0.6)


def ward():
    random.seed(17)
    dur = 0.85
    out = []
    phase = 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        f = 170.0 + 90.0 * min(1.0, t / 0.35)  # тёплый подъём «купола»
        phase += 2 * math.pi * f / SR
        env = min(1.0, t / 0.1) * math.exp(-max(0.0, t - 0.25) * 4.0)
        out.append((math.sin(phase) + 0.4 * math.sin(2 * phase) + 0.15 * math.sin(3 * phase)) * env)
    mix_in(out, 0.12, bell(880.0, 0.6, decay=5.0), 0.25)
    write_wav("ward.wav", out, peak=0.65)


def swift():
    random.seed(18)
    dur = 0.55
    n = noise(dur)
    cut = [400.0 + 5000.0 * (i / (SR * dur)) ** 1.3 for i in range(len(n))]
    air = lowpass(n, cut)
    out = []
    phase = 0.0
    for i, s in enumerate(air):
        t = i / SR
        phase += 2 * math.pi * (600.0 + 900.0 * t / dur) / SR
        env = math.sin(math.pi * t / dur)
        out.append((s * 1.3 + 0.15 * math.sin(phase)) * env)
    write_wav("swift.wav", out, peak=0.6)


if __name__ == "__main__":
    for make in (defeat, level_up, fire_whoosh, lightning, heal_chime, frost, ward, swift):
        make()

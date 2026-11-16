"""Synthesises the game's sound effects as small WAV files. Run: python3 tool/gen_sfx.py"""
import math, random, struct, wave

RATE = 22050

def env(i, n, attack=0.005, release=0.6):
    t = i / n
    a = min(1.0, i / max(1, attack * RATE))
    return a * (1 - t) ** (1 + release * 3)

def tone(freqs, dur, shape='sine', vol=0.5, slide=0.0, release=0.6):
    """freqs: one frequency or a list played in sequence. slide: fraction of pitch change over each note."""
    freqs = freqs if isinstance(freqs, list) else [freqs]
    out, per = [], int(RATE * dur / len(freqs))
    for f in freqs:
        phase = 0.0
        for i in range(per):
            fr = f * (1 + slide * i / per)
            phase += 2 * math.pi * fr / RATE
            s = math.sin(phase)
            if shape == 'square': s = 0.6 if s > 0 else -0.6
            if shape == 'tri': s = 2 / math.pi * math.asin(s)
            out.append(s * vol * env(i, per, release=release))
    return out

def noise(dur, vol=0.5, lowpass=0.3):
    out, last, n = [], 0.0, int(RATE * dur)
    rnd = random.Random(7)
    for i in range(n):
        last += lowpass * (rnd.uniform(-1, 1) - last)
        out.append(last * vol * env(i, n, release=0.8))
    return out

def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]

SOUNDS = {
    'tap': tone(520, 0.05, 'tri', 0.45, slide=-0.3),
    'correct': tone([660, 880, 1320], 0.28, 'tri', 0.5),
    'wrong': tone([220, 160], 0.3, 'square', 0.3, slide=-0.2),
    'coin': tone([1175, 1568], 0.16, 'square', 0.25),
    'powerup': tone([392, 523, 659, 784, 1047], 0.4, 'tri', 0.5),
    'levelUp': mix(tone([523, 659, 784, 1047, 1319, 1568], 0.7, 'tri', 0.45), tone([262, 330, 392, 523, 659, 784], 0.7, 'sine', 0.25)),
    'crash': mix(noise(0.4, 0.8, 0.15), tone(110, 0.35, 'square', 0.3, slide=-0.6)),
    'jump': tone(330, 0.14, 'tri', 0.45, slide=0.9),
    'drop': mix(tone(140, 0.12, 'sine', 0.7, slide=-0.5), noise(0.06, 0.3, 0.5)),
    'perfect': tone([880, 1175, 1760], 0.3, 'sine', 0.5),
    'merge': tone([440, 660], 0.14, 'tri', 0.5, slide=0.2),
    'swipe': noise(0.09, 0.35, 0.6),
    'win': tone([523, 659, 784, 659, 784, 1047], 0.75, 'square', 0.25),
    'lose': tone([392, 330, 262, 196], 0.6, 'tri', 0.45, slide=-0.1),
    'tick': tone(1000, 0.03, 'sine', 0.35),
}

for name, samples in SOUNDS.items():
    with wave.open(f'assets/sfx/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32000)) for s in samples))
print('wrote', len(SOUNDS), 'sounds')

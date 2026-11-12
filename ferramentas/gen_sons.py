# Sintetiza os efeitos sonoros do jogo (WAV 16 bits, 44,1 kHz). Uso: python3 gen_sons.py <saida>
import sys, os, wave, numpy as np

SR = 44100
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
rng = np.random.default_rng(3)


def t(d):
    return np.arange(int(SR * d)) / SR


def ruido(d):
    return rng.standard_normal(int(SR * d))


def banda(x, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    m = ((f >= lo) & (f <= hi)).astype(float)
    # bordas suaves
    m = np.convolve(m, np.ones(40) / 40, mode="same")
    return np.fft.irfft(X * m, n=len(x))


def env(n, a=0.005, d=0.2, forma=4.0):
    tt = np.arange(n) / SR
    e = np.minimum(1.0, tt / max(a, 1e-4)) * np.exp(-forma * np.maximum(0, tt - a) / max(d, 1e-4))
    return e


def varrer(d, f0, f1, onda="sin"):
    tt = t(d)
    f = f0 * (f1 / f0) ** (tt / d)
    fase = 2 * np.pi * np.cumsum(f) / SR
    if onda == "saw":
        return 2 * ((fase / (2 * np.pi)) % 1.0) - 1
    return np.sin(fase)


def norm(x, g=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * g


def reverb(x, tam=0.35, mix=0.25):
    n = int(SR * tam)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0, 6, n))
    ir = banda(ir, 200, 6000)
    w = np.convolve(x, ir)[: len(x) + n // 2]
    y = np.concatenate([x, np.zeros(len(w) - len(x))])
    return y + norm(w, np.max(np.abs(x)) * mix)


def salvar(nome, x, g=0.85):
    x = norm(x, g)
    fade = min(len(x), 400)
    x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(out, nome + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


# passo em pedra
x = banda(ruido(0.12), 80, 900) * env(int(SR * 0.12), 0.002, 0.03)
x += banda(ruido(0.12), 2000, 6000) * env(int(SR * 0.12), 0.001, 0.01) * 0.3
salvar("passo", x, 0.6)

# espada cortando o ar
n = ruido(0.28)
x = np.zeros_like(n)
seg = len(n) // 8
for i in range(8):
    lo = 600 + i * 350
    x[i * seg:(i + 1) * seg] = banda(n, lo, lo + 1800)[i * seg:(i + 1) * seg]
x *= np.sin(np.linspace(0, np.pi, len(x))) ** 1.5
salvar("espada", reverb(x, 0.2, 0.15), 0.7)

# impacto: baque + metal
d = 0.45
x = varrer(d, 140, 45) * env(int(SR * d), 0.002, 0.08) * 1.2
x += banda(ruido(d), 100, 2500) * env(int(SR * d), 0.001, 0.04)
for f, a in [(820, 0.25), (1310, 0.18), (2170, 0.12), (3020, 0.08)]:
    x += np.sin(2 * np.pi * f * t(d)) * env(int(SR * d), 0.001, 0.12) * a
salvar("impacto", reverb(x, 0.3, 0.2), 0.9)

# crítico
d = 0.7
x = varrer(d, 180, 38) * env(int(SR * d), 0.002, 0.12) * 1.4
x += banda(ruido(d), 80, 4000) * env(int(SR * d), 0.001, 0.06)
for f, a in [(1040, 0.3), (1560, 0.22), (2600, 0.18), (3900, 0.1)]:
    x += np.sin(2 * np.pi * f * t(d)) * env(int(SR * d), 0.001, 0.25) * a
salvar("critico", reverb(x, 0.45, 0.3), 0.95)

# giro (redemoinho)
d = 0.7
n = ruido(d)
x = banda(n, 300, 3500) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t(d))) * np.sin(np.linspace(0, np.pi, len(n)))
salvar("giro", reverb(x, 0.3, 0.2), 0.8)

# investida
d = 0.6
x = banda(ruido(d), 200, 2500) * np.sin(np.linspace(0, np.pi, int(SR * d))) ** 0.7
x += varrer(d, 90, 50) * env(int(SR * d), 0.05, 0.4) * 0.6
salvar("investida", x, 0.8)

# carga sagrada (sobe)
d = 0.55
x = varrer(d, 300, 1400) * 0.4 + varrer(d, 450, 2100) * 0.3
x += banda(ruido(d), 3000, 9000) * 0.25
x *= np.linspace(0.1, 1, len(x))
salvar("carga", reverb(x, 0.5, 0.35), 0.6)

# trovão
d = 1.8
x = banda(ruido(d), 40, 9000) * env(int(SR * d), 0.001, 0.05) * 1.5
x += banda(ruido(d), 30, 300) * env(int(SR * d), 0.02, 0.9, 3.0) * 1.2
x += varrer(d, 80, 30) * env(int(SR * d), 0.005, 0.6) * 0.8
salvar("trovao", reverb(x, 0.8, 0.35), 0.95)

# conjurar (cintilar mágico)
d = 0.8
tt = t(d)
x = np.sin(2 * np.pi * 520 * tt + 3 * np.sin(2 * np.pi * 7 * tt)) * 0.4
x += np.sin(2 * np.pi * 780 * tt + 2 * np.sin(2 * np.pi * 11 * tt)) * 0.3
x += banda(ruido(d), 4000, 10000) * 0.15
x *= np.sin(np.linspace(0, np.pi, len(x)))
salvar("conjurar", reverb(x, 0.6, 0.4), 0.55)

# bola de fogo
d = 0.7
x = banda(ruido(d), 150, 3000) * np.linspace(0.2, 1, int(SR * d)) * (0.7 + 0.3 * rng.random(int(SR * d)))
salvar("fogo", x, 0.7)

# explosão
d = 1.4
x = varrer(d, 110, 28) * env(int(SR * d), 0.003, 0.5) * 1.3
x += banda(ruido(d), 40, 5000) * env(int(SR * d), 0.002, 0.25)
x += banda(ruido(d), 30, 250) * env(int(SR * d), 0.01, 0.8, 3.0)
salvar("explosao", reverb(x, 0.7, 0.3), 0.95)

# rugido demoníaco
d = 1.6
tt = t(d)
f = 70 + 25 * np.sin(2 * np.pi * 3.5 * tt)
fase = 2 * np.pi * np.cumsum(f) / SR
x = np.sign(np.sin(fase)) * 0.5 + np.sin(fase * 2.01) * 0.4 + np.sin(fase * 3.3) * 0.2
x = banda(x + banda(ruido(d), 100, 1200) * 0.6, 50, 1800)
x *= env(int(SR * d), 0.15, 0.9, 2.5)
salvar("rugido", reverb(x, 0.9, 0.4), 0.95)

# portal
d = 1.2
x = varrer(d, 900, 120) * 0.4 + banda(ruido(d), 300, 2000) * 0.4
x *= np.sin(np.linspace(0, np.pi, int(SR * d)))
x += np.sin(2 * np.pi * 55 * t(d)) * 0.3 * np.sin(np.linspace(0, np.pi, int(SR * d)))
salvar("portal", reverb(x, 0.6, 0.3), 0.7)

# morte (ossos/queda)
d = 0.8
x = banda(ruido(d), 60, 600) * env(int(SR * d), 0.005, 0.25)
for k in range(9):
    i0 = int(rng.uniform(0.0, 0.45) * SR)
    seg = banda(ruido(0.05), 1500, 6000) * env(int(SR * 0.05), 0.001, 0.01)
    x[i0:i0 + len(seg)] += seg * rng.uniform(0.2, 0.5)
salvar("morte", reverb(x, 0.4, 0.3), 0.75)

# poção
d = 0.9
x = np.zeros(int(SR * d))
for k in range(5):
    i0 = int(k * 0.07 * SR)
    b = varrer(0.06, rng.uniform(300, 500), rng.uniform(700, 1100)) * env(int(SR * 0.06), 0.002, 0.03)
    x[i0:i0 + len(b)] += b * 0.5
for f, a in [(880, 0.3), (1320, 0.25), (1760, 0.2)]:
    x += np.sin(2 * np.pi * f * t(d)) * env(int(SR * d), 0.35, 0.4) * a
salvar("pocao", reverb(x, 0.6, 0.4), 0.6)

# porta de pedra afundando
d = 2.2
x = banda(ruido(d), 40, 400) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 6 * t(d)))) * np.sin(np.linspace(0, np.pi, int(SR * d))) ** 0.5
x += banda(ruido(d), 30, 120) * env(int(SR * d), 1.8, 0.2, 6) * 2.0
salvar("porta", reverb(x, 0.8, 0.3), 0.85)

# tambores de encontro
d = 1.6
x = np.zeros(int(SR * d))
for k, ti in enumerate([0.0, 0.32, 0.62]):
    i0 = int(ti * SR)
    b = varrer(0.6, 120, 48) * env(int(SR * 0.6), 0.003, 0.2) * (1.0 if k < 2 else 1.3)
    b += banda(ruido(0.6), 60, 900) * env(int(SR * 0.6), 0.001, 0.05) * 0.5
    x[i0:i0 + len(b)] += b[: len(x) - i0]
salvar("encontro", reverb(x, 1.0, 0.35), 0.9)

# vitória (acorde de metais)
d = 3.0
tt = t(d)
x = np.zeros_like(tt)
for f in [146.8, 220.0, 293.7, 370.0, 440.0]:
    fase = 2 * np.pi * f * tt
    x += (2 * ((fase / (2 * np.pi)) % 1.0) - 1) * 0.2
x = banda(x, 80, 2600) * env(len(tt), 0.4, 1.6, 2.0)
salvar("vitoria", reverb(x, 1.2, 0.4), 0.8)

# derrota (drone dissonante)
d = 3.0
tt = t(d)
x = np.sin(2 * np.pi * 55 * tt) * 0.5 + np.sin(2 * np.pi * 58.3 * tt) * 0.4 + np.sin(2 * np.pi * 82.4 * tt) * 0.3
x += banda(ruido(d), 40, 300) * 0.4
x *= env(len(tt), 0.3, 1.8, 2.0)
salvar("derrota", reverb(x, 1.2, 0.4), 0.8)

# baú abrindo
d = 1.4
x = np.zeros(int(SR * d))
rang = banda(ruido(0.5), 300, 1500) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * t(0.5)) ** 2) * np.sin(np.linspace(0, np.pi, int(SR * 0.5)))
x[: len(rang)] += rang
for f, a in [(523, 0.3), (659, 0.25), (784, 0.25), (1047, 0.2)]:
    x += np.sin(2 * np.pi * f * t(d)) * env(len(x), 0.5, 0.6) * a
salvar("bau", reverb(x, 0.8, 0.4), 0.7)

# drop lendário
d = 2.4
x = varrer(d, 90, 40) * env(int(SR * d), 0.003, 0.2) * 1.0
for f, a in [(392, 0.3), (587, 0.28), (784, 0.24), (1175, 0.18), (1568, 0.12)]:
    x += np.sin(2 * np.pi * f * t(d) + 0.6 * np.sin(2 * np.pi * 5 * t(d))) * env(int(SR * d), 0.08, 1.2, 2.2) * a
x += banda(ruido(d), 5000, 12000) * env(int(SR * d), 0.1, 1.0, 3.0) * 0.12
salvar("lendario", reverb(x, 1.2, 0.45), 0.85)

# UI
salvar("clique", banda(ruido(0.04), 1500, 5000) * env(int(SR * 0.04), 0.001, 0.008) + np.sin(2 * np.pi * 1200 * t(0.04)) * env(int(SR * 0.04), 0.001, 0.01) * 0.5, 0.5)
salvar("hover", np.sin(2 * np.pi * 2400 * t(0.03)) * env(int(SR * 0.03), 0.001, 0.006), 0.3)
salvar("negado", (np.sign(np.sin(2 * np.pi * 110 * t(0.22))) * 0.3 + np.sin(2 * np.pi * 116 * t(0.22)) * 0.3) * env(int(SR * 0.22), 0.005, 0.12), 0.5)

# ambiente da masmorra (loop de 24 s)
d = 24.0
tt = t(d)
x = banda(ruido(d), 30, 160) * 0.5
x += np.sin(2 * np.pi * 41.2 * tt) * 0.18 * (0.6 + 0.4 * np.sin(2 * np.pi * tt / 8.0))
x += banda(ruido(d), 300, 900) * 0.06 * (0.5 + 0.5 * np.sin(2 * np.pi * tt / 6.0 + 1.0))
for k in range(9):
    i0 = int(rng.uniform(0.5, d - 1.0) * SR)
    gota = varrer(0.12, rng.uniform(1400, 2200), rng.uniform(600, 900)) * env(int(SR * 0.12), 0.001, 0.03) * 0.25
    x[i0:i0 + len(gota)] += gota
cross = int(SR * 1.5)
x[:cross] = x[:cross] * np.linspace(0, 1, cross) + x[-cross:] * np.linspace(1, 0, cross)
x = x[:-cross]
salvar("ambiente", reverb(x, 1.5, 0.25)[: len(x)], 0.5)
print("sons ok")

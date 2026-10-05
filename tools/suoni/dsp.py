"""Gli attrezzi per costruire i suoni: oscillatori, rumori, filtri, inviluppi,
risonanze metalliche, riverbero. Tutto in numpy, senza altre librerie.

I filtri a FFT sono circolari: per i suoni in loop è proprio quello che serve
(la fine si ricongiunge all'inizio senza scatti); per i suoni singoli si
aggiunge un po' di silenzio prima di filtrare (vedi padded).
"""
import numpy as np

SR = 44100


def n_of(seconds):
    return max(1, int(round(seconds * SR)))


def t_of(n):
    return np.arange(n) / SR


# --- Sorgenti ------------------------------------------------------------------

def white(n, rng):
    return rng.uniform(-1.0, 1.0, n)


def colored(n, rng, slope):
    """Rumore con lo spettro che cala di slope dB per ottava (3 rosa, 6 marrone)."""
    spectrum = np.fft.rfft(rng.normal(0.0, 1.0, n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    spectrum *= 1.0 / np.maximum(f, 20.0) ** (slope / 6.0)
    out = np.fft.irfft(spectrum, n)
    return out / (np.max(np.abs(out)) + 1e-9)


def phase_of(freq, n):
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return 2.0 * np.pi * np.cumsum(freq) / SR


def sine(freq, n, phase0=0.0):
    return np.sin(phase_of(freq, n) + phase0)


def saw(freq, n):
    """Dente di sega con le armoniche sotto Nyquist (niente fischi d'aliasing)."""
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    ph = phase_of(freq, n)
    out = np.zeros(n)
    top = float(np.max(freq))
    k = 1
    while k * top < SR * 0.45 and k < 80:
        weight = np.clip((SR * 0.45 - k * freq) / (SR * 0.05), 0.0, 1.0)
        out += np.sin(k * ph) / k * weight
        k += 1
    return out * 0.6


def square(freq, n, duty=0.5):
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    ph = phase_of(freq, n)
    out = np.zeros(n)
    top = float(np.max(freq))
    k = 1
    while k * top < SR * 0.45 and k < 80:
        weight = np.clip((SR * 0.45 - k * freq) / (SR * 0.05), 0.0, 1.0)
        out += 2.0 / (np.pi * k) * np.sin(np.pi * k * duty) * np.cos(k * ph - np.pi * k * duty) * weight
        k += 1
    return out


def triangle(freq, n):
    ph = phase_of(freq, n) / (2.0 * np.pi)
    return 2.0 * np.abs(2.0 * (ph % 1.0) - 1.0) - 1.0


def sweep(f0, f1, n, curve="exp"):
    """Frequenza che va da f0 a f1 in n campioni."""
    x = np.linspace(0.0, 1.0, n)
    if curve == "exp":
        return f0 * (f1 / f0) ** x
    return f0 + (f1 - f0) * x


def modes(n, freqs, decays, amps, rng=None):
    """Risonanze che si spengono: metallo, campane, legno."""
    t = t_of(n)
    out = np.zeros(n)
    for f, d, a in zip(freqs, decays, amps):
        phase = rng.uniform(0, 2 * np.pi) if rng is not None else 0.0
        out += a * np.sin(2 * np.pi * f * t + phase) * np.exp(-t / d)
    return out


def metal(n, rng, base, count=8, spread=6.0, decay=0.25, bright=1.0):
    """Lamiera: risonanze inarmoniche sparse sopra base."""
    freqs = base * np.exp(rng.uniform(0, np.log(spread), count))
    decays = decay * rng.uniform(0.3, 1.0, count) * (base / freqs) ** 0.3
    amps = rng.uniform(0.4, 1.0, count) * (base / freqs) ** (0.5 / bright)
    return modes(n, freqs, decays, amps, rng)


# --- Inviluppi --------------------------------------------------------------------

def env_exp(n, decay, attack=0.002):
    t = t_of(n)
    return np.minimum(t / attack, 1.0) * np.exp(-t / decay)


def env_ad(n, attack, decay_curve=3.0):
    """Sale in attack secondi, poi scende fino a zero alla fine."""
    t = t_of(n)
    length = n / SR
    up = np.minimum(t / max(attack, 1e-4), 1.0)
    down = np.clip((length - t) / max(length - attack, 1e-4), 0.0, 1.0) ** decay_curve
    return up * down


def env_points(n, points):
    """Inviluppo a spezzata: [(secondi, livello), ...]."""
    times = [p[0] for p in points]
    levels = [p[1] for p in points]
    return np.interp(t_of(n), times, levels)


def fade(x, fade_in=0.002, fade_out=0.01):
    x = x.copy()
    a, b = n_of(fade_in), n_of(fade_out)
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b)
    return x


# --- Filtri -----------------------------------------------------------------------

def fft_filter(x, lo=None, hi=None, order=2):
    """Passa-alto lo e passa-basso hi (Butterworth, solo modulo), circolare."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    H = np.ones_like(f)
    if hi:
        H *= 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order))
    if lo:
        H *= 1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(X * H, n)


def fft_peak(x, f0, q):
    """Passa-banda risonante attorno a f0, circolare."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-3)
    H = 1.0 / np.sqrt(1.0 + (q * (f / f0 - f0 / f)) ** 2)
    return np.fft.irfft(X * H, n)


def padded(fn, x, pad=0.3):
    """Applica un filtro circolare a un suono singolo senza che la coda torni
    all'inizio."""
    p = n_of(pad)
    y = fn(np.concatenate([x, np.zeros(p)]))
    return y[:len(x)]


def lp(x, hi, order=2):
    return padded(lambda v: fft_filter(v, hi=hi, order=order), x)


def hp(x, lo, order=2):
    return padded(lambda v: fft_filter(v, lo=lo, order=order), x)


def bp(x, lo, hi, order=2):
    return padded(lambda v: fft_filter(v, lo=lo, hi=hi, order=order), x)


def peak(x, f0, q):
    return padded(lambda v: fft_peak(v, f0, q), x)


def svf(x, cutoff, q=0.707, mode="lp"):
    """Filtro a variabili di stato con la frequenza che cambia nel tempo."""
    n = len(x)
    cutoff = np.clip(np.broadcast_to(np.asarray(cutoff, dtype=float), (n,)), 20.0, SR * 0.45)
    g = np.tan(np.pi * cutoff / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    xs, a1s, a2s, a3s = x.tolist(), a1.tolist(), a2.tolist(), a3.tolist()
    out = [0.0] * n
    ic1 = ic2 = 0.0
    m = {"lp": 0, "bp": 1, "hp": 2}[mode]
    for i in range(n):
        v3 = xs[i] - ic2
        v1 = a1s[i] * ic1 + a2s[i] * v3
        v2 = ic2 + a2s[i] * ic1 + a3s[i] * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        out[i] = v2 if m == 0 else (v1 if m == 1 else xs[i] - k * v1 - v2)
    return np.array(out)


def drive(x, amount):
    """Saturazione morbida: più amount, più sporco e più forte."""
    return np.tanh(x * amount) / np.tanh(amount)


def reverb(x, size=1.0, mix=0.2, tail=0.6, circular=False):
    """Riverbero di Schroeder (quattro pettini in parallelo, due passa-tutto),
    calcolato nel dominio della frequenza. Circolare per i loop; per i suoni
    singoli aggiunge la coda."""
    src = x if circular else np.concatenate([x, np.zeros(n_of(tail * 3.0))])
    total = len(src)
    w = 2 * np.pi * np.fft.rfftfreq(total, 1.0 / SR)
    X = np.fft.rfft(src)
    H = np.zeros_like(X)
    for delay_ms in (29.7, 37.1, 41.1, 43.7):
        d = delay_ms / 1000.0 * size
        g = 10 ** (-3 * d / max(tail, 0.05))
        H += 1.0 / (1.0 - g * np.exp(-1j * w * d))
    H /= 4.0
    for delay_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = delay_ms / 1000.0 * size
        z = np.exp(-1j * w * d)
        H *= (-g + z) / (1.0 - g * z)
    wet = np.fft.irfft(X * H, total)
    wet *= np.max(np.abs(src)) / (np.max(np.abs(wet)) + 1e-9)
    return src * (1 - mix) + wet * mix


# --- Montaggio ----------------------------------------------------------------------

def place(dst, src, at_seconds, gain=1.0, circular=False):
    i = int(at_seconds * SR)
    if circular:
        idx = (np.arange(len(src)) + i) % len(dst)
        np.add.at(dst, idx, src * gain)
        return dst
    end = min(len(dst), i + len(src))
    if i < len(dst):
        dst[i:end] += src[:end - i] * gain
    return dst


def silence(seconds):
    return np.zeros(n_of(seconds))


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def trim(x, floor_db=-60.0):
    """Toglie il silenzio in coda."""
    level = 10 ** (floor_db / 20.0) * np.max(np.abs(x))
    loud = np.nonzero(np.abs(x) > level)[0]
    if len(loud) == 0:
        return x
    return x[:min(len(x), loud[-1] + n_of(0.02))]


def normalize_peak(x, db=-1.0):
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (db / 20.0)


def normalize_rms(x, db=-18.0, ceiling_db=-1.0):
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    y = x / rms * 10 ** (db / 20.0)
    ceiling = 10 ** (ceiling_db / 20.0)
    if np.max(np.abs(y)) > ceiling:
        y = np.tanh(y / ceiling) * ceiling
    return y

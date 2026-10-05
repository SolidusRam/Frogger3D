#!/usr/bin/env python3
"""Genera tutti gli effetti sonori del gioco in assets/audio/sfx.

Lo stile (deciso il 5 ottobre 2026, docs/studio-suono.md): la rana è buffa,
da cartone animato; il resto è semi-realistico ma caricaturale (lo schianto
più grosso del vero, la frenata più lunga).

Ogni ricetta è una funzione (rng, variante) -> campioni. I suoni singoli
diventano nome_N.wav (N = variante: il gioco ne sceglie una a caso); i loop
diventano nome.ogg e sono costruiti circolari, così la fine si ricongiunge
all'inizio senza scatti.

Uso: python3 tools/suoni/genera.py [nome...]   (senza nomi: tutti)
"""
import subprocess
import sys
import wave
import zlib
from multiprocessing import Pool
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from dsp import *  # noqa: E402,F401,F403

OUT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "sfx"
RECIPES = {}


def recipe(variants=1, loop=False, level=-1.0):
    """Registra una ricetta. level: picco in dB per i suoni singoli, volume
    medio (RMS) in dB per i loop."""
    def wrap(fn):
        RECIPES[fn.__name__] = {"fn": fn, "variants": variants, "loop": loop, "level": level}
        return fn
    return wrap


def jitter(rng, amount=0.05):
    return 1.0 + rng.uniform(-amount, amount)


def croak_voice(rng, f0, n, formants=(550, 1300, 2500), roll=32.0):
    """La voce della rana: un ronzio di gola (dente di sega) che vibra a
    scatti (il "rrr" del gracidio) e passa per le formanti di una vocale."""
    t = t_of(n)
    src = saw(f0, n)
    src *= 0.55 + 0.45 * np.clip(np.sin(2 * np.pi * roll * t) * 3.0, -1.0, 1.0)
    voice = np.zeros(n)
    for i, f in enumerate(formants):
        voice += peak(src, f, 5.0) * (1.0, 0.6, 0.25)[i]
    return voice


# =============================================================================
# La rana (buffa)
# =============================================================================

@recipe(variants=4, level=-6.0)
def frog_hop(rng, v):
    """Un passettino molle, appena udibile."""
    n = n_of(0.07)
    f = sweep(260 * jitter(rng, 0.15), 120, n)
    body = sine(f, n) * env_exp(n, 0.025)
    squish = bp(white(n, rng), 600, 2500) * env_exp(n, 0.012) * 0.3
    return body + squish


@recipe(variants=4)
def frog_jump(rng, v):
    """"Bwoip": una nota che sale di scatto, da cartone."""
    n = n_of(0.16)
    f0 = 210 * jitter(rng, 0.12)
    f = sweep(f0, f0 * 2.9, n)
    tone = triangle(f, n) * 0.6 + sine(f * 2.0, n) * 0.25
    tone *= env_points(n, [(0, 0), (0.008, 1), (0.08, 0.7), (0.16, 0)])
    puff = bp(white(n, rng), 900, 4000) * env_exp(n, 0.015) * 0.25
    return tone + puff


@recipe(variants=3)
def frog_land(rng, v):
    """"Plop": il tonfo molle di una rana che atterra."""
    n = n_of(0.2)
    thump = sine(sweep(150 * jitter(rng, 0.1), 60, n), n) * env_exp(n, 0.05)
    splat = bp(white(n, rng), 300, 1800) * env_exp(n, 0.03) * 0.5
    wet = sine(sweep(700, 1300, n_of(0.04)), n_of(0.04)) * env_exp(n_of(0.04), 0.01) * 0.2
    return mix(thump, splat, place(silence(0.2), wet, 0.012))


@recipe(variants=4)
def frog_croak(rng, v):
    """"Ri-bit": due sillabe gracidate."""
    f0 = 120 * jitter(rng, 0.12)
    a = croak_voice(rng, sweep(f0, f0 * 1.15, n_of(0.11)), n_of(0.11), (500, 1250, 2400)) * env_ad(n_of(0.11), 0.01, 1.5)
    b = croak_voice(rng, sweep(f0 * 1.25, f0 * 1.05, n_of(0.13)), n_of(0.13), (380, 2000, 2800)) * env_ad(n_of(0.13), 0.01, 2.0)
    out = silence(0.32)
    place(out, a, 0.0)
    place(out, b, 0.15)
    return out


@recipe(variants=2)
def frog_cheer(rng, v):
    """Il gracidio felice in tana: tre sillabe che salgono."""
    out = silence(0.55)
    f0 = 140 * jitter(rng, 0.08)
    for i, (at, ratio) in enumerate([(0.0, 1.0), (0.13, 1.26), (0.26, 1.6)]):
        n = n_of(0.12 if i < 2 else 0.22)
        f = sweep(f0 * ratio, f0 * ratio * (1.08 if i < 2 else 1.35), n)
        place(out, croak_voice(rng, f, n, (520, 1500, 2600)) * env_ad(n, 0.01, 1.6), at)
    return out


@recipe(variants=3)
def frog_hurt(rng, v):
    """Un guaito buffo: "uiih!" che sale e ricade."""
    n = n_of(0.3)
    t = t_of(n)
    f0 = 520 * jitter(rng, 0.12)
    f = np.interp(t, [0, 0.05, 0.3], [f0, f0 * 1.9, f0 * 0.8]) * (1 + 0.04 * np.sin(2 * np.pi * 18 * t))
    voice = croak_voice(rng, f, n, (800, 1500, 3000), roll=55.0)
    voice *= env_points(n, [(0, 0), (0.01, 1), (0.2, 0.6), (0.3, 0)])
    oof = sine(sweep(220, 110, n_of(0.08)), n_of(0.08)) * env_exp(n_of(0.08), 0.03) * 0.6
    return mix(voice, oof)


@recipe()
def frog_die(rng, v):
    """Il trombone triste: wah, wah, wah, waaah."""
    out = silence(2.4)
    notes = [(0.0, 233.1, 0.32), (0.4, 220.0, 0.32), (0.8, 207.7, 0.32), (1.2, 196.0, 1.1)]
    for i, (at, f, length) in enumerate(notes):
        n = n_of(length)
        t = t_of(n)
        wobble = 1 + (0.025 * np.sin(2 * np.pi * 6.0 * t) * np.clip(t / 0.3, 0, 1) if i == 3 else 0)
        tone = saw(f * wobble * (1 - 0.03 * t / length), n)
        # Il "wah": la sordina che si apre e si chiude.
        cutoff = 400 + 1800 * np.sin(np.pi * np.clip(t / length, 0, 1)) ** (0.8 if i < 3 else 0.5)
        if i == 3:
            cutoff = 400 + 1500 * (0.5 + 0.5 * np.sin(2 * np.pi * 3.0 * t))
        tone = svf(tone, cutoff, q=2.5)
        place(out, tone * env_ad(n, 0.03, 1.2), at)
    return out


@recipe()
def frog_revive(rng, v):
    """La seconda vita: un arpeggio luccicante che sale, e un gracidio."""
    out = silence(1.2)
    for i, midi in enumerate([72, 76, 79, 84, 88]):
        n = n_of(0.5)
        f = 440 * 2 ** ((midi - 69) / 12)
        bell = modes(n, [f, f * 2.0, f * 3.01], [0.25, 0.12, 0.06], [1.0, 0.4, 0.2], rng)
        place(out, bell * env_exp(n, 0.3), i * 0.07, 0.5)
    place(out, frog_croak(rng, 0) * 0.7, 0.45)
    return out


@recipe(variants=3)
def frog_splash(rng, v):
    """Il tuffo in acqua: lo schiaffo, lo spruzzo e qualche bolla."""
    n = n_of(0.6)
    t = t_of(n)
    slap = lp(white(n, rng), 3000) * env_exp(n, 0.03)
    spray = svf(white(n, rng), 4000 * np.exp(-t * 4) + 600, q=0.8) * env_exp(n, 0.15) * 0.6
    out = mix(slap, spray)
    for _ in range(rng.integers(5, 9)):
        place(out, bubble(rng, rng.uniform(500, 1400)) * rng.uniform(0.15, 0.35), rng.uniform(0.05, 0.45))
    return out


def bubble(rng, f):
    n = n_of(0.05)
    return sine(sweep(f, f * 1.8, n), n) * env_exp(n, 0.015)


@recipe(variants=3, level=-4.0)
def frog_swim(rng, v):
    """Una bracciata: "blub"."""
    n = n_of(0.25)
    out = bp(white(n, rng), 300, 1200) * env_exp(n, 0.06) * 0.5
    for _ in range(3):
        place(out, bubble(rng, rng.uniform(350, 800)) * 0.5, rng.uniform(0.0, 0.15))
    return out


@recipe(variants=2)
def frog_water_jump(rng, v):
    """Fuori dall'acqua con uno spruzzo."""
    n = n_of(0.35)
    t = t_of(n)
    spray = svf(white(n, rng), 1200 + 3000 * np.minimum(t / 0.1, 1.0), q=0.9) * env_points(n, [(0, 0), (0.02, 1), (0.35, 0)])
    return mix(spray * 0.7, frog_jump(rng, 0) * 0.6)


@recipe(variants=3)
def frog_burn(rng, v):
    """Scottata: un guaito acuto sopra uno sfrigolio."""
    yelp = frog_hurt(rng, 0)
    n = len(yelp)
    hiss = hp(white(n, rng), 3000) * env_exp(n, 0.15) * 0.4
    return mix(resample(yelp, 1.3), hiss)


def resample(x, ratio):
    """Più acuto (ratio > 1) o più grave, cambiando la durata."""
    n = int(len(x) / ratio)
    return np.interp(np.arange(n) * ratio, np.arange(len(x)), x)


# =============================================================================
# I poteri
# =============================================================================

@recipe(variants=3)
def punch_swing(rng, v):
    """Il pugno a vuoto: lo spostamento d'aria."""
    n = n_of(0.22)
    t = t_of(n)
    cutoff = np.interp(t, [0, 0.08, 0.22], [500, 2600 * jitter(rng, 0.2), 900])
    return svf(white(n, rng), cutoff, q=1.8, mode="bp") * env_points(n, [(0, 0), (0.07, 1), (0.22, 0)])


@recipe(variants=4)
def punch_hit(rng, v):
    """Il pugno che colpisce un'auto: il suono più importante della rana.
    Uno schiocco, il tonfo del guantone, e la lamiera che si accartoccia,
    tutto più grosso del vero."""
    n = n_of(0.7)
    t = t_of(n)
    click = hp(white(n_of(0.004), rng), 2000)
    thump = sine(sweep(120 * jitter(rng, 0.1), 42, n), n) * env_exp(n, 0.09)
    pow_ = drive(lp(white(n, rng), 1800) * env_exp(n, 0.04), 3.0) * 0.7
    dent = metal(n, rng, 380 * jitter(rng, 0.15), count=9, spread=7.0, decay=0.18) * env_exp(n, 0.2)
    crunch = np.zeros(n)
    for _ in range(4):
        grain = bp(white(n_of(0.03), rng), 1500, 6000) * env_exp(n_of(0.03), 0.008)
        place(crunch, grain, rng.uniform(0.0, 0.06), rng.uniform(0.3, 0.7))
    out = mix(place(silence(0.7), click, 0, 0.8), thump * 1.1, pow_, dent * 0.5, crunch * 0.6)
    return drive(out, 1.8)


@recipe(variants=3)
def super_jump(rng, v):
    """La molla che scatta: "boiiing"."""
    n = n_of(0.75)
    t = t_of(n)
    f0 = 170 * jitter(rng, 0.1)
    base = f0 * (1 + 1.6 * (1 - np.exp(-t * 7)))
    wobble = 1 + 0.18 * np.exp(-t * 4) * np.sin(2 * np.pi * 28 * t)
    tone = sine(base * wobble, n) * 0.7 + triangle(base * wobble * 2, n) * 0.2
    twang = metal(n, rng, 900, count=3, spread=2.5, decay=0.25) * 0.25
    return (tone + twang) * env_points(n, [(0, 0), (0.005, 1), (0.3, 0.5), (0.75, 0)])


@recipe(variants=2)
def glider_open(rng, v):
    """Il telo del deltaplano che si apre: "fwump"."""
    n = n_of(0.3)
    t = t_of(n)
    flap = lp(white(n, rng), 900) * (0.6 + 0.4 * np.sin(2 * np.pi * 38 * t)) * env_points(n, [(0, 0), (0.03, 1), (0.3, 0)])
    snap = bp(white(n_of(0.01), rng), 1500, 5000) * 0.5
    return mix(flap, place(silence(0.3), snap, 0.18))


@recipe(variants=2)
def glider_close(rng, v):
    n = n_of(0.15)
    t = t_of(n)
    return lp(white(n, rng), 1400) * (0.6 + 0.4 * np.sin(2 * np.pi * 50 * t)) * env_ad(n, 0.01, 2.0)


@recipe(loop=True, level=-20.0)
def glide_wind(rng, v):
    """Il vento in volo."""
    n = n_of(4.0)
    slow = fft_filter(rng.normal(0, 1, n), hi=0.8)
    slow = (slow - slow.min()) / (np.ptp(slow) + 1e-9)
    hiss = fft_filter(white(n, rng), lo=300, hi=1500) * (0.5 + 0.5 * slow)
    howl = fft_peak(white(n, rng), 700, 6.0) * slow * 0.6
    return hiss + howl


@recipe(variants=3)
def tongue_shoot(rng, v):
    """La lingua che parte: "thwip"."""
    n = n_of(0.12)
    f = sweep(300 * jitter(rng, 0.1), 1900, n)
    zip_ = sine(f, n) * env_points(n, [(0, 0), (0.005, 1), (0.12, 0)])
    wet = bp(white(n, rng), 1500, 5000) * env_exp(n, 0.02) * 0.3
    return zip_ * 0.6 + wet


@recipe(variants=3)
def tongue_stick(rng, v):
    """La lingua che si attacca: uno schiocco umido."""
    n = n_of(0.22)
    t = t_of(n)
    smack = drive(lp(white(n, rng), 2500) * env_exp(n, 0.02), 2.0)
    suck = svf(white(n, rng), 1800 * np.exp(-t * 12) + 250, q=4.0, mode="bp") * env_exp(n, 0.08) * 0.6
    thud = sine(sweep(160, 80, n), n) * env_exp(n, 0.04) * 0.5
    return smack * 0.6 + suck + thud


@recipe(variants=2)
def tongue_reel(rng, v):
    """La lingua che si ritira: "slurp"."""
    n = n_of(0.2)
    t = t_of(n)
    return svf(white(n, rng), 300 + 2500 * t / 0.2, q=5.0, mode="bp") * env_ad(n, 0.03, 1.5)


@recipe()
def slam_dive(rng, v):
    """La picchiata: il fischio della bomba dei cartoni."""
    n = n_of(0.9)
    f = sweep(1900, 600, n)
    return sine(f, n) * env_points(n, [(0, 0), (0.05, 0.8), (0.9, 1.0)]) * 0.6


@recipe(variants=3)
def slam_impact(rng, v):
    """Lo schianto sismico a terra: botta, rombo, sassi."""
    n = n_of(1.4)
    t = t_of(n)
    sub = sine(sweep(75 * jitter(rng, 0.1), 28, n), n) * env_exp(n, 0.25)
    boom = lp(white(n, rng), 350) * env_exp(n, 0.35) * 1.2
    crack = hp(white(n_of(0.01), rng), 1500)
    out = mix(sub, boom, place(silence(1.4), crack, 0, 0.6))
    for _ in range(14):
        g = n_of(0.04)
        grain = bp(white(g, rng), 800, 4000) * env_exp(g, 0.01)
        place(out, grain, 0.08 + rng.exponential(0.25), rng.uniform(0.05, 0.25))
    return drive(out, 2.0)


@recipe(level=-3.0)
def power_ready(rng, v):
    """Un potere di nuovo pronto: un "ding" leggero."""
    n = n_of(0.45)
    return modes(n, [1318.5, 1975.5, 2637], [0.18, 0.12, 0.06], [1.0, 0.5, 0.25], rng)


# =============================================================================
# Le auto (semi-realistiche, caricaturali)
# =============================================================================

@recipe(loop=True, level=-20.0)
def car_engine(rng, v):
    """Il motore al minimo che tira: scoppi regolari, filtrati. Il gioco
    cambia il tono con la velocità e col tipo di veicolo."""
    n = n_of(2.0)
    t = t_of(n)
    fire_rate = 45.0  # scoppi al secondo; 90 cicli in 2 s: chiude il loop
    pulses = np.zeros(n)
    period = SR / fire_rate
    for k in range(int(fire_rate * 2.0)):
        i = int(k * period + rng.uniform(-6, 6)) % n
        g = n_of(0.012)
        pulses[(np.arange(g) + i) % n] += rng.uniform(0.7, 1.0) * np.exp(-np.arange(g) / (g / 4))
    body = fft_filter(pulses, lo=30, hi=500)
    growl = fft_peak(white(n, rng), 140, 3.0) * 0.3
    rumble = fft_filter(white(n, rng), hi=180) * 0.5
    return body + growl + rumble


@recipe(variants=3)
def car_horn(rng, v):
    """Il clacson del cartone: due note un po' stonate. La terza variante
    suona due volte."""
    a, b = 350 * jitter(rng, 0.05), 440 * jitter(rng, 0.05)
    length = 0.42 if v < 2 else 0.16
    n = n_of(length)
    tone = square(a, n, 0.4) + square(b, n, 0.4)
    tone = drive(lp(tone, 2200), 1.5) * env_points(n, [(0, 0), (0.01, 1), (length - 0.03, 0.9), (length, 0)])
    if v < 2:
        return tone
    out = silence(0.45)
    place(out, tone, 0.0)
    place(out, tone, 0.22)
    return out


@recipe(variants=3)
def car_skid(rng, v):
    """La frenata lunga, gomme che stridono."""
    length = 1.1 * jitter(rng, 0.15)
    n = n_of(length)
    t = t_of(n)
    f = 1500 * jitter(rng, 0.15) * (1 + 0.06 * np.sin(2 * np.pi * 7.5 * t)) * (1 - 0.15 * t / length)
    squeal = sine(f, n) * 0.5 + sine(f * 2.02, n) * 0.15
    rubber = svf(white(n, rng), f, q=12.0, mode="bp") * 1.2
    return (squeal + rubber) * env_points(n, [(0, 0), (0.06, 1), (length * 0.7, 0.8), (length, 0)])


@recipe(variants=5)
def car_crash(rng, v):
    """Lo schianto: lamiere, una botta sorda, i vetri che si rompono."""
    n = n_of(1.5)
    t = t_of(n)
    thump = sine(sweep(95 * jitter(rng, 0.15), 40, n), n) * env_exp(n, 0.12)
    burst = drive(lp(white(n, rng), 5000) * env_exp(n, 0.07), 2.5) * 0.7
    out = mix(thump, burst)
    # La lamiera si accartoccia: più colpi ravvicinati.
    for _ in range(rng.integers(3, 6)):
        at = rng.uniform(0.0, 0.18)
        m = metal(n_of(0.6), rng, rng.uniform(250, 600), count=7, spread=8.0, decay=0.15) * env_exp(n_of(0.6), 0.15)
        place(out, m, at, rng.uniform(0.25, 0.5))
    # I vetri.
    for _ in range(rng.integers(12, 22)):
        at = 0.03 + rng.exponential(0.12)
        g = n_of(0.08)
        f = rng.uniform(3000, 8000)
        place(out, sine(f, g) * env_exp(g, 0.02), at, rng.uniform(0.04, 0.12))
    return drive(out, 1.6)


@recipe(variants=3)
def car_explode(rng, v):
    """L'esplosione: lo schiocco, il boato che rotola, i pezzi che ricadono."""
    n = n_of(2.2)
    t = t_of(n)
    crack = hp(white(n_of(0.015), rng), 1200)
    boom = svf(white(n, rng), 1500 * np.exp(-t * 6) + 120, q=0.8) * env_exp(n, 0.45) * 1.5
    sub = sine(sweep(60, 25, n), n) * env_exp(n, 0.4)
    out = mix(place(silence(2.2), crack, 0, 1.0), boom, sub)
    for _ in range(10):
        at = 0.4 + rng.exponential(0.4)
        m = metal(n_of(0.3), rng, rng.uniform(500, 1500), count=4, spread=4.0, decay=0.08)
        place(out, m, at, rng.uniform(0.05, 0.15))
    return drive(out, 2.5)


@recipe(variants=4, level=-3.0)
def wreck_hit(rng, v):
    """Un rottame che sbatte: lamiera più leggera."""
    n = n_of(0.5)
    thud = sine(sweep(110, 55, n), n) * env_exp(n, 0.06)
    clank = metal(n, rng, rng.uniform(300, 700), count=5, spread=5.0, decay=0.12)
    return thud + clank * 0.5 + lp(white(n, rng), 3000) * env_exp(n, 0.02) * 0.4


# =============================================================================
# L'incendio
# =============================================================================

def crackles(n, rng, rate, lo=1500, loud=1.0):
    """Scoppiettii sparsi nel tempo (circolari: vanno bene anche nei loop)."""
    out = np.zeros(n)
    count = int(rate * n / SR)
    for _ in range(count):
        g = n_of(rng.uniform(0.001, 0.004))
        grain = white(g, rng) * np.exp(-np.arange(g) / (g / 3))
        place(out, grain * rng.exponential(0.4) * loud, rng.uniform(0, n / SR), circular=True)
    return fft_filter(out, lo=lo)


@recipe(loop=True, level=-16.0)
def fire_loop(rng, v):
    """Il muro di fuoco: crepitio e fiamme che respirano."""
    n = n_of(6.0)
    slow = fft_filter(rng.normal(0, 1, n), hi=1.5)
    slow = 0.6 + 0.4 * (slow - slow.min()) / (np.ptp(slow) + 1e-9)
    roar = fft_filter(white(n, rng), hi=500) * slow
    flames = fft_filter(white(n, rng), lo=400, hi=2500) * slow * 0.35
    crack = crackles(n, rng, 60) * 0.7
    pops = np.zeros(n)
    for _ in range(14):
        g = n_of(0.03)
        pop = fft_peak(white(g, rng), rng.uniform(300, 900), 3.0) * np.exp(-np.arange(g) / (g / 4))
        place(pops, pop, rng.uniform(0, 6.0), rng.uniform(0.5, 1.2), circular=True)
    return roar + flames + crack + pops


@recipe(loop=True, level=-16.0)
def fire_roar(rng, v):
    """Il ruggito quando il fuoco è vicino: un vento profondo."""
    n = n_of(5.0)
    slow = fft_filter(rng.normal(0, 1, n), hi=2.0)
    slow = 0.5 + 0.5 * (slow - slow.min()) / (np.ptp(slow) + 1e-9)
    low = fft_filter(white(n, rng), hi=220) * slow * 1.5
    mid = fft_peak(white(n, rng), 500, 2.0) * slow * 0.4
    return low + mid + crackles(n, rng, 30, loud=0.5)


@recipe(variants=2)
def fire_ignite(rng, v):
    """Una fiammata che si accende: "fwoosh"."""
    n = n_of(0.8)
    t = t_of(n)
    cutoff = np.interp(t, [0, 0.15, 0.8], [200, 3500, 600])
    return svf(white(n, rng), cutoff, q=0.9) * env_points(n, [(0, 0), (0.12, 1), (0.8, 0)])


@recipe(loop=True, level=-20.0)
def sizzle(rng, v):
    """Sfrigolio: la rana che brucia."""
    n = n_of(3.0)
    flutter = fft_filter(rng.normal(0, 1, n), hi=12)
    flutter = 0.4 + 0.6 * (flutter - flutter.min()) / (np.ptp(flutter) + 1e-9)
    return fft_filter(white(n, rng), lo=2500, hi=9000) * flutter + crackles(n, rng, 80, lo=3000)


# =============================================================================
# Fiume e porto
# =============================================================================

def bubbles_circular(n, rng, rate, lo=400, hi=1300):
    out = np.zeros(n)
    for _ in range(int(rate * n / SR)):
        place(out, bubble(rng, rng.uniform(lo, hi)) * rng.uniform(0.1, 0.4), rng.uniform(0, n / SR), circular=True)
    return out


@recipe(loop=True, level=-22.0)
def river_loop(rng, v):
    """L'acqua che scorre: gorgoglii e bollicine."""
    n = n_of(6.0)
    gurgle = fft_filter(rng.normal(0, 1, n), hi=9.0)
    gurgle = 0.5 + 0.5 * (gurgle - gurgle.min()) / (np.ptp(gurgle) + 1e-9)
    flow = fft_filter(white(n, rng), lo=250, hi=1800) * gurgle
    return flow + bubbles_circular(n, rng, 25) * 0.6


@recipe(loop=True, level=-22.0)
def harbor_loop(rng, v):
    """Le onde contro il molo: risacca lenta e qualche schiaffo d'acqua."""
    n = n_of(8.0)
    t = t_of(n)
    swell = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 4.0)) ** 2  # due onde in 8 s
    wash = fft_filter(white(n, rng), lo=150, hi=1400) * swell
    slaps = np.zeros(n)
    for at in (1.6, 5.6):
        g = n_of(0.3)
        slap = fft_filter(white(g, rng), hi=2500) * env_exp(g, 0.05)
        place(slaps, slap, at + rng.uniform(-0.2, 0.2), 0.8, circular=True)
    return wash + slaps


@recipe(variants=2)
def log_creak(rng, v):
    """Il tronco che scricchiola sotto il peso."""
    length = 0.7
    n = n_of(length)
    t = t_of(n)
    rate = 45 + 35 * np.sin(np.pi * t / length) + rng.normal(0, 4, n).cumsum() * 0.02
    stick = saw(np.maximum(rate, 20), n)
    wood = peak(stick, 700 * jitter(rng, 0.2), 4.0) + peak(stick, 1500, 6.0) * 0.4
    return wood * env_points(n, [(0, 0), (0.1, 1), (0.55, 0.8), (length, 0)])


@recipe(variants=3)
def log_bubbles(rng, v):
    """Le bolle del tronco che va sotto."""
    out = silence(0.8)
    for _ in range(rng.integers(7, 12)):
        place(out, bubble(rng, rng.uniform(300, 900)), rng.uniform(0, 0.7), rng.uniform(0.3, 0.8))
    return out


@recipe(variants=3)
def croc_snap(rng, v):
    """La mascella che si chiude: "CIAC"."""
    n = n_of(0.35)
    knock = modes(n, [700 * jitter(rng, 0.1), 1650, 2900], [0.04, 0.025, 0.015], [1.0, 0.6, 0.3], rng)
    thud = sine(sweep(130, 60, n), n) * env_exp(n, 0.05)
    crunch = bp(white(n, rng), 1000, 4000) * env_exp(n, 0.03) * 0.5
    return drive(knock + thud + crunch, 2.0)


@recipe(variants=2, level=-4.0)
def croc_open(rng, v):
    """La bocca che si apre: un sibilo roco."""
    n = n_of(0.5)
    t = t_of(n)
    hiss = bp(white(n, rng), 1800, 6000) * env_points(n, [(0, 0), (0.08, 1), (0.5, 0)])
    growl = saw(60 + 10 * np.sin(2 * np.pi * 9 * t), n)
    growl = lp(growl, 500) * env_ad(n, 0.05, 1.5) * 0.5
    return hiss * 0.7 + growl


# =============================================================================
# La ferrovia
# =============================================================================

def bell_strike(rng, f, length=0.5):
    n = n_of(length)
    ratios = [1.0, 2.76, 5.40, 8.93]
    return modes(n, [f * r for r in ratios], [0.35, 0.18, 0.08, 0.04], [1.0, 0.5, 0.3, 0.15], rng)


@recipe(loop=True, level=-14.0)
def rail_bell(rng, v):
    """La campanella del passaggio a livello: quattro colpi al secondo."""
    n = n_of(1.0)
    out = np.zeros(n)
    for i in range(4):
        place(out, bell_strike(rng, 1150 if i % 2 == 0 else 1135), i * 0.25, 1.0, circular=True)
    return out


@recipe(variants=2)
def train_horn(rng, v):
    """La tromba del treno: un accordo di tre note. La seconda variante,
    due colpi corti."""
    chord = [311.1, 370.0, 466.2]
    length = 1.3 if v == 0 else 0.35
    n = n_of(length)
    t = t_of(n)
    tone = sum(saw(f * (1 + 0.004 * np.sin(2 * np.pi * 5 * t + i)), n) for i, f in enumerate(chord))
    tone = drive(lp(tone, 2500), 1.4) * env_points(n, [(0, 0), (0.05, 1), (length - 0.08, 0.95), (length, 0)])
    if v == 0:
        return tone
    out = silence(0.85)
    place(out, tone, 0.0)
    place(out, tone, 0.45)
    return out


@recipe(loop=True, level=-16.0)
def train_loop(rng, v):
    """Il treno che passa: rombo e il "ta-tam, ta-tam" dei carrelli sui giunti."""
    n = n_of(2.0)
    rumble = fft_filter(white(n, rng), hi=300) * 1.2
    wheels = fft_peak(white(n, rng), 900, 2.0) * 0.15
    clacks = np.zeros(n)
    for start in (0.0, 1.0):
        for k, offset in enumerate((0.0, 0.14)):
            g = n_of(0.12)
            clack = modes(g, [420, 980, 1900], [0.03, 0.02, 0.01], [1.0, 0.5, 0.3], rng)
            clack += fft_filter(white(g, rng), hi=1200) * np.exp(-np.arange(g) / (g / 6)) * 0.8
            place(clacks, clack, start + offset, 1.0 if k == 0 else 0.8, circular=True)
    return rumble + wheels + clacks * 1.4


# =============================================================================
# L'aeroporto
# =============================================================================

@recipe(loop=True, level=-14.0)
def jet_loop(rng, v):
    """Il motore a reazione: il ruggito e il fischio della turbina."""
    n = n_of(4.0)
    t = t_of(n)
    roar = fft_filter(white(n, rng), lo=60, hi=1500) * 1.2
    hiss = fft_filter(white(n, rng), lo=3000, hi=7000) * 0.25
    whine = sine(3200 + 15 * np.sin(2 * np.pi * 0.5 * t), n) * 0.06 + sine(1600, n) * 0.03
    return roar + hiss + whine


@recipe(variants=2)
def plane_touchdown(rng, v):
    """Le gomme che toccano la pista: due stridii brevi e la botta."""
    out = silence(1.2)
    for at in (0.0, 0.12):
        n = n_of(0.28)
        t = t_of(n)
        squeal = svf(white(n, rng), 2100 * jitter(rng, 0.1), q=10.0, mode="bp") + sine(2000 * (1 - 0.1 * t), n) * 0.3
        place(out, squeal * env_points(n, [(0, 0), (0.01, 1), (0.28, 0)]), at, 0.9)
    n = n_of(1.0)
    thump = sine(sweep(70, 30, n), n) * env_exp(n, 0.2) + lp(white(n, rng), 300) * env_exp(n, 0.3)
    place(out, thump, 0.02, 1.2)
    return out


@recipe()
def plane_reverse(rng, v):
    """I motori al contrario: il ruggito che monta e tiene."""
    n = n_of(3.0)
    t = t_of(n)
    cutoff = np.interp(t, [0, 0.4, 2.4, 3.0], [400, 3000, 2500, 500])
    roar = svf(white(n, rng), cutoff, q=0.7)
    return roar * env_points(n, [(0, 0), (0.4, 1), (2.4, 0.9), (3.0, 0)])


@recipe(loop=True, level=-16.0)
def scrape_loop(rng, v):
    """La pancia dell'aereo che striscia sulla pista: metallo e scintille."""
    n = n_of(3.0)
    grind = np.zeros(n)
    for f in rng.uniform(400, 3500, 8):
        grind += fft_peak(white(n, rng), f, 25.0) * rng.uniform(0.3, 1.0)
    flutter = fft_filter(rng.normal(0, 1, n), hi=25)
    flutter = 0.4 + 0.6 * (flutter - flutter.min()) / (np.ptp(flutter) + 1e-9)
    rumble = fft_filter(white(n, rng), hi=250) * 0.8
    return grind * flutter + rumble + crackles(n, rng, 50, lo=2500) * 0.6


@recipe(variants=3)
def baggage_hit(rng, v):
    """Una valigia che colpisce: tonfo morbido e una maniglia che sbatte."""
    n = n_of(0.35)
    thud = sine(sweep(140 * jitter(rng, 0.15), 70, n), n) * env_exp(n, 0.05)
    cloth = lp(white(n, rng), 1500) * env_exp(n, 0.03) * 0.6
    handle = modes(n_of(0.1), [2300, 3700], [0.015, 0.01], [1.0, 0.5], rng) * 0.3
    return mix(thud, cloth, place(silence(0.35), handle, 0.03))


@recipe(loop=True, level=-24.0)
def tug_loop(rng, v):
    """Il trattorino dei bagagli: un ronzio elettrico e i carrelli che sferragliano."""
    n = n_of(3.0)
    t = t_of(n)
    whine = sine(420 + 4 * np.sin(2 * np.pi * t / 1.5), n) * 0.3 + sine(840, n) * 0.1
    rattle = np.zeros(n)
    for _ in range(40):
        g = n_of(0.02)
        place(rattle, white(g, rng) * np.exp(-np.arange(g) / (g / 4)), rng.uniform(0, 3.0), rng.uniform(0.2, 0.6), circular=True)
    return whine + fft_filter(rattle, lo=800, hi=5000) + fft_filter(white(n, rng), hi=200) * 0.3


# =============================================================================
# Il porto
# =============================================================================

@recipe(variants=2)
def ship_horn(rng, v):
    """La sirena della nave: "BUOOOM" profondo."""
    length = 2.4 if v == 0 else 1.2
    n = n_of(length)
    t = t_of(n)
    f = 82 * jitter(rng, 0.04) * (1 + 0.01 * np.sin(2 * np.pi * 4 * t))
    tone = saw(f, n) + saw(f * 1.5, n) * 0.25
    tone = drive(lp(tone, 700), 1.8) * env_points(n, [(0, 0), (0.25, 1), (length - 0.3, 0.9), (length, 0)])
    return tone


@recipe(loop=True, level=-16.0)
def crane_warning(rng, v):
    """L'allarme della gru: bip, bip, bip."""
    n = n_of(1.0)
    out = np.zeros(n)
    for i in range(2):
        g = n_of(0.25)
        beep = fft_filter(square(1000.0, g, 0.5), hi=4000) * env_points(g, [(0, 0), (0.005, 1), (0.24, 1), (0.25, 0)])
        place(out, beep, i * 0.5, circular=True)
    return out


@recipe()
def crane_release(rng, v):
    """La gru che sgancia: il ferro che scatta e il container che fischia giù."""
    n = n_of(1.0)
    t = t_of(n)
    clunk = metal(n_of(0.4), rng, 250, count=6, spread=6.0, decay=0.12)
    whoosh = svf(white(n, rng), 300 + 1500 * t, q=1.2, mode="bp") * env_points(n, [(0, 0), (0.2, 0.3), (1.0, 0.8)])
    return mix(clunk, whoosh)


@recipe(variants=3)
def container_land(rng, v):
    """Il container che cade: un gong di lamiera enorme."""
    n = n_of(2.2)
    t = t_of(n)
    gong = metal(n, rng, 70 * jitter(rng, 0.15), count=10, spread=10.0, decay=0.9, bright=0.7)
    boom = sine(sweep(60, 30, n), n) * env_exp(n, 0.3) * 1.2
    burst = drive(lp(white(n, rng), 3000) * env_exp(n, 0.06), 2.0)
    return drive(gong * 0.6 + boom + burst * 0.6, 1.8)


@recipe(loop=True, level=-24.0)
def ship_engine(rng, v):
    """Il motore della nave: un "tum-tum" lento e grave."""
    n = n_of(3.0)
    out = np.zeros(n)
    for k in range(int(3.0 * 5)):
        g = n_of(0.15)
        pulse = sine(sweep(55, 40, g), g) * env_exp(g, 0.06)
        place(out, pulse, k / 5.0, circular=True)
    return out + fft_filter(white(n, rng), hi=150) * 0.4


# =============================================================================
# Tana, mosche, calore
# =============================================================================

def pluck(rng, midi, length=0.6):
    """Un'arpa: corda pizzicata (Karplus-Strong semplificato)."""
    f = 440 * 2 ** ((midi - 69) / 12)
    n = n_of(length)
    period = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, period)
    out = np.empty(n)
    for i in range(0, n, period):
        end = min(i + period, n)
        out[i:end] = buf[:end - i]
        buf = 0.5 * (buf + np.roll(buf, 1)) * 0.995
    return out


@recipe()
def den_arrive(rng, v):
    """L'arrivo in tana: un glissato d'arpa che sale e un luccichio."""
    out = silence(1.8)
    for i, midi in enumerate([60, 62, 64, 67, 69, 72, 74, 76, 79, 84]):
        place(out, pluck(rng, midi, 1.0), i * 0.05, 0.5)
    for _ in range(25):
        g = n_of(0.15)
        place(out, sine(rng.uniform(4000, 9000), g) * env_exp(g, 0.04), 0.3 + rng.uniform(0, 1.0), rng.uniform(0.03, 0.08))
    return reverb(out, mix=0.3, tail=1.0)


@recipe(variants=3, level=-4.0)
def flower_pop(rng, v):
    """Un fiore che si apre: "pop"."""
    n = n_of(0.08)
    f = sweep(400 * (1.2 ** v), 950 * (1.2 ** v), n)
    return sine(f, n) * env_exp(n, 0.025)


@recipe(variants=3, level=-3.0)
def fly_collect(rng, v):
    """Una mosca presa: un "blip" brillante."""
    a, b = [(987.8, 1318.5), (1046.5, 1396.9), (932.3, 1244.5)][v]
    out = silence(0.2)
    for at, f in ((0.0, a), (0.06, b)):
        n = n_of(0.09)
        place(out, square(f, n, 0.25) * env_exp(n, 0.04) * 0.5 + sine(f * 2, n) * env_exp(n, 0.03) * 0.3, at)
    return out


@recipe()
def fly_golden(rng, v):
    """Una mosca d'oro: tre note e un luccichio."""
    out = silence(0.9)
    for i, f in enumerate([1318.5, 1661.2, 1975.5]):
        n = n_of(0.6)
        bell = modes(n, [f, f * 2.0, f * 3.0], [0.3, 0.15, 0.08], [1.0, 0.4, 0.2], rng)
        place(out, bell, i * 0.07, 0.6)
    return reverb(out, mix=0.25, tail=0.6)


@recipe(loop=True, level=-26.0)
def fly_buzz(rng, v):
    """Il ronzio della mosca, da cartone."""
    n = n_of(2.0)
    t = t_of(n)
    f = 190 + 25 * np.sin(2 * np.pi * 3.0 * t) + 10 * np.sin(2 * np.pi * 7.0 * t)
    tone = saw(f, n) * (0.7 + 0.3 * np.sin(2 * np.pi * 42 * t))
    return fft_peak(tone, 900, 1.5) + fft_peak(tone, 2500, 3.0) * 0.4


@recipe()
def heat_up(rng, v):
    """Il calore sale di livello: un colpo d'allarme, come il "!" dei giochi
    di spionaggio, sopra un fruscio che monta."""
    n = n_of(1.0)
    t = t_of(n)
    stab = sum(saw(f, n) for f in (146.8, 174.6, 220.0, 293.7))
    stab = drive(lp(stab, 1800), 1.5) * env_exp(n, 0.25)
    hit = metal(n, rng, 600, count=6, spread=5.0, decay=0.3) * 0.4
    riser = svf(white(n, rng), 500 + 4000 * np.clip(1 - t / 0.25, 0, 1), q=1.0) * env_exp(n, 0.1) * 0.4
    return stab + hit + riser


@recipe(level=-3.0)
def chain_ding(rng, v):
    """Un anello della catena: il gioco alza il tono a ogni rottame in più."""
    n = n_of(0.35)
    return square(880, n, 0.3) * env_exp(n, 0.08) * 0.4 + modes(n, [1760, 2640], [0.15, 0.08], [0.6, 0.3], rng)


# =============================================================================
# L'interfaccia
# =============================================================================

@recipe(level=-8.0)
def ui_hover(rng, v):
    n = n_of(0.03)
    return sine(2200, n) * env_exp(n, 0.008)


@recipe(level=-4.0)
def ui_click(rng, v):
    n = n_of(0.07)
    return mix(sine(sweep(950, 600, n), n) * env_exp(n, 0.02), hp(white(n_of(0.003), rng), 3000) * 0.4)


@recipe(level=-4.0)
def ui_back(rng, v):
    n = n_of(0.08)
    return sine(sweep(600, 380, n), n) * env_exp(n, 0.025)


@recipe(level=-5.0)
def ui_card_in(rng, v):
    """Una carta che entra: un fruscio rapido."""
    n = n_of(0.18)
    t = t_of(n)
    return svf(white(n, rng), 800 + 4000 * t / 0.18, q=1.5, mode="bp") * env_ad(n, 0.05, 2.0)


@recipe()
def ui_card_pick(rng, v):
    """La carta scelta: due note che salgono, e un colpo."""
    out = silence(0.6)
    for at, f in ((0.0, 784.0), (0.08, 1174.7)):
        n = n_of(0.4)
        place(out, square(f, n, 0.3) * env_exp(n, 0.12) * 0.5 + sine(f, n) * env_exp(n, 0.2) * 0.5, at)
    place(out, punch_hit(rng, 0)[:n_of(0.3)] * 0.35, 0.0)
    return reverb(out, mix=0.2, tail=0.4)


@recipe()
def ui_buy(rng, v):
    """Allo stagno: comprato. Monete che tintinnano."""
    out = silence(0.5)
    for i in range(3):
        n = n_of(0.3)
        f = rng.uniform(2400, 3200)
        place(out, modes(n, [f, f * 1.5, f * 2.2], [0.1, 0.06, 0.04], [1.0, 0.5, 0.3], rng), i * 0.05, 0.6)
    return out


@recipe()
def ui_refund(rng, v):
    """Rimborso: monete che scendono."""
    out = silence(0.7)
    for i in range(6):
        n = n_of(0.25)
        f = 3200 - i * 300
        place(out, modes(n, [f, f * 1.5], [0.08, 0.05], [1.0, 0.4], rng), i * 0.07, 0.5)
    return out


@recipe(level=-4.0)
def ui_pause(rng, v):
    out = silence(0.4)
    for at, f in ((0.0, 659.3), (0.07, 523.3)):
        n = n_of(0.3)
        place(out, triangle(f, n) * env_exp(n, 0.1), at)
    return out


@recipe(level=-4.0)
def ui_resume(rng, v):
    out = silence(0.4)
    for at, f in ((0.0, 523.3), (0.07, 659.3)):
        n = n_of(0.3)
        place(out, triangle(f, n) * env_exp(n, 0.1), at)
    return out


@recipe()
def ui_record(rng, v):
    """Nuovo record: una piccola fanfara."""
    out = silence(1.3)
    for i, (midi, length) in enumerate([(72, 0.12), (76, 0.12), (79, 0.12), (84, 0.6)]):
        n = n_of(length + 0.2)
        f = 440 * 2 ** ((midi - 69) / 12)
        place(out, square(f, n, 0.5) * env_ad(n, 0.01, 1.0) * 0.5 + saw(f / 2, n) * env_ad(n, 0.01, 1.0) * 0.3, i * 0.12)
    return reverb(out, mix=0.25, tail=0.6)


# =============================================================================

def render(name):
    spec = RECIPES[name]
    written = []
    for v in range(spec["variants"]):
        rng = np.random.default_rng(zlib.crc32(f"{name}:{v}".encode()))
        x = np.asarray(spec["fn"](rng, v), dtype=float)
        if spec["loop"]:
            x = normalize_rms(x, spec["level"])
            path = OUT / f"{name}.ogg"
        else:
            x = normalize_peak(fade(trim(x)), spec["level"])
            path = OUT / (f"{name}_{v}.wav" if spec["variants"] > 1 else f"{name}.wav")
        write(path, x)
        written.append(path.name)
    return written


def write(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    wav = path.with_suffix(".tmp.wav") if path.suffix == ".ogg" else path
    with wave.open(str(wav), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())
    if path.suffix == ".ogg":
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5", str(path)], check=True)
        wav.unlink()


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or list(RECIPES)
    unknown = [n for n in names if n not in RECIPES]
    if unknown:
        sys.exit("Ricette sconosciute: " + ", ".join(unknown))
    with Pool() as pool:
        for files in pool.imap_unordered(render, names):
            print(" ".join(files))
    print(f"{len(names)} suoni in {OUT}")

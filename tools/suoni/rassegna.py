#!/usr/bin/env python3
"""Mette in fila tutti gli effetti in un solo file da ascoltare, con l'elenco
dei tempi: per giudicarli senza giocare. Dei suoni con più varianti suona la
prima; dei loop, 3 secondi.

Uso: python3 tools/suoni/rassegna.py uscita.ogg
"""
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from genera import OUT, RECIPES  # noqa: E402

SR = 44100
GAP = 0.7


def load(path):
    if path.suffix == ".wav":
        with wave.open(str(path)) as f:
            return np.frombuffer(f.readframes(f.getnframes()), np.int16) / 32768.0
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-f", "s16le", "-ac", "1", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16) / 32768.0


if __name__ == "__main__":
    out = Path(sys.argv[1])
    parts, lines, at = [], [], 0.0
    for name, spec in RECIPES.items():
        if spec["loop"]:
            x = load(OUT / f"{name}.ogg")
            x = np.tile(x, int(np.ceil(3 * SR / len(x))))[:3 * SR]
            x[-2000:] *= np.linspace(1, 0, 2000)
        else:
            x = load(OUT / (f"{name}_0.wav" if spec["variants"] > 1 else f"{name}.wav"))
        lines.append(f"{int(at // 60)}:{at % 60:04.1f}  {name}{'  (loop)' if spec['loop'] else ''}")
        parts += [x, np.zeros(int(GAP * SR))]
        at += len(x) / SR + GAP
    data = (np.concatenate(parts) * 32767).astype(np.int16)
    tmp = out.with_suffix(".wav")
    with wave.open(str(tmp), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp), "-c:a", "libvorbis", "-q:a", "5", str(out)], check=True)
    tmp.unlink()
    out.with_suffix(".txt").write_text("\n".join(lines) + "\n")
    print(out, f"{at:.0f} s")

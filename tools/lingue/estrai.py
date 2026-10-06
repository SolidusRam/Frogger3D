#!/usr/bin/env python3
"""Raccoglie i testi da tradurre e controlla le traduzioni.

Scrive assets/lingue/testi.pot (tutti i testi italiani del gioco) e, per ogni
lingua (assets/lingue/*.po), elenca i testi senza traduzione e quelle che non
servono più. Uso: tools/lingue/estrai.py

Dove li trova, negli script:
- tr("...") e TranslationServer.translate("...");
- le scritte fisse passate ai costruttori dell'interfaccia (_label, _button,
  _note, _text, _page, _slider, _toggle, _choice), che Godot traduce da solo;
- i cataloghi: "name", "text" e "trial" di carte, statistiche e maestria; i
  nomi di slot, azioni, tasti, pulsanti, poteri, stili, modi dello schermo.
Il test tests/test_language.gd fa lo stesso controllo dentro Godot.
"""
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
STRING = r'"((?:[^"\\]|\\.)*)"'
PATTERNS = [
    r'\btr\(\s*' + STRING,
    r'TranslationServer\.translate\(\s*' + STRING,
    r'\b(?:_label|_button|_note)\(\s*' + STRING,
    r'\b_text\(\s*"[^"]*",\s*' + STRING,
    r'\b_page\(\s*(?:\w+,\s*)?' + STRING,
    r'\b(?:_slider|_toggle|_choice)\(\s*\w+,\s*' + STRING,
    r'"(?:name|text|trial|reward_name|group|pro|contro)":\s*' + STRING,
]
# Costanti con nomi da mostrare: tutte le stringhe dentro il loro blocco.
BLOCKS = {
    "scripts/settings.gd": ["ACTIONS", "KEY_NAMES", "MOUSE_NAMES", "PAD_NAMES", "TRIGGER_NAMES", "UI_NAMES", "WINDOW_MODES"],
    "scripts/upgrades.gd": ["SLOT_NAMES"],
    "scripts/hud.gd": ["NEW_POWER", "TOKEN_NAMES"],
    "scripts/drought.gd": ["LEVELS"],
}
# Stringhe che non si traducono (codici, nomi propri, simboli).
SKIP = {"", "Frogger 3D", "Esc", "A", "B", "X", "Y", "LB", "RB", "LT", "RT", "L1", "R1", "L2", "R2",
        "L3", "R3", "Start", "Back", "Select", "Options", "Tab", "Alt", "Ctrl", "Super", "PS1", "Arcade",
        "Controller", "Menu", "Mouse 4", "Mouse 5", "Home", "Backspace", "%d/%d",
        "Lingua · Language", "Italiano", "English"}
# Testi che i modelli sopra non vedono: il limite dei fotogrammi "Nessuno"
# (scripts/options_panel.gd, dentro una funzione).
EXTRA = {"Nessuno": "scripts/options_panel.gd", "Quello della rana": "scripts/cosmetics.gd",
         "Game Boy": "scripts/style.gd"}
# Chiavi dei blocchi (nomi di azioni) da non prendere per testi.
NOT_TEXT = re.compile(r'^[a-z_]+$')


def unescape(text):
    return text.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def collect():
    found = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True)):
        rel = os.path.relpath(path, ROOT)
        if rel in ("scripts/test_mode.gd", "scripts/perf_overlay.gd"):
            continue  # strumenti da sviluppo: restano in italiano
        source = open(path, encoding="utf-8").read()
        lines = [line for line in source.split("\n") if not line.lstrip().startswith("#")]
        code = "\n".join(lines)
        for pattern in PATTERNS:
            for match in re.finditer(pattern, code):
                found.setdefault(unescape(match.group(1)), rel)
        for name in BLOCKS.get(rel, []):
            start = code.index("const " + name)
            first = code[start:].split("\n")[0].rstrip()
            if first.endswith("{"):
                end = code.index("\n}", start)
            elif first.endswith("["):
                end = code.index("\n]", start)
            else:
                end = code.index("\n", start)
            for match in re.finditer(STRING, code[start:end + 2]):
                text = unescape(match.group(1))
                if not NOT_TEXT.match(text):
                    found.setdefault(text, rel)
        if rel == "scripts/hud.gd":
            start = code.index("const POWERS")
            for match in re.finditer(r'\[\s*' + STRING, code[start:code.index("\n}", start)]):
                found.setdefault(unescape(match.group(1)), rel)
        if rel == "scripts/style.gd":
            for match in re.finditer(r'^\t\t"name":\s*' + STRING, code, re.M):
                found.setdefault(unescape(match.group(1)), rel)
    found.update(EXTRA)
    for text in list(found):
        if text in SKIP or not re.search(r'[A-Za-zÀ-ú]', text):
            del found[text]
    return found


def po_escape(text):
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def read_po(path):
    messages = {}
    current = None
    field = None
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line.startswith("msgid "):
            current = [unescape(line[7:-1]), ""]
            field = 0
        elif line.startswith("msgstr ") and current is not None:
            current[1] = unescape(line[8:-1])
            field = 1
            messages[current[0]] = current
        elif line.startswith('"') and current is not None:
            current[field] += unescape(line[1:-1])
    return {key: value[1] for key, value in messages.items() if key != ""}


def main():
    found = collect()
    with open(os.path.join(ROOT, "assets", "lingue", "testi.pot"), "w", encoding="utf-8") as pot:
        pot.write('msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n\n')
        for text, rel in found.items():
            pot.write('#: %s\nmsgid "%s"\nmsgstr ""\n\n' % (rel, po_escape(text)))
    print("%d testi in assets/lingue/testi.pot" % len(found))
    problems = 0
    for po in sorted(glob.glob(os.path.join(ROOT, "assets", "lingue", "*.po"))):
        messages = read_po(po)
        missing = [text for text in found if not messages.get(text)]
        unused = [text for text in messages if text not in found]
        print("%s: %d da tradurre, %d non servono più" % (os.path.basename(po), len(missing), len(unused)))
        for text in missing:
            print("  manca:   " + text)
        for text in unused:
            print("  inutile: " + text)
        problems += len(missing)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()

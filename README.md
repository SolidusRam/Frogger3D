# Frogger 3D

*Una rana con i superpoteri e un mondo che reagisce al caos.*

Un omaggio a Frogger in 3D, in terza persona e in stile low-poly PS1. La rana deve attraversare strade, fiumi, ferrovie, aeroporti e porti, inseguita da un incendio. Può prendere a pugni le macchine: l'auto colpita vola via e si schianta contro le altre, e i rottami diventano ostacoli, zattere e altri proiettili. Più caos si fa, più il mondo diventa pericoloso.

È un roguelite a run infinite: nelle tane si scelgono le carte per costruire la propria rana, e fra una run e l'altra si sbloccano rane, carte e cappelli.

## Giocare

Scarica lo zip per il tuo sistema dalle [Release](../../releases), estrailo e avvia `Frogger3D.x86_64` (Linux) o `Frogger3D.exe` (Windows). Non serve installare niente. Il gioco è in italiano e in inglese (si sceglie nelle opzioni).

| Comando | Tastiera e mouse | Controller |
| --- | --- | --- |
| Muoversi | WASD | Levetta sinistra |
| Guardarsi intorno | Mouse | Levetta destra |
| Salto (tenuto in aria: deltaplano) | Spazio | A |
| Pugno | Clic sinistro | RT |
| Super salto | Clic destro | RB |
| Lingua | E | LT |
| Schianto | Ctrl | B |
| Pausa | Esc | Start |
| Stile grafico (PS1, Base, Arcade…) | F2 | |

I tasti si possono riassegnare dalle opzioni. F1 apre la modalità prova (calore, biomi, carte a richiesta): è lo strumento usato durante lo sviluppo, ed è rimasto dentro.

## Dal codice

Serve [Godot 4.7](https://godotengine.org/). Si apre la cartella del progetto con Godot, oppure da terminale:

```
godot --path .
```

| Cosa | Comando |
| --- | --- |
| Test automatici | `tests/run.sh` |
| Partire già in un bioma, per provare | `tools/prova.sh --bioma=aeroporto --calore=3` |
| Build per Linux e Windows | `tools/build.sh VERSIONE` |

## Come è stato fatto

Il gioco è stato sviluppato in 12 giorni (1-12 ottobre 2026) insieme a Claude, un assistente AI di Anthropic, tramite Claude Code. Le idee, le decisioni di design e le prove di gioco sono dell'autore. Gran parte del codice, dei modelli 3D (costruiti da codice in Blender) e degli effetti sonori (generati da codice) l'ha scritta l'AI. Ogni commit lo dichiara con la riga `Co-Authored-By`.

Lo sviluppo è documentato nella cartella [docs](docs):

- [regole-design.md](docs/regole-design.md): le regole del gioco, con le decisioni datate e la roadmap;
- [cronologia.md](docs/cronologia.md): lo sviluppo giorno per giorno e le decisioni che sono cambiate;
- [idee-future.md](docs/idee-future.md): le idee accantonate e quelle in riserva;
- [porting-browser.md](docs/porting-browser.md): il tentativo, messo da parte, di una versione per il browser;
- gli studi su imprese, suono e musica.

I documenti sono in italiano.

## Licenze

Il codice è sotto licenza [MIT](LICENSE). Modelli, suoni, traduzioni e documenti sono sotto [CC BY 4.0](LICENSE-ASSETS.md); i font Lilita One e Nunito sotto SIL Open Font License.

"Frogger" è un marchio di Konami. Questo è un progetto amatoriale e gratuito, un omaggio senza legami con Konami.

---

## In English

*A frog with superpowers and a world that reacts to chaos.* A 3D, third-person, PS1-style homage to Frogger: cross roads, rivers, railways, airports and harbours while a wildfire chases you, and punch cars into each other to make your way. It's an endless-run roguelite, playable in English (set the language in the options). Download it from the [Releases](../../releases); see the controls table above. Built in 12 days with Claude Code: the design is the author's, most of the code, models and sounds were written by the AI. Code under MIT, assets under CC BY 4.0. "Frogger" is a trademark of Konami; this is an unofficial fan project.

# Frogger 3D — Imprese e sblocchi

Ultimo aggiornamento: 2026-10-04

Deciso il 4 ottobre 2026: **il mazzo delle tane parte ridotto** e si allarga con le imprese. Ogni impresa sblocca una cosa sola (una carta che entra nel mazzo delle tane, o una rana), e si vede cosa sblocca. Gli sblocchi delle imprese danno opzioni, non forza; la forza permanente si compra con le mosche (sotto). Il sistema non è ancora nel gioco: per ora tutte le carte sono nel mazzo, e la modalità prova (F1) equipaggia qualsiasi power-up.

Questo file lo compila il giocatore. Gli id delle carte sono quelli di `scripts/upgrades.gd` (CATALOG).

## Il mazzo iniziale

Le carte disponibili dalla prima run, senza imprese.

| Carta | Id |
| --- | --- |
| | |

## Imprese

| Impresa | Sblocca | Note |
| --- | --- | --- |
| | | |

## Rane

| Rana | Pro | Contro | Si sblocca con |
| --- | --- | --- | --- |
| Comune | — | — | dall'inizio |
| | | | |

## Deciso: quando la tana non ha più niente da offrire

Con tutti gli slot pieni e i numerici al massimo, la tana non resta vuota: dà qualcosa al posto della carta, come in Vampire Survivors (deciso il 4 ottobre 2026). Proposta: vita piena e una manciata della valuta di gioco (sotto).

## Brainstorming del 4 ottobre (proposte, da scegliere)

### La valuta: le mosche (decisa il 4 ottobre 2026)

Nel Frogger originale la mosca nella tana dava punti in più: qui le mosche sono la valuta di gioco, come l'oro di Vampire Survivors. Si raccolgono durante la run e si spendono **alla fine della partita**.

**Dove stanno** (deciso): in posizioni predefinite e casuali, **sopra le cose che si muovono**: il tetto di un'auto, il dorso di un coccodrillo, un tronco, il tetto di un treno, l'ala di un aereo, il ponte di una nave. Per prenderle bisogna salirci, o arrivarci con la lingua. **Non** attorno ai rottami: il caos non c'entra.

**Cosa comprano** (deciso): come in Vampire Survivors, **forza permanente**: potenziamenti delle statistiche e miglioramenti delle carte, che valgono per le run successive. Qui la regola "sblocchi di opzioni, mai forza" non vale: vale per le imprese, non per le mosche.

Proposte di Claude, da scegliere:
- **Quante e quanto valgono**: una mosca su circa un'auto su 12, un tronco o un coccodrillo su 6, un treno su 3, un aereo o una nave su 2. Vale 1; la **mosca d'oro**, rara e solo su treni e aerei, vale 5. Una manciata in ogni tana (di più quando la tana non ha carte).
- **Statistiche** (ognuna a livelli, il prezzo sale a ogni livello): vita, velocità, altezza del salto, ricarica dei poteri, durata del deltaplano, vantaggio sull'incendio (parte più lontano), meno calore dai poteri, raggio di raccolta delle mosche, un gettone Rilancia in più a ogni run.
- **Carte migliorate**: ogni carta con slot ha due miglioramenti da comprare (per esempio guantoni esplosivi: raggio da 6 a 8 m, poi esplosione immediata). Sono i "livelli" delle carte, ma comprati fra una run e l'altra.
- **Gettoni della tana** (Rilancia, Salta, Esilia) e **cose da vedere** (cappelli, colori, stili).

### Imprese

Ogni impresa con la sua proposta di sblocco. Le categorie servono a far giocare in modi diversi, non solo più lontano.

**Percorso**
| Impresa | Sblocca (proposta) |
| --- | --- |
| Raggiungi la tana 3 | Molle-trampolino |
| Raggiungi la tana 10 | La raganella |
| Fai 500 m in una run | Schianto sismico |
| Fai 2000 m in una run | Uno stile grafico nuovo |
| Arriva al primo porto | Lingua-rampino |
| Sopravvivi 15 minuti | Il gettone Esilia |

**Caos**
| Impresa | Sblocca (proposta) |
| --- | --- |
| Fai una catena di 6 rottami | Montante |
| Fai una catena di 15 rottami | Guantoni magnetici (da fare) |
| 50 rottami in una run | La rana pugile |
| Un'auto esplosa ne fa esplodere altre tre | Napalm (la fusione entra nel mazzo) |
| Un rottame scagliato dal getto di un aereo colpisce un'auto | Ala a reazione |
| Un container cade su un'auto | Il gettone Rilancia |

**Biomi**
| Impresa | Sblocca (proposta) |
| --- | --- |
| Attraversa un fiume senza toccare l'acqua né un tronco | Ala più grande |
| Viaggia 100 m sul tetto di un treno | La rana pompiere |
| Arriva al bordo seduta sull'ala di un aereo | Occhiali da pilota (cappello) |
| Viaggia su una nave mentre la gru la carica | Pelle impermeabile |
| Schiva il rapido a meno di 2 m | Molle rapide |
| Attraversa il raccordo durante un decollo | Elmetto del pompiere (cappello) |

**Poteri**
| Impresa | Sblocca (proposta) |
| --- | --- |
| Plana 50 m in un solo volo | Correnti calde |
| Sali oltre 10 m nel getto di un aereo | La rana paracadutista |
| Fatti trascinare dalla lingua per 40 m | Lingua elastica (da fare) |
| Uno schianto ribalta 5 auto | Terremoto (la fusione entra nel mazzo) |
| Rimbalza 10 volte di fila sui tetti | Molle a razzo (da fare) |

**Calore e incendio**
| Impresa | Sblocca (proposta) |
| --- | --- |
| Arriva al livello 5 di calore | Benzina sul fuoco (da fare) |
| Resta 2 minuti al livello 5 | La rana dorata |
| Raggiungi una tana col fuoco a meno di 5 m | Il gettone Salta |
| Arriva alla tana 3 senza mai usare il pugno | Il rospo |
| Arriva alla tana 3 senza usare poteri | Una modalità di sfida: "Calma piatta" |

**Segrete e ironiche** (non si vedono finché non si fanno)
| Impresa | Sblocca (proposta) |
| --- | --- |
| Muori travolta da un'auto che hai colpito tu | Cappello "Boomerang" |
| Muori bruciata dall'incendio | Rana carbonizzata (colore) |
| Un coccodrillo ti morde mentre sei appesa alla lingua | Rana di fiume |
| Ti schiaccia un container | Cappello "Elmetto da cantiere" |

### Rane

Ognuna cambia come si gioca, con un pro e un contro.

| Rana | Pro | Contro |
| --- | --- | --- |
| Comune | equilibrata | — |
| Pugile | parte col montante, pugno più forte | 75 di vita |
| Paracadutista | deltaplano che dura il doppio | super salto lento a ricaricarsi |
| Rana di fiume | parte con la pelle impermeabile, nuota veloce | lenta a terra |
| Raganella | salto normale molto più alto | 70 di vita |
| Rospo | 150 di vita | niente deltaplano |
| Rana pompiere | l'incendio corre al 70% | i poteri scaldano il doppio |
| Rana dorata | chi la investe diventa rottame (è velenosa) | ogni colpo toglie il doppio |

### Altri sblocchi possibili

- **Modalità di sfida**: "Calma piatta" (niente poteri), "Notte eterna" (calore al livello 4 da subito, solo fari), "Solo strade", "Corsa all'incendio" (il fuoco parte a 20 m).
- **Stili grafici**: altri oltre a PS1, Base e Arcade.
- **Lo stagno**: la schermata fra una run e l'altra, dove si spendono le mosche e si vedono le imprese.

## Primi esempi (sostituiti dal brainstorming qui sopra)

| Impresa | Sblocca |
| --- | --- |
| Raggiungi la tana 3 | Molle-trampolino |
| Fai una catena di 6 rottami | Montante |
| Attraversa un fiume senza toccare l'acqua né un tronco | Ala a reazione |
| Viaggia su una nave mentre la gru la carica | Lingua-rampino |
| Resta 60 s al livello 3 di calore | La rana pugile |
| Fai 500 m in una run | Schianto sismico |

| Rana | Pro | Contro |
| --- | --- | --- |
| Pugile | parte col montante, pugno più forte | meno vita |
| Paracadutista | deltaplano più lungo | super salto più lento a ricaricarsi |
| Rana di fiume | parte con la pelle impermeabile | più lenta a terra |

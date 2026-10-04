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

**Nel gioco** (fatto il 4 ottobre 2026; numeri da tarare giocando):
- **Dove**: su circa un'auto su 12, un tronco o un coccodrillo su 6, un vagone su 3, un aereo o una nave su 2 (sull'ala, sopra una casella). Vale 1; la **mosca d'oro** (il 20% delle mosche su treni e aerei) vale 5. Si prende toccandola (raggio 1,1 m) o con la lingua, che la mangia a distanza senza agganciarsi e che col mirino la preferisce. Ogni tana ne dà 3; una tana senza carte da offrire dà vita piena e 8 mosche.
- **Quando si spendono**: la fine della run le somma al totale (una run di prova no). Lo **stagno** si apre dal menu iniziale e dalla fine della run.
- **Statistiche** (livelli massimi; prezzo base, il livello n costa base × n): Vita +10 (5; 15), Corazza -5% di danno (4; 25), Riposo +15% di vita in tana (3; 20), Riflessi +0,25 s di invulnerabilità (2; 20), Zampe veloci +4% (4; 20), Zampe forti +8% di salto (3; 20), Nuotatrice +15% in acqua e -15% di danno dall'acqua (3; 15), Molle tese +0,5 m di super salto (3; 25), Ricarica -6% (4; 30), Pugno +10% (3; 20), Ala +0,3 s (4; 20), Vantaggio: incendio 5 m più lontano (4; 30), Sangue freddo -6% di calore dai poteri (4; 30), Lingua lunga +0,7 m di raggio per le mosche (3; 10), Golosa +10% di mosche (3; 30), Fortuna +50% di mosche d'oro (3; 25), Più scelta: una carta in più nelle tane (1; 150), Seconda vita: una volta per run ci si rialza con metà vita (1; 200).
- **Carte migliorate** (due per carta, valgono quando la si equipaggia): guantoni esplosivi (raggio 8 m; le esplosioni non feriscono la rana), montante (auto più in alto; +40% di spinta), guantone a molla (5,5 m; zona larga il doppio), molle-trampolino (3,6 m; rimbalzando ribalti l'auto sotto), schianto sismico (+2 m; ricarica in 1 s), correnti calde (si sale più in fretta; fumo 9 s), ala a reazione (scalda la metà; 20 m/s), pelle impermeabile (nuoto veloce; dall'acqua si salta fuori come da terra), lingua (16 m; ricarica dimezzata).
- **Rimborso**: si azzera tutto e le mosche tornano indietro, come in Vampire Survivors.

Ancora da fare: i gettoni della tana (Rilancia, Salta, Esilia) e le cose da vedere (cappelli, colori, stili). Altre statistiche possibili: spinta dello schianto, durata della seconda vita, mosche d'oro anche su auto e navi.

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

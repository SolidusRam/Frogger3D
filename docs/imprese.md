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
- **Dove**: su circa un'auto su 12, un tronco o un coccodrillo su 6, un vagone su 3, un aereo o una nave su 2 (sull'ala, sopra una casella). Vale 1; la **mosca d'oro** (il 20% delle mosche su treni e aerei) è una valuta a sé, per la maestria delle carte. Si prende toccandola (raggio 1,1 m) o con la lingua, che la mangia a distanza senza agganciarsi e che col mirino la preferisce. Ogni tana ne dà 3; una tana senza carte da offrire dà vita piena e 8 mosche.
- **Quando si spendono**: la fine della run le somma al totale (una run di prova no). Lo **stagno** si apre dal menu iniziale e dalla fine della run.
- **Statistiche** (livelli massimi; prezzo base, il livello n costa base × n): Vita +10 (5; 15), Corazza -5% di danno (4; 25), Riposo +15% di vita in tana (3; 20), Riflessi +0,25 s di invulnerabilità (2; 20), Zampe veloci +4% (4; 20), Zampe forti +8% di salto (3; 20), Nuotatrice +15% in acqua e -15% di danno dall'acqua (3; 15), Molle tese +0,5 m di super salto (3; 25), Ricarica -6% (4; 30), Pugno +10% (3; 20), Ala +0,3 s (4; 20), Vantaggio: incendio 5 m più lontano (4; 30), Sangue freddo -6% di calore dai poteri (4; 30), Lingua lunga +0,7 m di raggio per le mosche (3; 10), Golosa +10% di mosche (3; 30), Fortuna +50% di mosche d'oro (3; 25), Più scelta: una carta in più nelle tane (1; 150), Seconda vita: una volta per run ci si rialza con metà vita (1; 200).
- **La maestria delle carte** (decisa il 4 ottobre 2026, al posto dei miglioramenti comprati): ogni carta con slot ha due miglioramenti speciali, che cambiano come si usa la carta. Ognuno ha una prova legata all'uso della carta; superata la prova, si attiva allo stagno con le **mosche d'oro** (2 per il primo, 4 per il secondo), che sono una valuta a sé: la mosca d'oro non vale più 5 mosche. Le prove "in tutto" si sommano fra le run; quelle "in un colpo" o "di fila" tengono il risultato migliore. Una run di prova non le fa avanzare.

  | Carta | Miglioramento | Prova |
  | --- | --- | --- |
  | Guantoni esplosivi | Reazione a catena: le auto distrutte esplodono a loro volta (fino a 3 passaggi) | Fai esplodere 30 auto |
  | | Razzo: l'esplosione vicina non ferisce, lancia in alto | Distruggi 4 auto con una sola esplosione |
  | Montante | Meteora: l'auto lanciata ricade con un'onda | Lancia 30 auto col montante |
  | | Doppio montante: il pugno arriva anche in alto | Un'auto lanciata ne ribalta un'altra ricadendo |
  | Guantone a molla | Perforante: tutte le auto sulla linea | Colpisci 25 auto da più di 3 m |
  | | Tira e molla: l'auto viene tirata, poi scagliata più forte | Colpisci 2 auto con un solo pugno |
  | Molle-trampolino | Crescendo: ogni rimbalzo di fila più alto | Rimbalza 50 volte sui tetti |
  | | Bombardiera: rimbalzando si ribalta l'auto sotto | Rimbalza 6 volte di fila |
  | Schianto sismico | Doppia onda: mezzo secondo dopo, un'onda più larga | Ribalta 40 auto con lo schianto |
  | | Dal cielo: più si cade dall'alto, più l'onda è grande | Ribalta 5 auto con un solo schianto |
  | Correnti calde | Fenice: nel fumo si recupera vita | Sali per 100 m nel fumo |
  | | Camino: anche il fumo davanti all'incendio solleva | Resta 6 s di fila in una colonna di fumo |
  | Ala a reazione | Postbruciatore: le auto sotto l'ala diventano rottami | Vola 800 m con l'ala a reazione |
  | | Raffreddata: in volo il calore non sale | Vola 60 m in un solo volo |
  | Pelle impermeabile | Tuffo: in acqua, Ctrl, si va sotto tronchi e coccodrilli | Nuota per 300 m |
  | | Ondata: saltando fuori dall'acqua si spingono via auto e rottami | Resta 15 s di fila in acqua |
  | Lingua | Fionda: lasciando dopo un traino si parte a velocità doppia | Fatti trascinare 20 volte |
  | | Lingua doppia: mentre la lingua trascina, le mosche vicine finiscono in bocca | Fatti trascinare per 50 m in un solo traino |

  Da rivedere in futuro: il bilanciamento dei miglioramenti e delle prove.

  **Maestria delle carte nuove** (proposta del 6 ottobre 2026, da rivedere: le carte sono nel mazzo deciso, riga "Mazzo deciso" di regole-design.md, ma non ancora nel gioco):

  | Carta | Miglioramento | Prova |
  | --- | --- | --- |
  | Guantoni di ghiaccio | Pista: il blocco colpito scivola il doppio e congela ciò che urta | Congela 30 auto |
  | | Iceberg: sul blocco ci stai anche in acqua, è una zattera | Un blocco di ghiaccio ne travolge 3 |
  | Molle da canguro | Marsupio: atterrare in acqua o su un tetto non azzera il ritmo | Fai 300 saltelli a ritmo |
  | | Salto lungo: al ritmo massimo un saltello scavalca una corsia | Fai 15 saltelli di fila |
  | Molle a razzo | Terzo stadio: un terzo salto in aria | Fai 40 secondi salti |
  | | Scia di fuoco: il secondo salto lascia sotto una fiammata che fa rottami | Supera 12 m d'altezza |
  | Ala corazzata | Ariete: in volo, l'auto che tocchi diventa rottame | Assorbi 10 colpi in volo |
  | | Blindata: assorbe due colpi per volo | Vola 40 m in un solo volo |
  | Ala a elica | Turbina: sospesa, l'elica spinge via le auto sotto di te | Resta sospesa 60 s in tutto |
  | | Seme d'acero: la sospensione dura il doppio | Resta sospesa mentre ti passano sotto 4 auto |
  | Guscio | Spine: l'auto che rompe il guscio diventa rottame | Il guscio para 20 colpi |
  | | Guscio rapido: si ricarica in metà tempo | Para 3 colpi nella stessa sezione |
  | Assicurazione | Franchigia: ti salva con 30 di vita invece di 1 | L'assicurazione ti salva 5 volte |
  | | Premio: quando ti salva, il calore non sale | Salvata, raggiungi la tana senza altri colpi |
  | Rana velenosa | Tossina: il rottame avvelenato avvelena le auto che lo urtano | Avvelena 30 auto |
  | | Antidoto: le auto ti colpiscono a metà danno | Avvelena 3 auto in 5 s |
  | Lingua mangiafuoco | Raffica: tre palle più piccole invece di una | Sputa 30 palle di fuoco |
  | | Drago: la palla esplode e fa rottami intorno | Una palla di fuoco fa partire una catena di 4 rottami |
  | Lingua-catapulta | Lancio lungo: gittata doppia | Scaglia 30 rottami |
  | | Strike: il rottame scagliato rimbalza da un'auto all'altra | Un rottame scagliato ne colpisce 2 |
  | Lingua-ancora | Ancora pesante: tiene 8 s invece di 4 | Ferma 40 cose |
  | | Doppia ancora: due ancore insieme | Passa su 3 tronchi ancorati in una sola traversata |
- **Rimborso**: si azzera tutto e le mosche (anche quelle d'oro) tornano indietro, come in Vampire Survivors; le prove superate restano superate.

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

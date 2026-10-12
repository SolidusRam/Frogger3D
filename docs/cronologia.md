# Cronologia dello sviluppo

Materia prima per il post sul blog: cosa è successo, in che ordine, e quali decisioni sono cambiate strada facendo. Fonti: la storia dei commit e i documenti di design (regole-design.md, idee-future.md, imprese.md, studio-suono.md). Le osservazioni in fondo sono spunti da discutere, non conclusioni.

## In numeri (al 12 ottobre 2026)

| Cosa | Quanto |
| --- | --- |
| Durata | 12 giorni di calendario (1-12 ottobre 2026), di cui 7 con commit; l'idea è del 30 settembre |
| Commit | 128, tutti scritti insieme a Claude (Claude Code) |
| Codice del gioco | 64 script GDScript, circa 15.200 righe |
| Test automatici | 45, circa 5.300 righe |
| Strumenti | screenshot senza finestre, benchmark, modalità prova, generatore di suoni: circa 2.400 righe |
| Modelli 3D | 57, costruiti da codice in Blender |
| Suoni | 71 effetti (147 file con le varianti), generati da codice |
| Documenti di design | circa 23.000 parole |
| Motore | Godot 4.7, fisica Jolt |

## Prima del codice: l'idea (30 settembre)

L'idea nasce in una sessione di ideazione: un remake 3D di Frogger, caotico. Le decisioni prese prima di scrivere una riga:

- **Terza persona**, mouse e tastiera, **low-poly** in stile Megabonk, modelli in Blender.
- **Una rana coi poteri**: super salto, pugno alle macchine per farle schiantare fra loro, deltaplano per il fiume.
- **Caos emergente** ("proprio ciò che volevo"): nasce da regole semplici che si incrociano, non da eventi scritti a mano.
- **Escalation alla GTA**: più caos fai, più il mondo reagisce. Il "calore" sale col tempo e non cala mai.
- Motore **Godot**, movimento libero (non a griglia), vita al posto della morte al primo colpo.

Le decisioni stavano in un documento online, commentato riga per riga. Dal 1° ottobre la fonte unica diventa `docs/regole-design.md`, dentro il progetto.

## Giorno per giorno

### 1° ottobre: il gioco base in un giorno

- **01:06** il prototipo: rana, strada con traffico "ibrido" e fiume. Le auto guidano su binari invisibili e diventano rottami fisici solo quando vengono colpite forte. Undici minuti dopo ci sono già super salto e deltaplano.
- **Pomeriggio**: percorso infinito a sezioni con le tane; calore, fine della run e HUD. Il commit delle 17:16 dice "gioco base completo".
- **Sera**: stili grafici (lo stile PS1 diventa quello predefinito), i primi modelli in Blender, i test automatici, i power-up nelle tane.
- **Notte**: ferrovia (il treno è l'unico veicolo che non diventa mai rottame), poi aeroporto e porto.

Il 2 e 3 ottobre non ci sono commit.

### 4 ottobre: il giorno delle decisioni (38 commit)

- I biomi diventano pericolosi: la fiamma dei motori, i bagagli scagliati, le gru che inseguono. Il porto viene rifatto con le navi portacontainer.
- **15:09, le decisioni di fondo**: il gioco diventa un **roguelite a run infinite**, la forza si guadagna solo nelle tane, e "si pubblica comunque, senza budget".
- Arriva **l'incendio che insegue la rana**: la spinta ad andare avanti e la fine della run insieme.
- Poi, in serata: lingua-rampino e schianto sismico; le mosche come valuta; lo stagno (forza permanente alla Vampire Survivors); la maestria delle carte; il menu sopra il gioco vivo.

### 5 ottobre: la cornice

- La rana, i tronchi e i coccodrilli diventano modelli di Blender; animazioni della rana; la tana diventa uno stagno con fiori e lucciole.
- L'aeroporto viene rifatto: gli aerei atterrano, e metà atterra di pancia.
- **Lo studio del suono** (ruolo, identità, riferimenti: Megabonk e Castlevania, ascolti dalla PS1), poi 71 effetti generati da codice in un'ora.
- Opzioni, controller, la traduzione inglese, i suggerimenti del primo minuto al posto di un tutorial.
- **La prima prova vera da giocatore**: il porto nuovo, l'aeroporto, l'incendio che accelera, i gradini di difficoltà. Un solo problema segnalato (la tana che fermava la rana troppo presto), corretto.

### 6 ottobre: il roguelite prende forma

- Il mazzo da 20 carte, 4 per attrezzo. **Ogni rana parte con un solo attrezzo**: si parte coi soli guantoni.
- Le imprese sbloccano carte; sei rane diverse; i gettoni della tana (Rilancia, Salta, Esilia); il guardaroba; lo stile Game Boy; la Siccità, cinque livelli di difficoltà per rana.

### 7 ottobre: attrezzi in due passi, e i mondi su carta

- Prima l'attrezzo semplice, poi le sue modifiche; carte rare ed epiche.
- **Sera e notte, solo design**: i mondi. Un giro alla Risk of Rain 2, un teletrasporto che compare al calore massimo e lascia indietro l'incendio, il punteggio dal caos. Dodici commit di decisioni fra le 20:09 e le 00:42.

### 8 ottobre: il cielo

- Il secondo mondo in una mattina. Al posto dell'acqua c'è il vuoto, nuvole al posto dei tronchi, aquile al posto dei coccodrilli. I veicoli diventano mezzi volanti, il treno una funivia, l'incendio un temporale.
- Il bioma esclusivo del cielo: **la pattuglia acrobatica**, aerei in formazione con giri della morte, su cui si può salire.

### 9 ottobre: il tentativo del browser

- La pubblicazione si ridimensiona: niente Steam, il gioco solo nel browser, su un sito proprio.
- La build web parte, ma gira a 1-3 fps in Firefox. Due cause trovate: troppe chiamate di disegno (2.700, ridotte a 1.500) e una perdita di memoria dell'audio di Godot nel browser (la scheda arrivava a 3 GB). Una terza causa, in Firefox, resta sconosciuta.
- Un incidente: un test di Chromium con la scheda grafica vera riempie la RAM e blocca il pc.

### 12 ottobre: si mette da parte

- Il porting nel browser viene messo da parte; main torna alla versione dell'8 ottobre. Il lavoro resta nel branch `web`, il resoconto in `docs/porting-browser.md`.
- Nuova direzione: il gioco su GitHub, lo sviluppo raccontato in un post, e un'opinione sullo sviluppo dei videogiochi.

## Le decisioni che sono cambiate

| Prima | Poi | Quando | Perché |
| --- | --- | --- | --- |
| Il caos dà esperienza, raccolta a terra fra i rottami | Il caos non dà forza ("per ora"): la forza viene solo dalle tane | 4 ottobre | L'ingorgo sarebbe diventato il posto più comodo per raccogliere esperienza |
| I tre poteri ci sono da subito | Si parte coi soli guantoni, gli altri attrezzi arrivano dalle carte | 6 ottobre | Rane diverse con attrezzi diversi; le build nascono nelle tane |
| L'HUD annuncia la soglia del caos e i gradini di difficoltà | Annunci tolti | 4 ottobre | Su richiesta, dopo averli visti |
| L'aeroporto coi decolli | Gli aerei atterrano, metà di pancia | 5 ottobre | L'aeroporto era da rifare |
| Il porto coi nastri trasportatori | Il porto con le navi e le gru | 4 ottobre | Il porto era da rifare; i nastri restano per un futuro magazzino |
| Un bivio paradiso/inferno scelto dal calore | Mondi in sequenza dentro la run | 7 ottobre | Scartato il bivio |
| Una build "fredda" che premia la prudenza | Scartata | 6 ottobre | — |
| Pubblicazione: pagina Steam, demo per la Next Fest, uscita a 5-8 € | Solo browser, sito proprio | 9 ottobre | Obiettivi ridimensionati |
| Solo browser | Messo da parte; GitHub e un post | 12 ottobre | Nel browser il gioco restava a 1-3 fps |

## Spunti per il post (da discutere)

- **Il ritmo.** Il gioco base in 16 ore, e "gioco base completo" alle 17:16 del primo giorno. Dopo, ogni giorno ha aggiunto sistemi, quasi mai tolti. Che cosa ha reso possibile questo ritmo, e che cosa è costato?
- **Decidere contro provare.** Le decisioni sono tutte scritte e datate. La lista "Da provare giocando" è cresciuta più in fretta di quello che è stato provato davvero, e il criterio della fase 1 (5-10 persone esterne che vogliono rigiocare) non è mai stato messo alla prova.
- **Le notti di design.** Molte decisioni sono arrivate di sera tardi, in raffica (i mondi: dodici commit dopo le 20). Il codice arrivava la mattina dopo.
- **I ripensamenti come materiale.** La tabella qui sopra racconta il game design meglio dell'elenco delle feature.
- **Il browser.** Un gioco che "funzionava" crolla in un contesto nuovo per ragioni invisibili dal gioco stesso. Cosa dice di quanto serve capire cosa c'è sotto?
- **L'AI.** Ogni commit porta la riga `Co-Authored-By: Claude`. Cosa hai fatto tu: le idee, le scelte, il gusto, le prove. Cosa ha fatto l'AI: gran parte del codice, dei modelli e dei suoni. Dove sta la linea, e conta per chi gioca?

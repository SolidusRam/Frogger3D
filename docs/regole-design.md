# Frogger 3D — Regole di design

Ultimo aggiornamento: 2026-10-04

## Visione

Una rana con i superpoteri attraversa all'infinito strade e fiumi. Il caos che provoca le dà forza, ma rende il mondo sempre più ostile.

Il Frogger originale parla di una creatura fragile in un mondo indifferente. Qui la rana può reagire, e il mondo reagisce a sua volta: più caos provochi, più il mondo ti dà la caccia.

Riferimenti:

- **Frogger**: gli ostacoli (strada, fiume, coccodrilli) e le tane.
- **Megabonk**: grafica low-poly, esperienza e oggetti durante la run, alta intensità.
- **GTA**: il livello di ricercato, cioè il mondo che reagisce alle tue azioni.
- **Risk of Rain**: la difficoltà sale col tempo e non si ferma mai.
- **Left 4 Dead (AI Director)**: l'intensità arriva a ondate, con momenti in cui si respira.
- **Burnout (modalità Crash)**: tamponamenti a catena come fonte di punti.

## Regole decise

Il cuore del gioco è uno scambio: ogni potere usato ti rende più forte ma accelera l'ostilità del mondo, che non torna mai indietro.

```mermaid
flowchart LR
    P["Usi un potere"] --> XP["Esperienza e oggetti"] --> F["Rana più forte"]
    P --> H["Il calore sale"] --> O["Mondo più ostile"]
    T["Il tempo passa"] -. anche senza poteri .-> H
    F -- più forza per altro caos --> P
    O -- più pericoli: servono di nuovo i poteri --> P
```

Il calore sale anche se il giocatore non fa nulla; i poteri lo accelerano, ma sono anche l'unico modo di diventare più forti.

| Area | Regola |
| --- | --- |
| Motore | Godot |
| Telecamera | Terza persona, dietro la rana |
| Controlli | Mouse e tastiera. Provvisori: WASD movimento, mouse telecamera, Spazio salto (premuto di nuovo in aria e tenuto: deltaplano), tasto sinistro pugno, tasto destro super salto, Esc pausa |
| Movimento | Libero, non su griglia |
| Grafica | 3D low-poly in stile Megabonk, modelli fatti in Blender. Stile scelto: PS1 sgranato (gli altri, Base e Arcade, restano disponibili con F2). Tutti i materiali vengono da una tavolozza per stile, scelti per nome del materiale. I modelli si costruiscono con assets/models/build_models.py (Blender): ogni modello ha il suo .blend da ritoccare a mano e il .glb per Godot |
| Ferrovia | Da 1 a 3 binari. Il treno (locomotiva e 3-5 vagoni tra carri chiusi, alti, e pianali, bassi) è l'unico veicolo che non diventa mai rottame: travolge auto e rottami e toglie 60 di vita alla rana; sul tetto si viaggia sicuri. Avviso leale: le luci dei pali lampeggiano 2,5 s prima che il muso entri nella zona di gioco, e l'avviso non cala col calore; il calore rende i treni più veloci solo fino al +30% |
| Aeroporto | Dalla terza sezione. Aerei di linea in rullaggio, enormi e lenti (7 m/s, fino a +30% col calore), che non diventano mai rottami: fusoliera, motori e carrelli travolgono (35 alla rana), sotto le ali si passa, su ali e fusoliera si sta sicuri. Il pericolo è dietro: per 7 m dietro ogni motore una fiamma visibile brucia (60 di vita al secondo); poi il getto, un cono che si allarga fino a 8 m e sale fino a 12 m, reso visibile da strisce d'aria, spinge via la rana (vento fino a 16 m/s) e scaglia i rottami. Sotto le ali, accanto ai motori, corrono due strade di servizio con i trenini bagagli (un trattorino e 2-4 carrelli carichi di valigie e pacchi, 5-8 m/s): non diventano mai rottami, ci si sale sopra, fa male solo il muso del trattorino (15). Quando il getto investe i carrelli porta via il carico e lo scaglia all'indietro a 12-25 m/s, aperto a ventaglio: un bagaglio che arriva addosso veloce toglie 10. Il pugno fa volare i bagagli, anche dai carrelli. Col deltaplano il getto è un ascensore: si sale fino a 10 m/s, si rallenta, il vento spinge la metà e la carica non si consuma (con super salto e deltaplano aperto dentro il getto si arriva a circa 11 m). |
| Porto | Dalla terza sezione. Nastri trasportatori che portano di lato (3-5 m/s) e due gru a portale che lasciano cadere container. Quando mira alla rana, la gru la insegue e calcola dove sarà quando il container tocca terra (il nastro compreso): l'ombra lampeggia mentre insegue, poi resta accesa fissa negli ultimi 0,6 s, quando la gru si blocca (0,45 s al calore massimo). L'avviso dura 1,5 s (1,1 al calore massimo); il container è spinto giù e pesa, e tocca terra in circa 0,7 s (prima 1,4). Toglie 50; a terra resta come ostacolo e piattaforma e i nastri lo trascinano. Col calore la gru mira più spesso (dal 25% a quasi sempre), è più veloce (da 6 a 11 m/s) e ricarica prima |
| Veicoli | Quattro tipi: utilitaria, berlina, furgone, camion (danno 20, 25, 30, 40). Ruote che girano, fari e fanali che si accendono di notte, collisione su misura (si sta sul cofano; la cabina del camion è più bassa del rimorchio) |
| Sfondo | Montagne all'orizzonte e una pianura sotto il piano di gioco, che seguono la rana; ai lati alberi, case e lampioni |
| Colori e calore | Il calore sposta l'ora del giorno come nel dinosauro di Google: giorno, tramonto, notte; lampo invertito a ogni nuovo livello. Di notte le minacce restano leggibili (nello stile arcade brillano) |
| Personaggio | Una rana con gli attrezzi: guantoni da boxe grandi, molle sotto le zampe, deltaplano a delta a strisce con telaio, che si apre e si chiude con un'animazione |
| Animazioni | Fermo-immagine di 110 ms solo quando il pugno colpisce un'auto, con il guantone già disteso, lampo d'impatto e scossa della telecamera; rallentatore e telecamera larga sulle catene di 4 o più rottami vicino alla rana; schiacciamento e allungamento della rana; sospensioni e sobbalzo di spavento delle auto; scintille e fumo dai rottami |
| Ostacoli | Autostrada, fiume, coccodrilli |
| Poteri | Super salto, pugno alle macchine, deltaplano: poteri base, disponibili da subito; in futuro poteri nuovi o potenziamenti di quelli base |
| Struttura della run | Infinita: si gioca finché non si muore |
| Giocatori | Singleplayer per ora; multiplayer cooperativo possibile in futuro |
| Tana | Checkpoint lungo il percorso, non la fine: salva il record su disco e diventa il punto di ripartenza se si cade fuori dal mondo, ma la morte chiude la run |
| Power-up | Si scelgono nelle tane, uno tra tre, a gioco fermo. Gli slot sono gli attrezzi della rana (guantoni, molle, ala, corpo): un modificatore per slot, e uno nuovo sostituisce il precedente. I potenziamenti numerici non hanno slot e si sommano fino a 3 volte. I tre freni contro un gioco troppo facile: slot, scelta tra tre, calore |
| Power-up attuali | Guantoni esplosivi (l'auto colpita esplode al primo urto con un veicolo, o dopo 1,2 s: le auto nel raggio di 6 m diventano rottami e volano; la rana entro 4,5 m perde 30). Correnti calde (col deltaplano, il fumo dei rottami solleva come un ascensore e la carica non si consuma; il fumo dura 6 s). Numerici: pugno più forte, molle rapide, ala più grande, pelle dura |
| Fine della run | Quando la vita finisce: schermata con distanza, tane, tempo, calore massimo e record; Invio o il pulsante fanno ricominciare da zero |
| Percorso | Infinito, a sezioni: strade, fiumi, ferrovie (dalla seconda sezione), aeroporti e porti (dalla terza), separati da strisce sicure, poi una tana. Ogni sezione ha più corsie e veicoli e correnti più veloci; i fiumi hanno sempre terra su entrambi i lati. Muri invisibili ai lati della zona di gioco |
| Calore | Un'unica barra da 0 a 100 in 5 livelli, per strada e palude insieme; sale di continuo col tempo (0,15 al secondo); i poteri (pugno +1, deltaplano +2, super salto +3) e ogni rottame entro 50 m dalla rana (+0,6: conta il caos che si vede, non quello di un aeroporto lontano) lo fanno salire più in fretta; non cala mai. Effetti al massimo: veicoli e correnti più veloci (+80% e +40%), veicoli un po' più radi (+25% di spazio): meno auto ma più veloci, così il traffico minaccia invece di ingorgarsi, frenata -60%, schianti più facili; dal 60% le auto perdono il controllo da sole. Al massimo 80 rottami insieme |
| Ritmo | Ondate di pericolo sopra una base che cresce sempre |
| Ricompensa | Provocare caos dà esperienza o oggetti, in stile Megabonk |
| Vita | Statistiche e vita che crescono durante la run; auto, acqua e coccodrilli tolgono vita: un solo colpo non basta a perdere |
| Sconfitta | Colpito dalle macchine (anche quelle che hai colpito tu), mangiato dal coccodrillo, caduto in acqua |
| Traffico | Ibrido: le auto guidano in modo cinematico e diventano rottami fisici quando vengono colpite forte; un rottame che colpisce un'auto la trasforma a sua volta. Con il calore alto il traffico passa alla fisica e diventa instabile da solo. I veicoli frenano davanti agli ostacoli e si formano code; se non fanno in tempo a fermarsi si schiantano. I rottami spariscono dopo 25 s |
| Tetto dei veicoli | Si può stare sul tetto: non fa danno e la rana viene trasportata, come su un tronco |
| Sbalzo | Un veicolo che colpisce la rana la butta di lato, fuori dalla corsia, anche nella corsia accanto |
| Acqua | Chi cade in acqua galleggia, nuota lento, segue la corrente e perde 20 di vita al secondo. Per uscire serve un salto tenuto premuto |
| Rottami nel fiume | Galleggiano e seguono la corrente: un'auto lanciata nel fiume diventa una zattera |
| Coccodrilli | La schiena è sicura; la bocca si apre a intervalli e morde |
| Urti | Fa male solo un veicolo che ti viene addosso: chi viaggia insieme a un veicolo, sopra o accanto, non si fa male, e nemmeno chi sbatte contro un veicolo fermo. I rottami che galleggiano sono zattere e non fanno mai male |
| Caos | Deve essere emergente: nasce da regole semplici che si incrociano, non da eventi scritti a mano |

## Roadmap

Ogni passo si aggiunge solo quando il precedente è divertente. L'ordine dei passi da fare è una proposta e si può riordinare.

### Dove siamo (4 ottobre 2026)

Il gioco base è finito e giocabile: una run infinita in cui si muore e si ricomincia. Sopra il gioco base ci sono già i modelli in Blender, i power-up nelle tane e tre biomi. Manca ancora metà del ciclo del gioco: oggi il caos fa salire solo il calore, e la rana si rafforza solo nelle tane. "Il caos ti dà forza" non esiste ancora.

### Fatto

| Passo | Cosa c'è |
| --- | --- |
| Gioco base | Rana in terza persona, strade con traffico ibrido (auto cinematiche che diventano rottami fisici), fiumi con tronchi e coccodrilli, vita, percorso infinito a sezioni con le tane, calore, fine della run e record su disco |
| Poteri | Pugno, super salto, deltaplano, ognuno come nodo separato della rana |
| Grafica | Modelli low-poly in Blender, stile PS1 (più Base e Arcade con F2), il giorno che scende verso la notte col calore, fermo-immagine e rallentatore sulle catene di rottami |
| Power-up nelle tane | Scelta uno tra tre a gioco fermo; slot-attrezzo (guantoni, molle, ala, corpo). Fatti: guantoni esplosivi, correnti calde, quattro numerici |
| Biomi | Ferrovia (treni inarrestabili, avviso leale); aeroporto (fiamma e getto dei motori, trenini bagagli il cui carico vola via nel getto, il getto come ascensore per il deltaplano); porto (nastri, gru che inseguono la rana: da rifare, vedi sotto) |
| Primi segni del mondo che reagisce | Col calore le auto perdono il controllo da sole, e le gru mirano alla rana e la inseguono |
| Strumenti | 14 test automatici (tests/run.sh) e screenshot senza finestre (tools/screenshot.sh) |

### Da provare giocando

- Aeroporto e porto dopo le ultime modifiche: il super salto con il deltaplano nel getto, il momento giusto per attraversare dietro l'aereo, l'ombra fissa delle gru.
- I bagagli scagliati dal getto: piccoli e veloci, vanno visti con la telecamera dietro la rana. Se si perdono: più grandi, più lenti o con una scia.
- Il calore che ora conta solo i rottami entro 50 m dalla rana.

### Da fare, in ordine proposto

Prima di tutto: **rifare il porto**. Le gru sui nastri sono statiche, non ci si interagisce e la difficoltà non si sente (il container cade sempre sulla stessa riga del molo, che la rana attraversa in mezzo secondo). Proposta: acqua e navi portacontainer da riempire mentre ci sei sopra; è in idee-future.md, con le domande ancora aperte.

1. **Esperienza dal caos**: è la metà mancante del ciclo. Gli incidenti danno esperienza, e le catene valgono più delle auto singole; il passaggio di livello fa scegliere una statistica. Prima va sciolto il nodo con l'ingorgo (vedi idee-future.md): l'esperienza a terra fa dell'ingorgo il posto più comodo per raccoglierla.
2. **Reazioni del mondo**: auto che danno la caccia, coccodrilli aggressivi. Ogni reazione ha un avviso visibile, come l'ombra delle gru.
3. **Ondate**: picchi di pericolo sopra la base del calore, con momenti di respiro.
4. **Altri power-up** dal catalogo di idee-future.md, compresi gli oggetti che cambiano le regole e non solo i numeri.
5. **Suono**.
6. **Altri biomi** (lago ghiacciato, città con semafori, palude) e forse il bivio nella tana.
7. **Multiplayer** cooperativo, se lo facciamo. Per ora si sviluppa e si testa in singleplayer.

## Domande aperte

Nessuna per ora. Le risposte alle domande precedenti sono nella tabella "Regole decise".

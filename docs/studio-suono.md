# Frogger 3D — Studio del suono

Cominciato il 5 ottobre 2026. Il suono è l'ultimo passo della fase 1 (roadmap in regole-design.md), e prima di produrre un solo file si studia: che cosa deve fare il suono in questo gioco, che voce ha, come si costruisce in Godot e da dove arrivano i file. Oggi il gioco è muto: nessuno script usa l'audio.

Questo documento è materiale su cui ragionare. Le decisioni, quando arrivano, vanno nella tabella "Regole decise" di regole-design.md, e qui si segnano come prese.

## 1. Perché qui il suono conta più del solito

In questo gioco il suono non è solo decorazione: in quattro punti porta informazioni che l'immagine non riesce a dare.

- **L'incendio sta dietro, la telecamera guarda avanti.** Oggi lo si capisce dal bagliore, dal fumo e dalla scritta "Fuoco: N m". Il suono è l'unico senso che non ha bisogno di girarsi: un crepitio che cresce alle spalle dice "corri" meglio di un numero. È probabilmente **il suono più importante del gioco**.
- **Gli avvisi leali.** I 2,5 s del treno, le luci rosse del punto di contatto degli aerei, l'ombra della gru: oggi sono tutti visivi e tutti davanti. Un pericolo che arriva di lato o mentre si guarda altrove si può annunciare solo con l'orecchio (campanella del passaggio a livello, rombo dell'aereo che scende, cigolio della gru).
- **Il caos deve suonare ricco, non diventare rumore.** A calore 5, con trenta rottami, catene, esplosioni e getti dei motori, cinquanta suoni insieme diventano una poltiglia. Il mix deve scegliere che cosa si sente (vedi §4).
- **Il pugno.** Il fermo-immagine dura 0,11 s; senza un colpo secco sotto, il pugno resta a metà. Qui il suono è "feel" puro, e la sensazione del gioco è il suo motivo d'essere.

**Esercizio** (da fare prima di decidere qualsiasi cosa): gioca una run di 5 minuti a volume zero, come ora, e segna i momenti in cui sei stato colpito "a sorpresa" o in cui hai dovuto guardare l'HUD. Quella lista è la mappa dei suoni indispensabili, scritta dal gioco stesso.

## 2. Tre domande di identità

### 2a. Che epoca suona?

La grafica è PS1: modelli sfaccettati, pose a 15 al secondo, pixel grossi. La roadmap parla però di "effetti in stile sfxr", e **sfxr è un'altra epoca**: onde quadre e rumore bianco, NES e Game Boy. La PS1 suonava in modo diverso: campionamenti di suoni veri, a bassa qualità (compressi a 4 bit), con il riverbero della console (lo SPU, che aveva preset fissi come "stanza", "sala", "spazio") e una musica fatta di strumenti campionati, non di sintesi. Crash Bandicoot, Ape Escape, Spyro, Tony Hawk.

| Strada | Come suona | A favore | Contro |
| --- | --- | --- | --- |
| **PS1 vera** | Suoni realistici, degradati: frequenze tagliate, un po' di sporco, riverbero corto | Coerente con la grafica; l'estetica "PS1 indie" (Megabonk, i giochi alla Haunted PS1) ha un pubblico che la riconosce | Più lavoro: bisogna trovare suoni veri e poi "sporcarli" bene |
| **Chiptune / sfxr** | Bip, zap ed esplosioni sintetiche | Velocissimo da produrre, licenza pulita, molto leggibile | Stride con la grafica 3D; i giochi in 3D con suoni da Game Boy sembrano prototipi |
| **Moderna, pulita** | Suoni realistici a piena qualità | Massimo impatto (la scuola di Burnout per gli schianti) | Perde la personalità; la grafica dice una cosa e il suono un'altra |

Un collegamento: il gioco ha già **tre stili grafici su F2** (PS1, Base, Arcade). Il suono può seguire lo stesso interruttore con gli effetti sul bus master: in PS1 frequenze tagliate e riverbero corto, in Base suono pulito, in Arcade un po' di compressione. Gli stessi file, tre colori diversi. È anche il modo più economico per provare la domanda 2a giocando invece che a parole.

La mia inclinazione, da discutere: PS1 vera, coi suoni presi da librerie realistiche e degradati nel motore, e sfxr solo per l'interfaccia (carte, mosche, stagno), dove un suono "da gioco" si accetta.

### 2b. La musica e il calore

Il calore non cala mai. Se la musica lo segue (cinque strati, uno per livello, che entrano uno dopo l'altro), anche la musica non cala mai: in una run di 15-20 minuti si rischia di passare gli ultimi dieci minuti a volume massimo, e l'orecchio si stanca prima dell'occhio.

- **Strati per calore** (stratificazione verticale): ogni livello aggiunge uno strumento. È il modello più diretto e in Godot c'è già lo strumento (§4). Il rischio è quello appena detto.
- **Ondate**: la base segue il calore, ma **la tana è una pausa musicale**: lì restano solo due strati e il fuoco si allontana. È lo stesso ritmo a ondate che l'incendio dà già al gioco ("dopo ogni sezione si respira"). Con le sezioni più lunghe, la tana diventa una ricompensa anche per l'orecchio.
- **La musica reagisce alle azioni, non solo al calore**: in Untitled Goose Game il pianoforte (Debussy, tagliato a pezzi) suona più forte e più veloce quando l'oca combina guai, e si zittisce quando si nasconde. Qui il caos provocato dal giocatore è il cuore del gioco: un pugno o una catena potrebbero "accendere" la musica per qualche secondo, sopra la base data dal calore. È il sistema ibrido del design (caos del giocatore + mondo che reagisce) tradotto in musica.
- **Niente musica, solo mondo**: traffico, treni, fuoco e fiumi sono già una colonna sonora. Più facile e più leggibile, ma si perde il richiamo da "sala giochi" e la musica che rimane in testa.

Domanda da farsi: alla fine di una buona run, che cosa deve restare nell'orecchio? Un motivo da fischiettare (musica protagonista) o la sensazione del caos (il mondo protagonista)?

### 2c. Quanto è "vero" il mondo?

Il gioco è comico: una rana coi guantoni da boxe che fa volare le auto. Le auto devono suonare come auto vere (lo schianto pesante di Burnout, che rende il pugno assurdo per contrasto) o come giocattoli (clacson buffi, sgommate da cartone)? Il contrasto fra una rana ridicola e un mondo pesante e serio è spesso più divertente della comicità esplicita. E la rana ha una voce? Un gracidio quando salta, uno "hup!" sul super salto, un verso diverso quando prende danno: la voce del personaggio è il modo più veloce per affezionarsi, ma stanca presto (servono varianti).

## 3. Inventario: tutto ciò che nel gioco può fare rumore

Ricavato dal codice del 5 ottobre 2026. La priorità: **A** serve a leggere il gioco (senza, si muore senza capire), **B** è la sensazione (senza, il gioco è più piatto), **C** è atmosfera.

| Gruppo | Eventi | Priorità |
| --- | --- | --- |
| Incendio | crepitio alle spalle che cresce con la vicinanza; ruggito quando è sotto i 25 m; la rana che brucia | A |
| Rana | passi e saltelli; salto; super salto (molle che si caricano e scattano); atterraggio; deltaplano che si apre e si chiude, vento in volo; tuffo, nuoto, uscita dall'acqua; danno preso; morte; seconda vita | A per danno e morte, B per il resto |
| Pugno e poteri | pugno a vuoto; pugno che colpisce (con il fermo-immagine); lingua che parte, aggancia, si ritira; schianto sismico (picchiata e onda); poteri che tornano pronti | B (il "pronto" è A: oggi lo dice solo un lampeggio dell'HUD) |
| Auto | motori (ognuno, o un brusio di traffico per corsia); clacson; frenata; sbandata del livello 3; schianto; rottame che rotola; esplosione dei guantoni esplosivi; catene (che crescono a ogni anello) | A per la sbandata, B per il resto |
| Fiume | acqua che scorre; tronco che affonda (tremore, bolle); coccodrillo che apre la bocca e morde | A per il morso e per il tronco, C per l'acqua |
| Ferrovia | campanella dell'avviso (2,5 s); treno in arrivo da lontano, passaggio, effetto Doppler; il rapido più acuto e la sua scia | A |
| Aeroporto | aereo che scende (rombo che cresce con l'ombra); contatto, gomme che fumano; motori al contrario; getto e fiamma; trenini bagagli; bagaglio scagliato; atterraggio di pancia (motore in fiamme, strisciata di metallo) | A per l'aereo in volo e il getto |
| Porto | navi (sirena, motore); gru: avviso, discesa del container, urto; container sul ponte; onde | A per la gru |
| Mondo | calore che sale di livello; transizione giorno-notte; vento | B |
| Tana | arrivo (fiori che si aprono, lucciole); la festa della rana; carte che entrano; scelta | B |
| Interfaccia | pulsanti, carte, stagno (acquisto, rimborso), mosca presa, mosca d'oro, pausa, fine della run, nuovo record | B |

Sono circa **60 eventi**, e ognuno ne vuole 2-4 varianti per non stancare: fra i 150 e i 200 file in tutto. Va considerato nella scelta della strada in §2a: con sfxr sono un pomeriggio, con suoni veri da sporcare qualche settimana.

## 4. Come si costruisce in Godot 4.7

- **Bus**: Master, poi Musica, Effetti, Ambiente, Interfaccia, ognuno col suo volume nelle opzioni (la cornice della fase 1 prevede già le opzioni audio). Gli effetti "da stile" (filtro passa-basso, riverbero, compressione) vanno sui bus, così F2 li cambia tutti insieme.
- **Varianti**: AudioStreamRandomizer sceglie a caso fra più file e varia un po' tono e volume a ogni colpo: dieci pugni di fila non suonano mai uguali.
- **Suoni nello spazio**: AudioStreamPlayer3D per tutto ciò che sta nel mondo (auto, treni, aerei, fuoco), con l'effetto Doppler per treni e aerei. L'ascoltatore sta sulla telecamera o sulla rana? Con la terza persona di solito sulla rana con l'orientamento della telecamera: così "dietro" vuol dire dietro alla rana, ed è il caso dell'incendio.
- **Mettere ordine nel caos**: un limite di voci per tipo (max_polyphony), una priorità (il danno alla rana, il fuoco e gli avvisi non vengono mai coperti), e per il traffico un brusio di corsia invece di un motore per auto. Quando parte un suono importante, gli altri si abbassano per un attimo (ducking, con un compressore collegato sul bus).
- **La musica a strati**: AudioStreamSynchronized (da Godot 4.3) tiene più tracce allineate al campione e ne cambia il volume mentre suonano; AudioStreamInteractive passa da un brano all'altro in tempo con la battuta (per esempio dalla corsa alla tana). Si possono combinare: strati dentro i brani.
- **Il tempo**: il fermo-immagine e il rallentatore cambiano Engine.time_scale, ma l'audio non lo segue da solo. Si decide se il rallentatore abbassa il tono di tutto (AudioServer.playback_speed_scale) o solo degli effetti, con la musica che continua: è una scelta di sensazione da provare.
- **Pausa**: musica e interfaccia continuano col gioco fermo (carte, stagno), il mondo si ferma.
- **Test**: i test headless girano senza scheda audio (driver finto), quindi l'audio non li rompe; si può verificare che ogni evento importante faccia partire il suo suono.

## 5. Da dove arrivano i file

Ogni file va segnato in un registro (assets/audio/CREDITI.md: file, fonte, licenza, autore). Per Steam serve sapere sempre da dove viene tutto.

| Fonte | Che cosa | Licenza |
| --- | --- | --- |
| [ChipTone](https://sfbgames.itch.io/chiptone) | Generatore di effetti sintetici nel browser | CC0: libero per qualsiasi uso |
| jsfxr / sfxr | Generatore di effetti 8 bit | L'output è di chi lo genera |
| Kenney (audio pack) | Effetti di interfaccia, impatti, ambiente | CC0 |
| [Sonniss GameAudioGDC](https://gamefromscratch.com/sonniss-27-5gb-sound-effect-giveaway-at-gdc-2024/) | Decine di GB di suoni professionali, ogni anno | Royalty-free e commerciale, senza credito; vietato usarli per addestrare IA |
| Freesound | Di tutto, anche registrazioni rare | **Miste**: solo CC0 o CC-BY (col credito); mai NC (non commerciale) |
| Musica | OpenGameArt, incompetech, compositori CC0, oppure comporla | Da controllare brano per brano; CC-BY vuole il credito |
| Strumenti PS1 | Plugin che imitano il riverbero e il suono della console ([PlayStation1Vsts](https://github.com/BodbDearg/PlayStation1Vsts), SPS) | Per elaborare i suoni prima di importarli |

Domanda a parte: **la musica la compri, la prendi o la fai?** È la cosa che più resta in testa di un gioco, ed è quella che più si confonde fra i giochi indie se è presa da una libreria. Una via di mezzo: un solo tema, fatto apposta (da te, da un amico, o commissionato per poco), con variazioni per ogni strato di calore e per la tana.

## 6. Metodo proposto

1. **Riferimenti**: scegliere 3 giochi il cui suono ti piace per questo gioco, e per ognuno una cosa precisa da rubare. Proposte su cui reagire: Crash Bandicoot (PS1, comico, ogni oggetto ha la sua voce), Burnout 3 (lo schianto come premio), Untitled Goose Game (la musica che reagisce al caos), Crossy Road (il treno che si sente prima di vederlo), Megabonk (la stessa estetica, oggi).
2. **Prova di leggibilità**: solo i suoni A dell'inventario, provvisori anche brutti (incendio, campanella del treno, aereo che scende, gru, danno, sbandata), messi nel gioco in un giorno. Poi una run: si muore ancora "a sorpresa"? È l'esercizio del §1 rifatto col suono.
3. **La voce**: decisa la strada del §2a, un primo gruppo di suoni B (pugno, salto, schianto, catena) fatti bene, e i tre stili sul bus da confrontare con F2.
4. **Tutto il resto** dell'inventario.
5. **La musica**, per ultima: a quel punto si sa quanto spazio lascia il mondo.

## Risposte del giocatore

**5 ottobre 2026, i riferimenti: Megabonk e Castlevania.** I due riferimenti sono quasi uno solo: il compositore di Megabonk (Miguel, "Miguelangell960") descrive la colonna sonora come un omaggio a Vampire Survivors, Castlevania, Undertale e Mega Man X, con rock, metal ed elettronica, un gusto un po' comico, e il proposito di fondere epoche diverse con un suono di oggi. Lavora con Ableton Live e plugin per l'80% gratuiti, fra cui sintetizzatori chiptune (Chipsynth, Magical 8bit Plug) e librerie di suoni di vecchi giochi ([intervista su Game*Spark](https://www.gamespark.jp/article/2025/10/05/158058.html)).

Conseguenza per il §2a: la scelta non è più fra PS1, chiptune e moderno, ma un **miscuglio di epoche**: suoni chiptune e chitarre rock dentro una produzione di oggi, piena e potente. Per gli effetti, la stessa idea: suoni carichi ed esagerati, che premiano ogni colpo. Il filtro PS1 diventa un colore sul bus (F2), non un vincolo sui file.

## Ascolti dalla PS1

Proposti il 5 ottobre 2026, per farsi l'orecchio. Si trovano su YouTube cercando "nome del gioco OST" (musica) o "sound effects" (effetti).

**Musica**
- **Castlevania: Symphony of the Night** (Michiru Yamane): "Dracula's Castle" (chitarre rock sopra un'atmosfera gotica), "Lost Painting", "Wood Carving Partita". Il ponte fra Castlevania e la PS1.
- **Mega Man X4**: i temi dei livelli, per esempio Cyber Peacock. Chitarre sintetiche e ritmo da azione, uno dei riferimenti dichiarati di Megabonk.
- **Ape Escape** (Soichi Terada): drum and bass frenetico e buffo. Musica comica che non rallenta mai: il caso più vicino a una rana che fa volare le auto.
- **Crash Bandicoot** (Mutato Muzik): "N. Sanity Beach". Marimba, percussioni e il cartone animato in musica.
- **Spyro the Dragon** (Stewart Copeland, il batterista dei Police): "Stone Hill", "Dark Hollow". Batteria viva e melodie che restano in testa.
- **Wipeout 2097**: elettronica dura (c'è anche "Firestarter" dei Prodigy). Che cosa vuol dire velocità e pericolo in musica.

**Effetti**
- **Metal Gear Solid**: il "!" dell'allarme quando si viene scoperti, e la musica che cambia. È il calore che sale di livello.
- **Spyro**: la gemma raccolta (un tintinnio diverso per valore) e **Crash**: la cassa rotta e il frutto Wumpa. Sono le mosche e la mosca d'oro.
- **Final Fantasy VII**: il cursore dei menu. Un suono minuscolo che milioni di persone riconoscono: l'interfaccia ha una voce.
- **Driver** (1999): inseguimenti in auto alla anni '70, sirene, frenate e schianti. Il traffico.
- **Twisted Metal 2**: auto che esplodono e lamiere che volano. Le catene di rottami.
- **GTA 2**: la polizia che arriva quando si esagera. L'escalation da cui è nata l'idea del calore.
- **Frogger** (1997, PS1): il Frogger 3D dell'epoca. Da sentire per capire che cosa omaggiare e che cosa evitare.

## Domande aperte

1. ~~Quale strada per l'epoca del suono~~: riferimenti scelti, Megabonk e Castlevania (sopra). Resta da dire quale Castlevania: quello del NES (chiptune) o Symphony of the Night (PS1, gotico e orchestrale)?
2. La musica (§2b): segue il calore, respira nelle tane, reagisce alle azioni, oppure non c'è?
3. Il mondo (§2c): auto pesanti e serie o giocattolo? La rana ha una voce?
4. La musica la si fa, la si prende o la si commissiona?
5. I tre riferimenti, e che cosa rubare a ognuno.

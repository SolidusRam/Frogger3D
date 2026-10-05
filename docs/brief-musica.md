# Frogger 3D — Dritte per la musica

Scritto il 5 ottobre 2026 per chi produce la colonna sonora in parallelo. Le scelte artistiche (melodie, strumenti, generi) non sono qui: restano a chi compone. Qui c'è che cosa è il gioco, che sensazione dà, che cosa fa già il suono, e che cosa serve perché la musica entri nel gioco senza intralciare. Per il percorso che ci ha portati fin qui, docs/studio-suono.md; le regole del suono sono nella riga "Suono" di docs/regole-design.md.

## 1. Il gioco in una pagina

Una rana coi guantoni da boxe, le molle sotto le zampe e un deltaplano scappa da un incendio partito nella sua foresta. Davanti a lei, all'infinito: strade, fiumi, ferrovie, aeroporti, porti. Dietro di lei, sempre, il fuoco. Ogni tanto una tana: uno stagno coi fiori dove ci si ferma, si sceglie un potenziamento e si riparte.

Si può attraversare con prudenza, come nel Frogger classico, oppure prendere a pugni le auto, che volano e si schiantano fra loro a catena. Ogni gesto violento fa salire il **calore**, che non cala mai: col calore il traffico va più veloce, il giorno diventa notte, il mondo diventa più pericoloso e l'incendio corre di più. La run finisce quando la rana muore; si ricomincia subito.

## 2. La sensazione, analizzata

### Il tono: panico comico

Il gioco mette pressione di continuo (il fuoco dietro, il traffico davanti, i treni, gli aerei che atterrano), ma non fa mai paura davvero. Il pericolo è da cartone animato: la rana viene sbalzata, rimbalza, guaisce, e quando muore si gira a pancia in su con un trombone triste. È lo slapstick: la catastrofe fa ridere perché chi la subisce è ridicolo e indistruttibile fino all'ultimo.

Il secondo ingrediente è il **contrasto**. La rana è buffa; il mondo intorno è quasi serio: auto pesanti, treni da 55 m/s, aerei di linea enormi, navi portacontainer. Gli effetti sonori sono costruiti apposta così (rana da cartone, mondo semi-realistico ma esagerato). Il comico nasce dalla sproporzione: una rana minuscola che manda all'aria un'autostrada.

Il terzo è il **potere**. Il giocatore non è solo una preda: può provocare il disastro, e il gioco lo premia con momenti di gloria (il fermo-immagine del pugno, il rallentatore sulle catene di rottami, le esplosioni). Ma ogni gloria costa calore, cioè futuro più difficile. La sensazione è quella di chi gioca col fuoco sapendo di farlo: euforia con un retrogusto di "ora la pago".

In una frase: **allegria del disastro, sotto inseguimento**.

### L'arco di una run: dalla mattina alla notte in fiamme

Una run dura fra i 15 e i 20 minuti, e non ha un ritorno indietro:

- **L'inizio** è una passeggiata di giorno: poche corsie, auto lente, il fuoco lento e lontano. È il Frogger classico: osservare, aspettare il varco, passare. Un rompicapo di tempismo.
- **Il centro**: il calore sale (da solo un livello ogni due minuti circa, molto prima se si fa casino), arriva il tramonto, poi la notte. Compaiono ferrovie, aeroporti, porti. Dal livello 3 ogni ambiente cambia comportamento: le auto sbandano da sole, i tronchi affondano, passa il rapido, gli aerei atterrano di pancia, le gru danno la caccia. Il giocatore smette di aspettare e comincia a improvvisare.
- **La fine**: notte, calore massimo, il fuoco che corre quanto la rana (accelera minuto dopo minuto) e un mondo in cui tutto si muove e tutto ferisce. Si sopravvive di riflessi e di poteri.

Il calore **non cala mai**: la tensione cresce in modo monotono per tutta la run. È il dato più importante per la musica (vedi §4).

### Il respiro: la tana

Il ritmo non è solo una salita: è una salita a gradini. Fra una tana e l'altra ci sono da 75 m (la prima) a circa 270 m (dalla quinta in poi): da mezzo minuto a due minuti di corsa. Raggiunta la tana succedono tre cose insieme: il fuoco viene respinto indietro, la rana fa festa (fiori che si aprono, lucciole, gracidio felice) e **il tempo si ferma** mentre si sceglie la carta. È il solo momento di calma vera della run, ed è anche un momento di scelta e di speranza ("con questa carta ce la faccio").

Quindi due ritmi sovrapposti: la **salita lunga** del calore, che non torna indietro, e le **ondate corte** delle sezioni, ognuna chiusa da un sollievo.

### I ritmi del gioco, in numeri

| Ritmo | Valore | Nota |
| --- | --- | --- |
| Saltelli della rana mentre cammina | 3 al secondo | 180 al minuto: il passo naturale del personaggio |
| Pose della rana | 15 al secondo | Animazione a scatti, come sulla PS1 |
| Avviso del treno | 2,5 s | Campanella del passaggio a livello, quattro colpi al secondo |
| Avviso della gru | 1,1-1,5 s | Bip ogni mezzo secondo |
| Fermo-immagine del pugno | 0,11 s | Il colpo |
| Rallentatore sulle catene | 0,8 s | Ogni 4 s al massimo |
| Festa in tana | 0,9 s | Poi le carte, a gioco fermo |
| Sezione fra due tane | 30 s - 2 min | Si allunga con le tane |
| Livello di calore | circa 2 min da solo, meno col caos | Cinque livelli; giorno, tramonto, notte |
| Run | 15-20 min | Poi si ricomincia subito |

### Le altre schermate

- **Il menu iniziale** sta sopra il gioco vivo: dietro c'è la partita vera, col traffico che passa, l'incendio fermo all'orizzonte e la telecamera che gira piano attorno alla rana che aspetta. Il mondo si sente lontano e ovattato. È un'attesa: il prima della corsa.
- **La fine della corsa** è comica, non tragica: il trombone, la rana a pancia in su, i numeri (distanza, record, tane), e il pulsante per ripartire subito. Il messaggio non è "hai perso" ma "ancora una!".
- **Lo stagno** (il negozio, dal menu e dalla fine della corsa) è un momento di calma e di progetti: si spendono le mosche raccolte per diventare più forti nelle run successive.
- **La pausa** ferma tutto.

### L'estetica

Grafica 3D low-poly in stile PS1 (modelli sfaccettati, pixel grossi, pose a scatti), con altri due stili scelti dal giocatore (Base, pulito; Arcade, colori al neon). Colori caldi e saturi di giorno, il cielo che si scurisce col calore. Il riferimento visivo è Megabonk; quelli sonori scelti finora sono Megabonk e Castlevania (docs/studio-suono.md).

## 3. Che cosa fa già il suono

Tutti gli effetti esistono e sono nel gioco: 71 suoni generati da codice (tools/suoni/genera.py), suonati dall'autoload Sfx (scripts/sfx.gd). La musica dovrà convivere con loro, quindi conviene sapere dove stanno.

### Lo spazio che occupano

- **I bassi sono pieni**: motori delle auto (40-500 Hz, sempre presenti in strada), il ruggito dell'incendio (sotto i 500 Hz, cresce quando il fuoco si avvicina), treni, aerei, esplosioni, schianti, il gong dei container, la sirena delle navi (attorno agli 80 Hz).
- **La voce della rana** sta fra 120 Hz e 3 kHz (le formanti del gracidio e dei guaiti attorno a 500-2500 Hz).
- **Gli avvisi stanno attorno a 1-1,2 kHz**: la campanella del treno (circa 1150 Hz) e il bip della gru (1000 Hz). Sono i suoni che salvano la vita al giocatore: la musica non deve coprirli.
- **I suoni di premio stanno in alto**: mosche (1-1,4 kHz), il "ding" dei poteri pronti (1,3-2,8 kHz), le catene (880 Hz e sopra).

Dritta pratica: un basso asciutto e controllato lascia passare motori e schianti; tenere un po' di spazio attorno a 1 kHz lascia passare gli avvisi.

### Gli effetti intonati

Alcuni effetti hanno note precise. Conviene che la musica sia in una tonalità che li accoglie, oppure li ritocco io (è un numero nella ricetta):

| Effetto | Note |
| --- | --- |
| Calore che sale di livello (l'allarme) | Re minore: Re3, Fa3, La3, Re4 |
| Arrivo in tana (arpa) | Pentatonica di Do: Do, Re, Mi, Sol, La |
| Nuovo record (fanfara) | Do maggiore: Do5, Mi5, Sol5, Do6 |
| Carta scelta | Sol5, Re6 |
| Catena di rottami | La5, che sale a ogni rottame in più |
| Morte (trombone) | Sib3, La3, Lab3, Sol3: discesa cromatica fino al Sol |
| Tromba del treno | Mib4, Fa#4, Sib4 |
| Campanella del treno | circa Re6, un po' calante |

Re minore e la pentatonica di Do stanno insieme senza attriti nel modo dorico di Re (le stesse note di Do maggiore): se la musica gira attorno a Re minore o Re dorico, quasi tutti gli effetti intonati ci stanno dentro. Se la tonalità sarà un'altra, dimmela e riaccordo gli effetti.

## 4. Che cosa chiede il gioco alla musica

Non sono scelte artistiche: sono le domande che il gioco pone, con i pro e i contro come li vedo.

### Deve crescere per 15-20 minuti senza stancare

Il calore sale in cinque livelli e non torna indietro. Una musica che aggiunge uno strato a ogni livello segue bene la tensione, ma rischia di passare gli ultimi dieci minuti al massimo. Due modi per evitarlo, compatibili fra loro:

- **la tana come pausa musicale**: lì la musica si spoglia, poi riparte; così ogni sezione è un'ondata con un inizio e un culmine, sopra la salita lunga del calore;
- **materiale abbastanza lungo e vario**: loop di almeno uno o due minuti per livello, o più varianti, perché lo stesso giro di 16 battute ascoltato per sei minuti diventa un rumore di fondo.

### Deve seguire il calore, le tane o gli ambienti?

- **Il calore** è il filo più naturale: è la misura della tensione e del caos provocato dal giocatore.
- **Le tane** danno la struttura a ondate e il momento di respiro.
- **Gli ambienti** (strada, fiume, ferrovia, aeroporto, porto) cambiano ogni 10-30 secondi: troppo in fretta per avere un brano ciascuno. Al più, un colore o uno strumento che entra ed esce, ma è difficile da far suonare bene. Il mio consiglio è di non legare la musica agli ambienti.

### Deve rispondere ai momenti di gloria?

Il pugno (0,11 s di fermo-immagine), le catene (0,8 s di rallentatore), le esplosioni. Gli effetti li coprono già bene. La musica può lasciarli soli, oppure "rispondere" (uno stacco, un colpo sul tempo). Un dato tecnico che conta: **oggi il rallentatore rallenta tutto l'audio del 30%**, musica compresa. Sulla musica fa l'effetto di un nastro che si ferma: può essere un bell'effetto comico o un fastidio. Si può escludere la musica, se serve.

### Il menu, la fine, lo stagno

Sono tre stati con tre umori diversi: l'attesa prima della corsa, la risata e il "ancora una!" dopo la morte, la calma dei progetti allo stagno. Il trombone della morte finisce sul Sol: un breve brano di fine corsa che ne riparte, o che arriva dopo, si lega bene. Si riparte subito, quindi la musica di fine corsa deve reggere anche pochi secondi.

## 5. Le specifiche tecniche

### Formato

- **OGG Vorbis**, 44,1 kHz, stereo. Qualità alta (in ffmpeg `-q:a 6` o simili).
- **Loop senza scatti**: il file deve finire esattamente dove ricomincia, alla battuta. Se il brano ha un riverbero o code che passano il punto di loop, renderle e sovrapporle all'inizio (si esporta il giro due volte e si tiene il secondo). Se c'è un'introduzione prima del loop, va bene: dimmi a che secondo comincia il loop (Godot lo chiama loop_offset).
- **Volume**: tenere la musica più bassa degli effetti. Come punto di partenza, un mix musicale attorno a -16/-18 LUFS integrati, picchi sotto -1 dBTP. Il volume vero lo regolo nel gioco, ma partire da lì evita di schiacciare la dinamica.

### La musica a strati (se si sceglie questa strada)

Godot 4.7 sa sovrapporre più tracce perfettamente allineate e cambiarne il volume mentre suonano (AudioStreamSynchronized), e passare da un brano all'altro a tempo, sulla battuta (AudioStreamInteractive). Per usarli servono:

- **gli strati (stem) esportati separati**, tutti della stessa identica lunghezza in campioni, tutti dall'inizio della prima battuta;
- **il tempo (BPM), il metro e il numero di battute** di ogni brano, per i passaggi a tempo;
- **per ogni passaggio** (corsa → tana, tana → corsa, corsa → fine), se deve aspettare la fine della battuta o della frase, o tagliare subito.

### Nel gioco

- Il bus **Musica** esiste già. Non si attutisce dietro i menu (gli effetti sì) e non ha gli effetti degli stili grafici: se si vuole il "colore PS1" anche sulla musica, si decide.
- Lì dove il gioco è fermo (le carte in tana, lo stagno, la pausa) la musica può continuare: va deciso stato per stato.
- **Nomi dei file**: in assets/audio/musica/, con nomi che dicono stato e strato, per esempio `corsa_strato1.ogg`, `corsa_strato2.ogg`, `tana.ogg`, `fine.ogg`, `menu.ogg`. E un file di testo accanto con BPM, battute e loop_offset.
- **Licenze**: se ci sono campioni o strumenti di terzi, segnarli con la loro licenza. Per Steam serve sapere da dove viene tutto.

Quando arrivano i primi file, collego io gli stati del gioco agli strati e ai passaggi.

## 6. Domande da decidere

1. La musica segue il calore (strati), le tane (ondate), tutte e due?
2. La tana spoglia la musica, la ferma o ha un brano suo?
3. Il rallentatore rallenta anche la musica (nastro che si ferma) o la lascia andare?
4. Un tema solo, con variazioni per ogni stato, o brani diversi?
5. Il colore PS1 (filtro e riverbero) anche sulla musica?
6. La tonalità: Re minore/dorico, che accoglie gli effetti già fatti, o un'altra (e riaccordo gli effetti)?

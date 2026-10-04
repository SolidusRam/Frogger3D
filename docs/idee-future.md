# Frogger 3D — Idee future e domande aperte

Ultimo aggiornamento: 2026-10-04

Qui ci sono le idee discusse ma **non ancora decise**. Le regole decise stanno in [regole-design.md](regole-design.md): quando un'idea viene scelta, passa di là.

## Il paradosso dell'ingorgo

Al calore massimo, nei test, restano in marcia 20-30 auto su 120: le altre sono rottami o ferme in coda. Una strada ferma è una strada sicura, quindi **il caos massimo rischia di rendere il gioco più facile**.

Strade possibili:

- **L'ingorgo è una ricompensa**: il giocatore se l'è guadagnato col calore. Il pericolo si sposta altrove (fiume, rottami che volano, strade nuove).
- **L'ingorgo si ribella**: dalle auto ferme scendono automobilisti arrabbiati, oppure le auto ferme suonano e poi sfondano (reazione del mondo in stile GTA).
- **L'ingorgo prende fuoco**: i rottami accumulati diventano zone che bruciano; il tappo passa da ponte a trappola.

Domanda: davanti a una strada completamente bloccata al calore 5, il giocatore deve provare sollievo, sospetto o paura?

## Il fiume "freddo"

Oggi il calore agisce sul fiume solo rendendo più veloci le correnti dei fiumi creati dopo (fino a +40%). La strada sente il calore molto di più. Idee per l'equivalente fluviale dell'auto che perde il controllo:

- **L'acqua sale col calore** e si mangia le strisce sicure delle sponde (solo nei blocchi nuovi).
- **I coccodrilli si svegliano**: lasciano la corrente e puntano la rana (già previsto al passo "Reazioni del mondo").
- **Aironi**: predatori naturali delle rane, arrivano dall'alto. Sarebbero l'unica minaccia per chi plana col deltaplano, che oggi permette di saltare il fiume. Inclinazione di Claude, da discutere.
- **Tronchi che marciscono**: al calore alto sono più corti, o affondano dopo qualche secondo che la rana ci sta sopra.

## Esperienza dal caos e ingorgo

Se l'esperienza cade a terra tra i rottami, l'ingorgo diventa il posto più comodo per raccoglierla. Alternativa: l'esperienza sparisce dopo pochi secondi, così bisogna tuffarsi nel caos mentre le auto si muovono ancora.

## La tana che "mette in banca"

Oggi la distanza conta fino al punto della morte e la tana salva il record. Alternativa: conta solo la distanza raggiunta all'ultima tana. Chi muore tra due tane perde il tratto fatto dopo, e ogni sezione diventa una scommessa (come incassare in Balatro).

## Power-up ancora da fare

Ogni power-up si vede addosso alla rana (è un supereroe con gli attrezzi). Già fatti: guantoni esplosivi, correnti calde e quattro numerici.

| Slot | Power-up | Cosa cambia |
| --- | --- | --- |
| Guantoni | Montante | spinta verso l'alto triplicata: le auto volano e ricadono su altre auto |
| Guantoni | Guantoni magnetici | l'auto colpita curva verso il veicolo più vicino: catene garantite |
| Guantoni | Guantone a molla | portata da 1,3 a 4 m |
| Molle | Molle a razzo | un secondo super salto in aria |
| Molle | Atterraggio sismico | atterrando da un super salto si ribaltano le auto intorno |
| Molle | Molle-trampolino | sui tetti delle auto si rimbalza da soli: il traffico diventa una strada |
| Ala | Ala a reazione | più veloce, ma scalda finché si vola |
| Ala | Ala corazzata | in volo assorbe un colpo |
| Corpo | Pelle impermeabile | l'acqua non toglie vita |
| Corpo | Assicurazione | si sopravvive a un colpo mortale, ma il calore sale di un livello |
| Calore | Più caldo, più forte | i poteri crescono col livello del calore |
| Calore | Benzina sul fuoco | calore ×1,5, esperienza ×2 |

Combinazioni da cercare: correnti calde + guantoni esplosivi (il caos sulla strada fa volare sopra il fiume), molle-trampolino + traffico veloce, montante + atterraggio sismico. Domanda aperta: un secondo slot per attrezzo come premio raro?

## Poteri

- **Equilibrio attuale**: super salto più deltaplano coprono circa 29 m, il fiume ne è largo 14. Per ora restano forti; il contrappeso è il calore (decisione provvisoria).
- **Un potere che rompe la regola**: congela il calore per 10 secondi, senza abbassarlo. Desiderabile proprio perché rompe la regola "il calore non scende mai", ma ogni eccezione la indebolisce.
- **Lingua-rampino**: agganci un camion e ti fai trascinare, oppure tiri un rottame verso di te.
- **Gracidio sonico**: le auto vicine sbandano. Un pugno ad area che fa salire molto il calore.

## Biomi

Un bioma deve aggiungere una sola regola nuova sopra strada e fiume, comprensibile nei primi 3 secondi. Fatti, come tipi di blocco del percorso: ferrovia, aeroporto, porto. Candidati: lago ghiacciato (si scivola; i rottami crepano il ghiaccio), città con semafori (il traffico segue un ritmo), palude di notte (fango, ninfee che affondano, idroscivolanti).

Domande aperte: alternanza per sezione, a stagioni o con un bivio scelto nella tana (mappa alla Slay the Spire); come combinare tavolozza del bioma, stile e ora del giorno senza perdere leggibilità.

## Proposta da approvare: la difficoltà nei biomi e il porto con le navi (4 ottobre)

Oggi solo la strada cambia davvero col calore: è l'unico bioma in cui il calore aggiunge un comportamento nuovo (le auto che perdono il controllo). Negli altri il calore alza solo dei numeri, per esempio gli aerei da 7 a 9 m/s, e non se ne accorge nessuno. L'aeroporto non cambia nemmeno con la distanza.

### I criteri

**Due assi, con due compiti diversi.**

| Asse | Cosa cambia | Quando si legge |
| --- | --- | --- |
| Distanza (la sezione) | La **quantità**: più corsie, binari, navi, aerei più frequenti. È la struttura del blocco | Quando il blocco nasce |
| Calore | Il **comportamento**: qualcosa che prima non succedeva | Dal vivo, anche nei blocchi già creati |

**Un gradino di calore** è un comportamento nuovo che si sblocca a una soglia. Per essere un gradino deve rispettare cinque regole:

1. **È un comportamento, non un numero.** "Il treno va più veloce" non è un gradino; "il treno passando risucchia la rana" sì.
2. **Ha un avviso leale**, con il linguaggio visivo che il gioco usa già: luci che lampeggiano, ombra rossa a terra, fiamma.
3. **Scatta subito**, anche nei blocchi già in campo, così il giocatore lo collega al livello appena raggiunto.
4. **L'HUD lo annuncia una volta**, insieme al messaggio del nuovo livello (per esempio "Calore 3: gli aerei decollano").
5. **Non cancella la regola del bioma**: la aggiunge. Il bioma resta riconoscibile in 3 secondi.

**Quanti e quando.** Per ora **un gradino per bioma**, tutti al **livello 3 di calore (60)**. È la soglia a cui le auto già cominciano a perdere il controllo: diventa "la soglia del caos", un momento unico in cui tutto il mondo cambia. Un secondo gradino si valuta solo dopo aver provato il primo. Gli aumenti numerici di oggi (+30% e simili) restano, ma non contano come difficoltà.

### Il gradino di ogni bioma

| Bioma | Distanza (quantità) | Gradino al livello 3 | Avviso |
| --- | --- | --- | --- |
| Strada | più corsie, più veloci (c'è già) | le auto perdono il controllo da sole (c'è già) | la sbandata |
| Fiume | più correnti, più coccodrilli (c'è già) | **i tronchi affondano**: con la rana sopra, un tronco comincia ad affondare dopo circa 1 s e va sott'acqua in 2 s. Non si può più aspettare sui tronchi | il tronco trema e fa bolle |
| Ferrovia | più binari (c'è già) | **il rapido**: un treno bianco più corto e molto più veloce, la cui scia risucchia verso i binari chi sta entro 2-3 m. Avviso identico, 2,5 s: arriva esattamente quando le luci promettono, ma vicino ai binari non si può più aspettare | le luci dei pali, che restano leali |
| Aeroporto | **nuovo**: aerei sempre più frequenti (da 9-15 s fino a 6-10 s tra un aereo e l'altro) | **il decollo**: un aereo si ferma in mezzo al raccordo, la fiamma cresce per 2 s, poi accelera fino a circa 35 m/s, con un getto lungo il doppio che svuota i trenini bagagli | l'aereo fermo con la fiamma che si allunga |
| Porto | una nave, poi due corsie d'acqua con navi in versi opposti; navi che arrivano più cariche | **la gru caccia la rana**: sotto il livello 3 le gru caricano le navi seguendo uno schema, e il labirinto si legge dalla banchina; dal livello 3 mirano alla rana quando è sul ponte, prevedendo dove la porterà la nave | l'ombra lampeggiante, poi fissa quando la gru si blocca |

Il gradino del porto risponde anche alla domanda "la gru costruisce il labirinto prima che tu salga, o mentre sei sopra?": **prima**, finché il calore è basso; **mentre**, dal livello 3.

### Il porto nuovo

L'immagine guida: **un labirinto che viene costruito sotto i tuoi piedi**.

- **Il blocco**: una banchina con le gru, una corsia d'acqua con la nave portacontainer (due corsie nelle sezioni avanzate), una banchina sicura dall'altra parte. I nastri trasportatori escono dal porto, e si tengono per un futuro bioma "magazzino": un blocco, una regola nuova.
- **La nave**: un tronco enorme, circa 40 x 10 m, che scorre lungo X a 3-5 m/s. Il ponte è appena più alto della banchina: si sale col salto normale. La nave arriva in parte carica, e i container già a bordo formano il labirinto iniziale.
- **La prua spinge e non fa male**: la punizione è finire in acqua, come coi tronchi.
- **Le gru**: stanno sulla banchina col braccio sopra l'acqua. Il carrello scorre lungo il braccio, così il container può cadere in qualunque punto del ponte, non più sempre sulla stessa riga. Restano l'ombra lampeggiante, l'ombra fissa negli ultimi istanti e la caduta rapida (0,7 s).
- **I container caricati**: restano sul ponte e viaggiano con la nave. Sono muri alti 2,6 m, che col salto normale non si superano e col super salto sì. Sopra ci si può stare.
- **L'acqua**: le regole del fiume (20 di vita al secondo, si esce col salto tenuto).

**La fisica, in due tempi.**

1. **Prima la nave cinematica**: niente inclinazione, i container si fissano al ponte. Serve a verificare che il labirinto che si chiude sia divertente da solo.
2. **Poi l'inclinazione**, solo dopo averlo provato: la nave si inclina col carico (fino a circa 10°), e oltre una soglia i container scivolano come corpi fisici e cadono in acqua, dove galleggiano come i rottami. Qui il pugno trova finalmente un ruolo: un pugno a un container sposta il peso e fa scivolare gli altri.

### Ordine di lavoro

1. Il porto nuovo, prima fase (cinematica), con il suo gradino.
2. L'annuncio dei gradini nell'HUD.
3. I gradini di aeroporto, ferrovia e fiume, e l'asse della distanza per l'aeroporto.
4. La seconda fase del porto (inclinazione), dopo averlo provato.

Ogni passo con test e screenshot, come sempre.

## Pubblicazione e aspetto economico (discussione, 4 ottobre)

- **Il nome va cambiato**: "Frogger" è un marchio di Konami. Le meccaniche non sono protette (Crossy Road esiste), il nome sì. Va deciso prima di qualsiasi pagina Steam.
- **Quanto può valere**: dipende quasi tutto dalla visibilità. Ordini di grandezza per un indie su Steam a 5-10 €, con la regola pratica che nella prima settimana si vende il 10-20% delle wishlist e che il netto è circa il 50-55% del lordo (quota di Steam, IVA, rimborsi; le tasse a parte):

  | Scenario | Wishlist al lancio | Copie il primo anno | Netto |
  | --- | --- | --- | --- |
  | Senza marketing (il caso più comune) | meno di 1.000 | 100-300 | qualche centinaio di € |
  | Indie discreto | circa 10.000 | 2.000-5.000 | 7-20 mila € |
  | Buon successo | circa 50.000 | 15.000-40.000 | 50-150 mila € |
  | Virale (Megabonk, Vampire Survivors) | centinaia di migliaia | milioni | milioni |

- **A favore**: il gancio si capisce in 3 secondi (una rana che prende a pugni le macchine); il caos fa clip per TikTok, Shorts e streamer; il genere (roguelite, run infinite, prezzo basso) tira.
- **Rischi**: genere affollato; manca ancora il ciclo "il caos ti dà forza"; niente suono.
- **Cosa serve**: un nome proprio, la pagina Steam aperta presto (6-12 mesi prima) per le wishlist, una demo per la Steam Next Fest, clip brevi con costanza. Il costo vivo è basso: 100 $ per Steam Direct, rimborsati dopo 1.000 $ di incassi.

## Nuovi ambienti

- **Ferrovia**: il treno è l'unico veicolo che non diventa mai rottame. È inarrestabile e trasforma tutto ciò che tocca: un "boss" senza bisogno di intelligenza artificiale.
- **Notte**: le auto si vedono solo dai fari; il pericolo diventa leggere il traffico.
- **Pioggia**: le auto frenano peggio, come col calore alto; è calore che arriva dall'ambiente.

## Multiplayer

Il modello ibrido aiuta la rete: il traffico in marcia è deterministico (con lo stesso seme casuale due computer vedono le stesse auto), quindi va sincronizzata solo la parte fisica, cioè i rottami. Fisica più multiplayer era considerata la combinazione più costosa; con l'ibrido lo è molto meno. Decisione attuale: singleplayer, cooperativo possibile in futuro.

## Prestazioni da tenere d'occhio

- Al calore massimo la fisica arriva a circa 6 ms per passo, su un limite di 16,7; nelle sezioni avanzate fino a 8.
- Se diventa un problema: fermare il traffico nei blocchi lontani dalla rana.

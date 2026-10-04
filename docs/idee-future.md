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

## Porto con le navi (proposta, 4 ottobre)

Il porto di oggi non funziona: le gru sono statiche e non ci si interagisce, e la difficoltà non si sente. Il container cade sempre sulla riga centrale della gru, che si muove solo lungo X: chi attraversa il molo in avanti passa quella riga in mezzo secondo, quindi l'inseguimento colpisce solo chi si ferma lì. Il pugno colpisce solo le auto, e al porto non c'è niente da colpire.

Idea del giocatore: mettere l'acqua e far salire la rana su delle navi, che le gru riempiono di container da schivare.

- **Blocco**: banchina con le gru, una corsia d'acqua con le portacontainer (due nelle sezioni avanzate), banchina sicura.
- **Navi**: scorrono lungo X piano (3-5 m/s), come tronchi enormi (circa 40 x 10 m). Il ponte è appena più alto della banchina: si sale col salto normale. Arrivano vuote da un lato e ripartono piene dall'altro.
- **Gru**: sulla banchina, col braccio sopra l'acqua; il carrello scorre lungo il braccio, quindi il container può cadere ovunque sul ponte. L'ombra resta l'avviso. Se la rana è sulla nave, la gru mira a lei; più calore, più spesso.
- **Container caricati**: restano sul ponte e viaggiano con la nave. Sono muri da aggirare e piattaforme; si impilano.
- **Acqua**: le regole del fiume (20 di vita al secondo, si esce col salto tenuto).

Fisica della nave, tre strade:

| | Come | Pro | Contro |
| --- | --- | --- | --- |
| Cinematica | Nave piatta a velocità costante, i container si attaccano al ponte | Stabile, prevedibile, costa poco | Niente caos: un tronco grande |
| Ibrida (inclinazione di Claude) | Traslazione cinematica, ma la nave si inclina col carico (fino a circa 10°); oltre una soglia i container scivolano come corpi fisici e cadono in acqua, dove galleggiano come i rottami | Caos emergente: il carico sbilanciato fa scivolare gli altri container, un pugno sposta il peso. È lo stesso modello delle auto | Va tarata perché resti leggibile |
| Fisica piena | La nave è un corpo rigido che galleggia | Realistica | Instabile, costosa, la rana su un corpo rigido mobile dà problemi, difficile da rendere leale |

Domande aperte: quale fisica; i nastri trasportatori spariscono o restano sulla banchina; la prua spinge via soltanto o fa anche male.

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

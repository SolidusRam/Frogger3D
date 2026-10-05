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

## Esperienza dal caos (accantonata)

Il 4 ottobre 2026 l'utente ha deciso che, per ora, il caos non dà forza: la forza si guadagna nelle tane. L'idea resta qui se si volesse riprenderla. Il nodo era l'ingorgo: se l'esperienza cade a terra tra i rottami, l'ingorgo diventa il posto più comodo per raccoglierla. Le alternative erano l'esperienza che sparisce dopo pochi secondi, o l'esperienza accreditata subito e moltiplicata dalle catene, come in Burnout.

## Il caos senza ricompensa: perché provocarlo?

Se il caos non dà forza, deve servire a passare, altrimenti la strategia migliore è evitarlo. Oggi serve già in parte: un'auto ribaltata blocca una corsia, un rottame fa da zattera, il fumo solleva il deltaplano (correnti calde), un'esplosione svuota la strada (guantoni esplosivi). Da tenere d'occhio nelle prove: il giocatore usa il pugno per passare, o lo evita perché scalda? I power-up nuovi dovrebbero dare al caos sempre più usi.

## Meta-progressione del roguelite

Decisa il 4 ottobre 2026 (sblocchi a imprese, rane diverse, run da 15-20 minuti): sta nella roadmap di regole-design.md. Da scegliere più avanti: quali imprese, quali rane, quali fusioni.

## La tana che "mette in banca"

Oggi la distanza conta fino al punto della morte e la tana salva il record. Alternativa: conta solo la distanza raggiunta all'ultima tana. Chi muore tra due tane perde il tratto fatto dopo, e ogni sezione diventa una scommessa (come incassare in Balatro).

## Power-up ancora da fare

Ogni power-up si vede addosso alla rana (è un supereroe con gli attrezzi). Già fatti: guantoni esplosivi, montante, guantone a molla, molle-trampolino, schianto sismico, correnti calde, ala a reazione, pelle impermeabile, lingua-rampino, quattro numerici; fusioni Napalm e Terremoto.

| Slot | Power-up | Cosa cambia |
| --- | --- | --- |
| Guantoni | Guantoni magnetici | l'auto colpita curva verso il veicolo più vicino: catene garantite |
| Molle | Molle a razzo | un secondo super salto in aria |
| Ala | Ala corazzata | in volo assorbe un colpo |
| Corpo | Assicurazione | si sopravvive a un colpo mortale, ma il calore sale di un livello |
| Lingua | Lingua appiccicosa | ciò che la lingua tira resta attaccato e trascina la rana più a lungo |
| Lingua | Lingua elastica | portata da 12 a 20 m |
| Calore | Più caldo, più forte | i poteri crescono col livello del calore |
| Calore | Benzina sul fuoco | calore ×1,5, ma nelle tane si sceglie tra quattro carte invece che tra tre |

Fusioni da cercare: molle-trampolino + ala a reazione, lingua-rampino + guantone a molla (la lingua tira l'auto e la colpisce), guantoni magnetici + montante. Domanda aperta: un secondo slot per attrezzo come premio raro?

## Poteri

- **Equilibrio attuale**: super salto più deltaplano coprono circa 29 m, il fiume ne è largo 14. Per ora restano forti; il contrappeso è il calore (decisione provvisoria).
- **Un potere che rompe la regola**: congela il calore per 10 secondi, senza abbassarlo. Desiderabile proprio perché rompe la regola "il calore non scende mai", ma ogni eccezione la indebolisce.
- **Un potere per muoversi in orizzontale**: scelta la lingua-rampino (fatta il 4 ottobre 2026). I due candidati erano:
  - **Scatto**: un balzo laterale rapido, di pochi metri, con una breve ricarica. Semplice e leggibile; serve a schivare e a raggiungere un tronco che si allontana.
  - **Lingua-rampino**: agganci un veicolo, un tronco o una nave e ti fai trascinare, oppure tiri un rottame verso di te. Più ricco (si usa il traffico come mezzo, e il caos come attrezzo), ma più difficile da mirare e da rendere leggibile.
- **Gracidio sonico**: le auto vicine sbandano. Un pugno ad area che fa salire molto il calore.

## Il rework dell'aeroporto (proposta, 4 ottobre; superata il 5 ottobre)

Il 5 ottobre l'utente ha scelto un'altra strada: gli aerei che atterrano, il cielo pericoloso e l'atterraggio di pancia (sta in regole-design.md). Qui sotto la proposta di allora, se servisse.

Cosa non è in linea: i pilastri del gioco sono attraversare corsie a tempo, il traffico ibrido che si rompe e fa catene, e i poteri. L'aeroporto ne ha solo un pezzo: un gigante ogni 10 s su un raccordo quasi vuoto; il pugno non serve e il caos non nasce. Da tenere: l'aereo che passa e travolge, il getto dietro, la scena.

Proposta di Claude, "la strada dei giganti": attorno all'aereo, corsie di veicoli aeroportuali con la fisica ibrida delle auto (autobotti di carburante che esplodono quando diventano rottami, navette passeggeri, furgoni del catering). L'aereo diventa il "treno" del bioma: inarrestabile, travolge le corsie che incrocia sotto le ali, il getto scaglia i rottami. Il pugno torna utile e l'aereo in mezzo alle autobotti fa le catene più spettacolari. Ancora da decidere.

## Biomi

Un bioma deve aggiungere una sola regola nuova sopra strada e fiume, comprensibile nei primi 3 secondi. Fatti, come tipi di blocco del percorso: ferrovia, aeroporto, porto. Candidati: lago ghiacciato (si scivola; i rottami crepano il ghiaccio), città con semafori (il traffico segue un ritmo), palude di notte (fango, ninfee che affondano, idroscivolanti).

Domande aperte: alternanza per sezione, a stagioni o con un bivio scelto nella tana (mappa alla Slay the Spire); come combinare tavolozza del bioma, stile e ora del giorno senza perdere leggibilità.

## Dopo il porto nuovo

La proposta del 4 ottobre (criteri di difficoltà e porto con le navi) è stata approvata e sta in regole-design.md. Restano aperti:

- **I nastri trasportatori** sono usciti dal porto: scripts/conveyor.gd resta per un futuro bioma "magazzino".
- **Un secondo gradino per bioma**, da valutare dopo aver provato il primo.

## Pubblicazione e aspetto economico (discussione, 4 ottobre)

Deciso: il gioco si pubblica comunque, senza budget; il nome verrà più avanti. Il percorso in quattro fasi sta nella roadmap di regole-design.md.

- **Il nome va cambiato**: "Frogger" è un marchio di Konami. Le meccaniche non sono protette (Crossy Road esiste), il nome sì. Va deciso prima di qualsiasi pagina Steam.
- **Quanto può valere**: dipende quasi tutto dalla visibilità. Ordini di grandezza per un indie su Steam a 5-10 €, con la regola pratica che nella prima settimana si vende il 10-20% delle wishlist e che il netto è circa il 50-55% del lordo (quota di Steam, IVA, rimborsi; le tasse a parte):

  | Scenario | Wishlist al lancio | Copie il primo anno | Netto |
  | --- | --- | --- | --- |
  | Senza marketing (il caso più comune) | meno di 1.000 | 100-300 | qualche centinaio di € |
  | Indie discreto | circa 10.000 | 2.000-5.000 | 7-20 mila € |
  | Buon successo | circa 50.000 | 15.000-40.000 | 50-150 mila € |
  | Virale (Megabonk, Vampire Survivors) | centinaia di migliaia | milioni | milioni |

- **A favore**: il gancio si capisce in 3 secondi (una rana che prende a pugni le macchine); il caos fa clip per TikTok, Shorts e streamer; il genere (roguelite, run infinite, prezzo basso) tira.
- **Rischi**: genere affollato; mancano ancora la ragione per rigiocare e il suono.
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

# Il porting nel browser (tentativo del 9 ottobre 2026, messo da parte)

Il 9 ottobre 2026 si è provato a fare del gioco una versione solo browser, da pubblicare su un sito proprio al posto di Steam. Nel browser il gioco partiva e si giocava, ma restava lentissimo (1-3 fps su un portatile con Radeon 740M, in Firefox). Il 12 ottobre 2026 il tentativo è stato messo da parte e main è tornato alla versione di prima (commit b307fdc).

Il lavoro non è perso: sta tutto nel branch **web** (commit 823c393 e d47b47e). Per riprenderlo: `git checkout web`.

## Cosa è stato fatto (nel branch web)

| Cosa | Dettaglio |
| --- | --- |
| Renderer | Compatibility (OpenGL / WebGL 2) anche sviluppando, perché il browser supporta solo quello. Il look regge: è lo stesso renderer degli screenshot di tools/screenshot.sh |
| Build | export_presets.cfg con il preset "Web", senza thread (va su qualsiasi hosting statico, senza intestazioni speciali). tools/web.sh fa la build in build/web (circa 42 MB, di cui 39 di motore); con --apri la serve su localhost:8765 |
| Template | Servono i template web di Godot 4.7.2 (web_nothreads_release.zip e web_nothreads_debug.zip) in ~/.local/share/godot/export_templates/4.7.2.stable/. Sono già installati su questo pc; si possono estrarre dall'archivio ufficiale da 1,3 GB senza scaricarlo tutto |
| Correzioni per il web | Nomi dei tasti senza errori (keyboard_get_keycode_from_physical non esiste nel browser); niente "Esci" né V-Sync nel menu; pausa automatica quando il browser libera il mouse con Esc |
| Chiamate di disegno | tools/draws.sh le conta e dice da dove vengono. Veicoli, tronchi, coccodrilli, nuvole, mosche e bordi disegnati solo fino a 110 m e senza ombra (Style.FAR_DRAW): nel caos, a terra, da circa 2.700 a circa 1.500 chiamate |
| Audio | Nel browser Godot usava la modalità Sample, che copia l'intero suono a ogni play: la scheda arrivava a 2-3 GB in pochi secondi. Con audio/general/default_playback_type.web = Stream la memoria restava ferma intorno ai 650 MB |
| Contatore F3 | Una seconda riga che divide il tempo del fotogramma fra grafica, script e fisica e "resto"; con il contatore acceso 1, 2 e 3 spengono ombre, luci e particelle |

## Cosa si è misurato

- **Nel nativo** il gioco è leggero: 4-5 ms di CPU a fotogramma, 120 MB di memoria, 15 MB di texture.
- **In Firefox** (Radeon 740M, scheda grafica attiva, non software): 2 fps, fotogramma di 340-670 ms. Di questi, la grafica lato CPU era 4-7 ms e script più fisica circa 22-26 ms; il resto (312-638 ms) se ne andava fuori dal gioco. La scheda del gioco usava 3 GB.
- La risoluzione più bassa non cambiava niente, quindi non era un problema di pixel. Il gioco sembrava rallentare solo dopo la prima interazione.
- La pagina con l'audio spento (--audio-driver Dummy) andava male lo stesso.
- Nel profilo di Chromium (grafica software, in un recinto di memoria) il tempo andava in `_duplicateAudioBuffer` (l'audio, corretto con Stream) e in `blitOffscreenFramebuffer`, la copia finale dell'immagine. Quest'ultima in grafica software misura soprattutto l'attesa della grafica, quindi non si è capito se in Firefox fosse lo stesso.

## Cosa è rimasto aperto

- **La causa del "resto" in Firefox.** La correzione dell'audio non è stata provata in Firefox. L'audio spento non bastava, quindi probabilmente c'era anche una seconda causa, forse nel percorso grafico di Firefox su Linux. Prove mai fatte: la stessa pagina in Chromium aperto normalmente, e i tasti 1, 2, 3 e F2 di F3 per spegnere ombre, luci, particelle e post-processing.
- **Lo script in WebAssembly** girava 4-6 volte più lento del nativo (19-26 ms contro 4-5): anche risolto il resto, il gioco sarebbe rimasto sotto i 60 fps senza alleggerire gli script.
- **Il passo successivo sulle chiamate di disegno**: unire le superfici dei modelli (ogni colore della tavolozza è una superficie: un'auto costa quasi due chiamate, un coccodrillo quattro). È un lavoro grosso sui modelli e sul sistema dei colori di Style.

## Attenzione

- Non avviare Chromium headless con la GPU vera forzata (`--ignore-gpu-blocklist`): il 9 ottobre ha riempito la RAM e bloccato il pc. Con buona probabilità era la stessa perdita di memoria dell'audio. Per i test nel browser: grafica software, e un limite di memoria (`systemd-run --user --scope -p MemoryMax=3G -p MemorySwapMax=0 ...`).
- Il nome resta da cambiare prima di qualsiasi pubblicazione: "Frogger" è un marchio di Konami.

# nxnative Easy

[English](README.md) · **Español**

**Prepara tus juegos para iPhone desde una app de Mac. Sin comandos para el uso diario.**

![Nuestra app para preparar juegos](docs/images/nxnative-easy-es.png)

## Qué aporta esta versión

Partimos de [seedds/nxnative](https://github.com/seedds/nxnative): el motor, los perfiles y la compatibilidad son trabajo del proyecto original. **nxnative Easy** añade:

- **App para Mac:** elegir juego, avance, cancelación y acceso a IPA, datos y Sideloadly.
- **Controles editables en iPhone:** posición, tamaño y opacidad, guardados por juego y layout.
- **IPA ligera automática:** los datos `romfs` van aparte; se conservan salidas y cachés válidas.
- **Llaves del usuario:** debes seleccionar la carpeta de tus propias `prod.keys`. No incluimos, descargamos ni distribuimos llaves o juegos.
- **Preparación local:** sin cuenta Apple, sin certificados de empresa y sin servicio que reciba tus archivos.

Entregamos **código, una interfaz de preparación y herramientas de compilación**. El resultado es una IPA sin firmar; tú la firmas e instalas con Sideloadly. No ofrecemos juegos, llaves, firma de Apple ni compatibilidad garantizada con cualquier juego.

## Idioma

La app inicia en **English**. Cambia a **Español** con el selector de la esquina superior; la elección se guarda en este Mac. Cambia el idioma de la interfaz, no el del juego. Los detalles técnicos se muestran en su idioma original.

## Abre la app y elige tu juego

1. Abre **nxnative.app**.
2. Elige la **Carpeta de tu juego**, selecciona tu **Carpeta de llaves** una vez y pulsa **Preparar juego**.

La app prepara las herramientas, compila y deja lista la **IPA ligera**. Verás el avance en la ventana. Al terminar aparecen los dos pasos para instalar. **Enviar a Sideloadly** abre allí la IPA preparada; si Sideloadly no está instalado, el botón ofrece descargarlo.

**Una vez creada:** abre `nxnative.app`. Recuerda tu última carpeta y permite volver a mostrar la IPA ya preparada.

**En otro Mac:** después de descargar este repositorio, abre [`scripts/Abrir-interfaz.command`](scripts/Abrir-interfaz.command) con doble clic. Crea y abre la app local. La primera vez necesitas Xcode completo y Homebrew instalados; si hacen falta tus llaves, te pedirá elegir la carpeta donde guardas tu propio `prod.keys`. Mantén cada juego fuera del repositorio, en una carpeta con su base y actualizaciones.

## Cómo se compila la app de Mac

El acceso de apertura usa el compilador Swift de tu Xcode. La firma de la app es **ad hoc**, local y sin cuenta, certificado ni equipo Apple (`TeamIdentifier` no asignado). No usa cuentas de empresa. Sólo al instalar la **IPA de iPhone con Sideloadly** introduces tu cuenta personal, dentro de Sideloadly.

El icono del teléfono con controles es original. Los símbolos de los perfiles son genéricos del sistema; no se usan imágenes ni logotipos de los juegos en la app. La galería de documentación de abajo procede de upstream y está separada de la interfaz.

## Instalar: Sideloadly + Finder

1. Con la IPA lista, conecta tu iPhone y pulsa **Enviar a Sideloadly**. La app abre allí el archivo preparado.
2. Dentro de Sideloadly pulsa **Start** con tu cuenta Apple **personal**. Si hace falta buscar el archivo manualmente, usa **Mostrar IPA**.
3. La primera vez, pulsa **Mostrar datos del juego** y copia la carpeta `romfs` completa por **Finder → iPhone → Archivos → tu juego**.

Para actualizar, usa la misma cuenta y el mismo bundle ID efectivo de Sideloadly. **Instala encima; no desinstales la app**, para conservar tus partidas. Si los datos del juego no cambiaron, puedes reutilizar el `romfs` existente. La app instala las herramientas de compilación que falten después de tener Xcode y Homebrew, pero **no firma ni instala el juego en el iPhone**. Esos pasos los hace Sideloadly. La app los explica cuando la IPA está lista.

## Perfiles de juegos con soporte

El carrusel muestra los perfiles de esta copia; no proporciona ni descarga juegos. Debes añadir tus propios archivos del juego. Pulsa **Ver todos** arriba a la derecha para consultar la lista completa de soporte. Busca por nombre, versión o Title ID; cada resultado enlaza a su ficha. El catálogo vuelve a leer los perfiles locales cada vez que lo abres. El carrusel rota automáticamente y se pausa al colocar el cursor encima.

![Buscador de perfiles de juegos](docs/images/nxnative-catalog-es.png)

**Las pruebas propias cubren compilación y empaquetado en Mac, no una verificación automática de juego en iPhone.** Los perfiles y reportes de juego proceden de upstream; revisa [la ficha de tu juego](dm/games/README.md#games) antes de prepararlo. Un perfil no garantiza que cualquier versión funcione en cualquier iPhone.

Esta base requiere iOS/iPadOS 26 o posterior, iPhone con A17 Pro o posterior o iPad con M1 o posterior. Los datos de los juegos y las llaves los aportas tú.

<table>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/mario-kart-8-deluxe.jpg" width="256" alt="Mario Kart 8 Deluxe"><br>Mario Kart 8 Deluxe<br><sub>~11.9 GB · no Mii heads</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/mario-vs-donkey-kong.jpg" width="256" alt="Mario vs. Donkey Kong"><br>Mario vs. Donkey Kong<br><sub>~1.6 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/paper-mario-the-thousand-year-door.jpg" width="256" alt="Paper Mario: The Thousand-Year Door"><br>Paper Mario: The Thousand-Year Door<br><sub>~5 GB · 60 fps with 1.0.1</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/super-mario-3d-world.jpg" width="256" alt="Super Mario 3D World + Bowser's Fury"><br>Super Mario 3D World + Bowser's Fury<br><sub>~3 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/super-mario-bros-wonder.jpg" width="256" alt="Super Mario Bros. Wonder"><br>Super Mario Bros. Wonder<br><sub>~4 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/super-mario-galaxy.jpg" width="256" alt="Super Mario Galaxy"><br>Super Mario Galaxy<br><sub>~3 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/super-mario-galaxy-2.jpg" width="256" alt="Super Mario Galaxy 2"><br>Super Mario Galaxy 2<br><sub>~3 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/super-mario-odyssey.jpg" width="256" alt="Super Mario Odyssey"><br>Super Mario Odyssey<br><sub>~6 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/zelda-breath-of-the-wild.jpg" width="256" alt="The Legend of Zelda: Breath of the Wild"><br>The Legend of Zelda: Breath of the Wild<br><sub>~16 GB · 60 fps with 1.9.0</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/zelda-links-awakening.jpg" width="256" alt="The Legend of Zelda: Link's Awakening"><br>The Legend of Zelda: Link's Awakening<br><sub>~6 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/zelda-tears-of-the-kingdom.jpg" width="256" alt="The Legend of Zelda: Tears of the Kingdom"><br>The Legend of Zelda: Tears of the Kingdom<br><sub>~17 GB · 60 fps with 1.4.3</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/13-sentinels.jpg" width="256" alt="13 Sentinels: Aegis Rim"><br>13 Sentinels: Aegis Rim<br><sub>~5 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/absolum.jpg" width="256" alt="Absolum"><br>Absolum<br><sub>~2 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/ace-attorney-investigations.jpg" width="256" alt="Ace Attorney Investigations Collection"><br>Ace Attorney Investigations Collection<br><sub>~7 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/advance-wars-1-2-re-boot-camp.jpg" width="256" alt="Advance Wars 1+2: Re-Boot Camp"><br>Advance Wars 1+2: Re-Boot Camp<br><sub>~7.1 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/ai-the-somnium-files.jpg" width="256" alt="AI: THE SOMNIUM FILES"><br>AI: THE SOMNIUM FILES<br><sub>~8.3 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/ai-the-somnium-files-nirvana-initiative.jpg" width="256" alt="AI: THE SOMNIUM FILES - nirvanA Initiative"><br>AI: THE SOMNIUM FILES - nirvanA Initiative<br><sub>~11.6 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/animal-crossing-new-horizons.jpg" width="256" alt="Animal Crossing: New Horizons"><br>Animal Crossing: New Horizons<br><sub>~10.5 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/animal-well.png" width="256" alt="ANIMAL WELL"><br>ANIMAL WELL<br><sub>~54 MB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/astral-chain.png" width="256" alt="ASTRAL CHAIN"><br><a href="dm/games/01007300020FA000/README.md">ASTRAL CHAIN</a><br><sub>~9.7 GB · 60 fps target with 1.0.1</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/balatro.jpg" width="256" alt="Balatro"><br>Balatro<br><sub>~82 MB · played by touch</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/ball-x-pit.jpg" width="256" alt="BALL x PIT"><br>BALL x PIT<br><sub>~1.1 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/bayonetta.jpg" width="256" alt="Bayonetta"><br>Bayonetta<br><sub>~8.8 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/bayonetta-2.jpg" width="256" alt="Bayonetta 2"><br>Bayonetta 2<br><sub>~12.5 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/bayonetta-3.jpg" width="256" alt="Bayonetta 3"><br>Bayonetta 3<br><sub>~14.2 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/big-brain-academy-brain-vs-brain.jpg" width="256" alt="Big Brain Academy: Brain vs. Brain"><br>Big Brain Academy: Brain vs. Brain<br><sub>~0.8 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/brain-memory-training-academy.jpg" width="256" alt="Brain Memory Training Academy"><br>Brain Memory Training Academy<br><sub>~0.1 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/captain-toad-treasure-tracker.jpg" width="256" alt="Captain Toad: Treasure Tracker"><br>Captain Toad: Treasure Tracker<br><sub>~2 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/catherine-full-body.jpg" width="256" alt="Catherine: Full Body"><br>Catherine: Full Body<br><sub>~14 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/celeste.jpg" width="256" alt="Celeste"><br>Celeste<br><sub>~0.9 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/cuphead.jpg" width="256" alt="Cuphead"><br>Cuphead<br><sub>~5 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/dark-souls-remastered-creation.jpg" width="256" alt="DARK SOULS: REMASTERED"><br>DARK SOULS: REMASTERED<br><sub>~4 GB · 60 fps with 1.0.3</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/digimon-story-cyber-sleuth.jpg" width="256" alt="Digimon Story Cyber Sleuth: Complete Edition"><br>Digimon Story Cyber Sleuth: Complete Edition<br><sub>~5 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/dragon-quest-vii-reimagined.jpg" width="256" alt="DRAGON QUEST VII Reimagined"><br>DRAGON QUEST VII Reimagined<br><sub>~5.9 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/dragon-quest-xi-s.jpg" width="256" alt="DRAGON QUEST XI S: Echoes of an Elusive Age – Definitive Edition"><br>DRAGON QUEST XI S: Echoes of an Elusive Age – Definitive Edition<br><sub>~15 GB · 60 fps with 1.0.4</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/final-fantasy-resonance.jpg" width="256" alt="FINAL FANTASY RESONANCE"><br>FINAL FANTASY RESONANCE<br><sub>~10 GB · 60 fps with 1.0.1</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/final-fantasy-tactics.jpg" width="256" alt="FINAL FANTASY TACTICS - The Ivalice Chronicles"><br>FINAL FANTASY TACTICS - The Ivalice Chronicles<br><sub>~11 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/fire-emblem-engage.jpg" width="256" alt="Fire Emblem Engage"><br>Fire Emblem Engage<br><sub>~15 GB · 60 fps with 2.0.0</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/fire-emblem-three-houses.jpg" width="256" alt="Fire Emblem: Three Houses"><br>Fire Emblem: Three Houses<br><sub>~13 GB · 60 fps with 1.2.0</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/ghost-trick-phantom-detective.jpg" width="256" alt="Ghost Trick: Phantom Detective"><br>Ghost Trick: Phantom Detective<br><sub>~3 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/the-great-ace-attorney-chronicles.jpg" width="256" alt="The Great Ace Attorney Chronicles"><br>The Great Ace Attorney Chronicles<br><sub>~4 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/hades.jpg" width="256" alt="Hades"><br>Hades<br><sub>~4 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/hades-ii.jpg" width="256" alt="Hades II"><br>Hades II<br><sub>~4 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/hollow-knight-silksong.jpg" width="256" alt="Hollow Knight: Silksong"><br>Hollow Knight: Silksong<br><sub>~6.4 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/hyrule-warriors-age-of-calamity.jpg" width="256" alt="Hyrule Warriors: Age of Calamity"><br>Hyrule Warriors: Age of Calamity<br><sub>~15 GB · 60 fps with 1.3.0</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/luigis-mansion-3.jpg" width="256" alt="Luigi's Mansion 3"><br>Luigi's Mansion 3<br><sub>~7.5 GB · 60 fps with 1.4.0</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/metroid-dread.jpg" width="256" alt="Metroid Dread"><br>Metroid Dread<br><sub>~5 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/monster-hunter-rise.jpg" width="256" alt="Monster Hunter Rise"><br>Monster Hunter Rise<br><sub>~22 GB · 60 fps with 16.0.2</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/monster-train-2.jpg" width="256" alt="Monster Train 2"><br>Monster Train 2<br><sub>~1.6 GB · 60 fps with 1.1.1</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/octopath-traveler-0.jpg" width="256" alt="Octopath Traveler 0"><br>Octopath Traveler 0<br><sub>~4 GB · 60 fps with 1.0.5</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/octopath-traveler-ii.jpg" width="256" alt="Octopath Traveler II"><br>Octopath Traveler II<br><sub>~5.9 GB · 60 fps with 1.1.1</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/patricks-parabox.jpg" width="256" alt="Patrick's Parabox"><br>Patrick's Parabox<br><sub>~0.2 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/persona-5-royal.jpg" width="256" alt="Persona 5 Royal"><br>Persona 5 Royal<br><sub>~14.9 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/pikmin-4.jpg" width="256" alt="Pikmin 4"><br>Pikmin 4<br><sub>~10.8 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/pokemon-brilliant-diamond.jpg" width="256" alt="Pokémon Brilliant Diamond"><br>Pokémon Brilliant Diamond<br><sub>~4.6 GB · 60 fps with 1.3.0</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/pokemon-legends-z-a.jpg" width="256" alt="Pokémon Legends: Z-A"><br>Pokémon Legends: Z-A<br><sub>~6 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/pokemon-sword.jpg" width="256" alt="Pokémon Sword"><br>Pokémon Sword<br><sub>~12.4 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/pokemon-shield.jpg" width="256" alt="Pokémon Shield"><br>Pokémon Shield<br><sub>~12.4 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/portal.jpg" width="256" alt="Portal"><br>Portal<br><sub>~2.6 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/raging-loop.jpg" width="256" alt="Raging Loop"><br>Raging Loop<br><sub>~0.9 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/rhythm-heaven-groove.jpg" width="256" alt="Rhythm Heaven Groove"><br>Rhythm Heaven Groove<br><sub>~3 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/romance-of-the-three-kingdoms-8-remake.jpg" width="256" alt="ROMANCE OF THE THREE KINGDOMS 8 REMAKE"><br>ROMANCE OF THE THREE KINGDOMS 8 REMAKE<br><sub>~16.8 GB · controller only</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/stardew-valley.jpg" width="256" alt="Stardew Valley"><br>Stardew Valley<br><sub>~0.6 GB</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/steins-gate-reboot.jpg" width="256" alt="STEINS;GATE RE:BOOT"><br>STEINS;GATE RE:BOOT<br><sub>~6 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/super-smash-bros-ultimate.jpg" width="256" alt="Super Smash Bros. Ultimate"><br>Super Smash Bros. Ultimate<br><sub>~17.5 GB · offline</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/taiko-risshiden-v-dx.jpg" width="256" alt="Taiko Risshiden V DX"><br>Taiko Risshiden V DX<br><sub>~3.3 GB · Japanese · played by touch</sub></td>
</tr>
<tr>
<td align="center" valign="top" width="33%"><img src="docs/images/unicorn-overlord.jpg" width="256" alt="Unicorn Overlord"><br>Unicorn Overlord<br><sub>~4 GB</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/nier-automata.png" width="256" alt="NieR:Automata The End of YoRHa Edition"><br>NieR:Automata The End of YoRHa Edition<br><sub>~10.9 GB · 60 fps with 1.0.3</sub></td>
<td align="center" valign="top" width="33%"><img src="docs/images/zelda-echoes-of-wisdom.jpg" width="256" alt="The Legend of Zelda: Echoes of Wisdom"><br>The Legend of Zelda: Echoes of Wisdom<br><sub>~7.8 GB</sub></td>
</tr>
</table>

## Controles a tu gusto

En el juego pulsa **Edit controls**. Mueve los botones, ajusta tamaño y opacidad y pulsa **Save**. **Cancel** descarta y **Reset control / Reset all** restaura. Cada juego guarda su acomodo 2D y 3D. El juego sigue corriendo mientras editas. El selector de idioma de la app de Mac no traduce este editor dentro del juego.

<details>
<summary>Guías, comandos y detalles técnicos</summary>

- [Guía de comandos e instalación detallada](README-comandos.md).
- [Automatización y solución de problemas](docs/personal-ios.md).
- [Revisión de los PR de upstream](docs/personal-pr-review.md).
- [README anterior y créditos completos](README-original.md).

</details>

Basado en [seedds/nxnative](https://github.com/seedds/nxnative), con nuestro editor de controles y automatización. Conservamos la [licencia MIT](LICENSE) y los [créditos originales](README-original.md#acknowledgements). Nuestros cambios pertenecen a la cuenta de GitHub **nalancer08**; los commits históricos de upstream conservan su autoría.

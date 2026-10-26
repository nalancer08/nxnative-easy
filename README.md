# nxnative personal · Juegos de Switch en iPhone y iPad

Esta es nuestra copia privada de [nxnative](https://github.com/seedds/nxnative), con **editor de controles táctiles** y **scripts que preparan herramientas, compilan y generan una IPA ligera** para instalar con Sideloadly.

**Empieza aquí:** elige un juego compatible → ejecuta un comando → instala la IPA ligera → copia `romfs` por Finder la primera vez.

[Qué juegos correr](#qué-juegos-correr) · [Preparar el Mac](#preparar-el-mac) · [Compilar fácilmente](#compilar-fácilmente) · [Instalar con Sideloadly](#instalar-con-sideloadly) · [Actualizar sin perder partidas](#actualizar-sin-perder-partidas) · [README anterior](README-original.md)

## Qué juegos correr

**Metroid Dread 2.1.0 es el juego confirmado funcionando en nuestro iPhone.** También comprobamos su recompilación sin firma y la generación automática de la IPA ligera. El editor nuevo todavía requiere comprobar su uso físico tras instalarlo.

Esta base incluye perfiles para los juegos de la tabla completa de abajo. Upstream publica pruebas en Mac o iPhone según el título: **tener un perfil o una IPA compilada no confirma que ese juego funcione en tu iPhone**. Abre la ficha del juego para comprobar plataforma, versión y problemas conocidos.

Algunos títulos incluidos para empezar a explorar:

| Juego | Versión del perfil | Referencia |
|---|---|---|
| **Metroid Dread** | **2.1.0** | [Ficha](dm/games/010093801237C000/README.md) · confirmado en nuestro iPhone |
| Super Mario Bros. Wonder | 1.2.1 / 1.0.0 | [Ficha y límites](dm/games/010015100B514000/README.md) |
| Super Mario Odyssey | 1.4.1 | [Ficha y límites](dm/games/0100000000010000/README.md) |
| Mario Kart 8 Deluxe | 4.0.0 | [Ficha y límites](dm/games/0100152000022000/README.md) |
| The Legend of Zelda: Breath of the Wild | 1.9.0 | [Ficha y límites](dm/games/01007EF00011E000/README.md) |
| The Legend of Zelda: Tears of the Kingdom | 1.4.3 | [Ficha y límites](dm/games/0100F2C0115B6000/README.md) |
| The Legend of Zelda: Link's Awakening | 1.1.0 | [Ficha y límites](dm/games/01006BB00C6F0000/README.md) |
| Hades | 1.0.38233 | [Ficha y límites](dm/games/0100535012974000/README.md) |
| Cuphead | 1.3.7 | [Ficha y límites](dm/games/0100A5C00D162000/README.md) |
| Celeste | 1.4.1.1 | [Ficha y límites](dm/games/01002B30028F6000/README.md) |
| Balatro | 1.1.3 | [Ficha y límites](dm/games/0100CD801CE5E000/README.md) |

<details>
<summary>Ver los 70 perfiles incluidos y sus versiones</summary>

| Juego y ficha | Versión del perfil |
|---|---|
| [13 Sentinels: Aegis Rim](dm/games/01003FC01670C000/README.md) | 1.10 |
| [13 Sentinels: Aegis Rim, Asian release](dm/games/01008D7016438000/README.md) | 1.00 (base) |
| [Absolum](dm/games/0100A83022A22000/README.md) | 1.1.1 |
| [Ace Attorney Investigations Collection](dm/games/010005501E68C000/README.md) | 1.0.0.2 |
| [Advance Wars 1+2: Re-Boot Camp](dm/games/0100300012F2A000/README.md) | 1.0.0 (base) |
| [AI: THE SOMNIUM FILES](dm/games/010089B00D09C000/README.md) | 1.0.1 |
| [ASTRAL CHAIN](dm/games/01007300020FA000/README.md) | 1.0.1 |
| [AI: THE SOMNIUM FILES - nirvanA Initiative](dm/games/0100713016CCC000/README.md) | 1.0.2 |
| [ANIMAL WELL](dm/games/010020D01AD24000/README.md) | 1.0.10 |
| [Animal Crossing: New Horizons](dm/games/01006F8002326000/README.md) | 3.0.3 |
| [BALL x PIT](dm/games/010086A022444000/README.md) | 1.293 |
| [Balatro](dm/games/0100CD801CE5E000/README.md) | 1.1.3 |
| [Bayonetta](dm/games/010076F0049A2000/README.md) | 1.1 |
| [Bayonetta 2](dm/games/01007960049A0000/README.md) | 1.2 |
| [Bayonetta 3](dm/games/01004A4010FEA000/README.md) | 1.2.0 |
| [Big Brain Academy: Brain vs. Brain](dm/games/0100620012D6E000/README.md) | 1.2.0 |
| [Brain Memory Training Academy](dm/games/0100F5D01DA3A000/README.md) | 1.0.0 (base) |
| [Captain Toad: Treasure Tracker](dm/games/01009BF0072D4000/README.md) | 1.4.2 |
| [Catherine: Full Body](dm/games/0100BF00112C0000/README.md) | 1.0.1a |
| [Celeste](dm/games/01002B30028F6000/README.md) | 1.4.1.1 |
| [Cuphead](dm/games/0100A5C00D162000/README.md) | 1.3.7 |
| [DARK SOULS: REMASTERED](dm/games/01004AB00A260000/README.md) | 1.0.3 |
| [Digimon Story Cyber Sleuth: Complete Edition](dm/games/010014E00DB56000/README.md) | 1.0.3 |
| [DRAGON QUEST VII Reimagined](dm/games/0100A9D01C446000/README.md) | 1.2.0 |
| [DRAGON QUEST XI S: Echoes of an Elusive Age – Definitive Edition](dm/games/01006C300E9F0000/README.md) | 1.0.4 |
| [FINAL FANTASY RESONANCE](dm/games/0100606026F12000/README.md) | 1.0.1 |
| [FINAL FANTASY TACTICS - The Ivalice Chronicles](dm/games/010038B015560000/README.md) | 1.4.0 |
| [Fire Emblem Engage](dm/games/0100A6301214E000/README.md) | 2.0.0 |
| [Fire Emblem: Three Houses](dm/games/010055D009F78000/README.md) | 1.2.0 |
| [Ghost Trick: Phantom Detective](dm/games/010029B018432000/README.md) | 1.0.0 (base) |
| [Hades](dm/games/0100535012974000/README.md) | 1.0.38233 |
| [Hades II](dm/games/0100A00019DE0000/README.md) | base game |
| [Hollow Knight: Silksong](dm/games/010013C00E930000/README.md) | 1.0.30000 |
| [Hyrule Warriors: Age of Calamity](dm/games/01002B00111A2000/README.md) | 1.3.0 |
| [Luigi's Mansion 3](dm/games/0100DCA0064A6000/README.md) | 1.4.0 |
| [Mario Kart 8 Deluxe](dm/games/0100152000022000/README.md) | 4.0.0 |
| [Mario vs. Donkey Kong](dm/games/0100B99019412000/README.md) | 1.0.1 (cartridge base) |
| [Metroid Dread](dm/games/010093801237C000/README.md) | 2.1.0 |
| [Monster Hunter Rise](dm/games/0100B04011742000/README.md) | 16.0.2 |
| [Monster Train 2](dm/games/010051701FB46000/README.md) | 1.1.1 |
| [NieR:Automata The End of YoRHa Edition](dm/games/010056B015FE8000/README.md) | 1.0.3 |
| [Octopath Traveler 0](dm/games/01005270232F2000/README.md) | 1.0.5 |
| [OCTOPATH TRAVELER II](dm/games/0100A3501946E000/README.md) | 1.1.1 |
| [Paper Mario: The Thousand-Year Door](dm/games/0100ECD018EBE000/README.md) | 1.0.1 |
| [Patrick's Parabox](dm/games/0100E44016C22000/README.md) | 1.0.1 |
| [Persona 5 Royal](dm/games/01005CA01580E000/README.md) | 1.0.2 |
| [Pikmin 4](dm/games/0100B7C00933A000/README.md) | 1.1.1 |
| [Pokémon Brilliant Diamond](dm/games/0100000011D90000/README.md) | 1.3.0 |
| [Pokémon Legends: Z-A](dm/games/0100F43008C44000/README.md) | 2.0.2 |
| [Pokémon Shield](dm/games/01008DB008C2C000/README.md) | 1.3.2 |
| [Pokémon Sword](dm/games/0100ABF008968000/README.md) | 1.3.2 |
| [Portal](dm/games/01007BB017812000/README.md) | 1.0.3 |
| [Raging Loop](dm/games/010020400E1C2000/README.md) | 1.0.0 (base) |
| [Rhythm Heaven Groove](dm/games/0100D9F01D474000/README.md) | 1.0.0 (base) |
| [ROMANCE OF THE THREE KINGDOMS 8 REMAKE](dm/games/0100C2A01A730000/README.md) | 1.1.3 |
| [STEINS;GATE RE:BOOT](dm/games/01008BC024FDE000/README.md) | 1.0.3 |
| [Stardew Valley](dm/games/0100E65002BB8000/README.md) | 1.6.15.13 |
| [Super Mario 3D World + Bowser's Fury](dm/games/010028600EBDA000/README.md) | 1.2.2 |
| [Super Mario Bros. Wonder](dm/games/010015100B514000/README.md) | 1.2.1 (and 1.0.0) |
| [Super Mario Galaxy](dm/games/010099C022B96000/README.md) | 1.3.1 |
| [Super Mario Galaxy 2](dm/games/0100FD8022DAA000/README.md) | 1.4.0 |
| [Super Mario Odyssey](dm/games/0100000000010000/README.md) | 1.4.1 |
| [Super Smash Bros. Ultimate](dm/games/01006A800016E000/README.md) | 13.0.5 |
| [Taiko Risshiden V DX](dm/games/0100346017304000/README.md) | 1.1.1 |
| [The Great Ace Attorney Chronicles](dm/games/010036E00FB20000/README.md) | 1.0.0 (base) |
| [The Legend of Zelda: Breath of the Wild](dm/games/01007EF00011E000/README.md) | 1.9.0 |
| [The Legend of Zelda: Echoes of Wisdom](dm/games/01008CF01BAAC000/README.md) | 1.1.0 |
| [The Legend of Zelda: Link's Awakening](dm/games/01006BB00C6F0000/README.md) | 1.1.0 |
| [The Legend of Zelda: Tears of the Kingdom](dm/games/0100F2C0115B6000/README.md) | 1.4.3 |
| [Unicorn Overlord](dm/games/010069401ADB8000/README.md) | 1.05 |

</details>

La región y versión del juego importan. Un título sin perfil puede recibir una compilación provisional y aun así no arrancar. Los PR de juegos nuevos que sólo revisamos no están incluidos automáticamente; consulta [la revisión de PR](docs/personal-pr-review.md).

## Preparar el Mac

Necesitas:

- Un Mac con **Xcode completo** instalado y abierto al menos una vez, y SDK de iOS 26 o posterior.
- [Homebrew](https://brew.sh) instalado. El script instala las demás herramientas que falten.
- Un iPhone con **A17 Pro o posterior**, o iPad con **M1 o posterior**, y **iOS/iPadOS 26 o posterior**, según los requisitos de esta base. El soporte para otros chips no se incorporó desde los PR revisados.
- Tus archivos del juego y `prod.keys`, en una carpeta fuera del repositorio.
- Espacio para los archivos originales, la extracción, cachés, la IPA completa y otra copia de `romfs`.
- [Sideloadly](https://sideloadly.io) para firmar e instalar con tu cuenta Apple personal.

En un Mac nuevo, descarga nuestra copia privada. Debes tener acceso con tu cuenta GitHub:

```sh
git clone https://github.com/nalancer08/nxnative-personal.git
cd nxnative-personal
```

**Si ya tienes nuestra copia en este Mac, abre Terminal en esa carpeta y omite el clonado.** No clones de nuevo el repositorio original para compilar: esa copia no tendría nuestro editor ni estos scripts.

## Compilar fácilmente

### Opción 1: un comando y selector de carpeta

Desde la carpeta del repositorio:

```sh
bash scripts/prepare_ios.sh
```

Selecciona la carpeta que contiene un solo juego con sus actualizaciones. El script pide `prod.keys` si no está en esa carpeta, prepara las herramientas, compila y separa los datos automáticamente.

### Opción 2: indicar la carpeta

Cambia la ruta del ejemplo por la tuya y conserva las comillas:

```sh
bash scripts/prepare_ios.sh "/Volumes/Juegos/MetroidDread"
```

La carpeta puede tener esta estructura; no cambies las extensiones de los archivos:

```text
MetroidDread/
  juego-base.nsp
  actualizacion.nsp
  prod.keys
```

También se admiten XCI y, con soporte adicional instalado por el script, NSZ/XCZ. Usa una carpeta distinta para cada juego. Por defecto se selecciona la actualización más reciente presente; puedes fijar una con `--package`.

### Opción 3: doble clic

Abre **`scripts/Build-iPhone.command`** desde Finder. Ejecuta el mismo flujo y te pide la carpeta. En nuestro Mac también está el acceso `Preparar-juego-iPhone.command` en Descargas.

### Qué obtienes

Al terminar, la consola muestra las rutas exactas. Junto al juego encontrarás:

```text
nxnative-ios-FECHA-unsigned.ipa             ← copia completa, se conserva
nxnative-ios-FECHA-unsigned-light-XXXX/
  nxnative-ios-FECHA-unsigned-light.ipa     ← instala ESTA con Sideloadly
  romfs/                                  ← datos del juego para Finder
  INSTALL.txt
nxnative-ios.json                         ← identidad y opciones de futuras compilaciones
```

Los nombres incluyen fecha y una parte única. La IPA ligera de Dread mide aproximadamente **57 MB**; sus datos van aparte. Otros juegos pueden tener tamaños distintos.

El proceso conserva las salidas anteriores y reutiliza las cachés válidas. **La IPA se genera sin firmar**: la cuenta Apple se usa después, dentro de Sideloadly. No se suben juegos, llaves ni partidas a GitHub.

## Instalar con Sideloadly

1. Descarga y abre [Sideloadly](https://sideloadly.io) en el Mac.
2. Conecta el iPhone por USB, desbloquéalo y acepta **Confiar** si lo solicita.
3. Selecciona tu iPhone en Sideloadly y arrastra la **IPA que termina en `-light.ipa`**.
4. Usa tu **cuenta Apple personal**, la misma que utilizaste si estás actualizando una instalación existente. En este proyecto no usamos cuentas ni equipos de empresa.
5. Pulsa **Start** y completa la autenticación que solicite Sideloadly.
6. Si el iPhone lo solicita, activa **Ajustes → Privacidad y seguridad → Modo de desarrollador**. Para un desarrollador no confiable, revisa **Ajustes → General → VPN y gestión de dispositivos** y autoriza la cuenta con la que firmaste.

Consulta las instrucciones vigentes y los errores en la [FAQ oficial de Sideloadly](https://sideloadly.io/faq). Con cuenta gratuita, la firma normalmente dura **7 días**; Sideloadly también ofrece renovación automática cuando su configuración y conexión lo permiten.

### Copiar los datos con Finder: primera instalación

1. En Finder, selecciona el **iPhone → Archivos → la app del juego**.
2. Arrastra la carpeta **`romfs` completa** del resultado de compilación a los documentos de esa app y espera a que termine.
3. Abre el juego. Si ya estaba abierto, ciérralo por completo y ábrelo otra vez.

En Dread, la estructura dentro de la app debe ser `Documents/romfs/system/shd/...`. Evita `romfs/romfs`. En otros juegos el contenido cambia, pero el directorio que copias sigue siendo `romfs`.

Si la app no aparece en Archivos de Finder, ábrela una vez y ciérrala; aún sin los datos puede fallar al arrancar. Copia `romfs` y vuelve a abrirla. [Guía de Apple para compartir archivos](https://support.apple.com/en-us/119585).

## Actualizar sin perder partidas

**Instala encima de la app existente. No la desinstales.** Desinstalar elimina sus documentos, partidas y datos copiados.

- Usa la **misma cuenta Apple personal** y el **mismo bundle ID efectivo** de la instalación anterior. Si configuraste un identificador personalizado en Sideloadly, consérvalo.
- Mantén `nxnative-ios.json`: nuestros scripts guardan ahí la identidad para siguientes compilaciones. Eso no sustituye los ajustes que Sideloadly haya aplicado al firmar.
- Haz una copia de `save` desde los documentos de la app antes de cambiar de versión, cuando esté disponible y con el juego cerrado.
- Una actualización del editor puede reutilizar el `romfs` del teléfono si los datos del juego siguen siendo idénticos. Una actualización del juego puede necesitar el nuevo `romfs`.
- Para renovar una firma, vuelve a instalar la misma IPA con la misma identidad o usa la renovación de Sideloadly. [Referencia oficial sobre actualizar y conservar progreso](https://sideloadly.io/faq).

### Recompilar sólo la app con los datos ya preparados

Para cambios del editor u otros cambios de la app, cuando ya existen extracción, módulos reescritos y shaders válidos:

```sh
bash scripts/prepare_ios.sh "/Volumes/Juegos/MetroidDread" --app-only
```

Este modo no necesita llaves ni vuelve a extraer el juego. Recompila y vuelve a generar las IPA y una copia de `romfs`. Verifica las cachés; si no son válidas, se detiene. Para una versión de juego o cadena de shaders distinta, usa el comando normal.

## Mover y ajustar los controles

Dentro del juego toca **Edit controls**:

1. Selecciona A, B, X, Y u otro control en el menú, o toca cerca de su centro.
2. Arrastra fuera del panel para mover el seleccionado. **Show / hide tools** muestra u oculta el panel para acceder al área detrás.
3. Ajusta **Size** entre 50–200% y **Opacity** entre 0–100%.
4. **Save** guarda; **Cancel** descarta. **Reset control** restaura el seleccionado y **Reset all** restaura el layout; confirma con **Save**.

Cada juego guarda sus propios acomodos de **2D y 3D**. Un control al 0% sigue recibiendo toques; el editor lo muestra parcialmente para encontrarlo. **El juego sigue corriendo mientras editas.** Conectar o desconectar un mando cancela los cambios de edición no guardados.

## Si algo falla

| Problema | Qué revisar |
|---|---|
| No hay NSP/XCI en la carpeta | Elige la carpeta que contiene los archivos directamente, no su carpeta padre. |
| Faltan herramientas | Instala Xcode y Homebrew; ejecuta otra vez el preparador y revisa el primer error. |
| Caché de shaders inválida en `--app-only` | Ejecuta el flujo normal para regenerar lo que haya cambiado. |
| Sideloadly no detecta el iPhone | Desbloquéalo, revisa el cable USB y acepta Confiar en el Mac/iPhone. |
| El juego no abre después de instalar | Comprueba que `romfs` se copió completo, la versión y los requisitos de la ficha del juego. |
| El juego dejó de abrir días después | Revisa si venció la firma y renueva conservando la cuenta y el identificador. |
| Error de compilación o pantalla incorrecta | Conserva el error y los logs de `<title ID>_build/logs/`; en el teléfono, busca `Documents/log.txt`. |

Los mensajes de compilación se muestran en inglés. El nuevo preparador usa esta copia del código y no exige borrar tus modificaciones ni volver al checkout original.

## Qué cambiamos en esta copia

- Editor compartido de posición, tamaño y opacidad por control, con guardado por juego/layout.
- Preparación de dependencias y compilación desde nuestra propia base.
- Exportación automática de IPA ligera y `romfs`, validación de integridad y conservación de archivos anteriores.
- Registro de identidad por juego y bloqueo de compilaciones simultáneas desde el wrapper.
- Corrección del cálculo de espacio de extracción del PR #277.
- [Revisión de 57 PR abiertos y 20 cambios posteriores](docs/personal-pr-review.md). Sólo #277 se integró desde esa revisión; los demás conservan decisiones y validaciones pendientes.

Guías adicionales: [automatización detallada](docs/personal-ios.md) · [documentación de desarrollo](docs/development.md) · [README anterior con la galería y créditos completos](README-original.md).

Este proyecto deriva de **seedds/nxnative** y conserva la [licencia MIT](LICENSE). Los créditos y licencias de sus componentes siguen en el [README anterior](README-original.md#acknowledgements) y en [third_party](dm/third_party/README.md). El repositorio no contiene los juegos ni sus llaves.

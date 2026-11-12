# nxnative Easy

[English](README.md) · **Español** · [Web](https://nalancer08.github.io/nxnative-easy/es/)

Una biblioteca de juegos para Mac basada en [nxnative](https://github.com/seedds/nxnative). Añade tus propios archivos de Switch, prepara el juego paso a paso y juega en Mac o instálalo en iPhone y iPad.

**[Descargar nxnative Easy para Mac](https://github.com/nalancer08/nxnative-easy/releases/latest/download/nxnative-Easy-macOS-arm64.zip)**

Descomprime el ZIP, mueve **nxnative Easy.app** a **Aplicaciones** y ábrela. La biblioteca está lista para usar. Si macOS bloquea la primera apertura, consulta la [ayuda de instalación](docs/personal-ios.md).

## Antes de empezar

1. Usa un Mac con Apple silicon, macOS 26.6+ y Xcode 27.2. Abre Xcode una vez antes de preparar un juego.
2. Pulsa **Añadir juego**, elige Mac o iPhone/iPad y añade tus propios archivos. Easy identifica el título, su versión y las actualizaciones antes de compilar. Los paquetes cifrados de Switch 1 también requieren tu propio `prod.keys`.
3. Elige dónde guardar la exportación y pulsa **Preparar juego**. Abre el resultado desde tu biblioteca o sigue los pasos de instalación en iPhone/iPad.

Para jugar en iPhone necesitas un chip A17 Pro o posterior. En iPad necesitas M1 o posterior. Usa iOS o iPadOS 26+ y tu cuenta Apple para firmar la instalación. [Instalación y renovación de firma](docs/game-maintenance.md)

## Compatibilidad

<!-- BEGIN GENERATED COMPATIBILITY LINKS -->
[Nintendo Switch 1 · 144](https://nalancer08.github.io/nxnative-easy/es/?console=switch1#games) · [Nintendo Switch 2 · 11](https://nalancer08.github.io/nxnative-easy/es/?console=switch2#games) · [Tabla completa de juegos probados](dm/games/README.md#games)
<!-- END GENERATED COMPATIBILITY LINKS -->

Filtra el catálogo por consola y busca por título o versión. Cada ficha indica qué versiones y dispositivos se probaron y sus limitaciones. Los juegos de Switch 2 se preparan en Mac desde un NUP o una carpeta extraída. [Formatos y requisitos de Switch 2](docs/switch2.md)

## Sigue jugando

- Revisa dónde está instalado cada juego, cuándo caduca su firma y cuándo conviene prepararlo de nuevo. [Mantenimiento de juegos](docs/game-maintenance.md)
- Prueba tu control en Mac y ajusta los botones táctiles en iPhone o iPad. [Opciones por juego](docs/game-options-and-cleanup.md)
- Continúa tu partida entre compilaciones compatibles de Mac y iPhone/iPad con iCloud Drive. Easy conserva ambas copias cuando hay un conflicto. [Configura tus partidas de iCloud](docs/icloud-saves.md)

Easy usa los archivos que tú añades. Usa tus propios juegos y llaves.

## Créditos y recursos

[seedds/nxnative](https://github.com/seedds/nxnative) aporta el motor y los perfiles de juegos. Easy añade la biblioteca, la preparación guiada y la instalación en tus dispositivos. [Créditos originales](README-original.md#acknowledgements) · [Licencia MIT](LICENSE)

[App portable y actualizaciones](docs/portable-desktop.md) · [Instalación desde código y comandos](README-comandos.md) · [Desarrollo](docs/development.md)

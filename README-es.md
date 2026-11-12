# nxnative Easy

[English](README.md) · **Español** · [Web](https://nalancer08.github.io/nxnative-easy/es/)

Una biblioteca de juegos para Mac basada en [nxnative](https://github.com/seedds/nxnative). Añade tus propios archivos de Switch, prepara el juego paso a paso y juega en Mac o instálalo en iPhone y iPad.

## Instala Easy en tu Mac

**[Descargar nxnative Easy para Mac](https://github.com/nalancer08/nxnative-easy/releases/latest/download/nxnative-Easy-macOS-arm64.zip)**

Haz doble clic en el ZIP, arrastra **nxnative Easy.app** a **Aplicaciones** y ábrela desde ahí. La descarga incluye la app lista para abrir.

Si macOS te pide autorizar esta descarga, intenta abrir la app primero y ve a **Configuración del Sistema → Privacidad y seguridad → Abrir de todos modos**. [Instrucciones de Apple](https://support.apple.com/es-mx/102445)

## Antes de empezar

Para preparar juegos, usa un Mac con Apple silicon y macOS 26.6 o posterior. Instala Xcode 27.2 y ábrelo una vez para completar su configuración. Si vas a preparar un juego para iPhone o iPad, instala el componente de iOS desde **Xcode → Configuración → Componentes**. [Descargar Xcode](https://developer.apple.com/news/releases/?id=10292026a)

1. En Easy, pulsa **Añadir juego**, elige Mac o iPhone/iPad y selecciona tus propios archivos. Easy muestra el título, la versión y las actualizaciones detectadas. Los paquetes cifrados de Switch 1 también requieren tu propio `prod.keys`.
2. Elige dónde guardar la exportación y pulsa **Preparar juego**.
3. **Mac:** juega desde tu biblioteca. **iPhone o iPad:** conecta por USB, desbloquea el dispositivo y sigue los pasos de Easy para firmar e instalar con tu cuenta Apple. Pulsa **Confiar** en el dispositivo si te lo pide.

Para jugar en iPhone necesitas un chip A17 Pro o posterior. En iPad necesitas M1 o posterior. Usa iOS o iPadOS 26+. [Instalación y renovación de firma](docs/game-maintenance.md)

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

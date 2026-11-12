# nxnative Easy

**English** · [Español](README-es.md) · [Website](https://nalancer08.github.io/nxnative-easy/)

A Mac game library built on [nxnative](https://github.com/seedds/nxnative). Add your own Switch game files, prepare them with a guided build, then play on Mac or install on iPhone and iPad.

**[Download nxnative Easy for Mac](https://github.com/nalancer08/nxnative-easy/releases/latest/download/nxnative-Easy-macOS-arm64.zip)**

Unzip, move **nxnative Easy.app** to **Applications**, and open it. The launcher is ready to run. If macOS blocks the first launch, see [installation help](docs/personal-ios.md).

## Before you start

1. Use an Apple silicon Mac with macOS 26.6+ and Xcode 27.2. Open Xcode once before preparing a game.
2. Choose **Add game**, select Mac or iPhone/iPad, and add your own game files. Easy identifies the title, version and updates before you build. Encrypted Switch 1 packages also need your own `prod.keys`.
3. Choose where to save the export and click **Prepare game**. Open the result from your library, or follow the installation steps for iPhone/iPad.

For mobile play, use an iPhone with A17 Pro or newer or an iPad with M1 or newer, running iOS or iPadOS 26+. Installing uses your Apple account for signing. [Installation and signature renewal](docs/game-maintenance.md)

## Compatibility

<!-- BEGIN GENERATED COMPATIBILITY LINKS -->
[Nintendo Switch 1 · 144](https://nalancer08.github.io/nxnative-easy/?console=switch1#games) · [Nintendo Switch 2 · 11](https://nalancer08.github.io/nxnative-easy/?console=switch2#games) · [Full tested games table](dm/games/README.md#games)
<!-- END GENERATED COMPATIBILITY LINKS -->

The catalog filters by console and searches by title or version. Each game note lists tested builds, devices and known limitations. Switch 2 preparation is available on Mac from a NUP or extracted game folder. [Switch 2 formats and requirements](docs/switch2.md)

## Keep playing

- Keep track of where each game is installed, when its signature expires, and when you need to prepare it again. [Game maintenance](docs/game-maintenance.md)
- Test your controller on Mac and adjust the touch layout on iPhone or iPad. [Game options](docs/game-options-and-cleanup.md)
- Continue a save between compatible Mac and iPhone/iPad builds using iCloud Drive. Easy keeps both copies when progress conflicts. [Set up iCloud saves](docs/icloud-saves.md)

Easy uses files you provide. Bring your own games and keys.

## Credits and resources

[seedds/nxnative](https://github.com/seedds/nxnative) provides the engine and game profiles. Easy adds the library, guided preparation and device installation. [Original credits](README-original.md#acknowledgements) · [MIT license](LICENSE)

[Portable app and updates](docs/portable-desktop.md) · [Source setup and commands](README-comandos.md) · [Development](docs/development.md)

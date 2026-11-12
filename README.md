# nxnative Easy

**English** · [Español](README-es.md) · [Website](https://nalancer08.github.io/nxnative-easy/)

A Mac game library built on [nxnative](https://github.com/seedds/nxnative). Add your own Switch game files, prepare them with a guided build, then play on Mac or install on iPhone and iPad.

## Install Easy on your Mac

**[Download nxnative Easy for Mac](https://github.com/nalancer08/nxnative-easy/releases/latest/download/nxnative-Easy-macOS-arm64.zip)**

Double-click the ZIP, drag **nxnative Easy.app** into **Applications**, then open it there. The download contains the ready-to-open app.

If macOS asks you to approve the first launch of this download, go to **System Settings → Privacy & Security → Open Anyway** after trying to open the app. [Apple's instructions](https://support.apple.com/en-us/102445)

## Before you start

To prepare games, use an Apple silicon Mac with macOS 26.6 or later. Install Xcode 27.2 and open it once to finish setup. If you're preparing for iPhone or iPad, install iOS platform support in **Xcode → Settings → Components**. [Download Xcode](https://developer.apple.com/news/releases/?id=10292026a)

1. In Easy, click **Add game**, choose Mac or iPhone/iPad, and select your own game files. Easy shows the title, version and detected updates. Encrypted Switch 1 packages also need your own `prod.keys`.
2. Choose where to save the export and click **Prepare game**.
3. **Mac:** play from your library. **iPhone or iPad:** connect by USB, unlock the device, and follow Easy's steps to sign and install with your Apple Account. Tap **Trust** on the device if asked.

For mobile play, use an iPhone with A17 Pro or newer or an iPad with M1 or newer, running iOS or iPadOS 26+. [Installation and signature renewal](docs/game-maintenance.md)

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

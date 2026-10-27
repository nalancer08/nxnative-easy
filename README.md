# nxnative Easy

**English** · [Español](README-es.md)

**Run your own supported Nintendo Switch games natively on Mac, iPhone and iPad — with Metal graphics, physical controllers and editable touch controls.**

## Start here

**First:** install full [Xcode](https://apps.apple.com/app/xcode/id497799835) from the Mac App Store and open it once. **Xcode compiles the games too**, so a prebuilt launcher cannot remove this requirement.

**Then:** paste this single command into Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nalancer08/nxnative-easy/main/install.sh)"
```

It downloads nxnative Easy, installs Homebrew and the missing build tools, **compiles your own Mac interface and opens it**. Follow the four numbered setup stages and any password or confirmation prompts in Terminal. No Apple developer account is used. If you run setup again, it verifies the new app before replacing your installed version and keeps the previous app as a backup.

**Already downloaded this repository?** Double-click **START-HERE.command** in its top-level folder. It performs the same setup; you do not need to find a script under `scripts/`. If macOS blocks that file, use the Terminal command above.

When the app opens:

1. Choose **iPhone / iPad** or **Mac**.
2. Choose your own **game folder** and **keys folder**.
3. Click **Prepare game**.

**After setup:** open **nxnative Easy.app** in your home **Applications** folder. The setup keeps its source checkout separately, so you can delete the downloaded ZIP and folder.

**Mac:** creates one complete game `.app`, with its game data included inside; click **Open game**. No separate RomFS folder to copy. No Sideloadly or iPhone needed. Saves stay in `~/Library/Application Support/nxnative/<title ID>/`.

**iPhone / iPad:** creates an unsigned lightweight IPA; install it with Sideloadly, then copy the game data as shown in the app. [See the iPhone/iPad preparation screen](docs/images/nxnative-ios-v1.4.png).

**Required:** an Apple silicon Mac (M1 or newer), macOS 26+ and Xcode 26+. The command installs the other tools. You must provide your own games and keys. Compilation can take time, especially for the first game.

![The nxnative Easy desktop app](docs/images/nxnative-mac-v1.4.png)

## What this version adds

Built on [seedds/nxnative](https://github.com/seedds/nxnative). The original project provides the engine, game profiles and compatibility work. **nxnative Easy** adds:

- **Native Mac app:** game-folder selection, progress, cancellation, and buttons for the IPA, RomFS data and Sideloadly.
- **Editable iPhone touch controls:** position, size and opacity, saved per game and 2D/3D layout.
- **Lightweight IPA export for iPhone/iPad only:** RomFS data live separately; existing outputs and valid caches are preserved.
- **Your own keys:** explicitly select the external folder containing your `prod.keys`. No games or keys are included, downloaded or distributed.
- **Local preparation:** no Apple account or company certificate is used to build the desktop app.

We provide **source code, a preparation interface and build tools**. The output is a local Mac game app, or an unsigned iPhone/iPad IPA that you sign and install yourself with Sideloadly. Games, console keys, Apple signing and universal game compatibility are not provided.

## Engine updates and multiplayer

Selected upstream build improvements are recorded in the [review and maintenance flow](docs/personal-pr-review.md): .NET discovery, Mac pipeline packaging, cache reuse and shader regression checks. Graphics/runtime upgrades are evaluated separately to preserve working games.

The current runtime plays **offline**. Nintendo online services, LAN/netplay and Windows are not supported. A Nintendo Switch Online subscription does not enable them here. Local controllers on one Mac are a separate feature. [How the game code, mods and networking work](docs/development.md#game-binaries-mods-and-networking).

## Language

The app starts in **English**. Choose **Español** using the selector at the top; your selection is remembered on this Mac. This changes the interface language, not the game's language. Build diagnostics keep their original language.

## Updating the app

From **version 1.4**, the app checks for new releases at launch and every six hours while open. When one is available, click **Update now**. It downloads the new source and game profiles, builds and verifies the new Mac interface, then restarts it. Progress stays in the window. You can also use **nxnative Easy → Check for updates…**.

The update uses a separate source folder and keeps the previous app as a backup. It does not reset your checkout or modify your game files, keys or saves. Updates are disabled while preparing a game. To apply new engine or profile changes to a previously prepared game, prepare that game again.

**Using version 1.3 or earlier?** Run the setup command above once, or double-click **START-HERE.command**. Future updates then appear inside the app.

## What happens after Prepare game?

The app prepares the tools and builds for your chosen device. **Mac** produces a game app with **Open game** and **Show app** buttons. **iPhone / iPad** produces a lightweight IPA and shows the Sideloadly and Finder steps when ready. Your own files and previous outputs stay in the game folder.

Setup keeps a separate source checkout and preserves local edits. Developers can still use [`scripts/Abrir-interfaz.command`](scripts/Abrir-interfaz.command).

## How the Mac app is built

The launcher uses Xcode's Swift compiler. The desktop app is explicitly **ad-hoc signed**, locally, with no Apple account, certificate or team (`TeamIdentifier` is unset). No company account is used. You enter your personal Apple account separately in Sideloadly when signing the **iPhone IPA**.

The app has an original phone-and-controller icon. Game cards use the existing upstream screenshots in this repository as a support reference; they do not provide or download games.

## Install with Sideloadly and Finder

1. When the IPA is ready, connect your iPhone and click **Send to Sideloadly**. The app opens the prepared IPA there.
2. In Sideloadly, click **Start** using your **personal** Apple account. If needed, use **Show IPA** to find the file manually.
3. On the first installation, click **Show game data** and copy the complete `romfs` folder using **Finder → iPhone → Files → your game**.

For updates, keep the same Apple account and effective bundle ID used in Sideloadly. **Install over the existing app; do not uninstall it**, to retain its saves. Reuse the existing `romfs` only when the game data have not changed. The app installs missing build dependencies after Xcode and Homebrew are available, but **does not sign or install the iPhone game**. Those steps happen in Sideloadly. The app explains them only when the IPA is ready. See the [official Sideloadly FAQ](https://sideloadly.io/faq).

## Included game profiles

The home carousel shows the game profiles in your checkout; it does not provide or download games. You must add your own game files. Click **View all** at the top right to browse the complete support list. Search by name, version or Title ID; each result links to its game notes. The catalog reads the local profiles each time you open it. The carousel rotates automatically and pauses while you hover over it.

**Our own checks cover macOS compilation and packaging, not automatic iPhone gameplay verification.** Profiles and gameplay reports come from upstream and may concern Mac or iPhone; read [your game's notes](dm/games/README.md#games). A profile does not guarantee that every game version works on every device.

This base requires iOS/iPadOS 26 or later, an iPhone with A17 Pro or later, or an iPad with M1 or later. Supply your own game files and keys.

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

## Xbox, PS5 and PS4 controllers

The game apps use Apple's GameController framework on **Mac, iPhone and iPad**:

- **Xbox:** Bluetooth-capable Xbox Wireless Controller (model 1708), Series X/S and Elite Series 2.
- **PS5:** DualSense and DualSense Edge.
- **PS4:** DualShock 4.

The preparation app automatically shows connected controller names and **Ready on this Mac** when Apple exposes a compatible gamepad profile. It updates when you connect or disconnect a controller. The Mac controller panel is hidden when you choose iPhone/iPad. Pair a controller directly with the device where you will play.

In **Mac** mode, click **Test controller** to see live input: buttons and D-pad light up, both sticks move, and trigger bars show pressure. **Input received!** appears only after input is detected. If several controllers are connected, choose which one to test. The tester reads input only while its window is visible and does not take input handlers away from games.

![Live controller test on Mac](docs/images/nxnative-controller-test.png)

Pair your controller in the device's **Bluetooth settings**, then open the prepared game. No extra driver or launcher setting is needed. Sticks, D-pad, face buttons, shoulders, triggers, stick clicks and menu buttons are mapped automatically. On iPhone/iPad, touch controls hide while a physical controller is connected.

Face buttons follow **Nintendo positions**, rather than the letters printed on an Xbox controller: Switch A = Xbox B / PlayStation Circle; Switch B = Xbox A / Cross; Switch X = Xbox Y / Triangle; Switch Y = Xbox X / Square.

Standard gamepad input is supported; DualSense adaptive triggers, controller motion and touchpad gestures are not mapped. Rumble depends on the features exposed by the controller and OS. Mac supports separate local players when the game allows it; iPhone/iPad merge controllers into player 1.

See Apple's [Xbox pairing guide](https://support.apple.com/en-us/111101) and [PlayStation pairing guide](https://support.apple.com/en-us/111100). This support was checked in the input code and automated tests; these specific physical models have not been tested in this checkout.

## Make the controls your own

Inside the game, tap **Edit controls**. Move buttons, adjust their size and opacity, then tap **Save**. **Cancel** discards edits; **Reset control / Reset all** restores defaults. Each game keeps separate 2D and 3D layouts. The game continues running while you edit. The desktop language selector does not translate this in-game editor.

<details>
<summary>Guides, commands and technical details</summary>

- [Detailed command and installation guide, in Spanish](README-comandos.md).
- [Automation and troubleshooting](docs/personal-ios.md).
- [Upstream PR applicability review](docs/personal-pr-review.md).
- [Previous README and full credits](README-original.md).

</details>

Based on [seedds/nxnative](https://github.com/seedds/nxnative), with our touch editor and preparation workflow. The [MIT license](LICENSE), [original acknowledgements](README-original.md#acknowledgements) and third-party licenses are retained. Personal additions are authored by **nalancer08**; upstream commits retain their original authors.

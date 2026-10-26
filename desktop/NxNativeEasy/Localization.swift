import Foundation

// English is the explicit first-launch default, independent of macOS language.
enum EasyLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    static func load(defaults: UserDefaults = .standard) -> EasyLanguage {
        EasyLanguage(rawValue: defaults.string(forKey:"interfaceLanguage") ?? "en") ?? .english
    }
    func save(defaults: UserDefaults = .standard) { defaults.set(rawValue,forKey:"interfaceLanguage") }
}

struct EasyStrings {
    static let english: [String:String] = [
        "Ver todos": "View all",
        "Todos los juegos": "All games",
        "Cerrar": "Close",
        "perfiles incluidos en esta copia": "profiles included in this checkout",
        "Son perfiles del repositorio, no una prueba de funcionamiento en tu dispositivo. Consulta la ficha para ver plataformas, versiones y límites.": "These are repository profiles, not proof of gameplay on your device. Check each game note for platforms, versions and limitations.",
        "Buscar por nombre, versión o Title ID": "Search by name, version or Title ID",
        "Limpiar búsqueda": "Clear search",
        "No pudimos leer los perfiles. Comprueba que el repositorio siga en su ubicación original.": "Could not read the profiles. Check that the source checkout is still at its original location.",
        "No encontramos juegos con esa búsqueda.": "No games match your search.",
        "Versiones del perfil": "Profile versions",
        "Ficha del juego": "Game notes",

        "Tu próximo juego empieza aquí.": "Your next game starts here.",
        "Elige su carpeta. Nosotros preparamos la IPA ligera.": "Choose its folder. We will prepare the lightweight IPA.",
        "Ningún juego seleccionado": "No game selected",
        "Elegir juego": "Choose game",
        "Selecciona la carpeta con el juego base y sus actualizaciones NSP/XCI.": "Select the folder containing the base game and its NSP/XCI updates.",
        "No encontramos el juego en esa carpeta.": "No game files found in that folder.",
        "Elige la carpeta que contiene los archivos NSP o XCI directamente.": "Choose the folder that directly contains the NSP or XCI files.",
        "Guarda el juego fuera del repositorio.": "Keep game files outside the repository.",
        "Así tus juegos y llaves se quedan fuera de GitHub.": "This keeps your games and keys out of GitHub.",
        "Listo para preparar el juego.": "Ready to prepare your game.",
        "Un clic más. Los archivos anteriores se conservan.": "One more click. Existing files are preserved.",
        "No pudimos leer esa carpeta.": "We could not read that folder.",
        "Usar mis llaves": "Use my keys",
        "Elige tu carpeta con prod.keys. No copiamos las llaves ni las incluimos en la app.": "Choose your folder containing prod.keys. Keys are not copied or bundled with this app.",
        "Elige una carpeta externa con tu prod.keys.": "Choose an external folder containing your prod.keys.",
        "No se proporcionan llaves. Debes seleccionar las tuyas.": "No keys are provided. You must select your own.",
        "Tus llaves están seleccionadas.": "Your keys folder is selected.",
        "Sólo guardamos la ruta en este Mac, nunca su contenido.": "Only the folder path is saved on this Mac, never its contents.",
        "No encontramos el código de nxnative.": "The nxnative source checkout could not be found.",
        "Vuelve a crear la app desde el repositorio con Abrir-interfaz.command.": "Recreate the app from the repository using Abrir-interfaz.command.",
        "Preparando herramientas…": "Preparing build tools…",
        "Puedes dejar esta ventana abierta. No necesitas usar Terminal.": "You can leave this window open. No Terminal commands are needed.",
        "Preparación cancelada.": "Preparation cancelled.",
        "Tus archivos y partidas anteriores se conservaron.": "Your existing files and saves were preserved.",
        "Terminó, pero no encontramos la IPA.": "The process finished, but the IPA was not found.",
        "Tu juego está listo para Sideloadly.": "Your game is ready for Sideloadly.",
        "Abre los detalles para revisar las rutas de salida.": "Open the details to check the output paths.",
        "Abre la IPA y arrástrala a Sideloadly. La firma se hace con tu cuenta personal.": "Show the IPA and drag it into Sideloadly. Sign it there with your personal account.",
        "Necesitamos revisar un paso.": "A step needs your attention.",
        "No borramos tus archivos. Abre los detalles para ver el error y vuelve a intentar.": "Your existing files were not deleted. Open details to review the error, then try again.",
        "No pudimos iniciar la preparación.": "Preparation could not be started.",
        "Creando tu IPA ligera…": "Creating your lightweight IPA…",
        "Compilando la app para iPhone…": "Building the iPhone app…",
        "Preparando los gráficos del juego…": "Preparing game graphics…",
        "Preparando los archivos del juego…": "Preparing game files…",
        "Cancelando…": "Cancelling…",
        "Del juego a tu iPhone.": "From game to iPhone.",
        "Elige una carpeta. Prepara tu juego. A jugar.": "Choose a folder. Prepare your game. Play.",
        "Juegos con perfiles incluidos; consulta la ficha de cada juego para compatibilidad": "Games with included profiles; check each game note for compatibility",
        "Una carpeta por juego, con su base y actualizaciones.": "One folder per game, with its base files and updates.",
        "1. Elegir juego": "1. Choose game",
        "Cambiar": "Change",
        "Tus llaves: selecciona su carpeta": "Your keys: select their folder",
        "Tus llaves: carpeta seleccionada": "Your keys: folder selected",
        "Elegir carpeta de llaves": "Choose keys folder",
        "Cambiar llaves": "Change keys folder",
        "Cancelar": "Cancel",
        "2. Preparar para iPhone": "2. Prepare for iPhone",
        "Mostrar IPA": "Show IPA",
        "Mostrar datos romfs": "Show RomFS folder",
        "Abrir Sideloadly": "Open Sideloadly",
        "Primera instalación: instala la IPA ligera y copia romfs por Finder. Para actualizar, conserva la misma cuenta y bundle ID; no desinstales la app.": "First install: install the lightweight IPA, then copy romfs using Finder. For updates, keep the same account and bundle ID; do not uninstall the game.",
        "Detalles": "Details",
        "Guía de instalación": "Installation guide",
        "Copiar diagnóstico": "Copy diagnostics",
        "Preparación local. No se incluyen juegos ni llaves. La firma e instalación se hacen por separado en Sideloadly.": "Local preparation. Games and keys are not included. Signing and installation happen separately in Sideloadly.",
        "Compatibilidad según perfil, versión y dispositivo. Esta app no verifica que un juego funcione en tu iPhone.": "Compatibility depends on the profile, version and device. This app does not verify gameplay on your iPhone.",
        "Los detalles de compilación se muestran en su idioma original.": "Build diagnostics are shown in their original language.",
        "Idioma de la interfaz": "Interface language",
    ]
    static func text(_ source:String, language:EasyLanguage) -> String {
        language == .spanish ? source : (english[source] ?? source)
    }
}

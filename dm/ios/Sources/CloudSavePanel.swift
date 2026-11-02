// Shared native game-launcher UI. The Apple signing account is never involved.
import SwiftUI
import UniformTypeIdentifiers

@_silgen_name("nxe_cloud_command")
private func cloudCommand(_ command: UnsafePointer<CChar>, _ argument: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>

struct CloudSaveChoice: Decodable, Identifiable {
    let id, device: String
    let date: Double
    let compatible, local: Bool
}
private struct CloudSaveReply: Decodable {
    let status, message: String
    let choices: [CloudSaveChoice]
    let history: [CloudSaveChoice]?
    let blocksPlay: Bool?
}

@MainActor final class CloudSaveModel: ObservableObject {
    static let shared = CloudSaveModel()
    @Published var busy = false
    @Published var ready = false
    @Published var blocked = true
    @Published var status = "local"
    @Published var message = ""
    @Published var folder: URL?
    @Published var choices: [CloudSaveChoice] = []
    @Published var history: [CloudSaveChoice] = []
    @Published var permissionError: String?
    private var access: URL?
    static var hasFolder: Bool { UserDefaults.standard.data(forKey: "saveContinuity.folder.v1") != nil }
    static func headlessPreflight() -> Bool {
        let pointer = "local-play".withCString { cmd in "".withCString { cloudCommand(cmd, $0) } }
        defer { free(pointer) }
        guard let reply = try? JSONDecoder().decode(CloudSaveReply.self, from: Data(String(cString: pointer).utf8)) else { return false }
        if reply.status == "error" { fputs("[RED] save continuity: \(reply.message)\n", stderr); return false }
        return true
    }
    private let bookmarkKey = "saveContinuity.folder.v1"
    var spanish: Bool { Locale.preferredLanguages.first?.hasPrefix("es") == true }
    func text(_ en: String, _ es: String) -> String { spanish ? es : en }

    private func invoke(_ command: String, _ argument: String = "") async -> Bool {
        let reply: CloudSaveReply? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let pointer = command.withCString { command in argument.withCString { cloudCommand(command, $0) } }
                let data = Data(String(cString: pointer).utf8)
                free(pointer)
                continuation.resume(returning: try? JSONDecoder().decode(CloudSaveReply.self, from: data))
            }
        }
        guard let reply else {
            blocked = true; status = "error"
            message = text("The save check could not finish. Reopen this game before playing.", "No se pudo comprobar la partida. Vuelve a abrir este juego antes de jugar.")
            return false
        }
        status = reply.status; message = reply.message
        choices = reply.choices; history = reply.history ?? []
        blocked = reply.blocksPlay ?? false
        return reply.status != "error"
    }

    func load() async {
        guard !ready && !busy else { return }
        busy = true
        if let data = UserDefaults.standard.data(forKey: bookmarkKey) {
            do {
                var stale = false
                #if os(macOS)
                let options: URL.BookmarkResolutionOptions = [.withSecurityScope, .withoutUI]
                #else
                let options: URL.BookmarkResolutionOptions = [.withoutUI]
                #endif
                let url = try URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &stale)
                guard !stale else { throw CocoaError(.fileReadNoPermission) }
                if url.startAccessingSecurityScopedResource() { access = url }
                folder = url
                _ = await invoke("folder", url.path)
            } catch {
                permissionError = text("Choose your iCloud folder again to restore access. Your local save is unchanged.", "Elige otra vez tu carpeta de iCloud para recuperar el acceso. Tu partida local sigue intacta.")
                _ = await invoke("check")
            }
        } else { _ = await invoke("check") }
        ready = true; busy = false
    }

    func choose(_ url: URL) async {
        guard !busy else { return }
        busy = true
        let scoped = url.startAccessingSecurityScopedResource()
        do {
            #if os(macOS)
            let options: URL.BookmarkCreationOptions = [.withSecurityScope]
            #else
            let options: URL.BookmarkCreationOptions = [.minimalBookmark]
            #endif
            let data = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
            access?.stopAccessingSecurityScopedResource()
            access = scoped ? url : nil; folder = url
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            permissionError = nil
            _ = await invoke("folder", url.path)
        } catch {
            if scoped { url.stopAccessingSecurityScopedResource() }
            permissionError = text("This folder could not be remembered. Choose it again in Files.", "No pudimos recordar esta carpeta. Elígela de nuevo en Archivos.")
        }
        ready = true; busy = false
    }

    func check() async { guard !busy else { return }; busy = true; _ = await invoke("check"); busy = false }
    func disable() async {
        guard !busy else { return }; busy = true
        _ = await invoke("folder", "")
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        access?.stopAccessingSecurityScopedResource(); access = nil; folder = nil; permissionError = nil
        busy = false
    }
    func resolve(_ ID: String) async { guard !busy else { return }; busy = true; _ = await invoke("resolve", ID); busy = false }
    func start(_ done: @escaping () -> Void) {
        guard ready && !busy && !blocked else { return }
        busy = true
        let explicitlyLocal = ["conflict", "waiting", "error"].contains(status)
        Task {
            let ok = await invoke(explicitlyLocal ? "local-play" : "play")
            busy = false
            // A newly discovered conflict stays on this screen for a real choice.
            if ok && (explicitlyLocal || !["conflict", "waiting", "error"].contains(status)) { done() }
        }
    }
}

struct CloudSavePanel: View {
    @ObservedObject var model: CloudSaveModel
    @State private var picking = false
    @State private var selected: CloudSaveChoice?
    private var accent: Color { Color(red: 0.79, green: 0.95, blue: 0.37) }
    private var heading: String {
        switch model.status {
        case "conflict": return model.text("Two adventures. Both kept.", "Dos aventuras. Ambas a salvo.")
        case "waiting": return model.text("Saved here. Waiting for iCloud.", "Guardada aquí. Esperando a iCloud.")
        case "empty": return model.text("Ready for your first save", "Lista para tu primera partida")
        case "available": return model.text("Continue on your other device", "Continúa en tu otro dispositivo")
        case "error": return model.text("Your save needs attention", "Revisemos tu partida")
        default: return model.text("Your adventure, on every device", "Tu aventura, en todos tus dispositivos")
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: model.status == "conflict" ? "arrow.triangle.branch" : "icloud")
                    .font(.system(size: 30)).foregroundStyle(model.status == "conflict" ? .orange : accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(heading).font(.headline)
                    Text(model.text("iPhone · iPad · Mac", "iPhone · iPad · Mac")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if model.busy { ProgressView().controlSize(.small).accessibilityLabel(model.text("Checking saves", "Comprobando partidas")) }
            }
            Text(model.text("Choose the same iCloud Drive folder on both devices. Save and close the game before switching devices. Your active save stays local.", "Elige la misma carpeta de iCloud Drive en ambos dispositivos. Guarda y cierra el juego antes de cambiar de dispositivo. Tu partida activa sigue siendo local."))
                .font(.callout).foregroundStyle(.secondary)
            if let folder = model.folder {
                Label(folder.lastPathComponent, systemImage: "folder").font(.callout.weight(.medium))
                Text(statusText).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            if let error = model.permissionError { Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange) }
            if model.status == "error" {
                DisclosureGroup(model.text("Details", "Detalles")) { Text(model.message).font(.caption).textSelection(.enabled) }
            }
            if model.status == "conflict" {
                ForEach(model.choices) { choice in choiceButton(choice) }
            }
            if !model.history.isEmpty {
                DisclosureGroup(model.text("Save history (\(model.history.count))", "Historial de partidas (\(model.history.count))")) {
                    Text(model.text("Restoring keeps a backup of your current progress. Older revisions are never automatically deleted.", "Restaurar conserva un respaldo de tu progreso actual. Las versiones anteriores nunca se borran automáticamente.")).font(.caption).foregroundStyle(.secondary)
                    ForEach(model.history) { choice in choiceButton(choice) }
                }
            }
            ViewThatFits {
                HStack { actions }
                VStack(alignment: .leading, spacing: 12) { actions }
            }
            Text(model.text("Uses this device’s iCloud account. No Apple signing login is needed. Use this folder only for your own progress.", "Usa la cuenta de iCloud de este dispositivo. Para sincronizar no necesitas iniciar sesión en la cuenta de firma. Usa esta carpeta sólo para tus propias partidas."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.075)))
        .disabled(model.busy)
        .task { await model.load() }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { Task { await model.choose(url) } }
        }
        .confirmationDialog(model.text("Continue with this save?", "¿Continuar con esta partida?"), isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }), titleVisibility: .visible) {
            if let choice = selected {
                Button(model.text("Use this save · keep both", "Usar esta partida · conservar ambas")) { Task { await model.resolve(choice.id) }; selected = nil }
            }
            Button(model.text("Cancel", "Cancelar"), role: .cancel) { selected = nil }
        } message: {
            Text(model.text("This changes the progress you will play next. All versions and a backup of the current save remain available.", "Esto cambia la partida con la que seguirás jugando. Se conservan todas las versiones y un respaldo de la partida actual."))
        }
    }
    @ViewBuilder private var actions: some View {
        Button(model.text(model.folder == nil ? "Choose iCloud folder" : "Change folder", model.folder == nil ? "Elegir carpeta de iCloud" : "Cambiar carpeta")) { picking = true }.buttonStyle(.bordered)
        if model.folder != nil {
            Button(model.text("Check now", "Comprobar ahora")) { Task { await model.check() } }.buttonStyle(.bordered)
            Button(model.text("Turn off", "Desactivar")) { Task { await model.disable() } }.buttonStyle(.borderless)
        }
    }
    private var statusText: String {
        switch model.status {
        case "empty": return model.text("No save yet. Play and save in the game; a snapshot will be queued automatically.", "Aún no hay partida. Juega y guarda dentro del juego; se preparará una copia automáticamente.")
        case "available": return model.text("Snapshot available in this folder. iCloud may still be uploading; check on the other device before playing.", "La partida está disponible en esta carpeta. iCloud puede seguir subiéndola; comprueba el otro dispositivo antes de jugar.")
        case "waiting": return model.text("Your local progress is safe. Some revisions are still downloading; check again before switching devices.", "Tu progreso local está a salvo. Hay versiones descargándose; comprueba de nuevo antes de cambiar de dispositivo.")
        case "conflict": return model.text("Progress differs between devices. Choose which one to continue, or play this device’s local save. Both are kept.", "El progreso es distinto en tus dispositivos. Elige con cuál seguir o juega tu partida local. Se conservan ambas.")
        case "error": return model.blocked ? model.text("Recovery must finish before play. Free space or restore folder access and check again.", "La recuperación debe terminar antes de jugar. Libera espacio o recupera el acceso y comprueba de nuevo.") : model.text("iCloud could not finish. You can play locally; snapshots remain queued for the next check.", "iCloud no pudo terminar. Puedes jugar localmente; las copias quedan pendientes para la próxima comprobación.")
        default: return model.text("Saved on this device.", "Guardada en este dispositivo.")
        }
    }
    private func choiceButton(_ choice: CloudSaveChoice) -> some View {
        Button { selected = choice } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: choice.local ? "checkmark.circle" : "clock.arrow.circlepath").foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(choice.device).font(.callout.weight(.semibold))
                    Text(Date(timeIntervalSince1970: choice.date), format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                    if !choice.compatible { Text(model.text("Different game version/content · kept in history", "Versión o contenido diferente · conservada en el historial")).font(.caption).foregroundStyle(.orange) }
                }
                Spacer(minLength: 0)
                Text(choice.local ? model.text("This device", "Este dispositivo") : model.text("Use save", "Usar partida")).font(.caption)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(.bordered).disabled(!choice.compatible)
    }
}

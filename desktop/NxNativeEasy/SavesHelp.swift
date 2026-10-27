import SwiftUI
import AppKit

struct SaveLocations {
    static func titleID(folder:URL?)->String? {
        guard let folder else {return nil}
        if let data=try? Data(contentsOf:folder.appendingPathComponent("nxnative-mac.json")),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let id=value["title_id"] as? String,id.range(of:"^[0-9A-Fa-f]{16}$",options:.regularExpression) != nil {return id.uppercased()}
        let ids=((try? FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)) ?? []).compactMap {url->String? in
            let name=url.lastPathComponent;return name.range(of:"^[0-9A-Fa-f]{16}_build$",options:.regularExpression) != nil ? String(name.prefix(16)).uppercased() : nil
        }
        return ids.count==1 ? ids[0] : nil
    }
    static func macRoot(titleID:String)->URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/nxnative/"+titleID)
    }
}
struct SavesHelpView:View {
    let folder:URL?
    let isMac:Bool
    let text:(String)->String
    let language:EasyLanguage
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Text(text("Tus partidas")).font(.title2.bold());Spacer();Button(text("Cerrar")){dismiss()}}
            Text(text("Se guardan en el dispositivo donde juegas. Todavía no hay sincronización en la nube."))
            if isMac {
                Text(text("En Mac: fuera de la app, en Application Support, por Title ID.")).font(.headline)
                if let id=SaveLocations.titleID(folder:folder) {
                    Text(SaveLocations.macRoot(titleID:id).path).font(.system(size:12,design:.monospaced)).textSelection(.enabled)
                    Button(text("Mostrar carpeta de partidas")) {NSWorkspace.shared.activateFileViewerSelecting([SaveLocations.macRoot(titleID:id)])}
                } else {Text("~/Library/Application Support/nxnative/<TITLE ID>/").font(.system(size:12,design:.monospaced)).textSelection(.enabled)}
            } else {
                Text(text("En tu iPhone/iPad: Finder → tu dispositivo → Archivos → tu juego.")).font(.headline)
                Text(text("Finder muestra Documents. Las partidas son save y, en algunos juegos, save_device. romfs contiene el juego, no tu progreso."))
            }
            Text(text("Guarda y cierra el juego antes de copiar. Conserva juntas save y save_device si existe. No copies save.work ni save.new."))
            Text(text("Al actualizar en iPhone/iPad: misma cuenta e identificador, instala encima y no desinstales. Reemplaza sólo romfs si cambió el juego."))
            Text(text("Los perfiles de controles son preferencias separadas; copiar save no los transfiere. Algunas partidas requieren metadatos que una copia manual puede perder."))
                .font(.callout).foregroundStyle(.secondary)
            Link(text("Guía completa de partidas y respaldos"),destination:URL(string:"https://github.com/nalancer08/nxnative-easy/blob/main/docs/"+(language == .spanish ? "saves-es.md" : "saves.md"))!)
        }.padding(24).frame(width:680)
    }
}

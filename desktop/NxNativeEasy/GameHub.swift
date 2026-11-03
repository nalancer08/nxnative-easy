import SwiftUI
import AppKit

struct GameDeviceReport:Identifiable {
    let observation:DeviceGameObservation
    let job:RefreshJob?
    let state:GameCareState
    let verified:Bool
    var id:String {observation.id}
}
struct GameCareContext {
    var reports:[GameDeviceReport]=[]
    var changes:[String]=[]
    var prepared:EasyBuildStamp?
    var current:EasyBuildStamp?
    var localReady=false
    var localRebuild:Bool?
    var state:GameCareState {
        let remote=reports.min(by:{priority($0.state)<priority($1.state)})?.state
        if localReady,localRebuild==true,priority(remote ?? .notInstalled)>priority(.rebuild) {return .rebuild}
        return remote ?? (localReady ? (localRebuild==false ? .current : .unknown) : .notInstalled)
    }
    private func priority(_ state:GameCareState)->Int {switch state {case .expired:return 0;case .expiring:return 1;case .contentUpdate:return 2;case .rebuild:return 3;case .unknown:return 4;case .current:return 5;case .notInstalled:return 6}}
    var title:String {switch state {case .expired:return "La firma registrada caducó";case .expiring:return "Tu firma está por caducar";case .contentUpdate:return "Tienes otra versión lista en este Mac";case .rebuild:return "Hay cambios de preparación disponibles";case .unknown:return "Comprueba tu instalación";case .current:return "Sin mejoras pendientes detectadas";case .notInstalled:return "Elige dónde quieres jugar"}}
    var reason:String {switch state {
    case .expired,.expiring:return "Renueva la firma para seguir abriendo el juego. No necesitas recompilar ni volver a copiar sus datos."
    case .contentUpdate:return "La versión preparada y la observada en el dispositivo son distintas. Revisa ambas antes de instalar encima."
    case .rebuild:return "Cambiaron componentes usados al preparar este juego. Recompila e instala con la misma identidad para aplicar esas mejoras."
    case .unknown:return "Falta el historial necesario para comparar esta instalación. No significa que tu juego esté viejo ni que debas recompilar."
    case .current:return "Tener una versión nueva de Easy no obliga a actualizar el juego. Puedes seguir jugando."
    case .notInstalled:return "Prepara el juego para Mac o instala tu IPA en un iPhone o iPad. Tus archivos siguen en su lugar."
    }}
    var action:String {switch state {case .expired,.expiring:return "Revisar firma";case .contentUpdate:return "Revisar versiones";case .rebuild:return "Ver mejoras";default:return "Ver mi juego"}}
}

struct GameVersionComparison:View {
    let context:GameCareContext
    let text:(String)->String
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Label(text("Qué versión tiene tu juego"),systemImage:"clock.arrow.circlepath").font(.headline)
            HStack(alignment:.top,spacing:16) {
                value("Preparado con",context.prepared.map{"Easy "+$0.version+" · "+String($0.build)})
                Image(systemName:"arrow.right").foregroundStyle(.tertiary).padding(.top,22)
                value("Easy en este Mac",context.current.map{$0.version+" · "+String($0.build)})
            }
            ForEach(context.reports) {item in
                VStack(alignment:.leading,spacing:5) {
                    Text(item.observation.deviceName).font(.caption.weight(.semibold))
                    Text(text("Última firma con")+" · "+(item.job?.signedWith.map{"Easy "+$0.version+" · "+String($0.build)} ?? text("Sin registro"))).font(.caption).foregroundStyle(.secondary)
                    if let expiry=item.job?.expires {Text(text("Vencimiento registrado")+" · "+expiry.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)}
                }
            }
            Text(text("Preparar cambia el juego; renovar sólo cambia la firma. Una actualización de Easy puede mejorar únicamente esta interfaz.")).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func value(_ title:String,_ value:String?)->some View {VStack(alignment:.leading,spacing:6) {Text(text(title)).font(.caption).foregroundStyle(.secondary);Text(value ?? text("Sin registro")).font(.callout.weight(.semibold))}.frame(maxWidth:.infinity,alignment:.leading)}
}

struct GameHub:View {
    let game:OwnedGameOutput
    let catalog:CatalogGame?
    let title:String
    let context:GameCareContext
    @ObservedObject var sideload:SideloadModel
    @ObservedObject var saves:SaveCenterModel
    let repo:URL
    let text:(String)->String
    let disabled:Bool
    let maintain:()->Void
    let openSaves:()->Void
    let importBackup:(URL)->Void
    let prepareMac:()->Void
    let install:()->Void
    let files:()->Void
    @State private var backup:DeviceGameObservation?
    @State private var confirmMac=false
    @State var section="overview"
    var body:some View {
        VStack(alignment:.leading,spacing:24) {
            HStack(alignment:.top,spacing:28) {
                VStack(alignment:.leading,spacing:16) {
                    EasyEyebrow(title:text("TU JUEGO · TUS PANTALLAS"))
                    Text(title).font(.system(size:38,weight:.bold)).tracking(-1.2).fixedSize(horizontal:false,vertical:true)
                    Text(text(context.title)).font(.title3.weight(.semibold)).foregroundStyle(context.state == .expired || context.state == .expiring ? .orange : EasyDesign.accent)
                    Text(text(context.reason)).font(.callout).foregroundStyle(.secondary).lineSpacing(3)
                    ForEach(context.changes,id:\.self){Label(text($0),systemImage:"sparkles").font(.caption)}
                    Button(text(context.state == .current || context.state == .unknown ? "Opciones de actualización" : context.action),action:maintain).buttonStyle(EasyPrimaryStyle()).disabled(disabled)
                }.frame(maxWidth:.infinity,alignment:.leading)
                if let catalog {GameArtworkView(game:catalog).frame(width:300,height:200).clipped().clipShape(RoundedRectangle(cornerRadius:16)).accessibilityHidden(true)}
            }
            HStack(spacing:24) {
                ForEach(["overview","saves"],id:\.self) {value in
                    Button {section=value} label:{Text(text(value=="overview" ? "Mi juego" : "Partidas y copias")).font(.headline).foregroundStyle(section==value ? EasyDesign.accent : .secondary).padding(.bottom,12).overlay(alignment:.bottom){if section==value {Capsule().fill(EasyDesign.accent).frame(height:2)}}}.buttonStyle(.plain)
                }
            }
            if section=="overview" {
            HStack(alignment:.top,spacing:18) {
                EasyCard {VStack(alignment:.leading,spacing:14) {
                    Label("Mac",systemImage:"desktopcomputer").font(.title3.bold())
                    Text(text(game.macApp==nil ? "Aún no tienes este juego en Mac" : "Listo en este Mac")).font(.callout)
                    Text(text("Versión del juego")+" · "+(game.version ?? "—")).font(.caption).foregroundStyle(.secondary)
                    Button(text(game.macApp==nil ? "Preparar en Mac" : "Continuar en Mac")) {if let app=game.macApp {NSWorkspace.shared.open(app)}else{prepareMac()}}.buttonStyle(EasySecondaryStyle()).disabled(disabled || game.missing)
                }}
                EasyCard {VStack(alignment:.leading,spacing:14) {
                    Label(text("iPhone / iPad"),systemImage:"iphone").font(.title3.bold())
                    if context.reports.isEmpty {Text(text("Conecta tu dispositivo para comprobar este juego.")).font(.callout)}
                    ForEach(context.reports) {report in
                        VStack(alignment:.leading,spacing:5) {
                            Label(report.observation.deviceName,systemImage:report.verified ? "checkmark.circle.fill" : "clock").font(.callout.weight(.semibold))
                            Text(text(report.verified ? "Instalación comprobada" : "Última instalación conocida")+" · "+(report.observation.version.isEmpty ? text("Versión sin registro") : report.observation.version)).font(.caption).foregroundStyle(.secondary)
                            if let expiry=report.job?.expires {Text(text("Firma registrada hasta")+" · "+expiry.formatted(date:.abbreviated,time:.omitted)).font(.caption).foregroundStyle(report.state == .expired || report.state == .expiring ? .orange : .secondary)}
                        }
                    }
                    HStack {Button(text("Comprobar conexión")){sideload.listDevices()}.buttonStyle(EasyLinkStyle());if context.reports.isEmpty {Button(text("Instalar en mi dispositivo"),action:install).buttonStyle(EasyLinkStyle()).disabled(game.iosIPA==nil)}}.disabled(disabled || sideload.busy)
                }}
            }
            EasyCard {GameVersionComparison(context:context,text:text)}
            if !context.reports.isEmpty {DisclosureGroup(text("Renovación automática")) {ForEach(context.reports) {report in if let job=report.job {Toggle(report.observation.deviceName,isOn:Binding(get:{sideload.jobs.first(where:{$0.id==job.id})?.enabled ?? false},set:{sideload.setRefresh(job,enabled:$0)})).disabled(sideload.busy)}}}.font(.caption)}
            } else {
            HStack(alignment:.center,spacing:24) {
                VStack(alignment:.leading,spacing:12) {
                    EasyEyebrow(title:text("TU PROGRESO"))
                    Text(text("Continúa donde lo dejaste.")).font(.system(size:28,weight:.bold)).tracking(-0.7)
                    Text(text("Trae una copia del iPhone, guárdala en tu Mac o revisa tus versiones de iCloud. El original se conserva.")).font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,alignment:.leading)
                if let image=Bundle.main.url(forResource:"save-vault",withExtension:"png",subdirectory:"Library").flatMap({NSImage(contentsOf:$0)}) {Image(nsImage:image).resizable().scaledToFit().frame(width:180,height:120).accessibilityHidden(true)}
            }
            HStack(alignment:.top,spacing:18) {
                EasyCard {VStack(alignment:.leading,spacing:14) {
                    Label(text("Guardar una copia en mi Mac"),systemImage:"externaldrive").font(.headline)
                    Text(text("Guarda y cierra el juego antes de copiar. No hace falta iniciar sesión con Apple.")).font(.callout).foregroundStyle(.secondary)
                    ForEach(context.reports) {report in
                        Button {backup=report.observation} label:{Label(text("Traer partida de")+" "+report.observation.deviceName,systemImage:"iphone.and.arrow.forward")}.buttonStyle(EasySecondaryStyle()).disabled(disabled || sideload.busy || !sideload.devices.contains(where:{$0.id==report.observation.device}))
                    }
                    if context.reports.isEmpty {Text(text("Conecta el iPhone y comprueba su instalación para sacar una copia.")).font(.caption).foregroundStyle(.secondary)}
                    if let id=game.titleID,FileManager.default.fileExists(atPath:SaveLocations.macRoot(titleID:id).appendingPathComponent("save").path) {Button(text("Respaldar partida de este Mac")){confirmMac=true}.buttonStyle(EasyLinkStyle()).disabled(disabled || saves.busy)}
                    if let url=sideload.exportedSaves,sideload.gameFolder==game.folder {
                        Label(text("Tu respaldo local está listo"),systemImage:"checkmark.shield").font(.callout)
                        Button(text("Mostrar respaldo")){NSWorkspace.shared.activateFileViewerSelecting([url])}.buttonStyle(EasyLinkStyle())
                        Button(text("Añadir este respaldo a iCloud")){importBackup(url)}.buttonStyle(EasyLinkStyle()).disabled(saves.busy)
                    }
                    if let url=saves.localBackup,saves.localBackupTitle==game.titleID {Button(text("Mostrar respaldo")){NSWorkspace.shared.activateFileViewerSelecting([url])}.buttonStyle(EasyLinkStyle())}
                }}
                EasyCard {VStack(alignment:.leading,spacing:14) {
                    Label(text("Continuar con iCloud"),systemImage:"icloud").font(.headline)
                    let count=saves.revisions.filter{$0.title==game.titleID}.count
                    Text(text(saves.cloud==nil ? "Elige la misma carpeta de iCloud dentro de tus juegos y en Easy." : count==0 ? "Todavía no hay versiones recibidas de este juego en la carpeta elegida." : "Hay versiones recibidas de este juego. Revísalas antes de elegir con cuál continuar.")).font(.callout).foregroundStyle(.secondary)
                    Button(text("Ver mis partidas y elegir"),action:openSaves).buttonStyle(EasySecondaryStyle()).disabled(disabled)
                    Text(text("Abre el juego en el destino para aplicar la partida. Los conflictos conservan ambas versiones; Easy no reemplaza un juego abierto.")).font(.caption).foregroundStyle(.secondary)
                    Text(text("Si tu juego es anterior a la continuidad con iCloud, prepáralo de nuevo con el mismo contenido en ambos dispositivos.")).font(.caption).foregroundStyle(.secondary)
                }}
            }
            }
            if sideload.busy {InstallActivityView(model:sideload,text:text)}
            if let error=sideload.error {Label(text(error),systemImage:"exclamationmark.triangle").font(.callout).foregroundStyle(.orange)}
            if saves.busy {ProgressView(text("Comprobando tu partida…"))}
            if let error=saves.error {Text(text(error=="close_game_first" ? "Guarda y cierra el juego antes de copiar. No hace falta iniciar sesión con Apple." : error=="destination_exists" ? "Ese respaldo ya existe. Elige otro nombre para conservar ambos." : "No pudimos preparar la copia. El original se conservó.")).font(.caption).foregroundStyle(.orange)}
            Button(text("Archivos y opciones avanzadas"),action:files).buttonStyle(EasyLinkStyle())
        }.padding(36).frame(maxWidth:1140).frame(maxWidth:.infinity,alignment:.top).background(EasyDesign.background)
        .task {saves.restoreFolder();if saves.cloud != nil && !saves.busy {saves.refresh(repo:repo)}}
        .alert(text("Guardar una copia local"),isPresented:Binding(get:{backup != nil || confirmMac},set:{if !$0 {backup=nil;confirmMac=false}})) {
            Button(text("Cancelar"),role:.cancel){backup=nil;confirmMac=false}
            Button(text("Ya guardé y cerré el juego")) {if let item=backup {sideload.backupGame(item,text:text)}else{saves.backupMac(repo:repo,game:game)};backup=nil;confirmMac=false}
        } message:{Text(text("Se creará un respaldo nuevo. No borramos ni reemplazamos la partida del dispositivo. Guarda y cierra el juego para copiar una versión completa."))}
    }
}

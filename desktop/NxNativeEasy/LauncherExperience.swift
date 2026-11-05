import SwiftUI
import AppKit

struct EngineHistory:Decodable {
    struct Entry:Decodable,Identifiable {let number:Int?;let version:String?;let revision,date,title:String;var id:String{revision}}
    let schema:Int
    let number:Int?
    let version:String?
    let versions:[String:String]?
    let revision,upstream:String
    let entries:[Entry]
    var sources:[String:Int]?
    func buildNumber(for source:String?)->Int? {
        guard let source,source.range(of:"^[a-fA-F0-9]{40}$",options:.regularExpression) != nil else{return nil}
        return sources?[source.lowercased()] ?? (source.lowercased()==revision ? number : nil)
    }
    func buildVersion(for source:String?)->String? {buildNumber(for:source).flatMap{versions?[String($0)]}}
    var firstVersion:String? {versions?.keys.compactMap(Int.init).min().flatMap{versions?[String($0)]}}
    static func load(repo:URL)->Self? {
        guard let handle=try? FileHandle(forReadingFrom:repo.appendingPathComponent("desktop/engine-history.json")) else{return nil}
        defer{try? handle.close()}
        guard let data=try? handle.read(upToCount:2_097_153),data.count<=2_097_152,
              var value=try? JSONDecoder().decode(Self.self,from:data),[1,2].contains(value.schema),
              value.revision.range(of:"^[a-f0-9]{40}$",options:.regularExpression) != nil else{return nil}
        if value.schema==2 {
            guard let number=value.number,(1...1_000_000).contains(number),value.entries.count<=24,let sources=value.sources,
                  let version=value.version,let versions=value.versions,versions[String(number)]==version,versions.allSatisfy({Int($0.key).map{(1...number).contains($0)}==true && $0.value.range(of:"^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$",options:.regularExpression) != nil}),
                  sources.count<20000,sources.allSatisfy({$0.key.range(of:"^[a-f0-9]{40}$",options:.regularExpression) != nil && (1...number).contains($0.value)}) else{return nil}
            // Packaging checks that this catalog still describes the runtime.
            // A frontend-only release uses the same engine number.
            if let sourceFile=try? FileHandle(forReadingFrom:repo.appendingPathComponent("SOURCE_REVISION")) {
                defer{try? sourceFile.close()}
                if let bytes=try? sourceFile.read(upToCount:64),let source=String(data:bytes,encoding:.utf8)?.trimmingCharacters(in:.whitespacesAndNewlines),source.range(of:"^[a-f0-9]{40}$",options:.regularExpression) != nil {value.sources?[source]=number}
            }
        }
        return value
    }
}

struct EngineBuildComparison:View {
    let history:EngineHistory?
    let revision:String?
    let text:(String)->String
    private var prepared:Int? {history?.buildNumber(for:revision)}
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            HStack(spacing:8) {
                Text(history?.buildVersion(for:revision).map{text("Motor")+" "+$0} ?? (prepared != nil ? text("Motor anterior a")+" "+(history?.firstVersion ?? "1.0.0") : text("Motor sin registrar"))).fontWeight(.semibold)
                if let current=history?.version {Image(systemName:"arrow.right").font(.caption2);Text(text("Actual")+" "+current)}
            }
            if let prepared,let current=history?.number {
                Label(text(prepared==current ? "Mismo motor que esta app" : prepared<current ? "Hay un motor posterior disponible" : "Este juego usa un motor posterior a esta app"),systemImage:prepared==current ? "checkmark.circle" : "arrow.up.circle").foregroundStyle(prepared==current ? Color.secondary : EasyDesign.accent)
            } else {Text(text("Esta preparación antigua no tiene un motor identificable.")).foregroundStyle(.secondary)}
        }.font(.caption)
        .help(revision.map{text("Revisión técnica")+": "+$0} ?? text("Motor sin registrar"))
    }
}

struct LauncherBrand:View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @State private var appeared=false
    var body:some View {
        HStack(spacing:8) {
            Image(nsImage:AppArtwork.icon).resizable().frame(width:24,height:24)
                .offset(x:appeared ? 0 : -5).opacity(appeared ? 1 : 0)
            Text("nxnative").font(.system(size:14,weight:.semibold)).tracking(-0.4)
            Text("easy").font(.system(size:10,weight:.medium)).foregroundStyle(.secondary)
        }.frame(width:132,alignment:.leading)
        .onAppear{withAnimation(reduceMotion || phase != .active ? nil : .easeOut(duration:0.45)){appeared=true}}
        .accessibilityElement(children:.ignore).accessibilityLabel("nxnative Easy")
    }
}

struct CloudWelcomeView:View {
    @ObservedObject var saves:SaveCenterModel
    let repo:URL
    let text:(String)->String
    let finish:()->Void
    @State private var skipping=false
    @State private var attempted=false
    @State private var otherAccount=false
    @State private var connecting=false
    @State private var confirmed=false
    @State private var sharedSelection=false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    var body:some View {
        GeometryReader {geometry in
            ScrollView {
                VStack(alignment:.leading,spacing:38) {
                    LauncherBrand()
                    ViewThatFits(in:.horizontal) {
                        HStack(spacing:38) {
                            message.frame(width:370)
                            artwork.frame(width:490,height:430)
                        }
                        VStack(alignment:.leading,spacing:20) {
                            artwork.frame(maxWidth:.infinity).frame(height:geometry.size.height<760 ? 195 : 250)
                            message
                        }.frame(maxWidth:560)
                    }
                }.frame(maxWidth:920,alignment:.leading).padding(36)
                    .frame(maxWidth:.infinity,minHeight:geometry.size.height,alignment:.center)
            }.background(EasyDesign.background)
        }
        .onChange(of:saves.cloudCheckedAt){_,_ in if connecting && saves.connectionState == .connected {connecting=false;confirmed=true}}
        .onChange(of:saves.scanning){_,scanning in if connecting && !scanning {connecting=false;confirmed=saves.connectionState == .connected}}
        .onChange(of:saves.connectionState){_,state in if confirmed && state != .connected {confirmed=false;connecting=false}}
        .alert(text("Continuar con partidas locales"),isPresented:$skipping) {
            Button(text("Volver"),role:.cancel){}
            Button(text("Continuar sin sincronizar")){saves.disconnectCloud();finish()}
        }message:{Text(text("Podrás jugar y guardar en este dispositivo. Easy no recibirá ni sincronizará copias en iCloud hasta que lo conectes. Los juegos que ya configuraste conservan sus ajustes."))}
    }
    private var artwork:some View {
        VStack(spacing:8) {
            LivingCloudScene(playing:phase == .active,reducedMotion:reduceMotion,label:text(reduceMotion ? "Escena de aventura" : "Mueve el cursor o pulsa para transformar la escena."))
            if !reduceMotion {Text(text("Mueve el cursor. Pulsa y descubre.")).font(.caption).foregroundStyle(.secondary)}
        }
    }
    @ViewBuilder private var message:some View {
        if confirmed {confirmation}
        else {
                VStack(alignment:.leading,spacing:22) {
                    Text(text("Tu progreso, contigo.")).font(.system(size:40,weight:.bold)).tracking(-1.2).fixedSize(horizontal:false,vertical:true)
                    Text(text("Guarda tus partidas en iCloud y continúa en Mac, iPhone o iPad.")).font(.system(size:15)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                    if attempted && saves.cloud==nil {Text(text("Activa iCloud Drive en Ajustes del Sistema y vuelve aquí. Tus partidas locales se conservan.")).font(.callout).foregroundStyle(.orange)}
                    VStack(alignment:.leading,spacing:12) {
                        Button {attempted=true;connecting=true;sharedSelection=false;saves.enableManagedCloud(repo:repo);if saves.usesICloud {saves.refresh(repo:repo)}else{connecting=false;openAccountSettings()}}label:{
                            HStack(spacing:12) {
                                if connecting {ProgressView().controlSize(.small)}else{Image(systemName:"person.icloud").font(.system(size:25,weight:.medium))}
                                Text(text(connecting ? "Comprobando iCloud…" : "Usar iCloud de este Mac")).font(.system(size:15,weight:.semibold))
                                Spacer(minLength:8)
                                Image(systemName:"arrow.right").font(.system(size:14,weight:.semibold))
                            }.frame(maxWidth:.infinity,alignment:.leading)
                        }.buttonStyle(EasyPrimaryStyle()).disabled(saves.busy || connecting)
                        Button(text("Usar otra cuenta de iCloud")){withAnimation(reduceMotion ? nil : .easeInOut(duration:0.2)){otherAccount.toggle()}}.buttonStyle(EasyLinkStyle()).disabled(connecting)
                        if otherAccount {
                            VStack(alignment:.leading,spacing:12) {
                                Text(text("iCloud usa la cuenta de macOS. Puedes administrarla en Ajustes o usar una carpeta que te comparta otra cuenta.")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                                Button(text("Administrar cuenta en macOS"),action:openAccountSettings).buttonStyle(EasySecondaryStyle())
                                Button(text("Usar una carpeta compartida")){if saves.chooseCloud(repo:repo,requireICloud:true) {connecting=true;attempted=true;sharedSelection=true}}.buttonStyle(EasyLinkStyle()).disabled(connecting || saves.busy)
                                if saves.error=="icloud_folder_required" {Text(text("Elige una carpeta de iCloud Drive, incluida una que te hayan compartido.")).font(.caption).foregroundStyle(.orange)}
                            }.padding(16).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:12))
                        }
                        Button(text("Continuar sin iCloud")){skipping=true}.buttonStyle(EasySecondaryStyle())
                    }
                    if attempted && saves.cloudIssue != nil && saves.cloud != nil {Text(text("No pudimos comprobar iCloud. Revisa la conexión e inténtalo de nuevo.")).font(.caption).foregroundStyle(.orange)}
                    Text(text("La cuenta para instalar tus juegos se elige después.")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                }
        }
    }
    private var confirmation:some View {
        VStack(alignment:.leading,spacing:22) {
            Image(systemName:"checkmark.icloud.fill").font(.system(size:42)).foregroundStyle(.green)
            Text(text("iCloud conectado")).font(.system(size:34,weight:.bold)).tracking(-1)
            Text(text(sharedSelection ? "Usando la carpeta de iCloud que elegiste." : "Usando la cuenta de iCloud configurada en este Mac.")).font(.callout).foregroundStyle(.secondary)
            VStack(alignment:.leading,spacing:12) {
                HStack(spacing:12) {MacProfileAvatar();VStack(alignment:.leading,spacing:4) {Text(MacProfile().name).font(.callout.bold());Text(text("Perfil de este Mac")).font(.caption).foregroundStyle(.secondary)}}
                if let folder=saves.cloud {Label(folder.lastPathComponent,systemImage:"folder").font(.callout).help(folder.path)}
                Text(text(saves.revisions.isEmpty ? "No hay copias recibidas todavía." : "Tus partidas ya aparecen en la biblioteca.")).font(.caption).foregroundStyle(.secondary)
            }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:12))
            Button(text("Abrir mi biblioteca"),action:finish).buttonStyle(EasyPrimaryStyle())
            Button(text("Ver cuenta en macOS"),action:openAccountSettings).buttonStyle(EasyLinkStyle())
            Button(text("Elegir otra opción")){confirmed=false;attempted=false}.buttonStyle(EasyLinkStyle())
        }
    }
    private func openAccountSettings() {SystemCloudAccount.open()}
}

struct EngineHistoryView:View {
    let history:EngineHistory?
    @ObservedObject var updater:AppUpdater
    let text:(String)->String
    private var version:String{Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "—"}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                EasyEyebrow(title:text("MOTOR Y ACTUALIZACIONES"))
                Text(text("Lo que mueve tus juegos.")).font(.system(size:34,weight:.bold)).tracking(-1)
                HStack(spacing:20) {
                    VStack(alignment:.leading,spacing:7) {Text("nxnative Easy "+version).font(.title2.bold());Text(text("Motor")+" "+(history?.version ?? "—")).font(.title3.bold()).foregroundStyle(EasyDesign.accent);if let history {Text(text("Base original")+" · "+history.upstream.prefix(8)).font(.caption).foregroundStyle(.secondary)}}
                    Spacer()
                    if updater.available != nil {Button(text("Actualizar Easy")){updater.start()}.buttonStyle(EasyPrimaryStyle()).disabled(updater.busy)}
                    else {Button(text(updater.checking ? "Buscando…" : "Buscar actualizaciones")){Task{await updater.check(manual:true)}}.buttonStyle(EasySecondaryStyle()).disabled(updater.checking || updater.busy)}
                }.padding(24).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:14))
                if let checked=updater.checkedAt {Text(text("Última comprobación")+" · "+checked.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)}
                if updater.available==nil,updater.checkedAt != nil,updater.error==nil {Label(text("Tienes la versión más reciente"),systemImage:"checkmark.circle").foregroundStyle(.green)}
                if updater.error != nil {Label(text("No pudimos buscar actualizaciones. Intenta de nuevo más tarde."),systemImage:"wifi.exclamationmark").foregroundStyle(.orange)}
                if updater.busy {ProgressView(value:updater.progress);Text(text(updater.phaseText)).font(.callout)}
                Text(text("Historial del motor")).font(.title2.bold());Text(text("Un motor 1.0.2 es posterior a 1.0.1. La versión de Easy se actualiza por separado.")).font(.callout).foregroundStyle(.secondary)
                Text(text("Cambios integrados en esta app. Una nueva versión de Easy no obliga a recompilar todos tus juegos.")).font(.callout).foregroundStyle(.secondary)
                ForEach(history?.entries ?? []) {entry in
                    HStack(alignment:.top,spacing:18) {
                        Image(systemName:"shippingbox").foregroundStyle(EasyDesign.accent).frame(width:22)
                        VStack(alignment:.leading,spacing:8) {Text(entry.title).font(.system(size:13,weight:.semibold)).fixedSize(horizontal:false,vertical:true);HStack {Text(entry.version.map{text("Motor")+" "+$0} ?? text("Antes de 1.0.0")).font(.caption.bold());Text(ISO8601DateFormatter().date(from:entry.date)?.formatted(date:.abbreviated,time:.omitted) ?? String(entry.date.prefix(10)))}.foregroundStyle(.secondary).font(.caption)}
                        Spacer(minLength:8)
                        Link(destination:URL(string:"https://github.com/nalancer08/nxnative-easy/commit/"+entry.revision)!){Image(systemName:"arrow.up.right").frame(width:36,height:36).contentShape(Rectangle())}.help(text("Ver cambio"))
                    }.padding(18).background(.white.opacity(0.025),in:RoundedRectangle(cornerRadius:10))
                }
            }.frame(maxWidth:900,alignment:.leading).padding(28).frame(maxWidth:.infinity,alignment:.leading)
        }.background(EasyDesign.background)
    }
}

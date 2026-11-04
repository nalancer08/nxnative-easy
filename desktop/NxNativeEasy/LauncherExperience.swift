import SwiftUI
import AppKit

struct EngineHistory:Decodable {
    struct Entry:Decodable,Identifiable {let revision,date,title:String;var id:String{revision}}
    let schema:Int
    let revision,upstream:String
    let entries:[Entry]
    static func load(repo:URL)->Self? {
        guard let data=try? Data(contentsOf:repo.appendingPathComponent("desktop/engine-history.json")),data.count<131072,
              let value=try? JSONDecoder().decode(Self.self,from:data),value.schema==1,
              value.revision.range(of:"^[a-f0-9]{40}$",options:.regularExpression) != nil else{return nil}
        return value
    }
}

struct LauncherBrand:View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @State private var hover=false
    @State private var appeared=false
    var body:some View {
        HStack(spacing:9) {
            Image(nsImage:AppArtwork.icon).resizable().frame(width:32,height:32).clipShape(RoundedRectangle(cornerRadius:8))
                .rotation3DEffect(.degrees(hover && !reduceMotion ? -14 : 0),axis:(x:0,y:1,z:0))
                .scaleEffect(appeared ? 1 : 0.8)
            VStack(alignment:.leading,spacing:0) {Text("nxnative").font(.system(size:14,weight:.bold)).tracking(-0.3);Text("EASY").font(.system(size:8,weight:.bold)).tracking(3).foregroundStyle(EasyDesign.accent)}
        }.frame(width:132,alignment:.leading).contentShape(Rectangle()).onHover{hover=$0}
        .onAppear{withAnimation(reduceMotion ? nil : .spring(response:0.45,dampingFraction:0.7)){appeared=true}}
        .animation(reduceMotion || phase != .active ? nil : .spring(response:0.35),value:hover)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    var body:some View {
        GeometryReader {geometry in
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    LauncherBrand().padding(.top,8)
                    LibraryDropMotion(playing:phase == .active && !reduceMotion,resource:"ecosystem-sync").frame(maxWidth:.infinity).frame(height:geometry.size.height<700 ? 160 : 220).allowsHitTesting(false).accessibilityHidden(true)
                    Text(text("Tu partida. Todas tus pantallas.")).font(.system(size:36,weight:.bold)).tracking(-1).fixedSize(horizontal:false,vertical:true)
                    Text(text("Conecta iCloud para recibir tus partidas y continuar en Mac, iPhone o iPad.")).font(.system(size:15)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                    HStack(spacing:12) {Image(systemName:saves.usesICloud ? "checkmark.icloud.fill" : "person.icloud").font(.title2).foregroundStyle(EasyDesign.accent);VStack(alignment:.leading,spacing:5) {Text(text(saves.usesICloud ? "iCloud de este Mac disponible" : "Usa tu cuenta de iCloud de macOS")).font(.headline);Text(text("La cuenta para firmar apps es independiente.")).font(.caption).foregroundStyle(.secondary)}}.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:12))
                    if attempted && saves.cloud==nil {Text(text("Activa iCloud Drive en Ajustes del Sistema y vuelve aquí. Tus partidas locales se conservan.")).font(.callout).foregroundStyle(.orange)}
                    HStack(spacing:12) {
                        Button {attempted=true;saves.enableManagedCloud(repo:repo);if saves.usesICloud {finish()}else{NSWorkspace.shared.open(URL(fileURLWithPath:"/System/Applications/System Settings.app"))}}label:{Label(text(saves.usesICloud ? "Continuar con iCloud" : "Conectar iCloud"),systemImage:"icloud")}.buttonStyle(EasyPrimaryStyle()).disabled(saves.busy)
                        Button(text("Continuar sin iCloud")){skipping=true}.buttonStyle(EasySecondaryStyle())
                    }
                    Text(text("Tus juegos y tus partidas locales siguen siendo tuyos. Los juegos antiguos necesitan actualizarse para sincronizar.")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                }.frame(maxWidth:590,alignment:.leading).padding(32).frame(maxWidth:.infinity)
            }.background(EasyDesign.background)
        }
        .alert(text("Continuar con partidas locales"),isPresented:$skipping) {
            Button(text("Conectar iCloud"),role:.cancel){}
            Button(text("Continuar sin sincronizar")){saves.disconnectCloud();finish()}
        }message:{Text(text("Podrás jugar y guardar en este dispositivo. Easy no recibirá ni sincronizará copias en iCloud hasta que lo conectes. Los juegos que ya configuraste conservan sus ajustes."))}
    }
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
                    VStack(alignment:.leading,spacing:7) {Text("nxnative Easy "+version).font(.title2.bold());Text(text("Motor integrado")+" · "+String(history?.revision.prefix(8) ?? "—")).font(.system(.callout,design:.monospaced)).foregroundStyle(EasyDesign.accent);if let history {Text(text("Base original")+" · "+history.upstream.prefix(8)).font(.caption).foregroundStyle(.secondary)}}
                    Spacer()
                    if updater.available != nil {Button(text("Actualizar Easy")){updater.start()}.buttonStyle(EasyPrimaryStyle()).disabled(updater.busy)}
                    else {Button(text(updater.checking ? "Buscando…" : "Buscar actualizaciones")){Task{await updater.check(manual:true)}}.buttonStyle(EasySecondaryStyle()).disabled(updater.checking || updater.busy)}
                }.padding(24).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:14))
                if let checked=updater.checkedAt {Text(text("Última comprobación")+" · "+checked.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)}
                if updater.available==nil,updater.checkedAt != nil,updater.error==nil {Label(text("Tienes la versión más reciente"),systemImage:"checkmark.circle").foregroundStyle(.green)}
                if updater.error != nil {Label(text("No pudimos buscar actualizaciones. Intenta de nuevo más tarde."),systemImage:"wifi.exclamationmark").foregroundStyle(.orange)}
                if updater.busy {ProgressView(value:updater.progress);Text(text(updater.phaseText)).font(.callout)}
                Text(text("Historial del motor")).font(.title2.bold())
                Text(text("Cambios integrados en esta app. Una nueva versión de Easy no obliga a recompilar todos tus juegos.")).font(.callout).foregroundStyle(.secondary)
                ForEach(history?.entries ?? []) {entry in
                    HStack(alignment:.top,spacing:18) {
                        Image(systemName:"shippingbox").foregroundStyle(EasyDesign.accent).frame(width:22)
                        VStack(alignment:.leading,spacing:8) {Text(entry.title).font(.system(size:13,weight:.semibold)).fixedSize(horizontal:false,vertical:true);HStack {Text(String(entry.revision.prefix(8))).font(.system(.caption,design:.monospaced));Text(ISO8601DateFormatter().date(from:entry.date)?.formatted(date:.abbreviated,time:.omitted) ?? String(entry.date.prefix(10)))}.foregroundStyle(.secondary).font(.caption)}
                        Spacer(minLength:8)
                        Link(destination:URL(string:"https://github.com/nalancer08/nxnative-easy/commit/"+entry.revision)!){Image(systemName:"arrow.up.right").frame(width:36,height:36).contentShape(Rectangle())}.help(text("Ver cambio"))
                    }.padding(18).background(.white.opacity(0.025),in:RoundedRectangle(cornerRadius:10))
                }
            }.frame(maxWidth:900,alignment:.leading).padding(28).frame(maxWidth:.infinity,alignment:.leading)
        }.background(EasyDesign.background)
    }
}

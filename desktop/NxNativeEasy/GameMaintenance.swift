import SwiftUI

enum GameMaintenanceAction {case renew(RefreshJob),install,rebuild(String)}

struct GameMaintenanceView:View {
    let game:OwnedGameOutput
    let title:String
    let jobs:[RefreshJob]
    let needsRebuild:Bool
    var context:GameCareContext?=nil
    let text:(String)->String
    let choose:(GameMaintenanceAction)->Void
    let close:()->Void
    @State var reason=""
    @State private var platform="ios"
    @State private var selectedJob=""
    private var matchingJobs:[RefreshJob] {jobs.filter {job in
        if let id=game.originalBundleID {return job.originalID==id}
        guard let title=game.titleID else {return false}
        return job.originalID.caseInsensitiveCompare("org.nxnative."+title) == .orderedSame
    }}
    private var job:RefreshJob? {matchingJobs.first(where:{$0.id==selectedJob}) ?? matchingJobs.first}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack {EasyEyebrow(title:text("MEJORA TU JUEGO"));Spacer();Button(text("Cerrar"),action:close).buttonStyle(EasyLinkStyle())}
                EasyStepRail(titles:["Qué necesitas","Revisar","Continuar"].map(text),current:reason.isEmpty ? 0 : 1)
                if context==nil {
                    EasyMilestone(kind:reason=="renew" ? .account : .review,title:text(reason=="renew" ? "Vuelve a jugar. Tu progreso sigue." : "Tu juego, mejor que antes."),subtitle:title)
                } else {Text(title).font(.system(size:26,weight:.bold)).lineLimit(2)}
                Text(text("Tu partida se conserva. Elige qué quieres actualizar.")).font(.callout).foregroundStyle(.secondary)
                if let context,context.state != .unknown,context.state != .current {
                    EasyCard {VStack(alignment:.leading,spacing:12) {Text(text(context.title)).font(.headline);Text(text(context.reason)).font(.callout).foregroundStyle(.secondary);ForEach(context.changes,id:\.self){Label(text($0),systemImage:"sparkles").font(.caption)}}}
                }
                if reason.isEmpty {
                choice("renew",title:"Caducó o está por caducar",body:"Para seguir abriendo el juego. No necesita compilar.",icon:"arrow.clockwise.circle")
                choice("update",title:"Quiero las mejoras o un update",body:"Añade las mejoras del motor o tus archivos de actualización.",icon:"sparkles")
                } else {
                    HStack {Label(text(reason=="renew" ? "Renovación de firma" : "Actualización del juego"),systemImage:reason=="renew" ? "arrow.clockwise.circle" : "sparkles").font(.headline);Spacer();Button(text("Cambiar")){reason=""}.buttonStyle(EasyLinkStyle())}
                }
                if reason=="renew" {
                    EasyCard {
                        VStack(alignment:.leading,spacing:16) {
                            if let job {
                                Label(text("Instalación registrada"),systemImage:"iphone").font(.headline)
                                if matchingJobs.count>1 {Picker(text("Dispositivo"),selection:$selectedJob) {ForEach(matchingJobs) {item in Text(item.udid.suffix(8)+" · "+item.expires.formatted(date:.abbreviated,time:.omitted)).tag(item.id)}}}
                                Text(text(job.expires<Date() ? "La firma ya caducó" : "La firma vence")+" · "+job.expires.formatted(date:.abbreviated,time:.shortened)).font(.callout)
                                Text(text("La siguiente pantalla te guía por dispositivo, cuenta y revisión. Se conserva el identificador de esta instalación.")).font(.callout).foregroundStyle(.secondary)
                            } else {
                                Text(text("Conecta el dispositivo para reconocer tu instalación.")).font(.headline)
                                Text(text("Todavía no hay un registro de firma para este juego. El instalador puede revisar una app existente antes de instalar; no la desinstales.")).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if reason=="update" {
                    EasyCard {
                        VStack(alignment:.leading,spacing:16) {
                            Picker(text("Dónde quieres actualizar"),selection:$platform) {Text("Mac").tag("mac");Text("iPhone / iPad").tag("ios")}.pickerStyle(.segmented)
                            if needsRebuild {Label(text("Conviene recompilar: cambiaron herramientas o el perfil de este juego."),systemImage:"sparkles").font(.callout).foregroundStyle(EasyDesign.accent)}
                            else {Text(text("Puedes aplicar tus archivos de update o volver a preparar con el motor actual. No se descarga ningún juego.")).font(.callout).foregroundStyle(.secondary)}
                            Label(text("Tus archivos originales y partidas permanecen en su lugar."),systemImage:"checkmark.shield").font(.callout)
                        }
                    }
                }
                if let context {DisclosureGroup(text("Historial de preparación")) {GameVersionComparison(context:context,text:text).padding(.top,12)}.font(.caption)}
            }.padding(30).frame(maxWidth:820,alignment:.leading).frame(maxWidth:.infinity)
        }.safeAreaInset(edge:.bottom,spacing:0) {
            if !reason.isEmpty {
                HStack(spacing:18) {
                    Text(text("Continuar no instala ni modifica el juego. Primero revisarás el destino.")).font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)
                    Button {
                        if reason=="renew" {if let job {choose(.renew(job))}else {choose(.install)}}else {choose(.rebuild(platform))}
                    } label:{Label(text(reason=="renew" ? "Revisar renovación" : "Revisar archivos"),systemImage:"arrow.right")}.buttonStyle(EasyPrimaryStyle()).disabled(reason=="renew" ? job==nil && game.iosIPA==nil : game.missing)
                }.padding(20).background(EasyDesign.background).overlay(alignment:.top){Divider()}
            }
        }.frame(minWidth:720,idealWidth:820,maxWidth:820,minHeight:520,idealHeight:700,maxHeight:760).background(EasyDesign.background).preferredColorScheme(.dark)
        .task {platform=game.macApp != nil ? "mac" : "ios";selectedJob=context?.attention?.job?.id ?? matchingJobs.first?.id ?? ""}
    }
    private func choice(_ value:String,title:String,body:String,icon:String)->some View {
        Button {reason=value} label:{HStack(alignment:.top,spacing:16) {Image(systemName:icon).font(.system(size:28,weight:.light)).foregroundStyle(EasyDesign.accent);VStack(alignment:.leading,spacing:8) {Text(text(title)).font(.headline);Text(text(body)).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.leading)};Spacer();Image(systemName:reason==value ? "checkmark.circle.fill" : "circle").foregroundStyle(reason==value ? EasyDesign.accent : .secondary)}.padding(20).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).strokeBorder(reason==value ? EasyDesign.accent.opacity(0.7) : .white.opacity(0.08))).foregroundStyle(EasyDesign.ink)}.buttonStyle(.plain)
    }
}

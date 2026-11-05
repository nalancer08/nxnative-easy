import SwiftUI
import AppKit

enum CloudConnectionState:Equatable {
    case disconnected,checking,connected,local,unavailable,accountChanged
    var title:String {
        switch self {
        case .disconnected:return "iCloud sin conectar"
        case .checking:return "Comprobando iCloud…"
        case .connected:return "iCloud listo en este Mac"
        case .local:return "Carpeta local conectada"
        case .unavailable:return "No pudimos comprobar iCloud"
        case .accountChanged:return "La cuenta de iCloud cambió"
        }
    }
    var symbol:String {self == .connected ? "checkmark.icloud.fill" : self == .checking ? "icloud" : "icloud.slash"}
}

extension SaveCenterModel {
    var connectionState:CloudConnectionState {
        if cloudIssue=="icloud_account_changed" {return .accountChanged}
        guard cloud != nil else{return .disconnected}
        if cloudIssue != nil {return .unavailable}
        guard usesICloud else{return .local}
        return cloudCheckedAt==nil ? .checking : .connected
    }

}

struct MacProfile {
    let name:String
    init(name:String=NSFullUserName()) {self.name=name.trimmingCharacters(in:.whitespacesAndNewlines)}
    var initials:String {let words=name.split(whereSeparator:{$0.isWhitespace});return String(words.prefix(2).compactMap(\.first)).uppercased()}
}

struct MacProfileAvatar:View {
    var profile=MacProfile()
    var body:some View {
        ZStack {
            Circle().fill(EasyDesign.accent.opacity(0.15))
            if profile.initials.isEmpty {Image(systemName:"person.fill").font(.system(size:15,weight:.semibold))}
            else {Text(profile.initials).font(.system(size:13,weight:.semibold))}
        }.foregroundStyle(EasyDesign.accent).frame(width:36,height:36).accessibilityHidden(true)
    }
}

struct CloudProfileButton:View {
    @ObservedObject var saves:SaveCenterModel
    let text:(String)->String
    let action:()->Void
    var body:some View {
        Button(action:action) {
            MacProfileAvatar().overlay(alignment:.bottomTrailing) {
                Image(systemName:saves.connectionState == .connected ? "checkmark.circle.fill" : "icloud.circle.fill")
                    .font(.system(size:12)).foregroundStyle(saves.connectionState == .connected ? Color.green : EasyDesign.accent)
                    .background(EasyDesign.background,in:Circle()).offset(x:2,y:2)
            }.frame(width:44,height:44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(text("Perfil de este Mac")+" · "+text(saves.connectionState.title))
        .help(text("Cuenta de iCloud")+" · "+text(saves.connectionState.title))
    }
}

enum SystemCloudAccount {
    static func open() {NSWorkspace.shared.open(URL(fileURLWithPath:"/System/Applications/System Settings.app"))}
}

struct CloudAccountPanel:View {
    @ObservedObject var saves:SaveCenterModel
    let repo:URL
    let text:(String)->String
    let configure:()->Void
    var profile=MacProfile()
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack(spacing:12) {
                MacProfileAvatar(profile:profile)
                VStack(alignment:.leading,spacing:3) {
                    Text(profile.name.isEmpty ? text("Este Mac") : profile.name).font(.headline).lineLimit(2)
                    Text(text("Perfil de este Mac")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            VStack(alignment:.leading,spacing:9) {
                Text(text("Cuenta de iCloud de este Mac")).font(.callout.bold())
                HStack(spacing:8) {
                    if saves.connectionState == .checking {ProgressView().controlSize(.small)}
                    else {Image(systemName:saves.connectionState.symbol)}
                    Text(text(saves.connectionState.title)).font(.callout)
                }.foregroundStyle(saves.connectionState == .connected ? Color.green : EasyDesign.accent)
                if let checked=saves.cloudCheckedAt {Text(text("Última comprobación")+" · "+checked.formatted(date:.omitted,time:.shortened)).font(.caption).foregroundStyle(.secondary)}
                if let folder=saves.cloud {Label(folder.lastPathComponent,systemImage:"folder").font(.caption).lineLimit(1).help(folder.path)}
                Text(text("macOS no comparte el correo ni la foto de iCloud con Easy. Puedes ver la cuenta real en Ajustes.")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
            Button(text("Ver cuenta en macOS"),action:SystemCloudAccount.open).buttonStyle(EasySecondaryStyle())
            if saves.cloud != nil {Button(text("Comprobar conexión")){saves.refresh(repo:repo)}.buttonStyle(EasyLinkStyle()).disabled(saves.scanning)}
            Button(text(saves.cloud==nil ? "Conectar iCloud" : "Cambiar conexión"),action:configure).buttonStyle(EasyLinkStyle())
        }.padding(22).frame(width:310).background(EasyDesign.background)
    }
}

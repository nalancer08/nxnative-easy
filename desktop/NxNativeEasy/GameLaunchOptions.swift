import SwiftUI
import Foundation

struct LaunchSetting:Decodable,Identifiable {
    let env:String
    let kind:String
    let label:String
    let note:String?
    let `default`:String
    let options:[LaunchChoice]?
    let min:Double?
    let max:Double?
    let step:Double?
    let on:String?
    let off:String?
    let needs:String?
    let level:String?
    var id:String {env}
    func permits(_ value:String)->Bool {
        switch kind {
        case "choice":return options?.contains {$0.value==value} == true
        case "toggle":return value==(on ?? "1") || value==(off ?? "0")
        case "range":guard let number=Double(value),number.isFinite,let min,let max else{return false};return number>=min && number<=max
        default:return false
        }
    }
}
struct LaunchChoice:Decodable,Identifiable {
    let value:String;let label:String;var id:String {value}
    init(from decoder:Decoder) throws {var fields=try decoder.unkeyedContainer();value=try fields.decode(String.self);label=try fields.decode(String.self)}
}
struct LaunchDocument:Decodable {let schema:Int?;let settings:[LaunchSetting]}

@MainActor final class GameLaunchOptions:ObservableObject {
    @Published var rows:[LaunchSetting]=[]
    @Published var values:[String:String]=[:]
    @Published var error:String?
    private var domain=""
    init(app:URL) {
        do {
            let info=try PropertyListSerialization.propertyList(from:Data(contentsOf:app.appendingPathComponent("Contents/Info.plist")),format:nil) as? [String:Any]
            guard let id=info?["CFBundleIdentifier"] as? String,id.range(of:"^[A-Za-z0-9.-]+$",options:.regularExpression) != nil else {throw CocoaError(.fileReadCorruptFile)}
            let data=try Data(contentsOf:app.appendingPathComponent("Contents/Resources/dm/launcher.json"))
            guard data.count<=262144 else {throw CocoaError(.fileReadTooLarge)}
            let document=try JSONDecoder().decode(LaunchDocument.self,from:data)
            guard (document.schema ?? 1)==1,document.settings.count<=100,Set(document.settings.map(\.env)).count==document.settings.count else {throw CocoaError(.fileReadCorruptFile)}
            domain=id
            rows=document.settings.filter {$0.env.range(of:"^DM_[A-Z0-9_]+$",options:.regularExpression) != nil && $0.permits($0.default)}
            for row in rows {
                let saved=CFPreferencesCopyAppValue(("launcher."+row.env) as CFString,id as CFString) as? String
                values[row.env]=saved.flatMap {row.permits($0) ? $0 : nil} ?? row.default
            }
        } catch {self.error="Este juego aún no ofrece opciones compatibles. Prepáralo de nuevo para habilitarlas."}
    }
    func visible(_ row:LaunchSetting)->Bool {
        guard let needs=row.needs,let split=needs.firstIndex(of:"=") else {return true}
        let key=String(needs[..<split]),value=String(needs[needs.index(after:split)...])
        return values[key]==nil || values[key]==value
    }
    func save() {
        guard !domain.isEmpty else{return}
        for row in rows {
            guard let value=values[row.env],row.permits(value) else {continue}
            CFPreferencesSetAppValue(("launcher."+row.env) as CFString,(value==row.default || (row.kind=="range" && Double(value)==Double(row.default))) ? nil : value as CFString,domain as CFString)
        }
        if !CFPreferencesAppSynchronize(domain as CFString) {error="No pudimos guardar las opciones. Vuelve a intentar."}
    }
    func reset() {for row in rows {values[row.env]=row.default};save()}
}

struct GameLaunchOptionsView:View {
    @StateObject private var model:GameLaunchOptions
    let text:(String)->String
    @State private var expanded=false
    @State private var advanced=false
    init(app:URL,text:@escaping(String)->String,initiallyExpanded:Bool=false) {_model=StateObject(wrappedValue:GameLaunchOptions(app:app));self.text=text;_expanded=State(initialValue:initiallyExpanded)}
    private func basic(_ row:LaunchSetting)->Bool {row.level=="basic" || ["DM_FPS_TARGET","DM_OPMODE","DM_LANG","DM_RENDER_SCALE","DM_FULLSCREEN"].contains(row.env)}
    private func title(_ value:String)->String {
        text(["Frame rate":"Límite de FPS","Console mode":"Modo de consola","Render scale":"Escala de resolución","Upscaling":"Reescalado","Game language":"Idioma del juego","Display mode":"Modo de pantalla","Game rumble":"Vibración del control","Rumble strength":"Intensidad de vibración","Docked":"En dock","Handheld":"Portátil","Window":"Ventana","Fullscreen":"Pantalla completa","Standard":"Estándar"][value] ?? value)
    }
    var body:some View {
        DisclosureGroup(text("Opciones del juego en Mac"),isExpanded:$expanded) {
            VStack(alignment:.leading,spacing:18) {
                Text(text("Se aplican al próximo inicio y se conservan al recompilar. Los ajustes del archivo env.txt tienen prioridad.")).font(.caption).foregroundStyle(.secondary)
                ForEach(model.rows.filter{model.visible($0) && (advanced || basic($0))}) {row in
                    VStack(alignment:.leading,spacing:5) {
                        let binding=Binding<String>(get:{model.values[row.env] ?? row.default},set:{model.values[row.env]=$0;model.save()})
                        if row.kind=="choice" {
                            Picker(title(row.label),selection:binding) {ForEach(row.options ?? []) {choice in Text(title(choice.label)).tag(choice.value)}}
                        } else if row.kind=="toggle" {
                            Toggle(title(row.label),isOn:Binding(get:{binding.wrappedValue==(row.on ?? "1")},set:{binding.wrappedValue=$0 ? (row.on ?? "1") : (row.off ?? "0")}))
                        } else if let low=row.min,let high=row.max,high>low {
                            HStack {Text(title(row.label));Spacer();Text(binding.wrappedValue).monospacedDigit()}
                            Slider(value:Binding(get:{Double(binding.wrappedValue) ?? low},set:{binding.wrappedValue=String(format:"%.3f",$0)}),in:low...high,step:Swift.max(row.step ?? 0.05,0.001))
                        }
                        if let note=row.note,!note.isEmpty {Text(text(note)).font(.caption).foregroundStyle(.secondary)}
                    }
                }
                if model.rows.contains(where:{!basic($0)}) {Button(text(advanced ? "Menos opciones" : "Más opciones")){advanced.toggle()}.buttonStyle(EasyLinkStyle())}
                if let error=model.error {Text(text(error)).foregroundStyle(.orange)}
                if !model.rows.isEmpty {Button(text("Restaurar opciones recomendadas")){model.reset()}.buttonStyle(EasySecondaryStyle())}
            }.padding(.top,16)
        }.padding(18).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:18))
    }
}

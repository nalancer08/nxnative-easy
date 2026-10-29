import SwiftUI
import AppKit

struct DisposableCache:Decodable,Encodable,Identifiable {let path:String;let digest:String;let bytes:Int64;let inode:UInt64;let device:UInt64;var id:String {path}}
struct CachePreview:Decodable {let candidates:[DisposableCache]}
struct CacheCleanupView:View {
    let folder:URL
    let repo:URL
    let text:(String)->String
    let disabled:Bool
    @State private var expanded=false
    @State private var items:[DisposableCache]=[]
    @State private var selected=Set<String>()
    @State private var busy=false
    @State private var message=""
    @State private var confirm=false
    private var size:String {ByteCountFormatter.string(fromByteCount:items.filter{selected.contains($0.id)}.reduce(0){$0+$1.bytes},countStyle:.file)}
    private func run(deleting:Bool) {
        guard !disabled,!busy else{return}
        busy=true;message=""
        let snapshot=items.filter{selected.contains($0.id)}
        Task {
            let result=await Task.detached {()->(Data?,Int32) in
                let process=Process(),pipe=Pipe();process.executableURL=PortableRuntime.python
                var arguments=[repo.appendingPathComponent("scripts/cache_cleanup.py").path,folder.path]
                let manifest=FileManager.default.temporaryDirectory.appendingPathComponent("nxnative-cache-"+UUID().uuidString+".json")
                defer {try? FileManager.default.removeItem(at:manifest)}
                if deleting {guard let data=try? JSONEncoder().encode(snapshot),(try? data.write(to:manifest,options:.atomic)) != nil else{return(nil,1)};arguments += ["--delete",manifest.path]}
                process.environment=PortableRuntime.environment();process.arguments=arguments;process.standardOutput=pipe;process.standardError=FileHandle.nullDevice
                do {try process.run();let data=pipe.fileHandleForReading.readDataToEndOfFile();process.waitUntilExit();return(data,process.terminationStatus)}catch{return(nil,1)}
            }.value
            busy=false
            guard result.1==0,let data=result.0 else{message="La revisión cambió o una preparación está en curso. Revisa las cachés otra vez.";return}
            if deleting {items=[];selected=[];message="Cachés eliminadas. Tus juegos, archivos y partidas se conservaron."}
            else if let preview=try? JSONDecoder().decode(CachePreview.self,from:data) {items=preview.candidates;selected=[];if items.isEmpty {message="No hay cachés desechables disponibles."}}
        }
    }
    var body:some View {
        DisclosureGroup(text("Liberar espacio de compilación"),isExpanded:$expanded) {
            VStack(alignment:.leading,spacing:14) {
                Text(text("Sólo cachés que se pueden regenerar. No se incluyen juegos, IPA, apps, RomFS, llaves ni partidas. La próxima compilación puede tardar más.")).font(.caption).foregroundStyle(.secondary)
                ForEach(items) {item in Toggle(isOn:Binding(get:{selected.contains(item.id)},set:{if $0 {selected.insert(item.id)}else{selected.remove(item.id)}})) {HStack {Text(item.path).font(.caption);Spacer();Text(ByteCountFormatter.string(fromByteCount:item.bytes,countStyle:.file))}}.disabled(busy || disabled)}
                HStack {Button(text("Revisar cachés")){run(deleting:false)}.disabled(busy || disabled);if !selected.isEmpty {Button(text("Eliminar seleccionadas")+" · "+size,role:.destructive){confirm=true}.disabled(busy || disabled)}}
                if busy {ProgressView().controlSize(.small)}
                if !message.isEmpty {Text(text(message)).font(.caption)}
            }.padding(.top,14)
        }.padding(18).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:18))
        .confirmationDialog(text("¿Eliminar estas cachés?"),isPresented:$confirm) {Button(text("Eliminar seleccionadas"),role:.destructive){run(deleting:true)}} message:{Text(size+" · "+text("Se regenerarán cuando prepares el juego otra vez."))}
    }
}

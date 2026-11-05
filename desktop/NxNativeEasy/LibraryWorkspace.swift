import SwiftUI
import AppKit

struct LibraryWorkspace:View {
    @ObservedObject var model:BuildModel
    @ObservedObject var library:GameLibrary
    @ObservedObject var updater:AppUpdater
    @ObservedObject var sideload:SideloadModel
    @StateObject private var navigation=LauncherNavigation()
    @StateObject private var saves=SaveCenterModel()
    @StateObject private var localSaves=LocalSaveMonitor()
    private var page:LauncherNavigation.Page {get{navigation.page} nonmutating set{navigation.go(newValue)}}
    @State private var query=""
    @State private var selectedEntryID:String?
    @State private var maintaining:OwnedGameOutput?
    @State private var reviewingSyncUpdate=false
    @State private var importingSave=false
    @State private var reviewingUpdate=false
    @State private var showCloudWelcome=false
    @State private var showCloudAccount=false
    @State private var engine:EngineHistory?
    @State private var optionsGame:OwnedGameOutput?
    @State private var changeReasons:[String:[String]]=[:]
    @State private var rebuildAdvice:[String:String]=[:]
    @State private var adviceGeneration=UUID()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var occupied:Bool {model.running || updater.busy || sideload.blocksGameWork}
    init(model:BuildModel,library:GameLibrary,updater:AppUpdater,sideload:SideloadModel,saves:SaveCenterModel?=nil,localSaves:LocalSaveMonitor?=nil,initialEntryID:String?=nil,navigation:LauncherNavigation?=nil) {
        self.model=model;self.library=library;self.updater=updater;self.sideload=sideload
        _navigation=StateObject(wrappedValue:navigation ?? LauncherNavigation())
        _saves=StateObject(wrappedValue:saves ?? SaveCenterModel());_localSaves=StateObject(wrappedValue:localSaves ?? LocalSaveMonitor());_selectedEntryID=State(initialValue:initialEntryID)
    }
    private var entries:[LibraryEntry] {LibraryEntry.merge(local:library.games,revisions:saves.revisions,known:saves.knownCloudTitles,installed:sideload.deviceGames)}
    private var selected:LibraryEntry? {entries.first{$0.id==selectedEntryID}}
    private func entryTitle(_ entry:LibraryEntry)->String {model.catalog.first{$0.id==entry.titleID}?.name ?? entry.local?.folder.lastPathComponent ?? model.text("Juego guardado")}
    private func name(_ game:OwnedGameOutput)->String {model.catalog.first{$0.id==game.titleID}?.name ?? game.folder.lastPathComponent}
    private func needsRebuild(_ game:OwnedGameOutput)->Bool {["Mac","iPhone / iPad"].contains {rebuildAdvice[game.id+$0]=="rebuild"}}
    private func configure(_ game:OwnedGameOutput) {
        guard !occupied else{return}
        model.updatingGame=true;model.expectedLibraryTitleID=game.titleID;model.folder=game.folder;model.defaults.set(game.item.folder,forKey:"lastGameFolder")
        model.output=nil;model.assets=nil;model.target=game.macApp != nil ? "mac" : game.iosIPA != nil ? "ios" : ""
        if model.target=="ios" {model.splitIOS=game.romfs != nil}
        model.restoreOutput();model.installingInline=false;model.preparationStep=0;page = .prepare
    }
    private func prepare(_ entry:LibraryEntry,target:String) {
        guard !occupied else{return};model.expectedLibraryTitleID=entry.titleID
        model.updatingGame = target=="ios" ? !sideload.observations(titleID:entry.titleID,originalID:entry.ios?.originalBundleID).isEmpty : entry.mac != nil
        if let source=entry.source(target),!source.missing {configure(source);model.target=target;model.updatingGame = target=="ios" ? !sideload.observations(titleID:entry.titleID,originalID:entry.ios?.originalBundleID).isEmpty : entry.mac != nil;model.preparationStep=1}
        else {model.folder=nil;model.target=target;model.output=nil;model.installingInline=false;model.preparationStep=1;page = .prepare}
    }
    private func addEntry(_ entry:LibraryEntry) {
        guard !occupied else{return};model.expectedLibraryTitleID=entry.titleID;model.folder=entry.sources.first(where:{!$0.missing})?.folder;model.target="";model.output=nil;model.installingInline=false;model.preparationStep=0;page = .prepare
    }
    private func maintain(_ game:OwnedGameOutput,device:String?=nil) {
        reviewingSyncUpdate=false
        let value=care(game,device:device)
        if (value.state == .expired || value.state == .expiring),let job=value.attention?.job {sideload.reviewRenewal(job);model.showSideload=true}
        else if value.state == .rebuild || value.state == .contentUpdate {configure(game);model.target="ios";model.preparationStep=1}
        else {maintaining=game}
    }
    private func install(_ game:OwnedGameOutput) {
        guard !occupied,!sideload.busy,let ipa=game.iosIPA else{return}
        model.installingInline=false;sideload.configure(ipa:ipa,folder:game.folder,romfs:game.romfs);model.showSideload=true
    }
    private func add() {
        guard !occupied else{return};model.updatingGame=false;query="";model.expectedLibraryTitleID=nil;model.installingInline=false;model.folder=nil;model.target="";model.failed=false;model.preparationStep=0;page = .prepare
    }
    private func remember() {guard let folder=model.folder else{return};do {try library.add(folder)}catch{library.error="No pudimos añadir esa carpeta a la biblioteca. Tus archivos siguen intactos."}}
    private func refreshScope(local:[OwnedGameOutput]?=nil,remote:[SaveRevision]?=nil,known:[String]?=nil) {
        let games=local ?? library.games
        sideload.preparedFolders=Dictionary(games.compactMap{game in game.titleID.map{($0,game.folder)}},uniquingKeysWith:{first,_ in first})
        let ids=games.compactMap{game in game.originalBundleID ?? game.titleID.map{"org.nxnative."+$0.lowercased()}}
        let titles=Set((known ?? saves.knownCloudTitles)+(remote ?? saves.revisions).map(\.title))
        let next=Array(Set(ids+titles.map{"org.nxnative."+$0.lowercased()})).sorted()
        if sideload.preparedIdentifiers != next {sideload.preparedIdentifiers=next;sideload.invalidateGameQueries()}
    }
    private func checkBuildAdvice(_ snapshot:[OwnedGameOutput]?=nil,jobsSnapshot:[RefreshJob]?=nil) {
        let generation=UUID();adviceGeneration=generation
        let games=snapshot ?? library.games,repo=model.repo,jobs=jobsSnapshot ?? sideload.jobs
        Task {
            let advice=await Task.detached(priority:.utility) { ()->[String:String] in
                var result:[String:String]=[:]
                for game in games {
                    guard let id=game.titleID else {continue}
                    for (platform,revision,ready) in [("Mac",game.macRevision,game.macApp != nil),("iPhone / iPad",game.iosRevision,game.iosIPA != nil)] where ready {
                        let value=BuildProvenance.recommendation(repo:repo,revision:revision,titleID:id)
                        if value==true {result[game.id+platform]="rebuild"}
                        else if value==nil {result[game.id+platform]="unknown"}else{result[game.id+platform]="current"}
                    }
                }
                for job in jobs {
                    if let id=SaveLocations.titleID(folder:URL(fileURLWithPath:job.gameFolder)),let reasons=BuildProvenance.reasons(repo:repo,revision:job.preparedWith?.revision,titleID:id) {result["receipt:"+job.id]=reasons.isEmpty ? "current" : "rebuild"}
                }
                return result
            }.value
            var reasons:[String:[String]]=[:]
            let groups=await Task.detached(priority:.utility) { ()->[String:[String]] in
                var values:[String:[String]]=[:]
                for game in games {if let id=game.titleID {values[game.id]=BuildProvenance.reasons(repo:repo,revision:game.iosRevision ?? game.macRevision,titleID:id)}}
                for job in jobs {if let id=SaveLocations.titleID(folder:URL(fileURLWithPath:job.gameFolder)) {values["receipt:"+job.id]=BuildProvenance.reasons(repo:repo,revision:job.preparedWith?.revision,titleID:id)}}
                return values
            }.value
            reasons=groups
            if adviceGeneration==generation {rebuildAdvice=advice;changeReasons=reasons}
        }
    }
    private func care(_ game:OwnedGameOutput,device:String?=nil)->GameCareContext {
        let observations=sideload.observations(titleID:game.titleID,originalID:game.originalBundleID).filter{device==nil || $0.device==device}
        let reports=observations.map {item -> GameDeviceReport in
            let job=sideload.jobs.first(where:{$0.udid==item.device && $0.effectiveID==item.bundleID})
            let advice=job.flatMap{rebuildAdvice["receipt:"+$0.id]}
            let evidence=GameCareEvidence(installed:true,installedVersion:item.version,preparedVersion:game.iosIPA == nil ? nil : PreviousPreparation.load(folder:game.folder,target:"ios")?.version,expires:job?.expires,rebuild:advice.map{$0=="rebuild"},preparedRevision:game.iosRevision,installedRevision:job?.preparedWith?.revision)
            return GameDeviceReport(observation:item,job:job,state:evidence.state(),verified:sideload.isVerified(item))
        }
        let changes=Set((changeReasons[game.id] ?? [])+reports.flatMap{report in report.job.flatMap{changeReasons["receipt:"+$0.id]} ?? []}).sorted()
        return GameCareContext(reports:reports,changes:changes,prepared:EasyBuildStamp.prepared(folder:game.folder,target:game.iosIPA != nil ? "ios" : "mac"),current:EasyBuildStamp.current,localReady:game.macApp != nil,localRebuild:rebuildAdvice[game.id+"Mac"].flatMap{$0=="unknown" ? nil : $0=="rebuild"},engine:engine)
    }

    private func selectAvailableGame() {
        if let selectedEntryID,entries.contains(where:{$0.id==selectedEntryID}) {return}
        let remembered=model.defaults.string(forKey:"launcher.selectedGame.v2")
        selectedEntryID=entries.first(where:{$0.id==remembered})?.id ?? entries.first?.id
    }
    private func showBuildActivity() {page = .prepare;model.installingInline=false;let unfinished=model.running || model.failed || model.output==nil;model.preparationStep=unfinished ? 4 : 5;model.showDetails=true}
    private func header(compact:Bool)->some View {
        HStack(spacing:8) {
                if compact {Image(nsImage:AppArtwork.icon).resizable().frame(width:24,height:24).frame(width:32).accessibilityLabel("nxnative Easy")}else{LauncherBrand()}
                if navigation.canGoBack || maintaining != nil {LauncherButton(title:"",symbol:"chevron.left"){if maintaining != nil {maintaining=nil}else{navigation.back()}}.frame(width:44,height:44).accessibilityLabel(model.text("Volver")).transition(.opacity.combined(with:.move(edge:.leading)))}
                LauncherButton(title:model.text("Biblioteca"),selected:page == .library){page = .library;maintaining=nil}.frame(width:100,height:44)
                LauncherButton(title:model.text("Compatibilidad"),selected:page == .compatibility){page = .compatibility}.frame(width:138,height:44)
                Spacer(minLength:0)
                Button {page = .engine}label:{VStack(alignment:.leading,spacing:2){Text(model.text("MOTOR")).font(.system(size:10,weight:.bold)).tracking(1);Text(engine?.version ?? "—").font(.system(size:13,weight:.semibold))}.frame(width:62,height:38).padding(.horizontal,10).contentShape(Rectangle()).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:8))}.buttonStyle(EasySelectionStyle(selected:page == .engine)).help(model.text("Historial del motor"))
                if model.running {Image(systemName:"hammer").font(.callout).foregroundStyle(EasyDesign.accent).help(model.text("Preparando tu juego…"))}
                if updater.visible && !model.running {Button {reviewingUpdate=true}label:{Image(systemName:"arrow.down.circle.fill").font(.title3).frame(width:34,height:38).contentShape(Rectangle())}.buttonStyle(EasyIconStyle()).foregroundStyle(EasyDesign.accent).accessibilityLabel(model.text("Actualizar Easy")).help(model.text("Actualizar Easy"))}
                LauncherButton(title:compact ? "" : model.text("Añadir juego"),symbol:"plus",enabled:!occupied,action:add).frame(width:compact ? 44 : 146,height:44).accessibilityLabel(model.text("Añadir juego"))
                CloudProfileButton(saves:saves,text:model.text){showCloudAccount.toggle()}.popover(isPresented:$showCloudAccount,arrowEdge:.bottom){CloudAccountPanel(saves:saves,repo:model.repo,text:model.text,configure:{showCloudAccount=false;showCloudWelcome=true})}
            }.padding(.horizontal,16).frame(height:60).background(EasyDesign.background).overlay(alignment:.bottom){Divider()}.zIndex(100)
    }
    private var shell:some View {
        VStack(spacing:0) {
            GeometryReader {geometry in header(compact:geometry.size.width<1000)}.frame(height:60)
            ZStack {
                RetainedPage(visible:page == .prepare && maintaining==nil) {
                    ContentView(updater:updater,sideload:sideload,model:model,visible:page == .prepare && maintaining==nil)
                        .environment(\.scenePhase,page == .prepare ? scenePhase : .inactive).preferredColorScheme(.dark)
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
                if page == .settings {WorkspaceSettingsView(model:model,sideload:sideload,saves:saves,games:library.games,showEngine:{page = .engine},showCloud:{showCloudWelcome=true})}
                if page == .compatibility {GameCatalogView(model:model)}
                if page == .engine {EngineHistoryView(history:engine,updater:updater,text:model.text)}
                if page == .library {
                    HStack(spacing:0) {
                        LauncherSidebar(entries:entries,catalog:model.catalog,text:model.text,selected:$selectedEntryID,query:$query,add:add,settings:{page = .settings})
                        if let entry=selected {
                            ScrollView {GameContinuityDetail(entry:entry,title:entryTitle(entry),catalog:model.catalog.first{$0.id==entry.titleID},context:entry.ios.map{care($0)} ?? entry.local.map{care($0)},saves:saves,localSaves:localSaves,sideload:sideload,repo:model.repo,text:model.text,disabled:occupied,prepare:{prepare(entry,target:$0)},reviewSync:{if let game=entry.ios ?? entry.local {reviewingSyncUpdate=true;maintaining=game}else{addEntry(entry)}},chooseDestination:{addEntry(entry)},maintain:{if let game=entry.ios ?? entry.local {maintain(game)}else{addEntry(entry)}},maintainDevice:{report in if let game=entry.ios ?? entry.local {maintain(game,device:report.device)}else{addEntry(entry)}},install:{if let game=entry.ios {install(game)}else{prepare(entry,target:"ios")}},files:{optionsGame=entry.local},upload:{guard let game=entry.ios ?? entry.mac else{return};saves.gameID=game.id;saves.source=nil;saves.selectedRevision=nil;saves.completed=nil;saves.chooseSource(repo:model.repo);if saves.source != nil {importingSave=true}},reviewRevision:{revision in saves.inspect(repo:model.repo,url:URL(fileURLWithPath:revision.path),revision:revision);importingSave=true},engineHistory:engine)}.id(entry.id).transition(.opacity.combined(with:.offset(y:8)))
                        } else {LauncherWelcome(text:model.text,add:add)}
                    }
                }
                if let game=maintaining {
                    GameMaintenanceView(game:game,title:name(game),jobs:sideload.jobs,needsRebuild:needsRebuild(game),context:care(game),cloudSync:reviewingSyncUpdate,text:model.text,choose:{action in
                        maintaining=nil
                        switch action {case .renew(let job):sideload.reviewRenewal(job);model.showSideload=true
                        case .install:install(game)
                        case .rebuild(let target):configure(game);model.target=target;model.preparationStep=1}
                    },close:{maintaining=nil},reason:reviewingSyncUpdate ? "update" : "").frame(maxWidth:.infinity,maxHeight:.infinity).background(EasyDesign.background).transition(.opacity)
                }
            }.frame(maxWidth:.infinity,maxHeight:.infinity).clipped().zIndex(0).animation(reduceMotion ? nil : .easeInOut(duration:0.24),value:selectedEntryID).animation(reduceMotion ? nil : .easeInOut(duration:0.2),value:navigation.page)
            if model.running || (!model.buildDockDismissed && (model.failed || !model.activity.history.isEmpty)) {Divider();BuildDock(model:model,completion:sideload.completedInstallation && sideload.gameFolder?.path==model.folder?.path ? model.text("Instalación completada en")+" "+(sideload.devices.first{$0.id==sideload.device}?.name ?? "iPhone / iPad") : nil,show:{page = .prepare;model.showDetails=true;model.preparationStep=model.running || model.failed ? 4 : 5})}
        }.background(EasyDesign.background)
        .overlay(alignment:.bottomTrailing) {
            if let connected=sideload.justConnected {
                HStack(spacing:9) {
                    Image(systemName:"checkmark.circle.fill").foregroundStyle(.green)
                    Text(connected.name).font(.system(size:12,weight:.medium)).lineLimit(1)
                    Text(model.text("Conectado")).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)
                    Button {sideload.dismissConnectionNotice()}label:{Image(systemName:"xmark").font(EasyDesign.metadata)}.buttonStyle(EasyIconStyle()).accessibilityLabel(model.text("Cerrar"))
                }.padding(12).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).strokeBorder(EasyDesign.border)).padding(16).id(connected.id)
            }
        }
    }
    private var observingShell:some View {
        shell
        .task {library.refresh();selectAvailableGame();refreshScope();sideload.canRefresh={!model.running && !updater.busy};Task{await updater.check()};checkBuildAdvice();engine=EngineHistory.load(repo:model.repo);saves.ensureManagedCloud(repo:model.repo);if !model.defaults.bool(forKey:"launcher.cloudWelcome.v1") {showCloudWelcome=true}}
        .task(id:scenePhase){if scenePhase == .active {await updater.check();await sideload.watchConnections()}}
        .task(id:String(scenePhase == .active)+":"+(saves.cloud?.path ?? "")){if scenePhase == .active {await saves.watchCloud(repo:model.repo)}}
        .task(id:String(scenePhase == .active)+":"+entries.compactMap(\.titleID).sorted().joined(separator:",")){if scenePhase == .active {await localSaves.watch(titles:entries.compactMap(\.titleID))}}
        .task(id:sideload.justConnected?.id){if sideload.justConnected != nil {do {try await Task.sleep(nanoseconds:5_000_000_000)}catch{return};sideload.dismissConnectionNotice()}}
        .onReceive(library.$games){games in checkBuildAdvice(games);refreshScope(local:games)}
        .onChange(of:entries.map(\.id)){_,_ in selectAvailableGame()}
        .onChange(of:selectedEntryID){_,value in if let value {model.defaults.set(value,forKey:"launcher.selectedGame.v2")}}
        .onReceive(NotificationCenter.default.publisher(for:.NSUbiquityIdentityDidChange)){_ in saves.systemCloudAccountChanged()}
        .onReceive(saves.$revisions){refreshScope(remote:$0)}
        .onReceive(saves.$knownCloudTitles){refreshScope(known:$0)}
        .onReceive(sideload.$jobs){checkBuildAdvice(jobsSnapshot:$0)}
        .onChange(of:model.folder){_,_ in if model.folder != nil && model.expectedLibraryTitleID==nil {remember()}}
        .onChange(of:model.inspection?.title_id){_,_ in if model.expectedLibraryTitleID != nil && model.matchesExpectedGame {remember()}}
        .onChange(of:model.running){old,new in if old && !new {if !model.failed,model.output != nil,let folder=model.folder,let revision=model.buildRevision {library.recordBuild(folder:folder,target:model.target,revision:revision)};library.refresh();checkBuildAdvice()}}
        .onChange(of:model.installingInline){_,inline in if inline {page = .prepare}}
        .onChange(of:model.showCatalog){_,show in if show {page = .compatibility;model.showCatalog=false}}
        .onChange(of:model.showDeviceLibrary){_,show in if show {page = .library;model.showDeviceLibrary=false}}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.showDevices"))){_ in page = .library}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.showCompatibility"))){_ in maintaining=nil;page = .compatibility}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.addGame"))){_ in add()}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.navigateBack"))){_ in if maintaining != nil {maintaining=nil}else{navigation.back()}}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.showLibrary"))){_ in page = .library;maintaining=nil;library.refresh()}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.openSettings"))){_ in page = .settings}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.showBuildActivity"))){_ in showBuildActivity()}
    }
    var body:some View {
        observingShell
        .buttonStyle(EasySecondaryStyle()).tint(EasyDesign.accent).preferredColorScheme(.dark).allowsWindowActivationEvents()
        .alert(model.text("Ya tienes la versión más reciente."),isPresented:$updater.showNotice) {Button(model.text("Aceptar"),role:.cancel) {}}
        .sheet(isPresented:$model.showSaves) {SavesHelpView(folder:model.folder,isMac:model.isMac,text:model.text,language:model.language)}
        .sheet(isPresented:$model.showSideload) {SideloadView(model:sideload,text:model.text).buttonStyle(EasySecondaryStyle()).tint(EasyDesign.accent)}
        .sheet(isPresented:$model.showAnalysis) {if let game=model.folder {GameAnalysisView(repo:model.repo,game:game,text:model.text)} else {Text(model.text("Primero selecciona la carpeta de un juego preparado.")).padding(24)}}
        .allowsHitTesting(!showCloudWelcome).accessibilityHidden(showCloudWelcome)
        .overlay {if showCloudWelcome {CloudWelcomeView(saves:saves,repo:model.repo,text:model.text,finish:{model.defaults.set(true,forKey:"launcher.cloudWelcome.v1");withAnimation(reduceMotion ? nil : .easeInOut(duration:0.25)){showCloudWelcome=false}}).transition(.opacity).zIndex(200)}}
        .sheet(isPresented:$importingSave,onDismiss:{saves.source=nil;saves.preview=nil;saves.completed=nil}) {
            VStack(spacing:0) {HStack {Text(model.text(saves.selectedRevision==nil ? "Subir un respaldo" : "Preparar una copia")).font(.headline);Spacer();Button(model.text("Cerrar")){importingSave=false}.disabled(saves.busy)}.padding(20);SaveCenterView(model:saves,repo:model.repo,games:library.games.filter{$0.titleID==selected?.titleID},catalog:model.catalog,text:model.text,focusTitle:selected?.titleID,devices:{})}.frame(width:820,height:740)
        }
        .sheet(item:$optionsGame) {game in
            VStack(spacing:0) {
                HStack {Text(name(game)).font(.title2.bold());Spacer();Button(model.text("Cerrar")){optionsGame=nil}}.padding(24)
                ScrollView {VStack(alignment:.leading,spacing:20) {
                    if let app=game.macApp {GameLaunchOptionsView(app:app,text:model.text).disabled(occupied)}
                    CacheCleanupView(folder:game.folder,repo:model.repo,text:model.text,disabled:occupied)
                    Button(model.text("Mostrar carpeta")){NSWorkspace.shared.activateFileViewerSelecting([game.folder])}.buttonStyle(EasySecondaryStyle())
                    Button(model.text("Quitar de la biblioteca")){library.remove(game.id);optionsGame=nil;selectedEntryID=nil}.buttonStyle(EasyLinkStyle()).disabled(occupied)
                    Text(model.text("Sólo se quita el registro. Tus archivos y partidas se conservan.")).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)
                }.padding(24)}
            }.frame(width:720,height:640).background(EasyDesign.background)
        }
        .sheet(isPresented:$reviewingUpdate) {
            VStack(alignment:.leading,spacing:20) {
                HStack {Text(model.text("Actualizar Easy")).font(.title2.bold());Spacer();Button(model.text("Cerrar")){reviewingUpdate=false}.disabled(updater.busy)}
                Text(updater.available?.version ?? "").font(.title.bold())
                Text(model.text("Actualiza la app y sus perfiles de juegos.")).font(.callout).foregroundStyle(EasyDesign.muted)
                Text(model.text("Tus juegos y partidas se conservan.")).font(.callout)
                if updater.busy {ProgressView(model.text(updater.phaseText));if let value=updater.progress {ProgressView(value:value)}}
                else {if let error=updater.error {Text(model.text(error)).font(EasyDesign.metadata).foregroundStyle(.orange)};Button(model.text("Actualizar ahora")){updater.start()}.buttonStyle(EasyPrimaryStyle()).disabled(occupied || updater.available==nil)}
            }.padding(28).frame(width:480).background(EasyDesign.background).interactiveDismissDisabled(updater.busy)
        }
    }
}

struct WorkspaceSettingsView:View {
    @ObservedObject var model:BuildModel
    @ObservedObject var sideload:SideloadModel
    @ObservedObject var saves:SaveCenterModel
    var games:[OwnedGameOutput]=[]
    var showEngine:()->Void={}
    var showCloud:()->Void={}
    enum Section:String,CaseIterable {case general,apple,controllers,storage}
    @State var section=Section.general
    @State private var copiedDiagnostics=false
    @State private var backgroundRenewal=SideloadModel.backgroundEnabled
    @AppStorage("buildNotifications") private var buildNotifications=true
    private var version:String {Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "development"}
    private func title(_ section:Section)->String {
        switch section {case .general:return "General";case .apple:return "Cuenta Apple";case .controllers:return "Control";case .storage:return "Almacenamiento"}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            VStack(alignment:.leading,spacing:20) {
                EasyEyebrow(title:model.text("PREFERENCIAS"))
                Text(model.text("Configuración")).font(.system(size:28,weight:.bold)).tracking(-1)
                HStack(spacing:12) {
                    ForEach(Section.allCases,id:\.self) {item in
                        Button {section=item} label:{Label(model.text(title(item)),systemImage:item == .general ? "slider.horizontal.3" : item == .apple ? "person.crop.circle" : item == .storage ? "externaldrive" : "gamecontroller").font(.system(size:13,weight:section==item ? .semibold : .regular)).foregroundStyle(section==item ? EasyDesign.ink : EasyDesign.muted).padding(.horizontal,12).padding(.vertical,12).contentShape(Rectangle()).overlay(alignment:.bottom){if section==item {Capsule().fill(EasyDesign.accent).frame(height:2)}}}.buttonStyle(EasySelectionStyle(selected:section==item)).accessibilityAddTraits(section==item ? .isSelected : [])
                    }
                }
            }.padding(28)
            Divider()
            switch section {
            case .general:
                ScrollView {
                    VStack(alignment:.leading,spacing:24) {
                        VStack(alignment:.leading,spacing:20) {
                            Label(model.text("Personaliza la app"),systemImage:"slider.horizontal.3").font(.headline)
                            HStack {
                                VStack(alignment:.leading,spacing:5) {Text(model.text("Idioma de la interfaz")).font(.callout.bold());Text(model.text("El idioma del juego se configura por separado.")).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)}
                                Spacer()
                                Picker(model.text("Idioma de la interfaz"),selection:$model.language){Text("English").tag(EasyLanguage.english);Text("Español").tag(EasyLanguage.spanish)}.labelsHidden().frame(width:180)
                            }
                            Divider()
                            Toggle(model.text("Notificar cuando termine una preparación"),isOn:$buildNotifications).toggleStyle(.switch)
                            Divider()
                            Toggle(model.text("Renovar aunque la ventana esté cerrada"),isOn:$backgroundRenewal).toggleStyle(.switch).onChange(of:backgroundRenewal){_,value in sideload.setLoginItem(value)}
                            Text(model.text("Sólo renueva los juegos que hayas autorizado. Requiere este Mac despierto, sesión guardada y el dispositivo emparejado accesible por USB o Wi-Fi. macOS puede pedir permiso en Elementos de inicio.")).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)

                        }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:16))
                        VStack(alignment:.leading,spacing:12) {
                            Label("iCloud",systemImage:"icloud").font(.headline)
                            Text(model.text(saves.cloud==nil ? "Activa iCloud Drive en Ajustes del Sistema. Easy prepara su carpeta automáticamente." : "Tus partidas se reciben automáticamente en la biblioteca.")).font(.callout).foregroundStyle(EasyDesign.muted)
                            Text(model.text("Usa la cuenta de iCloud de macOS. La cuenta Apple para firmar apps es independiente.")).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)
                            Button(model.text("Cuenta de iCloud"),action:showCloud).buttonStyle(EasySecondaryStyle())
                            if let folder=saves.cloud {Button(model.text("Mostrar carpeta")){NSWorkspace.shared.activateFileViewerSelecting([folder])}.buttonStyle(EasyLinkStyle())}
                            else {Button(model.text("Conectar iCloud"),action:showCloud).buttonStyle(EasySecondaryStyle())}
                            DisclosureGroup(model.text("Opciones avanzadas")) {HStack {Button(model.text("Cambiar carpeta")){saves.chooseCloud(repo:model.repo)};if saves.cloud != nil {Button(model.text("Desconectar iCloud")){saves.disconnectCloud()}}}.padding(.top,12)}.font(EasyDesign.metadata)
                        }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:16))
                        VStack(alignment:.leading,spacing:16) {
                            Label(model.text("Ayuda y diagnóstico"),systemImage:"lifepreserver").font(.headline)
                            Text(model.text("Comparte un resumen de la app y del último proceso, con datos sensibles ocultos.")).font(.callout).foregroundStyle(EasyDesign.muted)
                            Button(model.text(copiedDiagnostics ? "Diagnóstico copiado" : "Copiar diagnóstico")){model.copyDiagnostics();copiedDiagnostics=true}
                        }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:16))
                        Button(action:showEngine){Label(model.text("Motor y actualizaciones")+" · Easy "+version,systemImage:"shippingbox")}.buttonStyle(EasySecondaryStyle())
                    }.padding(28)
                }
            case .apple:
                SideloadView(model:sideload,text:model.text,accountOnly:true,embedded:true)
            case .storage:
                ScrollView {VStack(alignment:.leading,spacing:18) {Text(model.text("Tus originales y partidas se conservan. Libera archivos temporales que se pueden volver a generar.")).font(.callout).foregroundStyle(EasyDesign.muted);ForEach(games) {game in VStack(alignment:.leading,spacing:10) {Text(game.folder.lastPathComponent).font(.headline);CacheCleanupView(folder:game.folder,repo:model.repo,text:model.text,disabled:model.running)}}}.padding(28)}
            case .controllers:
                ScrollView {
                    VStack(alignment:.leading,spacing:12) {
                        Text(model.text("Prueba el control conectado a este Mac sin abrir ni preparar un juego.")).font(.callout).foregroundStyle(EasyDesign.muted).padding(.horizontal,26).padding(.top,24)
                        ControllerTestView(text:model.text,embedded:true)
                    }
                }
            }
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
    }
}

struct GameLibraryDetail:View {
    let game:OwnedGameOutput
    let title:String
    let catalog:CatalogGame?
    let text:(String)->String
    let building:Bool
    let disabled:Bool
    var installBusy=false
    var observations:[DeviceGameObservation]=[]
    var isVerified:(DeviceGameObservation)->Bool={_ in false}
    var needsRebuild=false
    var advice:[String]=[]
    var sourceRepo:URL?=nil
    var checkDevices:()->Void={}
    let open:()->Void
    let prepare:()->Void
    let install:()->Void
    let remove:()->Void
    var prepareMac:()->Void={}
    var prepareIOS:()->Void={}
    var manageDevices:()->Void={}
    var manageSaves:()->Void={}
    var maintain:()->Void={}
    @State var section="status"
    private var status:String {
        if building {return text("Compilando")}
        if let device=observations.first(where:isVerified) ?? observations.first {return text(isVerified(device) ? "Instalado en" : device.checkedAt==nil ? "Instalación registrada en" : "Última vez en")+" "+device.deviceName}
        return text(game.macApp != nil ? "Listo para jugar en Mac" : game.iosIPA != nil ? "IPA lista para instalar" : "Sin preparar")
    }
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            LibrarySpotlight(item:LibrarySpotlightItem(game:game,catalog:catalog,title:title,status:status,verified:!building && observations.contains(where:isVerified),installed:!observations.isEmpty,rebuild:needsRebuild),text:text,disabled:disabled || (game.macApp==nil && installBusy),secondaryTitle:"Mostrar carpeta",details:{NSWorkspace.shared.activateFileViewerSelecting([game.folder])},primary:{if game.macApp != nil {open()}else if game.iosIPA != nil {install()}else {prepare()}}).frame(height:310)
            VStack(alignment:.leading,spacing:24) {
                HStack(spacing:24) {
                    ForEach(["status","options","saves"],id:\.self) {value in
                        Button {section=value} label:{Text(text(value=="status" ? "Dónde jugar" : value=="options" ? "Archivos y opciones" : "Partidas")).font(.system(size:13,weight:section==value ? .semibold : .regular)).foregroundStyle(section==value ? EasyDesign.ink : EasyDesign.muted).padding(.vertical,12).overlay(alignment:.bottom){if section==value {Capsule().fill(EasyDesign.accent).frame(height:2)}}}.buttonStyle(.plain)
                    }
                    Spacer()
                    Menu {
                        Button(text("Actualizar o renovar"),action:maintain).disabled(disabled || game.missing)
                        Button(text("Mostrar carpeta")){NSWorkspace.shared.activateFileViewerSelecting([game.folder])}
                        Button(text("Quitar de esta lista"),role:.destructive,action:remove).disabled(disabled)
                    } label:{Image(systemName:"ellipsis")}.menuStyle(.borderlessButton).fixedSize().accessibilityLabel(text("Acciones del juego"))
                }
                if game.missing {Label(text("Carpeta no disponible"),systemImage:"externaldrive.badge.exclamationmark").foregroundStyle(.orange)}
                if section=="status" {
                    Button {maintain()} label:{Label(text("Actualizar o renovar"),systemImage:"arrow.triangle.2.circlepath")}.buttonStyle(EasySecondaryStyle()).disabled(disabled)
                    if needsRebuild {Label(text("Conviene recompilar: cambiaron herramientas o el perfil de este juego."),systemImage:"arrow.triangle.2.circlepath").font(.callout).foregroundStyle(.orange)}
                    HStack(alignment:.top,spacing:18) {
                        EasyCard {
                            VStack(alignment:.leading,spacing:16) {
                                HStack {Image(systemName:"desktopcomputer").font(.system(size:26,weight:.ultraLight)).foregroundStyle(EasyDesign.accent);Spacer();Image(systemName:game.macApp != nil ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(game.macApp != nil ? EasyDesign.accent : EasyDesign.muted)}
                                Text("Mac").font(.system(size:23,weight:.bold))
                                Text(text(game.macApp != nil ? "Mac: listo para jugar" : "Mac: sin app creada")).font(.callout).foregroundStyle(EasyDesign.muted)
                                Button(text(game.macApp != nil ? "Preparar actualización" : "Preparar en Mac"),action:prepareMac).buttonStyle(EasySecondaryStyle()).disabled(disabled || game.missing)
                            }
                        }
                        EasyCard {
                            VStack(alignment:.leading,spacing:16) {
                                HStack {Image(systemName:"ipad.and.iphone").font(.system(size:26,weight:.ultraLight)).foregroundStyle(EasyDesign.accent);Spacer();Button(action:checkDevices){Image(systemName:"arrow.clockwise")}.buttonStyle(.plain).disabled(disabled).accessibilityLabel(text("Comprobar dispositivos"))}
                                Text("iPhone / iPad").font(.system(size:23,weight:.bold))
                                if observations.isEmpty {Text(text("Todavía no verificamos este juego en un iPhone o iPad. Conéctalo para comprobarlo.")).font(.callout).foregroundStyle(EasyDesign.muted)}
                                ForEach(observations) {item in
                                    VStack(alignment:.leading,spacing:4) {
                                        Label(item.deviceName,systemImage:isVerified(item) ? "checkmark.circle.fill" : "clock").font(.callout.weight(.semibold)).foregroundStyle(isVerified(item) ? Color.green : EasyDesign.muted)
                                        Text(text(isVerified(item) ? "Instalación verificada" : item.checkedAt==nil ? "Instalación registrada" : "Última instalación observada")+(item.version.isEmpty ? "" : " · "+item.version)).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)
                                        if let checked=item.checkedAt {Text(checked.formatted(date:.abbreviated,time:.shortened)).font(EasyDesign.metadata).foregroundStyle(.tertiary)}
                                        if item.checkedAt==nil {Text(text("Hay un registro de instalación. Conecta el dispositivo para comprobar su estado actual.")).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)}
                                    }
                                }
                                Text(text(game.iosIPA != nil ? "Archivo IPA: listo para instalar" : "Archivo IPA: sin crear")).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)
                                if game.macApp != nil,game.iosIPA != nil {Button(text(observations.isEmpty ? "Instalar en iPhone / iPad" : "Actualizar en iPhone / iPad"),action:install).buttonStyle(EasySecondaryStyle()).disabled(disabled || installBusy || game.missing)}
                                else if game.iosIPA==nil {Button(text("Preparar para iPhone / iPad"),action:prepareIOS).buttonStyle(EasySecondaryStyle()).disabled(disabled || game.missing)}
                            }
                        }
                    }
                    if let version=game.version {Label(text("Versión preparada")+" · "+version,systemImage:"tag").font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)}
                    if !advice.isEmpty {DisclosureGroup(text("Historial de preparación")) {ForEach(advice,id:\.self){Text($0).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted).padding(.top,8)}}.font(.callout)}
                } else if section=="options" {
                    if let app=game.macApp {GameLaunchOptionsView(app:app,text:text).id(app.path).disabled(disabled)}
                    if let repo=sourceRepo {CacheCleanupView(folder:game.folder,repo:repo,text:text,disabled:disabled).id(game.folder.path)}
                    EasyCard {VStack(alignment:.leading,spacing:12) {Label(text("Tus archivos"),systemImage:"folder").font(.headline);Text(game.folder.path).font(EasyDesign.metadata.monospaced()).foregroundStyle(EasyDesign.muted).textSelection(.enabled);Button(text("Mostrar carpeta")){NSWorkspace.shared.activateFileViewerSelecting([game.folder])}.buttonStyle(EasySecondaryStyle());Button(text("Preparar o actualizar"),action:prepare).buttonStyle(EasyLinkStyle()).disabled(disabled || game.missing);Text(text("Usa tus archivos para preparar otra plataforma o aplicar un update. Tus partidas y archivos originales se conservan.")).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)}}
                } else {
                    EasyMilestone(kind:.transfer,title:text("Continúa tu partida"),subtitle:text("Guarda en tu dispositivo. Continúa en otra pantalla."))
                    EasyCard {
                        VStack(alignment:.leading,spacing:14) {
                            Label(text("Continuar entre iPhone y Mac"),systemImage:"icloud").font(.headline)
                            Text(text("Prepara las versiones para Mac y iPhone / iPad con esta actualización. Instala sobre la app existente para conservar sus partidas."))
                            Text(text("Abre cada juego y elige la misma carpeta de iCloud Drive. Usa la misma versión y contenido del juego en ambos dispositivos."))
                            Text(text("Guarda y cierra antes de cambiar de dispositivo. Si hay dos progresos distintos, eliges con cuál seguir y se conservan ambos."))
                            Text(text("No requiere iniciar sesión con tu cuenta de firma. iCloud usa la cuenta del propio dispositivo.")).foregroundStyle(EasyDesign.muted)
                            Link(text("Ver guía de partidas"),destination:URL(string:"https://github.com/nalancer08/nxnative-easy/blob/main/docs/icloud-saves.md")!)
                        }.font(.callout)
                    }
                    HStack {Button(text("Abrir mis partidas de iCloud"),action:manageSaves).buttonStyle(EasyPrimaryStyle());Button(text("Ver partidas del dispositivo"),action:manageDevices).buttonStyle(EasySecondaryStyle())}
                }
            }.padding(.horizontal,36).padding(.bottom,30).frame(maxWidth:1160).frame(maxWidth:.infinity)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}

struct BuildDock:View {
    @ObservedObject var model:BuildModel
    var completion:String?=nil
    let show:()->Void
    var body:some View {
        HStack(spacing:20) {
            VStack(alignment:.leading,spacing:5) {
                HStack {Image(systemName:model.failed ? "exclamationmark.triangle" : "hammer");Text(model.gameName).font(.headline);Text(model.isMac ? "Mac" : "iPhone / iPad").font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)}
                Text(!model.running ? (completion ?? model.text(model.phase)) : [model.activity.stage,model.activity.step,model.activity.count].filter{!$0.isEmpty}.joined(separator:" · ")).font(EasyDesign.metadata).lineLimit(1).foregroundStyle(EasyDesign.muted)
            }.frame(maxWidth:.infinity,alignment:.leading)
            if model.running {
                VStack(alignment:.leading,spacing:5) {
                    if let fraction=model.activity.fraction {ProgressView(value:fraction)}else{ProgressView().progressViewStyle(.linear)}
                    Text(model.text("Etapa actual")+(model.activity.fraction.map{" · "+String(Int($0*100))+" %"} ?? "")+(model.activity.eta.map{" · ~"+String(Int($0))+" s"} ?? "")).font(.caption2).foregroundStyle(EasyDesign.muted)
                }.frame(width:220)
            }
            Button(model.text("Ver actividad"),action:show)
            if model.running {Button(model.text("Cancelar")){model.cancel()}}
            else {Button {model.dismissBuildDock()} label:{Image(systemName:"xmark")}.buttonStyle(EasySecondaryStyle()).accessibilityLabel(model.text("Cerrar aviso de actividad")).help(model.text("Cerrar aviso de actividad"))}
        }.padding(.horizontal,24).padding(.vertical,16)
    }
}

struct BuildTimeline:View {
    let activity:BuildActivity
    let text:(String)->String
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {Text(text("Etapas de compilación")).font(.headline);Spacer();if activity.stages>0 {Text(String(activity.history.filter{$0.state == .done && $0.number>0}.count)+" / "+String(activity.stages)).font(EasyDesign.metadata).monospacedDigit().foregroundStyle(EasyDesign.muted)}}
            ForEach(activity.history) {stage in
                HStack(alignment:.top,spacing:10) {
                    VStack(spacing:4) {Image(systemName:stage.state == .done ? "checkmark.circle.fill" : stage.state == .failed ? "xmark.circle.fill" : stage.state == .cancelled ? "pause.circle" : "circle.inset.filled").foregroundStyle(stage.state == .failed ? Color.orange : stage.state == .done ? Color.green : Color.primary)
                        if stage.id != activity.history.last?.id {Rectangle().fill(.secondary.opacity(0.3)).frame(width:1,height:14)}
                    }
                    VStack(alignment:.leading,spacing:3) {Text(text(BuildActivity.displayName(stage.name))).font(.callout.weight(stage.state == .active ? .semibold : .regular));if stage.state == .active && !activity.step.isEmpty {Text(activity.step).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)}}
                    Spacer()
                }
            }
            if let eta=activity.eta {Text(text("Tiempo restante informado")+": ~"+String(Int(eta))+" s").font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted)}
        }.padding(16).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:12))
    }
}


struct LibraryPrimaryButtonStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {EasyPrimaryStyle().makeBody(configuration:configuration)}
}

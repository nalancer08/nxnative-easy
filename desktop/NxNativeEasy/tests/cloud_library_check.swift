import Foundation

private enum Failure:Error {case check(String)}
private func require(_ ok:Bool,_ message:String)throws {if !ok {throw Failure.check(message)}}
@MainActor private func until(_ check:()->Bool)async throws {
    for _ in 0..<300 {if check(){return};try await Task.sleep(nanoseconds:10_000_000)}
    throw Failure.check("async timeout")
}
@main private struct Check {
    @MainActor static func main()async {
        do {try await run();print("cloud library: merge, isolated metadata, offline recovery, scoped device monitoring and title guards passed")}
        catch {fputs("cloud library failed: \(error)\n",stderr);exit(1)}
    }
    @MainActor private static func run()async throws {
        let fm=FileManager.default,root=fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at:root,withIntermediateDirectories:true);defer{try? fm.removeItem(at:root)}
        let suite="nxnative.cloud-library.tests."+UUID().uuidString,defaults=UserDefaults(suiteName:suite)!
        defer{defaults.removePersistentDomain(forName:suite)}
        let title="010093801237C000",remote="010015100B514000"
        var mac=OwnedGameOutput(item:OwnedGame(id:"mac",folder:root.appendingPathComponent("Mac").path,added:Date()))
        mac.titleID=title;mac.macApp=root.appendingPathComponent("synthetic.app")
        var ios=OwnedGameOutput(item:OwnedGame(id:"ios",folder:root.appendingPathComponent("Phone").path,added:Date()))
        ios.titleID=title;ios.iosIPA=root.appendingPathComponent("synthetic.ipa")
        let revision=SaveRevision(id:String(repeating:"a",count:64),title:remote,path:"/not-an-active-save",device:"Old iPhone",version:"1",date:2)
        let observation=DeviceGameObservation(device:"TEST",deviceName:"Test iPad",bundleID:"org.nxnative."+title.lowercased(),titleID:title,version:"1",checkedAt:nil)
        let entries=LibraryEntry.merge(local:[mac,ios],revisions:[revision],known:["invalid",remote],installed:[observation])
        try require(entries.count==2,"merge must group a title across platforms")
        let combined=entries.first{$0.titleID==title}!,cloud=entries.first{$0.titleID==remote}!
        try require(combined.sources.count==2 && combined.mac?.id=="mac" && combined.ios?.id=="ios","keep both platform sources")
        try require(cloud.sources.isEmpty && cloud.local==nil && cloud.knownInCloud && cloud.revisions.count==1,"cloud save is not a local installation")
        try require(LibraryEntry.merge(local:[],revisions:[],installed:[observation]).first?.sources.isEmpty==true,"known device evidence must not invent files")

        let repo=root.appendingPathComponent("repo"),scripts=repo.appendingPathComponent("scripts")
        try fm.createDirectory(at:scripts,withIntermediateDirectories:true)
        try #"""
        import json,sys,time,os
        r=json.load(sys.stdin);folder=r['cloud']
        if folder.endswith('slow'):time.sleep(.3)
        title='010015100B514000' if folder.endswith('slow') else '010093801237C000'
        token='a'*64
        print(json.dumps({'ok':True,'result':{'revisions':[{'id':token,'title':title,'path':folder+'/nxnative-saves-v1/'+title+'/'+token+'.nxsave','device':'Synthetic iPad','version':'1','date':1}],'invalid':0,'pending':0}}))
        """#.write(to:scripts.appendingPathComponent("save_transfer.py"),atomically:true,encoding:.utf8)
        let slow=root.appendingPathComponent("slow"),fast=root.appendingPathComponent("fast")
        for folder in [slow,fast] {try fm.createDirectory(at:folder,withIntermediateDirectories:true)}
        let saves=SaveCenterModel(defaults:defaults,isCloudLocation:{_ in false})
        saves.connectCloud(folder:slow,repo:repo);saves.connectCloud(folder:fast,repo:repo)
        try await until{!saves.scanning && saves.cloudCheckedAt != nil}
        try await Task.sleep(nanoseconds:400_000_000)
        try require(saves.cloud==fast && saves.knownCloudTitles==[title] && saves.revisions.first?.title==title,"stale folder response must not replace the selected account")
        try require(!saves.usesICloud && !saves.busy,"local provider never claims iCloud or blocks browsing")
        let cached=SaveCenterModel(defaults:defaults,isCloudLocation:{_ in false});cached.restoreFolder()
        try require(cached.revisions.count==1 && cached.knownCloudTitles==[title],"cached library before network: revisions=\(cached.revisions.count) titles=\(cached.knownCloudTitles) folder=\(String(describing:cached.cloud)) cache=\(defaults.data(forKey:"cloudLibrary.cache.v1")?.count ?? 0)")
        let moved=root.appendingPathComponent("unavailable");try fm.moveItem(at:fast,to:moved)
        saves.refresh(repo:repo,force:false);try await until{!saves.scanning}
        try require(saves.cloudIssue != nil && saves.revisions.count==1,"offline cloud must preserve last known library")
        try fm.moveItem(at:moved,to:fast);saves.refresh(repo:repo,force:false);try await until{!saves.scanning}
        try require(saves.cloudIssue==nil && saves.revisions.count==1,"same folder stamp after reconnect must clear offline state")
        saves.disconnectCloud();try require(saves.revisions.isEmpty && saves.knownCloudTitles.isEmpty && defaults.data(forKey:"cloudLibrary.cache.v1")==nil,"disconnect clears only metadata")
        try require(fm.fileExists(atPath:fast.path),"disconnect must not remove files")

        let helper=root.appendingPathComponent("helper.py")
        try #"""
        #!/usr/bin/python3
        import json,sys,os
        root=os.path.dirname(__file__)
        cap=[] if os.path.exists(root+'/old') else ['scoped-games-v1']
        print(json.dumps({'event':'hello','protocol':1,'capabilities':cap}),flush=True)
        for line in sys.stdin:
            r=json.loads(line)
            with open(root+'/audit','a') as f:f.write(json.dumps(r)+'\n')
            if r['op']=='devices':
                items=[] if os.path.exists(root+'/unplugged') else [{'udid':'TEST','name':'Test iPad','connections':['USB'],'model':'iPad-test','os':'26'},{'udid':'TEST','name':'Test iPad','connections':['Wi-Fi'],'model':'iPad-test','os':'26'}]
                print(json.dumps({'event':'devices','items':items}),flush=True)
            elif r['op']=='installed_apps':
                items=[] if os.path.exists(root+'/absent') else [{'id':'org.nxnative.010093801237c000.ABCDE12345','name':'Test game','version':'1','save_continuity':2},{'id':'com.private.unrelated','name':'Private'}]
                print(json.dumps({'event':'installed_apps','items':items}),flush=True)
        """#.write(to:helper,atomically:true,encoding:.utf8)
        try fm.setAttributes([.posixPermissions:0o700],ofItemAtPath:helper.path)
        let sideload=SideloadModel(stateURL:root.appendingPathComponent("jobs.json"),defaults:defaults,helperURL:helper)
        sideload.preparedIdentifiers=["org.nxnative."+title.lowercased()]
        sideload.busy=true;sideload.codeRequired=true;sideload.email="synthetic@example.invalid"
        await sideload.refreshConnections()
        try require(sideload.devices.count==1 && sideload.deviceGames.count==1,"deduplicate transports and filter unrelated apps")
        try require(sideload.deviceGames[0].saveContinuity==2 && sideload.isVerified(sideload.deviceGames[0]),"marker and current query evidence retained")
        try require(sideload.busy && sideload.codeRequired && !sideload.blocksGameWork,"read-only connection monitoring must not disturb login or block games")
        try Data().write(to:root.appendingPathComponent("unplugged"));await sideload.refreshConnections()
        try require(sideload.devices.isEmpty && sideload.deviceGames.count==1 && !sideload.isVerified(sideload.deviceGames[0]),"unplug preserves historical evidence only")
        try fm.removeItem(at:root.appendingPathComponent("unplugged"));try Data().write(to:root.appendingPathComponent("absent"));sideload.invalidateGameQueries();await sideload.refreshConnections()
        try require(sideload.deviceGames.isEmpty && sideload.hasCheckedGames("TEST"),"fresh absence overrides history")
        try Data().write(to:root.appendingPathComponent("old"));sideload.invalidateGameQueries();await sideload.refreshConnections()
        try require(!sideload.hasCheckedGames("TEST"),"old helper cannot make a broad installed-app query")
        let audit=try String(contentsOf:root.appendingPathComponent("audit"),encoding:.utf8).split(separator:"\n").map{try JSONSerialization.jsonObject(with:Data($0.utf8)) as! [String:Any]}
        try require(audit.allSatisfy{["devices","installed_apps"].contains($0["op"] as? String ?? "")},"monitor must never send auth, install or save commands")
        try require(audit.filter{$0["op"] as? String=="installed_apps"}.count==2,"capability guard must refuse old helper before sending app query")
        let missing=SideloadModel(stateURL:root.appendingPathComponent("missing.json"),defaults:defaults,helperURL:root.appendingPathComponent("missing-helper"));await missing.refreshConnections()
        try require(missing.connectionIssue && !missing.checkingDevices,"missing helper must finish without deadlock")

        let build=BuildModel(defaults:defaults,sourceRepo:repo);build.expectedLibraryTitleID=title
        try require(!build.matchesExpectedGame,"cloud-origin add must require matching identification")
        build.build();try require(!build.running,"unmatched title must not compile")
        build.expectedLibraryTitleID=nil;try require(build.matchesExpectedGame,"generic add is still available")
    }
}

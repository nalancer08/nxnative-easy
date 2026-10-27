import Foundation

@main struct SideloadCheck {
    @MainActor static func main() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:root)}
        let suite="nxnative.tests.sideload."+UUID().uuidString
        let defaults=UserDefaults(suiteName:suite)!
        defer {defaults.removePersistentDomain(forName:suite)}
        let helper=root.appendingPathComponent("helper")
        try """
        #!/usr/bin/python3
        import sys,json,time
        def emit(value):print(json.dumps(value),flush=True)
        emit({'event':'hello','protocol':1,'architecture':'aarch64','capabilities':['scoped-games-v1']})
        for line in sys.stdin:
            value=json.loads(line)
            if value['op']=='devices':emit({'event':'devices','items':[{'udid':'SYNTHETIC-DEVICE','name':'Test iPad','model':'iPad-test','os':'26.0','connections':['Wi-Fi']},{'udid':'SYNTHETIC-DEVICE','name':'Test iPad','model':'iPad-test','os':'26.0','connections':['USB','Wi-Fi']}]})
            elif value['op']=='installed_apps':
                assert value.get('original_ids') and 'known_ids' in value
                emit({'event':'installed_apps','items':[{'id':'org.game.custom','name':'Test game'},{'id':'com.unrelated.private','name':'Test game'},{'id':'org.game.customevil','name':'Test game'}]})
            elif value['op']=='login':
                assert value['password']=='synthetic-password-only'
                emit({'event':'two_factor'})
            elif value['op']=='code':
                assert value['code']=='123456'
                emit({'event':'signed_in','teams':[{'id':'ABCDE12345','name':'Personal test team'}]})
            elif value['op']=='restore':emit({'event':'signed_in','teams':[{'id':'ABCDE12345','name':'Personal test team'}]})
            elif value['op']=='install':
                assert value['automatic']==False and value['update']==True
                assert value['expected_id']=='org.game.custom'
                assert value['sha256']=='a'*64 and 'romfs' not in value
                emit({'event':'installed','effective_id':value['expected_id'],'expires':time.time()+86400,'sha256':'a'*64})
            elif value['op']=='account_devices':
                assert value['team']=='ABCDE12345'
                emit({'event':'account_devices','team':value['team'],'items':[{'udid':'REGISTERED-DEVICE','name':'Synthetic iPhone','status':'a'}]})
            elif value['op']=='logout':emit({'event':'signed_out'})
            elif value['op']=='quit':break
        """.write(to:helper,atomically:true,encoding:.utf8)
        try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:helper.path)
        let missing=SideloadModel(stateURL:root.appendingPathComponent("missing-jobs.json"),defaults:defaults,helperURL:root.appendingPathComponent("missing-helper"));missing.listDevices();assert(!missing.busy && missing.error != nil)
        let emptyScope=SideloadModel(stateURL:root.appendingPathComponent("empty-scope.json"),defaults:defaults,helperURL:helper)
        emptyScope.listDevices();try await wait {!emptyScope.busy && emptyScope.devices.count==1};assert(emptyScope.apps.isEmpty);emptyScope.cancel()
        let model=SideloadModel(stateURL:root.appendingPathComponent("jobs.json"),defaults:defaults,helperURL:helper)
        model.preparedIdentifiers=["org.game.custom"]
        model.listDevices();try await wait { !model.busy && model.apps.count==1 }
        assert(model.device=="SYNTHETIC-DEVICE" && model.devices.count==1 && model.devices[0].model=="iPad-test" && model.devices[0].connections.contains("USB"))
        model.email=" TEST@example.org ";model.signIn(password:"synthetic-password-only",remember:false)
        try await wait {model.codeRequired};assert(model.busy && !model.authenticated)
        model.submitCode("123456");try await wait {model.authenticated && !model.busy}
        assert(model.email=="test@example.org" && model.teams.count==1 && model.team.isEmpty)
        assert(defaults.string(forKey:"sideloadEmail")==nil)
        model.inspectAccountDevices();assert(!model.busy && model.accountDevices.isEmpty)
        model.team="ABCDE12345";model.inspectAccountDevices();try await wait {!model.busy && model.accountDevices.count==1}
        assert(model.accountDeviceTeam==model.team)
        assert(!model.logs.map(\.message).joined().contains("synthetic-password-only"))
        assert(!model.logs.map(\.message).joined().contains("123456"))
        assert(!model.logs.map(\.message).joined().contains("test@example.org"))
        model.signOut();try await wait {!model.authenticated};model.cancel()
        let scope=GameAppScope(originals:["org.nxnative.010093801237c000"],known:["org.old.custom"])
        assert(scope.permits("org.nxnative.010093801237c000.ABCDE12345"))
        assert(scope.permits("org.old.custom"))
        for unrelated in ["com.private.app","org.nxnative.010093801237c000evil","org.nxnative.010093801237c000.news","org.nxnative.01007ef00011e000.ABCDE12345","org.nxnative.010093801237c000.ABCDE12345.extra"] {assert(!scope.permits(unrelated))}
        assert(!GameAppScope().permits("org.nxnative.010093801237c000"))
        let now=Date();var job=RefreshJob(id:"test",ipa:"/synthetic.ipa",gameFolder:root.path,originalID:"org.game",effectiveID:"org.game.custom",team:"ABCDE12345",udid:"test",account:RefreshPolicy.account("Test@Example.org"),sha256:"test",expires:now.addingTimeInterval(24*3600),enabled:true)
        assert(RefreshPolicy.due(job,now:now,account:RefreshPolicy.account("test@example.org")))
        assert(!RefreshPolicy.due(job,now:now,account:"another-account"))
        job.retryAfter=now.addingTimeInterval(3600);assert(!RefreshPolicy.due(job,now:now,account:job.account))
        job.retryAfter=nil;job.needsLogin=true;assert(!RefreshPolicy.due(job,now:now,account:job.account))
        assert(RefreshPolicy.identity(original:"org.game",team:"ABCDE12345",existing:"org.old.custom")=="org.old.custom")
        assert(RefreshPolicy.identity(original:"org.game",team:"bad",existing:"")==nil)
        assert(RefreshPolicy.identity(original:"org.game",team:"ABCDE12345",existing:"../save")==nil)
        let folder=root.appendingPathComponent("game");try FileManager.default.createDirectory(at:folder.appendingPathComponent("010093801237c000_build"),withIntermediateDirectories:true)
        assert(SaveLocations.titleID(folder:folder)=="010093801237C000")
        assert(SaveLocations.macRoot(titleID:"010093801237C000").path.hasSuffix("Library/Application Support/nxnative/010093801237C000"))
        let ipa=root.appendingPathComponent("Test game.ipa");try Data("synthetic-only".utf8).write(to:ipa)
        job.id="SYNTHETIC-DEVICE:org.game.custom";job.ipa=ipa.path;job.udid="SYNTHETIC-DEVICE";job.sha256=String(repeating:"a",count:64);job.needsLogin=false;job.enabled=false
        var second=job;second.id="SECOND-DEVICE:org.other";second.udid="SECOND-DEVICE";second.originalID="org.other";second.effectiveID="org.other"
        model.jobs=[job,second]
        model.setRefresh(job,enabled:true);assert(model.jobs[0].enabled)
        model.setRefresh(job,enabled:false);assert(!model.jobs[0].enabled)
        let reloaded=SideloadModel(stateURL:root.appendingPathComponent("jobs.json"),defaults:defaults,helperURL:helper)
        assert(reloaded.jobs.count==2 && !reloaded.jobs[0].enabled)
        model.email="different@example.org";model.renew(job);assert(!model.busy && model.error != nil)
        model.email="test@example.org";defaults.set(model.email,forKey:"sideloadEmail")
        model.restoreSession();try await wait {model.authenticated && !model.busy}
        model.renew(job);try await wait {!model.busy && model.jobs.first(where:{$0.id==job.id})?.expires != job.expires}
        assert(model.error==nil && model.jobs.count==2 && !model.jobs.first(where:{$0.id==job.id})!.enabled && model.jobs.first(where:{$0.id==job.id})!.sha256==job.sha256)
        model.forget(job);assert(model.jobs.count==1 && model.jobs[0].id==second.id && FileManager.default.fileExists(atPath:ipa.path))
        let empty=SideloadModel(stateURL:root.appendingPathComponent("jobs.json"),defaults:defaults,helperURL:helper);assert(empty.jobs.count==1 && empty.jobs[0].id==second.id)
        let lightweight=root.appendingPathComponent("light");try FileManager.default.createDirectory(at:lightweight,withIntermediateDirectories:true)
        try Data("synthetic-ipa".utf8).write(to:lightweight.appendingPathComponent("test.ipa"))
        let packaging:[String:Any]=["full_ipa":ipa.path,"light_dir":lightweight.path,"packaging":"full"]
        assert(IOSPackageOutput.load(record:packaging,split:false)?.ipa==ipa)
        assert(IOSPackageOutput.load(record:packaging,split:false)?.romfs==nil)
        assert(IOSPackageOutput.load(record:packaging,split:true)?.romfs==lightweight.appendingPathComponent("romfs"))
        assert(IOSPackageOutput.load(record:["full_ipa":ipa.path],split:false)==nil)
        try JSONSerialization.data(withJSONObject:["schema":1,"bundle_id":"org.game"]).write(to:folder.appendingPathComponent("nxnative-ios.json"))
        let selected=InstalledGame(id:"org.game.custom",name:"Test game")
        model.prepareUpdate(selected);model.configure(ipa:ipa,folder:folder,romfs:nil)
        try await wait {!model.busy && model.apps.count==1}
        assert(model.existing==selected.id && model.device=="SYNTHETIC-DEVICE")
        assert(model.logURL != nil)
        let permissions=try FileManager.default.attributesOfItem(atPath:model.logURL!.path)[.posixPermissions] as! NSNumber
        assert(permissions.intValue==0o600)
        model.cancel()
        print("Sideload client PASS: multi-game persistence, explicit manual refresh with original identity/hash and no RomFS recopy, account guard, metadata-only removal; private stdio login/2FA, explicit team selection, logout, refresh account/expiry/backoff guards, custom update identity and save-location mapping")
    }
    @MainActor static func wait(_ condition:()->Bool) async throws {
        let end=Date().addingTimeInterval(5)
        while !condition() {assert(Date()<end,"mock protocol timed out");try await Task.sleep(nanoseconds:20_000_000)}
    }
}

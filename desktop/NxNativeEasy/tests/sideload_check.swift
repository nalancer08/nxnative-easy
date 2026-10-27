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
        import sys,json,time,zipfile,os
        def emit(value):print(json.dumps(value),flush=True)
        emit({'event':'hello','protocol':1,'architecture':'aarch64','capabilities':['scoped-games-v1','save-export-v1','romfs-copy-v1','registration-consent-v1']})
        for line in sys.stdin:
            value=json.loads(line)
            with open(os.path.join(os.path.dirname(__file__),'operations.log'),'a') as audit:audit.write(value['op']+'\\n')
            if value['op']=='devices':emit({'event':'devices','items':[{'udid':'SYNTHETIC-DEVICE','name':'Test iPad','model':'iPad-test','os':'26.0','connections':['Wi-Fi']},{'udid':'SYNTHETIC-DEVICE','name':'Test iPad','model':'iPad-test','os':'26.0','connections':['USB','Wi-Fi']}]})
            elif value['op']=='installed_apps':
                assert value.get('original_ids') and 'known_ids' in value
                emit({'event':'installed_apps','items':[{'id':'org.game.custom','name':'Test game','version':'2.1.0'},{'id':'com.unrelated.private','name':'Test game'},{'id':'org.game.customevil','name':'Test game'}]})
            elif value['op']=='login':
                assert value['password']=='synthetic-password-only'
                emit({'event':'two_factor'})
            elif value['op']=='code':
                assert value['code']=='123456'
                emit({'event':'signed_in','teams':[{'id':'ABCDE12345','name':'Personal test team'}]})
            elif value['op']=='restore':
                if value['email']=='unavailable@example.invalid':emit({'event':'error','operation':'restore','code':'failed'})
                else:emit({'event':'signed_in','teams':[{'id':'ABCDE12345','name':'Personal test team'}]})
            elif value['op']=='install':
                assert value['automatic']==False and value['update']==True
                assert value.get('approve_registration') in (False,True)
                if value['approve_registration']:
                    assert value['udid']=='SYNTHETIC-DEVICE' and value['team']=='ABCDE12345'
                    emit({'event':'device_registered','team':value['team'],'udid':value['udid']})
                assert value['expected_id']=='org.game.custom'
                assert 'romfs' not in value
                if not value.get('app_only'):assert value['sha256']=='a'*64
                emit({'event':'installed','effective_id':value['expected_id'],'expires':time.time()+86400,'sha256':'a'*64})
            elif value['op']=='export_saves':
                assert value['effective_id']=='org.game.custom' and value['confirmed_closed']==True
                with zipfile.ZipFile(value['destination'],'x') as z:z.writestr('save/progress.bin',b'synthetic progress')
                os.chmod(value['destination'],0o600)
                emit({'event':'saves_exported','path':value['destination'],'files':1,'bytes':18})
            elif value['op']=='copy_romfs':
                assert value['effective_id']=='org.game.custom' and value['game_version']=='2.1.0' and value['confirmed_closed']==True
                emit({'event':'content_copied','effective_id':value['effective_id']})
            elif value['op']=='account_devices':
                assert value['team']=='ABCDE12345'
                emit({'event':'account_devices','team':value['team'],'free_device_limit':3,'items':[{'udid':'REGISTERED-DEVICE','name':'Synthetic iPhone','status':'a'}]})
            elif value['op']=='logout':emit({'event':'signed_out'})
            elif value['op']=='quit':break
        """.write(to:helper,atomically:true,encoding:.utf8)
        try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:helper.path)
        let recoverySuite=suite+".recovery",recoveryDefaults:UserDefaults
        recoveryDefaults=UserDefaults(suiteName:recoverySuite)!
        defer {recoveryDefaults.removePersistentDomain(forName:recoverySuite)}
        func restoredCount()->Int {
            let operations=(try? String(contentsOf:root.appendingPathComponent("operations.log"),encoding:.utf8)) ?? ""
            return operations.split(separator:"\n").filter{$0=="restore"}.count
        }
        let noSaved=SideloadModel(stateURL:root.appendingPathComponent("recovery/no-saved.json"),defaults:recoveryDefaults,helperURL:helper)
        noSaved.recoverRememberedSessionIfNeeded();assert(!noSaved.busy && !noSaved.authenticated && restoredCount()==0)
        recoveryDefaults.set("saved@example.invalid",forKey:"sideloadEmail")
        let saved=SideloadModel(stateURL:root.appendingPathComponent("recovery/saved.json"),defaults:recoveryDefaults,helperURL:helper)
        saved.recoverRememberedSessionIfNeeded();saved.recoverRememberedSessionIfNeeded()
        try await wait {saved.authenticated && !saved.busy}
        assert(restoredCount()==1 && !saved.recoveringSession && saved.jobs.isEmpty && saved.team.isEmpty)
        saved.team="ABCDE12345";saved.cancel()
        let restarted=SideloadModel(stateURL:root.appendingPathComponent("recovery/restarted.json"),defaults:recoveryDefaults,helperURL:helper)
        restarted.preparedIdentifiers=["org.game.custom"];restarted.listDevices();restarted.recoverRememberedSessionIfNeeded()
        try await wait {restarted.authenticated && !restarted.busy && restarted.apps.count==1}
        assert(restoredCount()==2 && restarted.team=="ABCDE12345" && restarted.jobs.isEmpty)
        restarted.signOut();try await wait {!restarted.authenticated};assert(recoveryDefaults.string(forKey:"sideloadEmail")==nil)
        restarted.recoverRememberedSessionIfNeeded();assert(!restarted.busy && restoredCount()==2);restarted.cancel()
        recoveryDefaults.set("unavailable@example.invalid",forKey:"sideloadEmail")
        let unavailable=SideloadModel(stateURL:root.appendingPathComponent("recovery/unavailable.json"),defaults:recoveryDefaults,helperURL:helper)
        unavailable.recoverRememberedSessionIfNeeded();try await wait {!unavailable.busy && unavailable.error != nil}
        assert(restoredCount()==3 && unavailable.hasRememberedSession && !unavailable.recoveringSession)
        unavailable.recoverRememberedSessionIfNeeded();try await Task.sleep(nanoseconds:50_000_000);assert(restoredCount()==3)
        unavailable.restoreSession();try await wait {!unavailable.busy};assert(restoredCount()==4 && unavailable.hasRememberedSession);unavailable.cancel()
        let unavailableHelper=SideloadModel(stateURL:root.appendingPathComponent("recovery/missing.json"),defaults:recoveryDefaults,helperURL:root.appendingPathComponent("missing-helper"))
        unavailableHelper.recoverRememberedSessionIfNeeded();assert(!unavailableHelper.busy && !unavailableHelper.recoveringSession && unavailableHelper.hasRememberedSession)
        let recoveryOperations=try String(contentsOf:root.appendingPathComponent("operations.log"),encoding:.utf8)
        assert(!recoveryOperations.split(separator:"\n").contains("install") && !recoveryOperations.split(separator:"\n").contains("login"))
        recoveryDefaults.set("saved@example.invalid",forKey:"sideloadEmail")
        let cancelledLogin=SideloadModel(stateURL:root.appendingPathComponent("recovery/cancelled-login.json"),defaults:recoveryDefaults,helperURL:helper)
        cancelledLogin.signIn(password:"synthetic-password-only",remember:false);try await wait {cancelledLogin.codeRequired}
        cancelledLogin.cancel();try await wait {!cancelledLogin.busy}
        cancelledLogin.restoreSession();try await wait {cancelledLogin.authenticated && !cancelledLogin.busy}
        assert(cancelledLogin.hasRememberedSession && recoveryDefaults.string(forKey:"sideloadEmail")=="saved@example.invalid")
        cancelledLogin.cancel()
        let missing=SideloadModel(stateURL:root.appendingPathComponent("missing-jobs.json"),defaults:defaults,helperURL:root.appendingPathComponent("missing-helper"));missing.listDevices();assert(!missing.busy && missing.error != nil)
        let emptyScope=SideloadModel(stateURL:root.appendingPathComponent("empty-scope.json"),defaults:defaults,helperURL:helper)
        emptyScope.listDevices();try await wait {!emptyScope.busy && emptyScope.devices.count==1};assert(emptyScope.apps.isEmpty);emptyScope.cancel()
        let model=SideloadModel(stateURL:root.appendingPathComponent("jobs.json"),defaults:defaults,helperURL:helper)
        model.preparedIdentifiers=["org.game.custom"]
        model.listDevices();try await wait { !model.busy && model.apps.count==1 }
        assert(model.device=="SYNTHETIC-DEVICE" && model.devices.count==1 && model.devices[0].model=="iPad-test" && model.devices[0].connections.contains("USB"))
        assert(model.deviceGames.count==1 && model.deviceGames[0].bundleID=="org.game.custom" && model.isVerified(model.deviceGames[0]))
        let cached=SideloadModel(stateURL:root.appendingPathComponent("cached-jobs.json"),defaults:defaults,helperURL:root.appendingPathComponent("missing-helper"))
        assert(cached.deviceGames.count==1 && !cached.isVerified(cached.deviceGames[0]))
        assert(cached.observations(titleID:nil,originalID:"org.game.custom").count==1)
        assert(cached.observations(titleID:"OTHER",originalID:"org.other").isEmpty)
        let cacheData=try String(contentsOf:root.appendingPathComponent("device-games.json"),encoding:.utf8)
        assert(!cacheData.contains("com.unrelated.private") && !cacheData.contains("customevil"))
        model.email=" TEST@example.org ";model.signIn(password:"synthetic-password-only",remember:false)
        try await wait {model.codeRequired};assert(model.busy && !model.authenticated)
        model.submitCode("123456");try await wait {model.authenticated && !model.busy}
        assert(model.email=="test@example.org" && model.teams.count==1 && model.team.isEmpty)
        assert(defaults.string(forKey:"sideloadEmail")==nil)
        model.inspectAccountDevices();assert(!model.busy && model.accountDevices.isEmpty)
        model.team="ABCDE12345";model.inspectAccountDevices();try await wait {!model.busy && model.accountDevices.count==1}
        assert(model.accountDeviceTeam==model.team && model.estimatedDeviceSlots==2)
        assert(model.registrationState == .new)
        let registered=[AccountDevice(id:"PHONE",name:"Test",status:"c"),AccountDevice(id:"phone",name:"duplicate",status:"c")]
        assert(AccountRegistrationPolicy.remaining(limit:3,devices:registered)==2)
        assert(AccountRegistrationPolicy.remaining(limit:nil,devices:registered)==nil)
        assert(AccountRegistrationPolicy.state(team:"A",loadedTeam:"A",checkedAt:Date(),device:"phone",devices:registered) == .registered)
        assert(AccountRegistrationPolicy.state(team:"B",loadedTeam:"A",checkedAt:Date(),device:"phone",devices:registered) == .unknown)
        assert(AccountRegistrationPolicy.state(team:"A",loadedTeam:"A",checkedAt:Date().addingTimeInterval(-301),device:"phone",devices:registered) == .unknown)
        assert(AccountRegistrationPolicy.remaining(limit:3,devices:(0..<4).map {AccountDevice(id:String($0),name:"Test",status:"c")})==0)
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
        try FileManager.default.createDirectory(at:lightweight.appendingPathComponent("romfs"),withIntermediateDirectories:true)
        try JSONSerialization.data(withJSONObject:["schema":1,"bundle_id":"org.game","version":"2.1.0","light_dir":lightweight.path]).write(to:folder.appendingPathComponent("nxnative-ios.json"))
        let selected=InstalledGame(id:"org.game.custom",name:"Test game",version:"2.1.0")
        model.prepareUpdate(selected);model.configure(ipa:ipa,folder:folder,romfs:nil)
        try await wait {!model.busy && model.apps.count==1}
        assert(model.existing==selected.id && model.device=="SYNTHETIC-DEVICE")
        assert(model.logURL != nil)
        let permissions=try FileManager.default.attributesOfItem(atPath:model.logURL!.path)[.posixPermissions] as! NSNumber
        assert(permissions.intValue==0o600)
        model.preparedFolders=["010093801237C000":folder];model.romfs=lightweight.appendingPathComponent("romfs")
        assert(model.titleID(for:InstalledGame(id:"org.nxnative.010093801237c000.ABCDE12345",name:"Metroid"))=="010093801237C000")
        assert(model.dataFolder(for:selected)?.path==model.romfs?.path)
        assert(model.canUpdateAppOnly)
        model.install(autoRefresh:false,includeContent:false);try await wait {!model.busy}
        model.inspectAccountDevices();try await wait {!model.busy};assert(model.estimatedDeviceSlots==2)
        model.install(autoRefresh:false,includeContent:false,approveRegistration:true);try await wait {!model.busy};assert(model.error==nil)
        assert(model.estimatedDeviceSlots==1 && model.registrationState == .registered)
        let backup=root.appendingPathComponent("progress.zip")
        model.exportSaves(selected,destination:backup,confirmedClosed:true);try await wait {!model.busy && model.exportedSaves != nil};assert(model.exportedSaves==backup)
        model.copyData(selected,confirmedClosed:true);try await wait {!model.busy};assert(model.fraction==1 && model.error==nil)
        model.copyData(InstalledGame(id:selected.id,name:selected.name,version:"9.0"),confirmedClosed:true);assert(!model.busy && model.error != nil)
        let unrelated=root.appendingPathComponent("unrelated.zip")
        model.exportSaves(InstalledGame(id:"com.unrelated.private",name:selected.name),destination:unrelated,confirmedClosed:true);assert(!FileManager.default.fileExists(atPath:unrelated.path))
        model.cancel()
        print("Sideload client PASS: multi-game persistence, explicit manual refresh with original identity/hash and no RomFS recopy, account guard, metadata-only removal; private stdio login/2FA, explicit team selection, logout, refresh account/expiry/backoff guards, custom update identity and save-location mapping")
    }
    @MainActor static func wait(_ condition:()->Bool) async throws {
        let end=Date().addingTimeInterval(5)
        while !condition() {assert(Date()<end,"mock protocol timed out");try await Task.sleep(nanoseconds:20_000_000)}
    }
}

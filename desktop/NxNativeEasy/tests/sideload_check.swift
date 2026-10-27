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
        import sys,json
        def emit(value):print(json.dumps(value),flush=True)
        emit({'event':'hello','protocol':1,'architecture':'aarch64'})
        for line in sys.stdin:
            value=json.loads(line)
            if value['op']=='devices':emit({'event':'devices','items':[{'udid':'SYNTHETIC-DEVICE','name':'Test iPad'}]})
            elif value['op']=='installed_apps':emit({'event':'installed_apps','items':[{'id':'org.game.custom','name':'Test game'}]})
            elif value['op']=='login':
                assert value['password']=='synthetic-password-only'
                emit({'event':'two_factor'})
            elif value['op']=='code':
                assert value['code']=='123456'
                emit({'event':'signed_in','teams':[{'id':'ABCDE12345','name':'Personal test team'}]})
            elif value['op']=='logout':emit({'event':'signed_out'})
            elif value['op']=='quit':break
        """.write(to:helper,atomically:true,encoding:.utf8)
        try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:helper.path)
        let missing=SideloadModel(stateURL:root.appendingPathComponent("missing-jobs.json"),defaults:defaults,helperURL:root.appendingPathComponent("missing-helper"));missing.listDevices();assert(!missing.busy && missing.error != nil)
        let model=SideloadModel(stateURL:root.appendingPathComponent("jobs.json"),defaults:defaults,helperURL:helper)
        model.listDevices();try await wait { !model.busy && model.apps.count==1 }
        assert(model.device=="SYNTHETIC-DEVICE")
        model.email=" TEST@example.org ";model.signIn(password:"synthetic-password-only",remember:false)
        try await wait {model.codeRequired};assert(model.busy && !model.authenticated)
        model.submitCode("123456");try await wait {model.authenticated && !model.busy}
        assert(model.email=="test@example.org" && model.teams.count==1 && model.team.isEmpty)
        assert(defaults.string(forKey:"sideloadEmail")==nil)
        model.signOut();try await wait {!model.authenticated};model.cancel()
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
        print("Sideload client PASS: private stdio login/2FA, explicit team selection, logout, refresh account/expiry/backoff guards, custom update identity and save-location mapping")
    }
    @MainActor static func wait(_ condition:()->Bool) async throws {
        let end=Date().addingTimeInterval(5)
        while !condition() {assert(Date()<end,"mock protocol timed out");try await Task.sleep(nanoseconds:20_000_000)}
    }
}

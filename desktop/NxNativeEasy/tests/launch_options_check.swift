import Foundation
@main struct CheckOptions {
 @MainActor static func main() throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".app")
  defer {try? FileManager.default.removeItem(at:root)}
  let res=root.appendingPathComponent("Contents/Resources/dm");try FileManager.default.createDirectory(at:res,withIntermediateDirectories:true)
  let domain="org.nxnative.test."+UUID().uuidString
  let info:[String:Any]=["CFBundleIdentifier":domain]
  try PropertyListSerialization.data(fromPropertyList:info,format:.xml,options:0).write(to:root.appendingPathComponent("Contents/Info.plist"))
  let settings="""
  {"schema":1,"settings":[{"env":"DM_FPS_TARGET","kind":"choice","label":"Frame rate","default":"60","options":[["30","30 fps"],["60","60 fps"]]}, {"env":"DM_RUMBLE","kind":"toggle","label":"Rumble","default":"1"}, {"env":"DM_RUMBLE_GAIN","kind":"range","label":"Strength","default":"1.0","min":0,"max":3,"step":0.1,"needs":"DM_RUMBLE=1"}]}
  """
  try Data(settings.utf8).write(to:res.appendingPathComponent("launcher.json"))
  let model=GameLaunchOptions(app:root);assert(model.error==nil && model.rows.count==3)
  model.values["DM_FPS_TARGET"]="30";model.save()
  assert(GameLaunchOptions(app:root).values["DM_FPS_TARGET"]=="30")
  model.values["DM_FPS_TARGET"]="999";model.save();assert(GameLaunchOptions(app:root).values["DM_FPS_TARGET"]=="30")
  model.values["DM_RUMBLE"]="0";assert(!model.visible(model.rows[2]))
  model.reset();assert(CFPreferencesCopyAppValue("launcher.DM_FPS_TARGET" as CFString,domain as CFString)==nil)
  assert(model.rows[2].permits("nan")==false)
  print("Launch options: real schema pairs, validation, shared preferences, default removal and dependent rows passed")
 }
}

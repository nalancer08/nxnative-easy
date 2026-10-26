import Foundation

@main struct LocalizationCheck {
    static func main() {
        let suite="nxnative.easy.localization.tests."+UUID().uuidString
        let d=UserDefaults(suiteName:suite)!
        defer {d.removePersistentDomain(forName:suite)}
        assert(EasyLanguage.load(defaults:d) == .english)
        EasyLanguage.spanish.save(defaults:d)
        assert(EasyLanguage.load(defaults:UserDefaults(suiteName:suite)!) == .spanish)
        EasyLanguage.english.save(defaults:d)
        assert(EasyLanguage.load(defaults:d) == .english)
        d.set("unsupported",forKey:"interfaceLanguage")
        assert(EasyLanguage.load(defaults:d) == .english)
        assert(EasyStrings.text("Carpeta del juego",language:.english)=="Game folder")
        assert(EasyStrings.text("Carpeta del juego",language:.spanish)=="Carpeta del juego")
        assert(EasyStrings.text("Creando tu IPA ligera…",language:.english)=="Creating your lightweight IPA…")
        assert(EasyStrings.text("raw system error",language:.spanish)=="raw system error")
        for (spanish,english) in EasyStrings.english {
            assert(!spanish.isEmpty && !english.isEmpty)
            assert(EasyStrings.text(spanish,language:.spanish)==spanish)
            assert(EasyStrings.text(spanish,language:.english)==english)
        }
        print("Localization PASS: English default, persisted choice, invalid preference fallback, both languages and untranslated diagnostics")
    }
}

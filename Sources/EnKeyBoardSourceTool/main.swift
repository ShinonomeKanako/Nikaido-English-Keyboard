import Foundation
import Carbon
import InputSourceSupport

func check(_ status: OSStatus, operation: String) {
    guard status == noErr else {
        FileHandle.standardError.write(Data("\(operation) failed: \(status)\n".utf8)); exit(1)
    }
}
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1)
}
let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "--diagnose":
    if let current = InputSources.current() { print("Current: \(InputSources.id(current))") }
    for source in InputSources.list(includeDisabled: true) {
        let id = InputSources.id(source)
        guard InputSources.isOurs(id) || id.hasPrefix("com.tencent.inputmethod.wetype")
                || (id.hasPrefix("com.apple.keylayout.") && InputSources.boolean(source, kTISPropertyInputSourceIsEnabled)) else { continue }
        print("\(id) | \(InputSources.string(source, kTISPropertyLocalizedName)) | type=\(InputSources.string(source, kTISPropertyInputSourceType)) | enabled=\(InputSources.boolean(source, kTISPropertyInputSourceIsEnabled)) | selectable=\(InputSources.boolean(source, kTISPropertyInputSourceIsSelectCapable)) | enableCapable=\(InputSources.boolean(source, kTISPropertyInputSourceIsEnableCapable)) | ascii=\(InputSources.boolean(source, kTISPropertyInputSourceIsASCIICapable))")
        print("  primaryLanguage=\(InputSources.languages(source).first ?? "unknown")")
    }
    if let recent = TISCopyCurrentASCIICapableKeyboardInputSource()?.takeRetainedValue() {
        print("Recent ASCII source: \(InputSources.id(recent))")
    }
case "--snapshot":
    guard args.count == 2 else { exit(2) }
    let url = URL(fileURLWithPath: args[1])
    if !FileManager.default.fileExists(atPath: url.path) {
        do { try InstallationState().save(to: url) }
        catch { fail(error.localizedDescription) }
    }
case "--register":
    guard args.count == 2 else { exit(2) }
    check(TISRegisterInputSource(URL(fileURLWithPath: args[1]) as CFURL), operation: "Register")
    let own = InputSources.list(includeDisabled: true).filter { InputSources.isOurs(InputSources.id($0)) }
    guard !own.isEmpty else { fail("Registered; restart the login session if EnKeyBoard is not listed yet.") }
    guard let mode = own.first(where: { InputSources.id($0) == InputSources.completionID }) else {
        fail("New composition mode not registered; restart the login session before enabling EnKeyBoard.")
    }
    guard !InputSources.boolean(mode, kTISPropertyInputSourceIsASCIICapable) else {
        if let current = InputSources.current(), InputSources.isOurs(InputSources.id(current)),
           let native = InputSources.nativeEnglish() {
            check(TISSelectInputSource(native), operation: "Leave unsafe Latin mode")
        }
        for source in own where InputSources.boolean(source, kTISPropertyInputSourceIsEnabled)
            && InputSources.boolean(source, kTISPropertyInputSourceIsSelectCapable) {
            check(TISDisableInputSource(source), operation: "Disable unsafe EnKeyBoard mode")
        }
        fail("EnKeyBoard is still ASCII-capable; refusing to enable it as a replacement for ABC.")
    }
    let obsolete = own.filter {
        let id = InputSources.id($0)
        return id != InputSources.bundleID && id != InputSources.completionID
    }
    if let current = InputSources.current(), obsolete.contains(where: { InputSources.id($0) == InputSources.id(current) }) {
        guard let native = InputSources.nativeEnglish() else { fail("请先启用 ABC 并切离旧版 EnKeyBoard。") }
        check(TISSelectInputSource(native), operation: "Leave legacy EnKeyBoard")
    }
    for source in obsolete where InputSources.boolean(source, kTISPropertyInputSourceIsEnabled) {
        check(TISDisableInputSource(source), operation: "Disable legacy EnKeyBoard")
    }
    for source in own.filter({ InputSources.id($0) == InputSources.bundleID || InputSources.id($0) == InputSources.completionID })
        .sorted(by: { InputSources.id($0).count < InputSources.id($1).count }) {
        if InputSources.boolean(source, kTISPropertyInputSourceIsEnableCapable) {
            check(TISEnableInputSource(source), operation: "Enable EnKeyBoard")
        }
    }
    print("Enabled EnKeyBoard; existing input source selection is unchanged")
case "--select":
    guard args.count == 2, let source = InputSources.source(id: args[1]) else { fail("Source not found") }
    check(TISSelectInputSource(source), operation: "Select")
    print("Selected \(InputSources.id(source))")
case "--restore-and-disable", "--disable":
    if let current = InputSources.current(), InputSources.isOurs(InputSources.id(current)) {
        var fallback: TISInputSource?
        if args.count == 2, let data = try? Data(contentsOf: URL(fileURLWithPath: args[1])),
           let snapshot = try? JSONDecoder().decode(InstallationState.self, from: data),
           let originalID = snapshot.selectedSourceID, !InputSources.isOurs(originalID),
           let original = InputSources.source(id: originalID), InputSources.selectable(original) {
            fallback = original
        }
        fallback = fallback ?? InputSources.nativeEnglish()
            ?? InputSources.list().first { !InputSources.isOurs(InputSources.id($0)) && InputSources.selectable($0) }
        guard let fallback else { fail("请先手动切换到另一个输入源，再运行卸载。") }
        check(TISSelectInputSource(fallback), operation: "Restore input source")
    }
    let own = InputSources.list(includeDisabled: true).filter { InputSources.isOurs(InputSources.id($0)) }
    for source in own.sorted(by: { InputSources.id($0).count > InputSources.id($1).count })
        where InputSources.boolean(source, kTISPropertyInputSourceIsEnabled) {
        check(TISDisableInputSource(source), operation: "Disable EnKeyBoard")
    }
    print("Disabled only EnKeyBoard; other input sources and global keyboard settings preserved")
default:
    if let current = InputSources.current() { print("Current: \(InputSources.id(current))") }
    for source in InputSources.list(includeDisabled: true) where InputSources.isOurs(InputSources.id(source)) {
        print("EnKeyBoard source: \(InputSources.id(source)) · \(InputSources.string(source, kTISPropertyLocalizedName))")
    }
}

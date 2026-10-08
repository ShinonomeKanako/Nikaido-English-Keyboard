import Foundation
import Carbon

public enum InputSources {
    public static let bundleID = "com.shinonome.inputmethod.EnKeyBoard"
    public static func isOurs(_ id: String) -> Bool { id == bundleID || id.hasPrefix(bundleID + ".") }

    public static func string(_ source: TISInputSource, _ key: CFString) -> String {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return "" }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
    public static func boolean(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
    }
    public static func id(_ source: TISInputSource) -> String { string(source, kTISPropertyInputSourceID) }
    public static func languages(_ source: TISInputSource) -> [String] {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return [] }
        return Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as? [String] ?? []
    }
    public static func current() -> TISInputSource? { TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() }
    public static func list(includeDisabled: Bool = false) -> [TISInputSource] {
        TISCreateInputSourceList(nil, includeDisabled)?.takeRetainedValue() as? [TISInputSource] ?? []
    }
    public static func source(id: String) -> TISInputSource? {
        list(includeDisabled: true).first { Self.id($0) == id && boolean($0, kTISPropertyInputSourceIsSelectCapable) }
    }
    public static func selectable(_ source: TISInputSource) -> Bool {
        boolean(source, kTISPropertyInputSourceIsEnabled) && boolean(source, kTISPropertyInputSourceIsSelectCapable)
    }
    public static func nativeEnglish() -> TISInputSource? {
        let layouts = list().filter {
            selectable($0) && string($0, kTISPropertyInputSourceType) == kTISTypeKeyboardLayout as String
                && id($0).hasPrefix("com.apple.keylayout.")
        }
        if let recent = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
           ["com.apple.keylayout.ABC", "com.apple.keylayout.US"].contains(id(recent)), selectable(recent) { return recent }
        return layouts.first { id($0) == "com.apple.keylayout.ABC" }
            ?? layouts.first { id($0) == "com.apple.keylayout.US" }
    }
}

public struct InstallationState: Codable {
    public let selectedSourceID: String?
    public let enabledSourceIDs: [String]
    public let alreadyInstalledAtSnapshot: Bool
    public let globalKeyboardSettingsModified: Bool

    public init() {
        selectedSourceID = InputSources.current().map(InputSources.id)
        enabledSourceIDs = InputSources.list().filter { InputSources.boolean($0, kTISPropertyInputSourceIsEnabled) }.map(InputSources.id)
        alreadyInstalledAtSnapshot = enabledSourceIDs.contains(where: InputSources.isOurs)
        globalKeyboardSettingsModified = false
    }
    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

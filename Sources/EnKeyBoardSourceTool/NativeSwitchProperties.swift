import Foundation
import Carbon
import Darwin

// Read-only registration diagnostics. These constants are exported by
// HIToolbox but absent from its public Swift headers. No private switching
// function is called, and the input-method app does not use this helper.
enum NativeSwitchProperties {
    private static let hitoolbox = dlopen(
        "/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/HIToolbox",
        RTLD_LAZY | RTLD_LOCAL
    )

    private static func value(_ source: TISInputSource, symbol: String) -> CFTypeRef? {
        guard let hitoolbox, let address = dlsym(hitoolbox, symbol) else { return nil }
        let key = address.assumingMemoryBound(to: CFString.self).pointee
        guard let value = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFTypeRef>.fromOpaque(value).takeUnretainedValue()
    }

    static func capsLockSwitch(_ source: TISInputSource) -> Bool? {
        guard let value = value(source, symbol: "kTISPropertyInputSourceDoesCapsLockSwitch"),
              CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return CFBooleanGetValue(unsafeBitCast(value, to: CFBoolean.self))
    }

    static func scriptCode(_ source: TISInputSource) -> Int? {
        guard let value = value(source, symbol: "kTISPropertyScriptCode"),
              CFGetTypeID(value) == CFNumberGetTypeID() else { return nil }
        var code: Int32 = 0
        guard CFNumberGetValue(unsafeBitCast(value, to: CFNumber.self), .sInt32Type, &code) else { return nil }
        return Int(code)
    }
}

import Foundation

enum DestinationStore {
    private static let key = "downloadFolderPath"

    static func load() -> URL {
        if let path = UserDefaults.standard.string(forKey: key) {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: path)
            }
        }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }

    static func save(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: key)
    }
}

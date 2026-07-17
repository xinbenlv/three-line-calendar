import Foundation

/// Build provenance shown in Settings → About. The "Generate BuildInfo" build
/// phase (project.yml) writes BuildInfo.plist into each app bundle with the
/// git commit and build timestamp; a build without git falls back to "dev".
enum BuildInfo {
    private static let info: [String: String] = {
        guard let url = Bundle.main.url(forResource: "BuildInfo", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil)
                          as? [String: String]
        else { return [:] }
        return dict
    }()

    /// "v2.1.1-bbc7d9" — marketing version + 6-char commit.
    static var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "?"
        return "v\(v)-\(info["GitCommit"] ?? "dev")"
    }

    static var buildDate: Date? {
        info["BuildDate"].flatMap { ISO8601DateFormatter().date(from: $0) }
    }
}

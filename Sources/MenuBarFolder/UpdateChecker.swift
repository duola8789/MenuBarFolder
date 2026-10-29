//
//  UpdateChecker.swift
//  MenuBarFolder
//
//  User-triggered version check against the project's latest GitHub release.
//  Deliberately does not download or replace the running app — a "Download"
//  action only opens the release page in the browser.
//

import Foundation

/// Dot-separated numeric version helpers. The project only ships
/// MAJOR.MINOR.PATCH versions, so no prerelease/build-number semantics.
enum Version {

    /// True when `candidate` is strictly newer than `current`.
    /// Missing segments count as 0 (`1.5` == `1.5.0`).
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let a = segments(candidate), let b = segments(current) else { return false }
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    /// False for tags like `latest` or `1.5.beta`, which must be reported as
    /// a failed check rather than silently compared as zero.
    static func isParseable(_ version: String) -> Bool {
        segments(version) != nil
    }

    private static func segments(_ version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }
        var out: [Int] = []
        out.reserveCapacity(parts.count)
        for part in parts {
            guard let number = Int(part), number >= 0 else { return nil }
            out.append(number)
        }
        return out
    }
}

enum UpdateChecker {

    enum Outcome {
        case upToDate(current: String)
        case updateAvailable(version: String, url: URL)
        case failed(String)
    }

    /// Fetches the latest release once and reports on `queue` (main by default).
    /// The only network entry point in the app; never called from startup paths.
    ///
    /// Uses the public `/releases/latest` page and follows its redirect to
    /// `/releases/tag/<tag>` instead of the REST API: unauthenticated API calls
    /// are capped at 60/hour per IP, which a shared egress address exhausts.
    static func check(deliveringOn queue: DispatchQueue = .main,
                      completion: @escaping (Outcome) -> Void) {
        guard let latestURL = URL(string: AppInfo.updateLatestPageURL) else {
            queue.async { completion(.failed("no update endpoint configured")) }
            return
        }

        var request = URLRequest(url: latestURL)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        // github.com is fine without one, but a UA makes the traffic identifiable.
        request.setValue("PinFold/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { _, response, error in
            let result: Outcome
            if let error {
                result = .failed(error.localizedDescription)
            } else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                result = .failed("GitHub returned HTTP \(http.statusCode)")
            } else if let page = response?.url, let tag = releaseTag(from: page) {
                var latest = tag
                if latest.hasPrefix("v") { latest.removeFirst() }
                if !Version.isParseable(latest) {
                    result = .failed("unrecognized version in tag \"\(tag)\"")
                } else if Version.isNewer(latest, than: AppInfo.version) {
                    result = .updateAvailable(version: latest, url: page)
                } else {
                    result = .upToDate(current: AppInfo.version)
                }
            } else {
                // Redirected to /releases rather than /releases/tag/<tag>:
                // the repository has no published release yet.
                result = .failed("no published release found")
            }
            queue.async { completion(result) }
        }.resume()
    }

    /// Extracts `<tag>` from a `.../releases/tag/<tag>` URL.
    private static func releaseTag(from url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 3,
              parts[parts.count - 3] == "releases",
              parts[parts.count - 2] == "tag",
              let tag = parts.last, !tag.isEmpty else { return nil }
        return tag.removingPercentEncoding ?? tag
    }
}

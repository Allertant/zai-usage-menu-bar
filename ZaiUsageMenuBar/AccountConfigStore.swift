import Foundation

protocol AuthTokenStore {
    func authToken(for accountID: String) -> String?
    func setAuthToken(_ token: String, for accountID: String) throws
    func removeAuthToken(for accountID: String) throws
}

enum AccountConfigStore {
    static let accountsKey = "accountsV1"
    static let legacyTokenKey = "anthropicAuthToken"
    private static let tokenStore: AuthTokenStore = FileAuthTokenStore()
    private static let tokenCacheLock = NSLock()
    private static var tokenCache: [String: TokenCacheEntry] = [:]
    
    static func loadAccounts(
        userDefaults: UserDefaults = .standard,
        tokenStore: AuthTokenStore = tokenStore
    ) -> [AccountConfig] {
        if let data = userDefaults.data(forKey: accountsKey) {
            if let storedAccounts = try? JSONDecoder().decode([StoredAccountConfig].self, from: data) {
                return storedAccounts.map {
                    AccountConfig(
                        id: $0.id,
                        name: $0.name,
                        authToken: cachedAuthToken(for: $0.id, tokenStore: tokenStore) ?? "",
                        isEnabled: $0.isEnabled
                    )
                }
            }
            
            if let legacyAccounts = try? JSONDecoder().decode([AccountConfig].self, from: data) {
                try? saveAccounts(legacyAccounts, userDefaults: userDefaults, tokenStore: tokenStore)
                return legacyAccounts
            }
        }
        
        return migrateLegacyTokenIfNeeded(userDefaults: userDefaults, tokenStore: tokenStore)
    }
    
    static func saveAccounts(
        _ accounts: [AccountConfig],
        userDefaults: UserDefaults = .standard,
        tokenStore: AuthTokenStore = tokenStore
    ) throws {
        let existingIDs = accountIDs(in: userDefaults)
        let storedAccounts = accounts.map { StoredAccountConfig(id: $0.id, name: $0.name, isEnabled: $0.isEnabled) }
        let data = try JSONEncoder().encode(storedAccounts)
        userDefaults.set(data, forKey: accountsKey)
        userDefaults.removeObject(forKey: legacyTokenKey)
        
        for account in accounts {
            let trimmedToken = account.authToken.trimmed
            if trimmedToken.isEmpty {
                try tokenStore.removeAuthToken(for: account.id)
                cacheMissingToken(for: account.id)
            } else {
                try tokenStore.setAuthToken(trimmedToken, for: account.id)
                cacheToken(trimmedToken, for: account.id)
            }
        }
        
        let removedIDs = existingIDs.subtracting(accounts.map(\.id))
        for accountID in removedIDs {
            try tokenStore.removeAuthToken(for: accountID)
            removeCachedToken(for: accountID)
        }
    }
    
    private static func migrateLegacyTokenIfNeeded(
        userDefaults: UserDefaults,
        tokenStore: AuthTokenStore
    ) -> [AccountConfig] {
        let legacyToken = userDefaults.string(forKey: legacyTokenKey)?.trimmed ?? ""
        guard !legacyToken.isEmpty else { return [] }
        
        let account = AccountConfig(
            id: UUID().uuidString,
            name: L10n.localized("default_account_name"),
            authToken: legacyToken,
            isEnabled: true
        )
        
        try? saveAccounts([account], userDefaults: userDefaults, tokenStore: tokenStore)
        return [account]
    }
    
    private static func accountIDs(in userDefaults: UserDefaults) -> Set<String> {
        guard let data = userDefaults.data(forKey: accountsKey),
              let storedAccounts = try? JSONDecoder().decode([StoredAccountConfig].self, from: data)
        else {
            return []
        }
        
        return Set(storedAccounts.map(\.id))
    }

    static func clearInMemoryTokenCache() {
        tokenCacheLock.lock()
        defer { tokenCacheLock.unlock() }
        tokenCache.removeAll()
    }

    private static func cachedAuthToken(for accountID: String, tokenStore: AuthTokenStore) -> String? {
        tokenCacheLock.lock()
        if let cached = tokenCache[accountID] {
            tokenCacheLock.unlock()
            return cached.token
        }
        tokenCacheLock.unlock()

        let loadedToken = tokenStore.authToken(for: accountID)
        tokenCacheLock.lock()
        tokenCache[accountID] = loadedToken.map(TokenCacheEntry.present) ?? .missing
        tokenCacheLock.unlock()
        return loadedToken
    }

    private static func cacheToken(_ token: String, for accountID: String) {
        tokenCacheLock.lock()
        defer { tokenCacheLock.unlock() }
        tokenCache[accountID] = .present(token)
    }

    private static func cacheMissingToken(for accountID: String) {
        tokenCacheLock.lock()
        defer { tokenCacheLock.unlock() }
        tokenCache[accountID] = .missing
    }

    private static func removeCachedToken(for accountID: String) {
        tokenCacheLock.lock()
        defer { tokenCacheLock.unlock() }
        tokenCache.removeValue(forKey: accountID)
    }
}

private struct StoredAccountConfig: Codable {
    let id: String
    let name: String
    let isEnabled: Bool
}

private enum TokenCacheEntry {
    case present(String)
    case missing

    var token: String? {
        switch self {
        case .present(let token):
            return token
        case .missing:
            return nil
        }
    }
}

private struct FileAuthTokenStore: AuthTokenStore {
    private let baseURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ZaiUsageMenuBar/tokens", isDirectory: true)
    }()

    private func tokenURL(for accountID: String) -> URL {
        baseURL.appendingPathComponent(accountID)
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: baseURL.path)
    }

    func authToken(for accountID: String) -> String? {
        let url = tokenURL(for: accountID)
        guard let data = FileManager.default.contents(atPath: url.path),
              let token = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return token
    }

    func setAuthToken(_ token: String, for accountID: String) throws {
        try ensureDirectory()
        let url = tokenURL(for: accountID)
        try token.data(using: .utf8)!.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func removeAuthToken(for accountID: String) throws {
        let url = tokenURL(for: accountID)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

enum AccountConfigStoreError: LocalizedError {
    case writeFailed(path: String)
    case readFailed(path: String)

    var errorDescription: String? {
        switch self {
        case .writeFailed(let path):
            return "Failed to write token to \(path)"
        case .readFailed(let path):
            return "Failed to read token from \(path)"
        }
    }
}

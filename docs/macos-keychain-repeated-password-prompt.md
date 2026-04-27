# macOS Keychain 重复弹密码框的排查与修复

## 问题现象

macOS 应用使用 Keychain 存储 API Token 等敏感信息时，每次启动应用都弹出系统密码框，要求用户授权访问钥匙串。即使点了 "Always Allow"，下次启动仍然弹窗。

## 根因分析

### 1. 认证 UI 字段触发了系统密码提示

在 `SecItemCopyMatching` 查询中使用了以下字段：

```swift
let context = LAContext()
context.interactionNotAllowed = true
query[kSecUseAuthenticationContext as String] = context
```

虽然 `interactionNotAllowed = true` 看起来是"不允许交互"，但 `kSecUseAuthenticationContext` 本身会让 Keychain 认为这次访问需要认证上下文，从而触发系统密码弹窗。

**解决方案：** 对于应用自行存取 Token（无需用户认证参与）的场景，不要使用任何认证相关字段，保持最简单的查询：

```swift
var query: [String: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: service,
    kSecAttrAccount: accountID,
    kSecReturnData: true,
    kSecMatchLimit: kSecMatchLimitOne,
]
```

需要避免使用的字段：

| 字段 | 作用 | 副作用 |
|------|------|--------|
| `kSecUseAuthenticationContext` | 指定 LAContext | 触发认证提示 |
| `kSecUseOperationPrompt` | 显示提示文字 | 触发认证提示 |
| `kSecUseAuthenticationUI` | 控制认证 UI 行为 | 可能触发认证提示 |
| `kSecAttrAccessControl` + `userPresence` / `biometryAny` | 要求生物识别 | 每次读取都要认证 |

### 2. 代码签名不稳定导致 Keychain 认为是"不同的应用"

macOS 的 Keychain 访问控制基于应用的**代码签名身份**，而非应用名称。以下情况会导致 Keychain 把同一应用识别为"不同的应用"：

- 每次从 Xcode 构建时签名发生变化（尤其是无稳定签名证书时）
- Debug 和 Release 使用不同的 Bundle ID
- 应用路径变化（从 DerivedData 运行 vs 从 /Applications 运行）
- 签名证书过期或更换

可以用以下命令检查应用的签名信息：

```bash
codesign -dv --verbose=4 /path/to/YourApp.app
codesign -d --requirements - /path/to/YourApp.app
codesign -d --entitlements :- /path/to/YourApp.app
```

重点关注 `Identifier`、`TeamIdentifier`、`Authority`、`designated` 等字段是否每次构建都一致。

**解决方案：**
- 固定 `Bundle Identifier` 不变
- 使用稳定的签名证书（创建本地自签名证书即可）
- 开发阶段尽量从同一位置运行应用

### 3. 删除再创建导致 ACL 被重置

每次刷新 Token 时使用 `SecItemDelete` + `SecItemAdd`，会擦除用户之前授权的 Access Control List（ACL），导致下次访问又要弹窗。

```swift
// 错误做法：每次 delete + add，ACL 被清空
SecItemDelete(query as CFDictionary)
SecItemAdd(query as CFDictionary, nil)

// 正确做法：优先 update，找不到再 add
let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
if status == errSecItemNotFound {
    SecItemAdd(query as CFDictionary, nil)
}
```

### 4. login keychain 自动锁定

如果弹窗标题是 "login keychain password" 而非 "App wants to use confidential information"，则是 login 钥匙串本身被锁住。

**解决方案：**
- 打开 Keychain Access → 右键 login → "Change Settings for Keychain 'login'" → 取消勾选 "Lock after X minutes of inactivity"

## 排查步骤

### 第一步：确认弹窗类型

| 弹窗内容 | 类型 |
|---------|------|
| "YourApp wants to use your confidential information stored in xxx" | Keychain item 访问权限问题 |
| "login keychain password" | 钥匙串本身锁定 |

### 第二步：检查代码中是否使用了认证字段

搜索以下关键词：`LAContext`、`kSecUseAuthenticationContext`、`kSecUseOperationPrompt`、`kSecUseAuthenticationUI`、`kSecAttrAccessControl`、`userPresence`、`biometryAny`。

对于仅存取 Token 的场景，全部移除。

### 第三步：确保写入逻辑使用 update 优先

检查保存逻辑是否为 `update → errSecItemNotFound → add`，而非 `delete → add`。

### 第四步：固定签名和运行环境

确保 Bundle ID、签名证书、应用路径在开发期间保持不变。

### 第五步：清理旧的 Keychain 条目

打开 Keychain Access，搜索应用的 `kSecAttrService` 值，删除旧条目，让应用以新的签名和新的代码逻辑重新创建。

## 修复后的推荐 Keychain 存取模式

```swift
final class KeychainStore {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.example.app") {
        self.service = service
    }

    func save(_ value: String, for key: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let attributes: [String: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
            return
        }
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }

    func read(for key: String) -> String? {
        var query: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
```

关键点：
- 读取时不使用任何认证相关字段
- 写入时优先 `SecItemUpdate`，保留已有 ACL
- `kSecAttrAccessible` 使用 `AfterFirstUnlockThisDeviceOnly`，不触发用户认证
- `service` 使用固定的 Bundle ID，不随调试/发布变化

## 参考链接

- [Apple: Allow apps to access your keychain](https://support.apple.com/en-gb/guide/mac-help/kychn002/mac)
- [Stack Overflow: Application always asks for permission to access keychain](https://stackoverflow.com/questions/11234323/application-always-asks-for-permission-to-access-keychain)
- [GitHub: Keychain password prompt repeats despite 'Always Allow'](https://github.com/steipete/CodexBar/issues/340)
- [Apple Developer: Sharing access to keychain items among apps](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps)

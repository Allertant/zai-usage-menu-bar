import Foundation

enum L10n {
    static var preferredLanguage: String {
        UserDefaults.standard.string(forKey: "preferredLanguage") ?? "system"
    }
    
    static func localized(_ key: String) -> String {
        let lang = preferredLanguage == "system" ? (Locale.current.language.languageCode?.identifier ?? "en") : preferredLanguage
        
        let translations: [String: [String: String]] = [
            "app_title": [
                "en": "Zai Usage",
                "zh": "智谱coding plan 用量查询"
            ],
            "settings": [
                "en": "Settings",
                "zh": "设置"
            ],
            "quit": [
                "en": "Quit",
                "zh": "退出"
            ],
            "retry": [
                "en": "Retry",
                "zh": "重试"
            ],
            "quota": [
                "en": "Quota",
                "zh": "配额"
            ],
            "token_label": [
                "en": "Token (5h)",
                "zh": "Token (5小时)"
            ],
            "mcp_label": [
                "en": "MCP (1m)",
                "zh": "MCP (1分钟)"
            ],
            "resets_prefix": [
                "en": "resets",
                "zh": "重置"
            ],
            "model_usage": [
                "en": "Model Usage",
                "zh": "模型用量"
            ],
            "tools": [
                "en": "Tools",
                "zh": "工具调用"
            ],
            "calls_suffix": [
                "en": "calls",
                "zh": "次调用"
            ],
            "api_config": [
                "en": "API Configuration",
                "zh": "API 配置"
            ],
            "base_url": [
                "en": "Base URL",
                "zh": "基础 URL"
            ],
            "auth_token": [
                "en": "Auth Token",
                "zh": "认证令牌"
            ],
            "auth_token_placeholder": [
                "en": "Your authentication token",
                "zh": "你的认证令牌"
            ],
            "done": [
                "en": "Done",
                "zh": "完成"
            ],
            "language": [
                "en": "Language",
                "zh": "语言"
            ],
            "system_default": [
                "en": "System Default",
                "zh": "跟随系统"
            ]
        ]
        
        let langKey = lang.hasPrefix("zh") ? "zh" : "en"
        return translations[key]?[langKey] ?? translations[key]?["en"] ?? key
    }
}

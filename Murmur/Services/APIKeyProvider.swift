import Foundation

enum APIKeyProvider {
    static var ppqAPIKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "PPQAPIKey") as? String,
              !key.isEmpty else {
            return nil
        }
        return key
    }

    static var analyticsEndpoint: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "StudioAnalyticsEndpoint") as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }

    static var analyticsAPIKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "StudioAnalyticsAPIKey") as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }
}

import Foundation

enum APIKeyProvider {
    static var ppqAPIKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "PPQAPIKey") as? String,
              !key.isEmpty else {
            return nil
        }
        return key
    }
}

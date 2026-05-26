import Foundation

struct UserDetail: Codable, Equatable {
    let id: String?
    let username: String?
    let superAdmin: Int?
    let token: String?
    let status: Int?
}

struct PublicConfig: Decodable, Equatable {
    let enableMobileRegister: Bool?
    let enableEmailRegister: Bool?
    let allowUserRegister: Bool?
    let version: String?
    let name: String?
    let sm2PublicKey: String?
}

struct UserPreferenceDTO: Codable, Equatable {
    let language: String?
    let agentLanguage: String?
    let timezone: String?
}

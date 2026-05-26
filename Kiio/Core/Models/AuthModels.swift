import Foundation

struct TokenDTO: Codable, Equatable {
    let token: String
    let expire: Int?
    let clientHash: String?
}

struct EmailCodeRequest: Encodable {
    let email: String
}

struct LoginPasswordRequest: Encodable {
    let email: String
    let password: String
}

struct LoginCodeRequest: Encodable {
    let email: String
    let emailCaptcha: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let emailCaptcha: String
    let language: String
}

struct ResetPasswordRequest: Encodable {
    let email: String
    let emailCaptcha: String
    let password: String
}

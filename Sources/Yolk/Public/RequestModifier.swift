//
//  RequestModifier.swift
//  Yolk
//
//  Created by 금가경 on 12/05/24.
//

import Foundation

/// HTTP 요청을 수정하는 프로토콜
///
/// URLRequest에 인증 헤더나 커스텀 헤더를 추가하는 등의 수정 작업을 수행합니다.
/// Kingfisher의 ImageDownloadRequestModifier 패턴을 참고하여 설계되었습니다.
///
/// # 사용 예시
/// ```swift
/// struct MyModifier: RequestModifier {
///     func modified(for request: URLRequest) -> URLRequest? {
///         var r = request
///         r.setValue("Bearer token", forHTTPHeaderField: "Authorization")
///         return r
///     }
/// }
///
/// let service = ImageCacheService(modifier: MyModifier())
/// ```
public protocol RequestModifier: Sendable {
    /// URLRequest를 수정하여 새로운 URLRequest를 반환합니다.
    ///
    /// 이 메서드는 다운로드 매니저가 HTTP 요청을 생성할 때 자동으로 호출됩니다.
    /// 인증 토큰, API 키, 커스텀 헤더 등을 추가할 수 있습니다.
    ///
    /// - Parameter request: 원본 URLRequest
    /// - Returns: 수정된 URLRequest (nil이면 요청 취소)
    ///
    /// # Example
    /// ```swift
    /// func modified(for request: URLRequest) -> URLRequest? {
    ///     var r = request
    ///     r.setValue("application/json", forHTTPHeaderField: "Content-Type")
    ///     r.setValue("my-api-key", forHTTPHeaderField: "X-API-Key")
    ///     return r
    /// }
    /// ```
    func modified(for request: URLRequest) -> URLRequest?
}

/// 클로저 기반 RequestModifier 구현체
///
/// 간단한 요청 수정 로직을 클로저로 구현할 수 있는 편리한 래퍼입니다.
/// Kingfisher의 AnyModifier 패턴을 참고하여 설계되었습니다.
///
/// # Example
/// ```swift
/// let modifier = AnyModifier { request in
///     var r = request
///     r.setValue("Bearer token", forHTTPHeaderField: "Authorization")
///     return r
/// }
///
/// let service = ImageCacheService(modifier: modifier)
/// ```
public struct AnyModifier: RequestModifier, Sendable {
    private let modify: @Sendable (URLRequest) -> URLRequest?

    /// AnyModifier를 클로저로 초기화합니다.
    ///
    /// - Parameter modify: URLRequest를 수정하는 클로저
    public init(_ modify: @escaping @Sendable (URLRequest) -> URLRequest?) {
        self.modify = modify
    }

    public func modified(for request: URLRequest) -> URLRequest? {
        return modify(request)
    }
}

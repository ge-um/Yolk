//
//  CacheService+Image.swift
//  Yolk
//
//  Created by 금가경 on 12/05/24.
//

import UIKit

/// CacheService 이미지 특화 Extension
extension CacheService {

    /// URL에서 이미지를 가져옵니다.
    ///
    /// 캐시에 이미지가 있으면 캐시에서 반환하고, 없으면 다운로드한 후 캐시에 저장합니다.
    /// 다운샘플링을 통해 메모리 효율적으로 이미지를 로드할 수 있습니다.
    ///
    /// - Parameters:
    ///   - url: 이미지의 원본 URL
    ///   - targetSize: 다운샘플링 목표 크기 (nil이면 원본 크기 사용)
    ///   - modifier: HTTP 요청을 수정하는 modifier (nil이면 defaultModifier 사용)
    ///   - progressHandler: 다운로드 진행률 콜백 (0.0 ~ 1.0)
    /// - Returns: 로드된 UIImage
    /// - Throws: `ImageCacheError` - 다운로드, 디코딩, 다운샘플링 실패 시
    ///
    /// # Example
    /// ```swift
    /// // 원본 크기로 가져오기
    /// let image = try await CacheService.image.getImage(from: url)
    ///
    /// // 다운샘플링하여 가져오기
    /// let thumbnail = try await CacheService.image.getImage(
    ///     from: url,
    ///     targetSize: CGSize(width: 200, height: 200)
    /// )
    ///
    /// // 요청별 modifier 사용
    /// let image = try await CacheService.image.getImage(
    ///     from: url,
    ///     modifier: AnyModifier { /* custom headers */ }
    /// )
    /// ```
    public func getImage(
        from url: URL,
        targetSize: CGSize? = nil,
        modifier: RequestModifier? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> UIImage {
        let actualModifier = modifier ?? defaultModifier
        let handler: (@Sendable (Double) -> Void)? = progressHandler.map { handler in
            { @Sendable progress in handler(progress) }
        }
        return try await cacheManager.getImage(
            from: url,
            targetSize: targetSize,
            modifier: actualModifier,
            progressHandler: handler
        )
    }

    /// URL에서 이미지를 다운로드하고 캐싱합니다.
    ///
    /// `getImage(from:targetSize:modifier:progressHandler:)`와 동일한 기능을 제공합니다.
    /// 의미론적으로 더 명확한 메서드명을 원하는 경우 사용할 수 있습니다.
    ///
    /// - Parameters:
    ///   - url: 이미지의 원본 URL
    ///   - targetSize: 다운샘플링 목표 크기 (nil이면 원본 크기 사용)
    ///   - modifier: HTTP 요청을 수정하는 modifier (nil이면 defaultModifier 사용)
    ///   - progressHandler: 다운로드 진행률 콜백 (0.0 ~ 1.0)
    /// - Returns: 캐시된 UIImage
    /// - Throws: `ImageCacheError` - 다운로드, 디코딩, 다운샘플링 실패 시
    public func cacheImage(
        from url: URL,
        targetSize: CGSize? = nil,
        modifier: RequestModifier? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> UIImage {
        return try await getImage(
            from: url,
            targetSize: targetSize,
            modifier: modifier,
            progressHandler: progressHandler
        )
    }

    /// 캐시에서 이미지를 가져옵니다.
    ///
    /// 캐시에 이미지가 없어도 다운로드하지 않고 nil을 반환합니다.
    /// UI 렌더링 중 즉시 표시할 이미지가 있는지 확인할 때 유용합니다.
    ///
    /// - Parameters:
    ///   - url: 이미지의 원본 URL
    ///   - targetSize: 다운샘플링 목표 크기 (nil이면 원본 크기)
    /// - Returns: 캐시된 UIImage (없으면 nil)
    ///
    /// # Example
    /// ```swift
    /// if let cachedImage = await CacheService.image.getCachedImage(for: url) {
    ///     imageView.image = cachedImage
    /// } else {
    ///     let image = try await CacheService.image.getImage(from: url)
    ///     imageView.image = image
    /// }
    /// ```
    public func getCachedImage(for url: URL, targetSize: CGSize? = nil) async -> UIImage? {
        return await cacheManager.getCachedImage(from: url, targetSize: targetSize)
    }

    /// 이미지가 캐시에 존재하는지 확인합니다.
    ///
    /// - Parameter url: 확인할 이미지의 URL
    /// - Returns: 캐시 존재 여부 (true: 존재, false: 미존재)
    public func hasCache(for url: URL) async -> Bool {
        return await cacheManager.hasImageCache(for: url)
    }
}

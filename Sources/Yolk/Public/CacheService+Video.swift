//
//  CacheService+Video.swift
//  Yolk
//
//  Created by 금가경 on 12/05/24.
//

import UIKit

/// CacheService 비디오 특화 Extension
extension CacheService {

    /// URL에서 동영상의 로컬 경로를 가져옵니다.
    ///
    /// 캐시에 동영상이 있으면 캐시된 로컬 URL을 반환하고, 없으면 다운로드한 후 로컬 URL을 반환합니다.
    /// AVPlayer 등에서 재생할 수 있는 로컬 파일 URL이 반환됩니다.
    ///
    /// - Parameters:
    ///   - url: 동영상의 원본 URL
    ///   - modifier: HTTP 요청을 수정하는 modifier (nil이면 defaultModifier 사용)
    ///   - progressHandler: 다운로드 진행률 콜백 (0.0 ~ 1.0)
    /// - Returns: 캐시된 동영상의 로컬 파일 URL
    /// - Throws: `VideoCacheError` - 다운로드 실패 시
    ///
    /// # Example
    /// ```swift
    /// let localURL = try await CacheService.video.getVideoURL(from: videoURL)
    /// let player = AVPlayer(url: localURL)
    /// ```
    public func getVideoURL(
        from url: URL,
        modifier: RequestModifier? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let actualModifier = modifier ?? defaultModifier
        let handler: (@Sendable (Double) -> Void)? = progressHandler.map { handler in
            { @Sendable progress in handler(progress) }
        }
        return try await cacheManager.getVideoURL(
            from: url,
            modifier: actualModifier,
            progressHandler: handler
        )
    }

    /// 동영상을 다운로드하고 캐싱합니다.
    ///
    /// `getVideoURL(from:modifier:progressHandler:)`와 동일한 기능을 제공합니다.
    /// 의미론적으로 더 명확한 메서드명을 원하는 경우 사용할 수 있습니다.
    ///
    /// - Parameters:
    ///   - url: 동영상의 원본 URL
    ///   - modifier: HTTP 요청을 수정하는 modifier (nil이면 defaultModifier 사용)
    ///   - progressHandler: 다운로드 진행률 콜백 (0.0 ~ 1.0)
    /// - Returns: 캐시된 동영상의 로컬 파일 URL
    /// - Throws: `VideoCacheError` - 다운로드 실패 시
    public func cacheVideo(
        from url: URL,
        modifier: RequestModifier? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        return try await getVideoURL(
            from: url,
            modifier: modifier,
            progressHandler: progressHandler
        )
    }

    /// 동영상의 썸네일 이미지를 가져옵니다.
    ///
    /// 썸네일이 캐시에 있으면 캐시에서 반환하고, 없으면 동영상을 다운로드하여 썸네일을 생성합니다.
    /// AVAssetImageGenerator를 사용하여 지정된 시간의 프레임을 추출합니다.
    ///
    /// - Parameters:
    ///   - url: 동영상의 원본 URL
    ///   - targetSize: 썸네일 크기 (기본: 200x200)
    ///   - time: 썸네일을 추출할 시간 (초 단위, 기본: 0.0)
    ///   - modifier: HTTP 요청을 수정하는 modifier (nil이면 defaultModifier 사용)
    /// - Returns: 썸네일 UIImage
    /// - Throws: `VideoCacheError` - 다운로드 또는 썸네일 생성 실패 시
    ///
    /// # Example
    /// ```swift
    /// // 첫 프레임 썸네일 가져오기
    /// let thumbnail = try await CacheService.video.getThumbnail(from: videoURL)
    ///
    /// // 5초 지점의 썸네일 가져오기
    /// let thumbnail = try await CacheService.video.getThumbnail(
    ///     from: videoURL,
    ///     at: 5.0
    /// )
    /// ```
    public func getThumbnail(
        from url: URL,
        targetSize: CGSize = CGSize(width: 200, height: 200),
        at time: Double = 0.0,
        modifier: RequestModifier? = nil
    ) async throws -> UIImage {
        let actualModifier = modifier ?? defaultModifier
        return try await cacheManager.getThumbnail(
            from: url,
            targetSize: targetSize,
            at: time,
            modifier: actualModifier
        )
    }

    /// 동영상 썸네일을 생성하고 캐싱합니다.
    ///
    /// `getThumbnail(from:targetSize:at:modifier:)`와 동일한 기능을 제공합니다.
    /// 의미론적으로 더 명확한 메서드명을 원하는 경우 사용할 수 있습니다.
    ///
    /// - Parameters:
    ///   - url: 동영상의 원본 URL
    ///   - targetSize: 썸네일 크기 (기본: 200x200)
    ///   - time: 썸네일을 추출할 시간 (초 단위, 기본: 0.0)
    ///   - modifier: HTTP 요청을 수정하는 modifier (nil이면 defaultModifier 사용)
    /// - Returns: 썸네일 UIImage
    /// - Throws: `VideoCacheError` - 다운로드 또는 썸네일 생성 실패 시
    public func cacheThumbnail(
        from url: URL,
        targetSize: CGSize = CGSize(width: 200, height: 200),
        at time: Double = 0.0,
        modifier: RequestModifier? = nil
    ) async throws -> UIImage {
        return try await getThumbnail(
            from: url,
            targetSize: targetSize,
            at: time,
            modifier: modifier
        )
    }

    /// 동영상이 캐시에 존재하는지 확인합니다.
    ///
    /// - Parameter url: 확인할 동영상의 URL
    /// - Returns: 캐시 존재 여부 (true: 존재, false: 미존재)
    public func hasVideoCache(for url: URL) async -> Bool {
        return await cacheManager.hasVideoCache(for: url)
    }

    /// 동영상 썸네일이 캐시에 존재하는지 확인합니다.
    ///
    /// - Parameters:
    ///   - url: 확인할 동영상의 URL
    ///   - time: 썸네일 추출 시간 (초 단위, 기본: 0.0)
    /// - Returns: 썸네일 캐시 존재 여부 (true: 존재, false: 미존재)
    public func hasThumbnailCache(for url: URL, at time: Double = 0.0) async -> Bool {
        return await cacheManager.hasThumbnailCache(for: url, at: time)
    }

    /// 캐시된 동영상의 로컬 URL을 가져옵니다.
    ///
    /// 캐시에 동영상이 없어도 다운로드하지 않고 nil을 반환합니다.
    /// 즉시 재생 가능한 동영상이 있는지 확인할 때 유용합니다.
    ///
    /// - Parameter url: 동영상의 원본 URL
    /// - Returns: 캐시된 동영상의 로컬 URL (없으면 nil)
    ///
    /// # Example
    /// ```swift
    /// if let cachedURL = await CacheService.video.getCachedVideo(for: videoURL) {
    ///     player.replaceCurrentItem(with: AVPlayerItem(url: cachedURL))
    /// } else {
    ///     let url = try await CacheService.video.getVideoURL(from: videoURL)
    ///     player.replaceCurrentItem(with: AVPlayerItem(url: url))
    /// }
    /// ```
    public func getCachedVideo(for url: URL) async -> URL? {
        return await cacheManager.getCachedFileURL(from: url)
    }
}

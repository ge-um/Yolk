//
//  CacheService.swift
//  Yolk
//
//  Created by 금가경 on 12/05/24.
//

import Foundation

/// 범용 캐시 서비스
///
/// 이미지와 비디오 캐싱을 위한 통합 서비스입니다.
/// 메모리 캐시와 디스크 캐시를 모두 활용하며, LRU 정책과 시간 기반 만료 정책을 지원합니다.
///
/// # 주요 기능
/// - 자동 캐싱: URL에서 파일을 가져오면 자동으로 캐시에 저장
/// - 중복 다운로드 방지: 동일한 URL에 대한 중복 요청 방지
/// - 자동 정리: 용량 초과 시 오래된 캐시 자동 삭제
/// - 스레드 안전: actor로 구현되어 동시성 보장
/// - RequestModifier: HTTP 요청 헤더 커스터마이징 지원
///
/// # 사용 예시
/// ```swift
/// // 글로벌 modifier 설정
/// let modifier = AnyModifier { request in
///     var r = request
///     r.setValue("Bearer token", forHTTPHeaderField: "Authorization")
///     return r
/// }
/// CacheService.image.defaultModifier = modifier
/// CacheService.video.defaultModifier = modifier
///
/// // 이미지 캐싱
/// let image = try await CacheService.image.getImage(from: imageURL)
///
/// // 비디오 캐싱
/// let videoURL = try await CacheService.video.getVideoURL(from: videoURL)
/// ```
public actor CacheService {

    /// 이미지 캐시 서비스 싱글톤
    public static let image = CacheService(config: .image)

    /// 비디오 캐시 서비스 싱글톤
    public static let video = CacheService(config: .video)

    /// 기본 RequestModifier
    ///
    /// 모든 요청에 적용될 기본 modifier입니다.
    /// 개별 메서드 호출 시 modifier를 전달하면 해당 modifier가 우선 적용됩니다.
    ///
    /// # Example
    /// ```swift
    /// // 앱 시작 시 글로벌 설정
    /// let modifier = AnyModifier { request in
    ///     var r = request
    ///     r.setValue("Bearer token", forHTTPHeaderField: "Authorization")
    ///     return r
    /// }
    /// Task {
    ///     await CacheService.image.setModifier(modifier)
    /// }
    /// ```
    var defaultModifier: RequestModifier?

    /// 기본 RequestModifier를 설정합니다.
    ///
    /// - Parameter modifier: 설정할 RequestModifier
    public func setModifier(_ modifier: RequestModifier?) {
        self.defaultModifier = modifier
    }

    let cacheManager: CacheManager

    private init(config: CacheServiceConfig) {
        let downloadManager = DownloadManager()

        let cacheConfig = CacheConfiguration(
            memoryLimit: config.memoryLimit,
            diskLimit: config.diskLimit,
            expirationDays: config.expirationDays,
            cacheDirectoryName: config.cacheDirectoryName
        )

        let metadataManager = CacheMetadataManager(
            userDefaultsKey: config.userDefaultsKey
        )

        self.cacheManager = CacheManager(
            config: cacheConfig,
            downloadManager: downloadManager,
            metadataManager: metadataManager
        )
    }

    /// 진행 중인 다운로드를 취소합니다.
    ///
    /// - Parameter url: 취소할 파일의 URL
    public func cancelDownload(for url: URL) async {
        await cacheManager.cancelDownload(for: url)
    }

    /// 특정 URL의 캐시를 삭제합니다.
    ///
    /// 메모리 캐시와 디스크 캐시에서 모두 삭제됩니다.
    ///
    /// - Parameter url: 삭제할 파일의 URL
    public func removeCache(for url: URL) async {
        await cacheManager.removeCache(for: url)
    }

    /// 모든 캐시를 삭제합니다.
    ///
    /// 메모리 캐시와 디스크 캐시를 모두 비우고, 메타데이터도 제거합니다.
    /// 로그아웃 또는 데이터 초기화 시 호출할 수 있습니다.
    public func clearAllCache() async {
        await cacheManager.clearAllCache()
    }

    /// 만료된 캐시를 삭제합니다.
    ///
    /// 설정된 만료 기간을 초과한 캐시를 삭제합니다.
    /// 주기적으로 호출하여 디스크 공간을 확보할 수 있습니다.
    public func cleanExpiredCache() async {
        await cacheManager.cleanExpiredCache()
    }

    /// 캐시 정리를 수행합니다.
    ///
    /// 만료된 캐시를 삭제합니다.
    public func cleanupIfNeeded() async {
        await cleanExpiredCache()
    }
}

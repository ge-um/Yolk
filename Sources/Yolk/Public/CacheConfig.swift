//
//  CacheConfig.swift
//  Yolk
//
//  Created by 금가경 on 11/30/24.
//

import Foundation

/// 캐시 시스템의 설정을 정의하는 구조체
///
/// 이미지, 동영상, 썸네일 등의 캐시 용량 제한, 만료 정책, 재시도 정책을 설정합니다.
/// 라이브러리 사용자가 커스텀 설정을 제공할 수 있도록 public으로 공개됩니다.
///
/// # Example
/// ```swift
/// let customConfig = CacheConfig(
///     maxVideoCacheSize: 500 * 1024 * 1024,  // 500MB
///     maxThumbnailCacheSize: 50 * 1024 * 1024,  // 50MB
///     expirationDays: 14
/// )
/// ```
public struct CacheConfig: Sendable {

    /// 동영상 캐시의 최대 크기 (단위: 바이트)
    ///
    /// 디스크에 저장되는 동영상 파일의 총 용량 제한입니다.
    /// 이 크기를 초과하면 LRU(Least Recently Used) 정책에 따라 오래된 캐시부터 자동으로 삭제됩니다.
    public let maxVideoCacheSize: Int64

    /// 썸네일 캐시의 최대 크기 (단위: 바이트)
    ///
    /// 디스크에 저장되는 썸네일 이미지의 총 용량 제한입니다.
    /// 이 크기를 초과하면 LRU 정책에 따라 오래된 캐시부터 자동으로 삭제됩니다.
    public let maxThumbnailCacheSize: Int64

    /// 메모리 캐시의 최대 크기 (단위: 바이트)
    ///
    /// NSCache를 사용하는 인메모리 캐시의 용량 제한입니다.
    /// 메모리 부족 시 시스템이 자동으로 정리하며, 메모리 경고 발생 시 수동으로 정리됩니다.
    public let maxMemoryCacheSize: Int

    /// 캐시 만료 기간 (단위: 일)
    ///
    /// 캐시된 파일이 이 기간을 초과하면 만료된 것으로 간주되어 자동으로 삭제됩니다.
    /// 시간 기반 만료 정책에 사용됩니다.
    public let expirationDays: Int

    /// 다운로드 실패 시 최대 재시도 횟수
    ///
    /// 네트워크 요청이 실패했을 때 재시도할 최대 횟수입니다.
    /// 재시도 간격은 `retryDelay`로 설정됩니다.
    public let maxRetryCount: Int

    /// 재시도 간격 (단위: 초)
    ///
    /// 다운로드 재시도 사이의 대기 시간입니다.
    /// 서버 부하를 줄이고 일시적인 네트워크 오류를 처리하기 위해 사용됩니다.
    public let retryDelay: TimeInterval

    /// 기본 캐시 설정
    ///
    /// 대부분의 일반적인 사용 사례에 적합한 기본값을 제공합니다.
    /// - 동영상 캐시: 230MB
    /// - 썸네일 캐시: 20MB (약 200개 썸네일)
    /// - 메모리 캐시: 50MB
    /// - 만료 기간: 7일
    /// - 재시도 횟수: 3회
    /// - 재시도 간격: 1.0초
    public static let `default` = CacheConfig(
        maxVideoCacheSize: 230 * 1024 * 1024,
        maxThumbnailCacheSize: 20 * 1024 * 1024,
        maxMemoryCacheSize: 50 * 1024 * 1024,
        expirationDays: 7,
        maxRetryCount: 3,
        retryDelay: 1.0
    )

    /// CacheConfig 초기화
    ///
    /// 커스텀 캐시 설정을 생성합니다.
    ///
    /// - Parameters:
    ///   - maxVideoCacheSize: 동영상 캐시 최대 크기 (바이트)
    ///   - maxThumbnailCacheSize: 썸네일 캐시 최대 크기 (바이트)
    ///   - maxMemoryCacheSize: 메모리 캐시 최대 크기 (바이트, 기본값: 50MB)
    ///   - expirationDays: 캐시 만료 기간 (일)
    ///   - maxRetryCount: 다운로드 최대 재시도 횟수 (기본값: 3회)
    ///   - retryDelay: 재시도 간격 (초, 기본값: 1.0초)
    public init(
        maxVideoCacheSize: Int64,
        maxThumbnailCacheSize: Int64,
        maxMemoryCacheSize: Int = 50 * 1024 * 1024,
        expirationDays: Int,
        maxRetryCount: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) {
        self.maxVideoCacheSize = maxVideoCacheSize
        self.maxThumbnailCacheSize = maxThumbnailCacheSize
        self.maxMemoryCacheSize = maxMemoryCacheSize
        self.expirationDays = expirationDays
        self.maxRetryCount = maxRetryCount
        self.retryDelay = retryDelay
    }
}

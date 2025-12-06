//
//  CacheServiceConfig.swift
//  Yolk
//
//  Created by 금가경 on 12/05/24.
//

import Foundation

/// CacheService 설정
///
/// 이미지 캐시와 비디오 캐시의 기본 설정을 제공합니다.
public struct CacheServiceConfig: Sendable {
    let memoryLimit: Int
    let diskLimit: Int
    let expirationDays: Int
    let cacheDirectoryName: String
    let userDefaultsKey: String

    /// 이미지 캐시 기본 설정
    ///
    /// - 메모리 캐시: 100MB
    /// - 디스크 캐시: 200MB
    /// - 만료 기간: 7일
    public static let image = CacheServiceConfig(
        memoryLimit: 100 * 1024 * 1024,
        diskLimit: 200 * 1024 * 1024,
        expirationDays: 7,
        cacheDirectoryName: "ImageCache",
        userDefaultsKey: "com.cache.imagecache.metadata"
    )

    /// 비디오 캐시 기본 설정
    ///
    /// - 메모리 캐시: 50MB
    /// - 디스크 캐시: 500MB
    /// - 만료 기간: 7일
    public static let video = CacheServiceConfig(
        memoryLimit: 50 * 1024 * 1024,
        diskLimit: 500 * 1024 * 1024,
        expirationDays: 7,
        cacheDirectoryName: "VideoCache",
        userDefaultsKey: "com.cache.videocache.metadata"
    )

    public init(
        memoryLimit: Int,
        diskLimit: Int,
        expirationDays: Int,
        cacheDirectoryName: String,
        userDefaultsKey: String
    ) {
        self.memoryLimit = memoryLimit
        self.diskLimit = diskLimit
        self.expirationDays = expirationDays
        self.cacheDirectoryName = cacheDirectoryName
        self.userDefaultsKey = userDefaultsKey
    }
}

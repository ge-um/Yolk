//
//  GenericCacheManager.swift
//  Yolk
//
//  Created by 금가경 on 12/05/24.
//

import Foundation
import CryptoKit

/// 범용 캐시 매니저 (라이브러리 내부 구현)
///
/// 이미지, 동영상 등 모든 파일 타입의 캐싱을 지원하는 내부 구현체입니다.
/// 메모리 캐시와 디스크 캐시를 함께 사용하며, LRU 정책과 시간 기반 만료를 지원합니다.
/// ImageCacheService와 VideoCacheService가 이 클래스를 내부적으로 사용합니다.
internal actor CacheManager {

    let config: CacheConfiguration
    let downloadManager: DownloadManager
    let metadataManager: CacheMetadataManager

    let memoryCache = NSCache<NSString, NSData>()
    let cacheDirectory: URL
    let fileManager = FileManager.default

    /// CacheManager 초기화
    ///
    /// - Parameters:
    ///   - config: 캐시 설정
    ///   - downloadManager: 다운로드 매니저
    ///   - metadataManager: 메타데이터 매니저 (기본값: 새 인스턴스)
    init(
        config: CacheConfiguration,
        downloadManager: DownloadManager,
        metadataManager: CacheMetadataManager? = nil
    ) {
        self.config = config
        self.downloadManager = downloadManager
        self.metadataManager = metadataManager ?? CacheMetadataManager()

        self.memoryCache.totalCostLimit = config.memoryLimit

        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDirectory.appendingPathComponent(config.cacheDirectoryName)

        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    /// URL에서 파일 데이터를 가져옵니다 (캐시 우선, 없으면 다운로드)
    ///
    /// - Parameters:
    ///   - url: 파일 URL
    ///   - cacheType: 캐시 타입 (기본값: .generic)
    ///   - modifier: HTTP 요청을 수정하는 modifier
    ///   - progressHandler: 다운로드 진행률 콜백
    /// - Returns: 파일 데이터
    /// - Throws: 다운로드 또는 캐시 로드 실패 시 에러
    func getFile(
        from url: URL,
        cacheType: CacheMetadata.CacheType = .generic,
        modifier: RequestModifier? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> Data {
        let key = cacheKey(from: url)

        if let cachedData = memoryCache.object(forKey: key as NSString) as Data? {
            await metadataManager.updateAccessTime(for: key)
            return cachedData
        }

        let fileURL = cacheDirectory.appendingPathComponent(key)
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL) {
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            await metadataManager.updateAccessTime(for: key)
            return data
        }

        let downloadedURL = try await downloadManager.download(
            from: url,
            modifier: modifier,
            progressHandler: progressHandler
        )

        let data = try Data(contentsOf: downloadedURL)

        // 임시 파일 정리
        try? fileManager.removeItem(at: downloadedURL)

        try await saveToCache(data: data, key: key, originalURL: url, cacheType: cacheType)

        return data
    }

    /// 캐시에서 파일 URL을 가져옵니다 (디스크 캐시만 확인)
    ///
    /// - Parameter url: 원본 URL
    /// - Returns: 캐시된 파일의 로컬 URL (없으면 nil)
    func getCachedFileURL(from url: URL) async -> URL? {
        let key = cacheKey(from: url)
        let fileURL = cacheDirectory.appendingPathComponent(key)

        if fileManager.fileExists(atPath: fileURL.path) {
            await metadataManager.updateAccessTime(for: key)
            return fileURL
        }

        return nil
    }

    /// 캐시에서 파일 데이터를 가져옵니다 (메모리 → 디스크 순서)
    ///
    /// - Parameter url: 원본 URL
    /// - Returns: 캐시된 파일 데이터 (없으면 nil)
    func getCachedData(from url: URL) async -> Data? {
        let key = cacheKey(from: url)

        if let cachedData = memoryCache.object(forKey: key as NSString) as Data? {
            await metadataManager.updateAccessTime(for: key)
            return cachedData
        }

        let fileURL = cacheDirectory.appendingPathComponent(key)
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL) {
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            await metadataManager.updateAccessTime(for: key)
            return data
        }

        return nil
    }

    /// 데이터를 캐시에 저장합니다.
    ///
    /// - Parameters:
    ///   - data: 저장할 데이터
    ///   - key: 캐시 키
    ///   - originalURL: 원본 URL
    ///   - cacheType: 캐시 타입
    func saveToCache(
        data: Data,
        key: String,
        originalURL: URL,
        cacheType: CacheMetadata.CacheType
    ) async throws {
        await enforceDiskLimit()

        let fileURL = cacheDirectory.appendingPathComponent(key)

        try data.write(to: fileURL)

        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)

        let metadata = CacheMetadata(
            key: key,
            originalURL: originalURL.absoluteString,
            size: Int64(data.count),
            type: cacheType
        )
        await metadataManager.addOrUpdate(metadata)
    }

    /// 특정 URL의 다운로드를 취소합니다.
    ///
    /// - Parameter url: 취소할 다운로드의 URL
    func cancelDownload(for url: URL) async {
        await downloadManager.cancelDownload(for: url)
    }

    /// 특정 URL의 캐시를 삭제합니다.
    ///
    /// - Parameter url: 삭제할 파일의 URL
    func removeCache(for url: URL) async {
        let key = cacheKey(from: url)

        memoryCache.removeObject(forKey: key as NSString)

        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: fileURL)

        await metadataManager.remove(for: key)
    }

    /// 모든 캐시를 삭제합니다.
    func clearAllCache() async {
        memoryCache.removeAllObjects()

        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        await metadataManager.removeAll()
    }

    /// 특정 타입의 캐시를 모두 삭제합니다.
    ///
    /// - Parameter cacheType: 삭제할 캐시 타입
    func clearCache(for cacheType: CacheMetadata.CacheType) async {
        let keys = await metadataManager.sortedByLRU(type: cacheType)

        for key in keys {
            memoryCache.removeObject(forKey: key as NSString)

            let fileURL = cacheDirectory.appendingPathComponent(key)
            try? fileManager.removeItem(at: fileURL)

            await metadataManager.remove(for: key)
        }
    }

    /// 디스크 캐시 용량 제한을 적용합니다.
    ///
    /// 용량이 초과되면 LRU 순서로 오래된 캐시부터 삭제합니다.
    private func enforceDiskLimit() async {
        let currentSize = await getCurrentDiskSize()

        if currentSize > config.diskLimit {
            let targetSize = Int64(Double(config.diskLimit) * 0.8)
            let sizeToRemove = currentSize - targetSize

            await removeOldestFiles(targetSize: sizeToRemove)
        }
    }

    /// 만료된 캐시를 삭제합니다.
    func cleanExpiredCache() async {
        let expiredKeys = await metadataManager.expiredKeys(expirationDays: config.expirationDays)

        for key in expiredKeys {
            memoryCache.removeObject(forKey: key as NSString)

            let fileURL = cacheDirectory.appendingPathComponent(key)
            try? fileManager.removeItem(at: fileURL)

            await metadataManager.remove(for: key)
        }
    }

    /// LRU 순서로 오래된 파일을 삭제합니다.
    ///
    /// - Parameter targetSize: 삭제할 목표 크기 (바이트)
    private func removeOldestFiles(targetSize: Int64) async {
        let sortedKeys = await metadataManager.sortedByLRU()
        var removedSize: Int64 = 0

        for key in sortedKeys {
            guard removedSize < targetSize else { break }

            if let metadata = await metadataManager.get(for: key) {
                removedSize += metadata.size

                memoryCache.removeObject(forKey: key as NSString)

                let fileURL = cacheDirectory.appendingPathComponent(key)
                try? fileManager.removeItem(at: fileURL)

                await metadataManager.remove(for: key)
            }
        }
    }

    /// 현재 디스크 캐시 크기를 계산합니다.
    ///
    /// - Returns: 총 캐시 크기 (바이트)
    private func getCurrentDiskSize() async -> Int64 {
        var totalSize: Int64 = 0

        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        for fileURL in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }

        return totalSize
    }

    /// URL에서 캐시 키를 생성합니다.
    ///
    /// - Parameter url: 원본 URL
    /// - Returns: 캐시 키 (SHA256 해시 + 확장자)
    nonisolated func cacheKey(from url: URL) -> String {
        let keyString = url.absoluteString
        let hash = SHA256.hash(data: Data(keyString.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

        // 확장자 추가 (AVPlayer가 파일 타입을 인식하기 위해 필요)
        let pathExtension = url.pathExtension
        if !pathExtension.isEmpty {
            return hashString + "." + pathExtension
        }

        return hashString
    }
}

/// 캐시 설정 구조체 (라이브러리 내부)
///
/// CacheManager의 동작을 제어하는 설정값을 담습니다.
internal struct CacheConfiguration {
    let memoryLimit: Int
    let diskLimit: Int
    let expirationDays: Int
    let cacheDirectoryName: String

    init(
        memoryLimit: Int = 50 * 1024 * 1024,
        diskLimit: Int = 200 * 1024 * 1024,
        expirationDays: Int = 7,
        cacheDirectoryName: String = "GenericCache"
    ) {
        self.memoryLimit = memoryLimit
        self.diskLimit = diskLimit
        self.expirationDays = expirationDays
        self.cacheDirectoryName = cacheDirectoryName
    }
}

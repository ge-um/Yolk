//
//  CacheMetadataManager.swift
//  Yolk
//
//  Created by 금가경 on 11/30/24.
//

import Foundation

/// 캐시 메타데이터 관리자 (라이브러리 내부 구현)
///
/// actor로 구현되어 스레드 안전성을 보장합니다.
/// 메타데이터는 UserDefaults에 JSON 형태로 저장되며,
/// LRU 정책과 만료 정책을 구현하는 데 사용됩니다.
internal actor CacheMetadataManager {
    var metadata: [String: CacheMetadata] = [:]
    let userDefaultsKey: String

    /// CacheMetadataManager 초기화
    ///
    /// - Parameter userDefaultsKey: UserDefaults에 저장할 키 (기본값: "com.cache.metadata")
    init(userDefaultsKey: String = "com.cache.metadata") {
        self.userDefaultsKey = userDefaultsKey

        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let metadataArray = try? JSONDecoder().decode([CacheMetadata].self, from: data) {
            metadata = Dictionary(uniqueKeysWithValues: metadataArray.map { ($0.key, $0) })
        }
    }

    /// 메타데이터 추가 또는 업데이트
    /// - Parameter metadata: 캐시 메타데이터
    func addOrUpdate(_ metadata: CacheMetadata) {
        self.metadata[metadata.key] = metadata
        save()
    }

    /// 메타데이터 조회
    /// - Parameter key: 캐시 키
    /// - Returns: 캐시 메타데이터 (없으면 nil)
    func get(for key: String) -> CacheMetadata? {
        return metadata[key]
    }

    /// 메타데이터 삭제
    /// - Parameter key: 캐시 키
    func remove(for key: String) {
        metadata.removeValue(forKey: key)
        save()
    }

    /// 접근 시간 업데이트
    /// - Parameter key: 캐시 키
    func updateAccessTime(for key: String) {
        guard var data = metadata[key] else { return }
        data.updateAccessTime()
        metadata[key] = data
        save()
    }

    /// LRU 순서로 정렬된 키 목록 반환
    /// - Parameter type: 캐시 타입 (nil이면 전체)
    /// - Returns: 오래된 순서로 정렬된 키 배열
    func sortedByLRU(type: CacheMetadata.CacheType? = nil) -> [String] {
        let filtered: [CacheMetadata]
        if let type = type {
            filtered = metadata.values.filter { $0.type == type }
        } else {
            filtered = Array(metadata.values)
        }

        return filtered
            .sorted { $0.lastAccessedAt < $1.lastAccessedAt }
            .map { $0.key }
    }

    /// 만료된 키 목록 반환
    /// - Parameter expirationDays: 만료 기간 (일)
    /// - Returns: 만료된 키 배열
    func expiredKeys(expirationDays: Int) -> [String] {
        return metadata.values
            .filter { $0.isExpired(expirationDays: expirationDays) }
            .map { $0.key }
    }

    /// 특정 타입의 총 크기 계산
    /// - Parameter type: 캐시 타입
    /// - Returns: 총 크기 (바이트)
    func totalSize(for type: CacheMetadata.CacheType) -> Int64 {
        return metadata.values
            .filter { $0.type == type }
            .reduce(0) { $0 + $1.size }
    }

    /// 비디오 메타데이터 업데이트
    ///
    /// 기존 CacheMetadata에 VideoMetadata를 추가합니다.
    ///
    /// - Parameters:
    ///   - key: 캐시 키
    ///   - metadata: 비디오 메타데이터
    func updateVideoMetadata(for key: String, metadata: VideoMetadata) {
        guard var data = self.metadata[key] else { return }
        data.videoMetadata = metadata
        self.metadata[key] = data
        save()
    }

    /// 비디오 메타데이터 조회
    ///
    /// - Parameter key: 캐시 키
    /// - Returns: 비디오 메타데이터 (없으면 nil)
    func getVideoMetadata(for key: String) -> VideoMetadata? {
        return metadata[key]?.videoMetadata
    }

    /// 모든 메타데이터 삭제
    func removeAll() {
        metadata.removeAll()
        save()
    }

    /// UserDefaults에 메타데이터 저장
    private func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(Array(metadata.values)) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}

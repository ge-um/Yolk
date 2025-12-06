//
//  CacheMetadata.swift
//  Yolk
//
//  Created by 금가경 on 11/30/24.
//

import Foundation

/// 캐시 파일의 메타데이터를 관리하는 모델
///
/// 캐시된 파일의 정보를 추적하며, LRU(Least Recently Used) 정책과
/// 시간 기반 만료 정책을 구현하는 데 사용됩니다.
///
/// 각 캐시 파일은 고유한 키, 원본 URL, 파일 크기, 생성/접근 시간, 타입 정보를 가집니다.
/// 이 정보는 UserDefaults에 JSON 형태로 영구 저장됩니다.
internal struct CacheMetadata: Codable {

    /// 캐시 파일을 식별하는 고유 키
    ///
    /// 일반적으로 원본 URL의 SHA256 해시값이 사용됩니다.
    /// 이 키는 디스크에 저장되는 파일명으로도 사용됩니다.
    let key: String

    /// 캐시된 파일의 원본 URL (문자열)
    ///
    /// 동일한 URL에 대한 중복 다운로드를 방지하고,
    /// 캐시 히트를 확인하는 데 사용됩니다.
    let originalURL: String

    /// 캐시된 파일의 크기 (단위: 바이트)
    ///
    /// 전체 캐시 용량을 계산하고, LRU 정책으로 오래된 파일을
    /// 삭제할 때 사용됩니다.
    let size: Int64

    /// 캐시 파일이 생성된 시간
    ///
    /// 시간 기반 만료 정책에 사용됩니다.
    /// 생성 시간으로부터 일정 기간이 지나면 캐시가 만료된 것으로 간주됩니다.
    let createdAt: Date

    /// 캐시 파일에 마지막으로 접근한 시간
    ///
    /// LRU 정책에 사용됩니다.
    /// 오래 접근하지 않은 캐시부터 삭제하여 공간을 확보합니다.
    var lastAccessedAt: Date

    /// 캐시 파일의 타입
    ///
    /// 이미지, 동영상, 썸네일 등 파일 타입별로 다른 용량 제한과
    /// 정리 정책을 적용하기 위해 사용됩니다.
    let type: CacheType

    /// 캐시 파일의 타입을 나타내는 열거형
    ///
    /// 각 타입별로 다른 용량 제한과 정리 정책을 적용할 수 있습니다.
    enum CacheType: String, Codable {
        /// 일반 이미지 파일
        case image

        /// 동영상 파일
        case video

        /// 동영상의 썸네일 이미지
        case thumbnail

        /// 범용 파일 (타입 미지정)
        case generic
    }

    /// CacheMetadata 초기화
    ///
    /// 새로운 캐시 메타데이터를 생성합니다.
    /// 생성 시간과 마지막 접근 시간은 자동으로 현재 시간으로 설정됩니다.
    ///
    /// - Parameters:
    ///   - key: 캐시 파일의 고유 키
    ///   - originalURL: 원본 URL (문자열)
    ///   - size: 파일 크기 (바이트)
    ///   - type: 캐시 파일 타입
    init(key: String, originalURL: String, size: Int64, type: CacheType) {
        self.key = key
        self.originalURL = originalURL
        self.size = size
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        self.type = type
    }

    /// 마지막 접근 시간을 현재 시간으로 업데이트합니다.
    ///
    /// LRU 정책을 위해 캐시 파일에 접근할 때마다 호출해야 합니다.
    mutating func updateAccessTime() {
        self.lastAccessedAt = Date()
    }

    /// 캐시가 만료되었는지 확인합니다.
    ///
    /// 생성 시간으로부터 지정된 일수가 경과했는지 검사합니다.
    ///
    /// - Parameter expirationDays: 만료 기간 (일)
    /// - Returns: 만료 여부 (true: 만료됨, false: 유효함)
    func isExpired(expirationDays: Int) -> Bool {
        let expirationDate = Calendar.current.date(byAdding: .day, value: expirationDays, to: createdAt)
        return Date() > (expirationDate ?? createdAt)
    }
}

//
//  VideoCacheError.swift
//  Yolk
//
//  Created by 금가경 on 11/30/24.
//

import Foundation

/// 동영상 캐싱 과정에서 발생할 수 있는 에러
///
/// 동영상 다운로드, 썸네일 생성, 저장 등의 작업에서 발생하는 오류를 정의합니다.
/// `LocalizedError` 프로토콜을 준수하여 사용자에게 표시할 수 있는 로컬라이즈된 에러 메시지를 제공합니다.
public enum VideoCacheError: LocalizedError {

    /// 동영상 다운로드 실패
    ///
    /// 네트워크 요청이 실패했거나 서버가 비정상 응답을 반환한 경우 발생합니다.
    case downloadFailed

    /// 썸네일 생성 실패
    ///
    /// AVAssetImageGenerator를 사용한 썸네일 생성 과정에서 실패한 경우 발생합니다.
    case thumbnailGenerationFailed

    /// 디스크 저장 실패
    ///
    /// 동영상 또는 썸네일 데이터를 디스크에 쓰는 과정에서 실패한 경우 발생합니다.
    case diskWriteFailed

    /// 저장 공간 부족
    ///
    /// 디바이스의 사용 가능한 저장 공간이 부족한 경우 발생합니다.
    /// 동영상은 파일 크기가 크므로 이미지보다 자주 발생할 수 있습니다.
    case insufficientStorage

    /// 유효하지 않은 URL
    ///
    /// 제공된 URL이 유효하지 않거나 접근할 수 없는 경우 발생합니다.
    case invalidURL

    /// 캐시를 찾을 수 없음
    ///
    /// 요청한 동영상이 캐시에 존재하지 않는 경우 발생합니다.
    case cacheNotFound

    /// 사용자에게 표시될 에러 메시지
    public var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "동영상 다운로드에 실패했습니다"
        case .thumbnailGenerationFailed:
            return "썸네일 생성에 실패했습니다"
        case .diskWriteFailed:
            return "파일 저장에 실패했습니다"
        case .insufficientStorage:
            return "저장 공간이 부족합니다"
        case .invalidURL:
            return "잘못된 URL입니다"
        case .cacheNotFound:
            return "캐시된 동영상을 찾을 수 없습니다"
        }
    }
}

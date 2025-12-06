//
//  ImageCacheError.swift
//  Yolk
//
//  Created by 금가경 on 11/30/24.
//

import Foundation

/// 이미지 캐싱 과정에서 발생할 수 있는 에러
///
/// 이미지 다운로드, 디코딩, 저장 등의 작업에서 발생하는 오류를 정의합니다.
/// `LocalizedError` 프로토콜을 준수하여 사용자에게 표시할 수 있는 로컬라이즈된 에러 메시지를 제공합니다.
public enum ImageCacheError: LocalizedError {

    /// 이미지 다운로드 실패
    ///
    /// 네트워크 요청이 실패했거나 서버가 비정상 응답을 반환한 경우 발생합니다.
    case downloadFailed

    /// 이미지 디코딩 실패
    ///
    /// 다운로드된 데이터를 UIImage로 변환하는 과정에서 실패한 경우 발생합니다.
    case decodingFailed

    /// 이미지 다운샘플링 실패
    ///
    /// 메모리 효율을 위한 다운샘플링 과정에서 실패한 경우 발생합니다.
    case downsamplingFailed

    /// 디스크 저장 실패
    ///
    /// 이미지 데이터를 디스크에 쓰는 과정에서 실패한 경우 발생합니다.
    case diskWriteFailed

    /// 저장 공간 부족
    ///
    /// 디바이스의 사용 가능한 저장 공간이 부족한 경우 발생합니다.
    case insufficientStorage

    /// 유효하지 않은 URL
    ///
    /// 제공된 URL이 유효하지 않거나 접근할 수 없는 경우 발생합니다.
    case invalidURL

    /// 유효하지 않은 이미지 데이터
    ///
    /// 다운로드된 데이터가 이미지 형식이 아니거나 손상된 경우 발생합니다.
    case invalidImageData

    /// 사용자에게 표시될 에러 메시지
    public var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "이미지 다운로드에 실패했습니다"
        case .decodingFailed:
            return "이미지 디코딩에 실패했습니다"
        case .downsamplingFailed:
            return "이미지 다운샘플링에 실패했습니다"
        case .diskWriteFailed:
            return "파일 저장에 실패했습니다"
        case .insufficientStorage:
            return "저장 공간이 부족합니다"
        case .invalidURL:
            return "잘못된 URL입니다"
        case .invalidImageData:
            return "유효하지 않은 이미지 데이터입니다"
        }
    }
}

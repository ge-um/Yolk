//
//  VideoMetadataExtractor.swift
//  Yolk
//
//  Created by 금가경 on 12/06/25.
//

import AVFoundation
import CoreGraphics

/// 비디오 메타데이터 추출 유틸리티 (라이브러리 내부)
///
/// AVURLAsset을 사용하여 비디오 파일에서 메타데이터를 추출합니다.
/// 회전 변환(preferredTransform)을 고려하여 실제 표시 크기를 계산합니다.
internal struct VideoMetadataExtractor {

    /// 비디오 파일에서 메타데이터 추출
    ///
    /// - Parameter url: 로컬 비디오 파일 URL
    /// - Returns: VideoMetadata
    /// - Throws: 메타데이터 추출 실패 시 에러
    static func extract(from url: URL) async throws -> VideoMetadata {
        let asset = AVURLAsset(url: url)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoMetadataError.trackNotFound
        }

        let duration = try await asset.load(.duration)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)

        let actualSize = calculateActualSize(naturalSize: naturalSize, transform: transform)

        return VideoMetadata(
            width: actualSize.width,
            height: actualSize.height,
            durationSeconds: duration.seconds
        )
    }

    /// 회전 변환을 고려한 실제 크기 계산
    ///
    /// 비디오의 preferredTransform을 분석하여 90도 또는 270도 회전되어 있는지 확인합니다.
    /// 회전되어 있으면 width와 height를 교환하여 실제 표시 크기를 반환합니다.
    ///
    /// - Parameters:
    ///   - naturalSize: 원본 크기
    ///   - transform: preferredTransform
    /// - Returns: 회전 보정된 실제 크기
    private static func calculateActualSize(
        naturalSize: CGSize,
        transform: CGAffineTransform
    ) -> CGSize {
        // 90도 또는 270도 회전인지 확인
        // transform.a == 0 && |b| == 1 && |c| == 1 && d == 0
        let isRotated = transform.a == 0
            && abs(transform.b) == 1.0
            && abs(transform.c) == 1.0
            && transform.d == 0

        if isRotated {
            return CGSize(width: naturalSize.height, height: naturalSize.width)
        }

        return naturalSize
    }
}

/// 비디오 메타데이터 추출 에러
internal enum VideoMetadataError: Error {
    /// 비디오 트랙을 찾을 수 없음
    case trackNotFound

    /// 잘못된 비디오 형식
    case invalidFormat
}

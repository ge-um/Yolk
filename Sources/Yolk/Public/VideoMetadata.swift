//
//  VideoMetadata.swift
//  Yolk
//
//  Created by 금가경 on 12/06/25.
//

import Foundation
import CoreGraphics

/// 비디오 메타데이터
///
/// 비디오의 해상도, 종횡비, 길이 정보를 담고 있습니다.
/// 캐시된 비디오의 메타데이터를 빠르게 조회하여 UI 레이아웃에 활용할 수 있습니다.
///
/// # Example
/// ```swift
/// let metadata = await CacheService.video.getVideoMetadata(for: videoURL)
/// if let metadata = metadata {
///     videoView
///         .aspectRatio(metadata.aspectRatio, contentMode: .fit)
/// }
/// ```
public struct VideoMetadataPublic: Sendable {
    /// 비디오 너비 (픽셀)
    ///
    /// 회전 변환이 적용된 실제 표시 너비입니다.
    public let width: CGFloat

    /// 비디오 높이 (픽셀)
    ///
    /// 회전 변환이 적용된 실제 표시 높이입니다.
    public let height: CGFloat

    /// 종횡비 (width / height)
    ///
    /// SwiftUI의 `.aspectRatio(_:contentMode:)` modifier에 직접 사용할 수 있습니다.
    public let aspectRatio: CGFloat

    /// 비디오 길이 (초)
    public let durationSeconds: Double

    public init(width: CGFloat, height: CGFloat, durationSeconds: Double) {
        self.width = width
        self.height = height
        self.aspectRatio = height > 0 ? width / height : 1.0
        self.durationSeconds = durationSeconds
    }

    internal init(from internal: VideoMetadata) {
        self.width = `internal`.width
        self.height = `internal`.height
        self.aspectRatio = `internal`.aspectRatio
        self.durationSeconds = `internal`.durationSeconds
    }
}

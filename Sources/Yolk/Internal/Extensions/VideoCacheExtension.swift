//
//  VideoCacheExtension.swift
//  Yolk
//
//  Created by 금가경 on 12/05/24.
//

import UIKit
import AVFoundation

/// CacheManager의 동영상 특화 Extension
///
/// 동영상 다운로드, 썸네일 생성 등 동영상 처리 기능을 제공합니다.
extension CacheManager {

    /// URL에서 동영상 로컬 경로를 가져옵니다 (캐시 우선, 없으면 다운로드)
    ///
    /// - Parameters:
    ///   - url: 동영상 URL
    ///   - modifier: HTTP 요청을 수정하는 modifier
    ///   - progressHandler: 다운로드 진행률 콜백
    /// - Returns: 로컬 파일 URL
    /// - Throws: 다운로드 실패 시 에러
    func getVideoURL(
        from url: URL,
        modifier: RequestModifier? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        if let cachedURL = await getCachedFileURL(from: url) {
            return cachedURL
        }

        _ = try await getFile(
            from: url,
            cacheType: .video,
            modifier: modifier,
            progressHandler: progressHandler
        )

        guard let localURL = await getCachedFileURL(from: url) else {
            throw VideoCacheError.cacheNotFound
        }

        // 메타데이터 자동 추출 (백그라운드)
        let key = cacheKey(from: url)
        Task(priority: .utility) {
            await extractAndCacheMetadata(for: localURL, cacheKey: key)
        }

        return localURL
    }

    /// 동영상의 썸네일 이미지를 가져옵니다.
    ///
    /// 썸네일이 캐시에 있으면 캐시에서 로드하고, 없으면 동영상에서 생성합니다.
    ///
    /// - Parameters:
    ///   - url: 동영상 URL
    ///   - targetSize: 썸네일 크기 (기본: 200x200)
    ///   - time: 썸네일 추출 시간 (초, 기본: 0.0)
    ///   - modifier: HTTP 요청을 수정하는 modifier
    /// - Returns: 썸네일 UIImage
    /// - Throws: 썸네일 생성 실패 시 에러
    func getThumbnail(
        from url: URL,
        targetSize: CGSize = CGSize(width: 200, height: 200),
        at time: Double = 0.0,
        modifier: RequestModifier? = nil
    ) async throws -> UIImage {
        let thumbnailKey = "\(url.absoluteString)_thumbnail_\(time)"
        let thumbnailURL = URL(string: thumbnailKey)!

        if let cachedThumbnailURL = await getCachedFileURL(from: thumbnailURL),
           let data = try? Data(contentsOf: cachedThumbnailURL),
           let thumbnail = UIImage(data: data) {
            return thumbnail
        }

        let videoURL = try await getVideoURL(from: url, modifier: modifier)

        let thumbnail = try await generateThumbnail(
            from: videoURL,
            targetSize: targetSize,
            at: time
        )

        if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
            try await saveThumbnailToCache(
                data: thumbnailData,
                originalVideoURL: url,
                time: time
            )
        }

        return thumbnail
    }

    /// 동영상에서 썸네일을 생성합니다.
    ///
    /// - Parameters:
    ///   - videoURL: 로컬 동영상 파일 URL
    ///   - targetSize: 썸네일 크기
    ///   - time: 썸네일 추출 시간 (초)
    /// - Returns: 생성된 UIImage
    /// - Throws: 썸네일 생성 실패 시 에러
    private func generateThumbnail(
        from videoURL: URL,
        targetSize: CGSize,
        at time: Double
    ) async throws -> UIImage {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = targetSize

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: cmTime, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            throw VideoCacheError.thumbnailGenerationFailed
        }
    }

    /// 썸네일을 캐시에 저장합니다.
    ///
    /// - Parameters:
    ///   - data: 썸네일 이미지 데이터
    ///   - originalVideoURL: 원본 동영상 URL
    ///   - time: 썸네일 추출 시간 (초)
    private func saveThumbnailToCache(
        data: Data,
        originalVideoURL: URL,
        time: Double
    ) async throws {
        let thumbnailKey = "\(originalVideoURL.absoluteString)_thumbnail_\(time)"
        let thumbnailURL = URL(string: thumbnailKey)!

        let key = cacheKey(from: thumbnailURL)
        try await saveToCache(
            data: data,
            key: key,
            originalURL: thumbnailURL,
            cacheType: .thumbnail
        )
    }

    /// 동영상이 캐시에 존재하는지 확인합니다.
    ///
    /// - Parameter url: 동영상 URL
    /// - Returns: 캐시 존재 여부
    func hasVideoCache(for url: URL) async -> Bool {
        return await getCachedFileURL(from: url) != nil
    }

    /// 동영상 썸네일이 캐시에 존재하는지 확인합니다.
    ///
    /// - Parameters:
    ///   - url: 동영상 URL
    ///   - time: 썸네일 추출 시간 (초, 기본: 0.0)
    /// - Returns: 썸네일 캐시 존재 여부
    func hasThumbnailCache(for url: URL, at time: Double = 0.0) async -> Bool {
        let thumbnailKey = "\(url.absoluteString)_thumbnail_\(time)"
        let thumbnailURL = URL(string: thumbnailKey)!
        return await getCachedFileURL(from: thumbnailURL) != nil
    }

    /// 비디오 메타데이터를 추출하여 캐시에 저장합니다.
    ///
    /// 백그라운드에서 실행되며, 실패해도 비디오 재생에 영향을 주지 않습니다.
    ///
    /// - Parameters:
    ///   - url: 로컬 비디오 파일 URL
    ///   - cacheKey: 캐시 키
    private func extractAndCacheMetadata(for url: URL, cacheKey: String) async {
        do {
            let metadata = try await VideoMetadataExtractor.extract(from: url)
            await metadataManager.updateVideoMetadata(for: cacheKey, metadata: metadata)
        } catch {
            // 무시 - 비치명적 에러
            // 다음번 조회 시 다시 시도
        }
    }
}

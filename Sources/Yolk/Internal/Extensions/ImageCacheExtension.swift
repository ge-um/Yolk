//
//  ImageCacheExtension.swift
//  Yolk
//
//  Created by 금가경 on 12/05/24.
//

import UIKit

/// CacheManager의 이미지 특화 Extension
///
/// 이미지 다운샘플링, UIImage 반환 등 이미지 처리 기능을 제공합니다.
extension CacheManager {

    /// URL에서 이미지를 가져옵니다 (캐시 우선, 없으면 다운로드)
    ///
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - targetSize: 다운샘플링 목표 크기 (nil이면 원본 크기)
    ///   - modifier: HTTP 요청을 수정하는 modifier
    ///   - progressHandler: 다운로드 진행률 콜백
    /// - Returns: UIImage
    /// - Throws: 다운로드 또는 이미지 변환 실패 시 에러
    func getImage(
        from url: URL,
        targetSize: CGSize? = nil,
        modifier: RequestModifier? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> UIImage {
        let data = try await getFile(
            from: url,
            cacheType: .image,
            modifier: modifier,
            progressHandler: progressHandler
        )

        if let targetSize = targetSize {
            return try downsample(data: data, to: targetSize)
        }

        guard let image = UIImage(data: data) else {
            throw ImageCacheError.invalidImageData
        }

        return image
    }

    /// 이미지 데이터를 다운샘플링하여 메모리 효율적으로 로드합니다.
    ///
    /// 큰 이미지를 작은 크기로 표시할 때 메모리를 절약할 수 있습니다.
    ///
    /// - Parameters:
    ///   - data: 이미지 데이터
    ///   - targetSize: 목표 크기
    /// - Returns: 다운샘플링된 UIImage
    /// - Throws: 다운샘플링 실패 시 에러
    nonisolated func downsample(data: Data, to targetSize: CGSize) throws -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            throw ImageCacheError.downsamplingFailed
        }

        let maxDimensionInPixels = max(targetSize.width, targetSize.height)

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            throw ImageCacheError.downsamplingFailed
        }

        return UIImage(cgImage: downsampledImage)
    }

    /// 이미지가 캐시에 존재하는지 확인합니다.
    ///
    /// - Parameter url: 이미지 URL
    /// - Returns: 캐시 존재 여부
    func hasImageCache(for url: URL) async -> Bool {
        return await getCachedFileURL(from: url) != nil
    }

    /// 캐시에서 이미지를 가져옵니다 (메모리/디스크 캐시만 확인, 다운로드 안 함)
    ///
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - targetSize: 다운샘플링 목표 크기 (nil이면 원본 크기)
    /// - Returns: 캐시된 UIImage (없으면 nil)
    func getCachedImage(from url: URL, targetSize: CGSize? = nil) async -> UIImage? {
        guard let data = await getCachedData(from: url) else {
            return nil
        }

        if let targetSize = targetSize {
            return try? downsample(data: data, to: targetSize)
        }

        return UIImage(data: data)
    }
}

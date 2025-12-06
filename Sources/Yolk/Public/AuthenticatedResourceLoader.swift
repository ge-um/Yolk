//
//  AuthenticatedResourceLoader.swift
//  Yolk
//
//  Created by 금가경 on 11/30/24.
//

import AVFoundation
import Foundation

/// AVAsset의 리소스 로딩을 관리하며 인증 헤더를 추가합니다.
///
/// 206 Partial Content 요청을 지원하며,
/// RequestModifier를 통해 커스텀 헤더를 추가할 수 있습니다.
public final class AuthenticatedResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    private var pendingRequests: [AVAssetResourceLoadingRequest: URLSessionDataTask] = [:]
    private let session = URLSession.shared
    private let modifier: RequestModifier?
    private let customScheme: String

    /// AuthenticatedResourceLoader 초기화
    ///
    /// - Parameters:
    ///   - customScheme: 인증이 필요한 커스텀 scheme (예: "custom-video")
    ///   - modifier: URLRequest를 수정하는 modifier (기본값: nil)
    public init(customScheme: String, modifier: RequestModifier? = nil) {
        self.customScheme = customScheme
        self.modifier = modifier
        super.init()
    }

    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let url = loadingRequest.request.url else {
            return false
        }

        let request = createRequest(from: url, loadingRequest: loadingRequest)
        let task = createDataTask(with: request, loadingRequest: loadingRequest)

        pendingRequests[loadingRequest] = task
        task.resume()

        return true
    }

    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        pendingRequests[loadingRequest]?.cancel()
        pendingRequests.removeValue(forKey: loadingRequest)
    }

    /// URLRequest를 생성합니다.
    ///
    /// - Parameters:
    ///   - url: 요청할 URL
    ///   - loadingRequest: AVAssetResourceLoadingRequest
    /// - Returns: 생성된 URLRequest
    private func createRequest(from url: URL, loadingRequest: AVAssetResourceLoadingRequest) -> URLRequest {
        let actualURL = convertToActualURL(url)
        var request = URLRequest(url: actualURL)

        if let modifier = modifier,
           let modifiedRequest = modifier.modified(for: request) {
            request = modifiedRequest
        }

        addRangeHeader(to: &request, loadingRequest: loadingRequest)

        return request
    }

    /// Range 헤더를 추가합니다.
    ///
    /// - Parameters:
    ///   - request: URLRequest
    ///   - loadingRequest: AVAssetResourceLoadingRequest
    private func addRangeHeader(to request: inout URLRequest, loadingRequest: AVAssetResourceLoadingRequest) {
        guard let dataRequest = loadingRequest.dataRequest else { return }

        let requestedOffset = dataRequest.requestedOffset
        let requestedLength = dataRequest.requestedLength

        let rangeEnd: String
        if dataRequest.requestsAllDataToEndOfResource {
            rangeEnd = ""
        } else {
            rangeEnd = "\(requestedOffset + Int64(requestedLength) - 1)"
        }

        request.setValue("bytes=\(requestedOffset)-\(rangeEnd)", forHTTPHeaderField: "Range")
    }

    /// URLSessionDataTask를 생성합니다.
    ///
    /// - Parameters:
    ///   - request: URLRequest
    ///   - loadingRequest: AVAssetResourceLoadingRequest
    /// - Returns: 생성된 URLSessionDataTask
    private func createDataTask(with request: URLRequest, loadingRequest: AVAssetResourceLoadingRequest) -> URLSessionDataTask {
        return session.dataTask(with: request) { [weak self, weak loadingRequest] data, response, error in
            guard let self = self, let loadingRequest = loadingRequest else { return }

            defer {
                self.pendingRequests.removeValue(forKey: loadingRequest)
            }

            self.handleResponse(data: data, response: response, error: error, loadingRequest: loadingRequest)
        }
    }

    /// 네트워크 응답을 처리합니다.
    ///
    /// - Parameters:
    ///   - data: 응답 데이터
    ///   - response: URLResponse
    ///   - error: 에러
    ///   - loadingRequest: AVAssetResourceLoadingRequest
    private func handleResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        loadingRequest: AVAssetResourceLoadingRequest
    ) {
        if let error = error {
            loadingRequest.finishLoading(with: error)
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            loadingRequest.finishLoading(with: VideoCacheError.downloadFailed)
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            loadingRequest.finishLoading(with: VideoCacheError.downloadFailed)
            return
        }

        configureContentInformation(from: httpResponse, loadingRequest: loadingRequest)

        if let data = data {
            loadingRequest.dataRequest?.respond(with: data)
        }

        loadingRequest.finishLoading()
    }

    /// Content 정보를 설정합니다.
    ///
    /// - Parameters:
    ///   - httpResponse: HTTPURLResponse
    ///   - loadingRequest: AVAssetResourceLoadingRequest
    private func configureContentInformation(from httpResponse: HTTPURLResponse, loadingRequest: AVAssetResourceLoadingRequest) {
        if let contentType = httpResponse.mimeType {
            loadingRequest.contentInformationRequest?.contentType = contentType
        }

        if let contentRangeHeader = httpResponse.allHeaderFields["Content-Range"] as? String,
           let totalSize = contentRangeHeader.split(separator: "/").last,
           let size = Int64(totalSize) {
            loadingRequest.contentInformationRequest?.contentLength = size
        } else {
            let contentLength = httpResponse.expectedContentLength
            if contentLength > 0 {
                loadingRequest.contentInformationRequest?.contentLength = contentLength
            }
        }

        loadingRequest.contentInformationRequest?.isByteRangeAccessSupported = true
    }

    /// Custom scheme을 실제 URL로 변환합니다.
    ///
    /// - Parameter url: Custom scheme URL (예: custom-video://...)
    /// - Returns: http 또는 https URL
    private func convertToActualURL(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if url.scheme == customScheme {
            components?.scheme = "http"
        }

        return components?.url ?? url
    }

    /// 모든 대기 중인 요청 취소
    public func cancelAllRequests() {
        pendingRequests.values.forEach { $0.cancel() }
        pendingRequests.removeAll()
    }

    deinit {
        cancelAllRequests()
    }
}

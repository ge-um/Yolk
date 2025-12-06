//
//  GenericDownloadManager.swift
//  Yolk
//
//  Created by 금가경 on 12/05/24.
//

import Foundation

/// 파일 다운로드 매니저 (라이브러리 내부 구현)
///
/// 이미지, 동영상 등 모든 파일 타입의 다운로드를 처리하는 내부 구현체입니다.
/// RequestModifier를 통해 프로젝트별 인증 헤더를 주입할 수 있습니다.
/// CacheManager가 이 클래스를 내부적으로 사용합니다.
internal actor DownloadManager: NSObject {

    var session: URLSession!

    var activeTasks: [URL: URLSessionDownloadTask] = [:]
    var progressHandlers: [URL: @Sendable (Double) -> Void] = [:]
    var completionHandlers: [URL: [(Result<URL, Error>) -> Void]] = [:]

    /// DownloadManager 초기화
    ///
    /// - Parameter sessionConfiguration: URLSession 설정 (기본값: .default)
    init(sessionConfiguration: URLSessionConfiguration = .default) {
        super.init()

        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated

        self.session = URLSession(
            configuration: sessionConfiguration,
            delegate: self,
            delegateQueue: queue
        )
    }

    /// URL에서 파일을 다운로드합니다.
    ///
    /// - Parameters:
    ///   - url: 다운로드할 파일의 URL
    ///   - modifier: HTTP 요청을 수정하는 modifier (nil이면 헤더 추가 없음)
    ///   - progressHandler: 다운로드 진행률 콜백 (0.0 ~ 1.0)
    /// - Returns: 다운로드된 파일의 로컬 URL
    /// - Throws: 다운로드 실패 시 에러
    func download(
        from url: URL,
        modifier: RequestModifier? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        // 이미 진행 중인 다운로드가 있으면 대기
        if activeTasks[url] != nil {
            return try await withCheckedThrowingContinuation { continuation in
                if completionHandlers[url] == nil {
                    completionHandlers[url] = []
                }
                completionHandlers[url]?.append { result in
                    continuation.resume(with: result)
                }
            }
        }

        // URLRequest 생성 및 헤더 설정
        var request = URLRequest(url: url)
        if let modifier = modifier {
            guard let modifiedRequest = modifier.modified(for: request) else {
                throw URLError(.cancelled)
            }
            request = modifiedRequest
        }

        // 다운로드 태스크 생성
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: request)

            activeTasks[url] = task
            progressHandlers[url] = progressHandler
            completionHandlers[url] = [{ result in
                continuation.resume(with: result)
            }]

            task.resume()
        }
    }

    /// resumeData를 사용하여 중단된 다운로드를 재개합니다.
    ///
    /// - Parameters:
    ///   - resumeData: 중단된 다운로드의 resumeData
    ///   - url: 다운로드 중이던 파일의 URL (진행률 추적용)
    ///   - progressHandler: 다운로드 진행률 콜백
    /// - Returns: 다운로드된 파일의 로컬 URL
    /// - Throws: 다운로드 실패 시 에러
    func resumeDownload(
        with resumeData: Data,
        for url: URL,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(withResumeData: resumeData)

            activeTasks[url] = task
            progressHandlers[url] = progressHandler
            completionHandlers[url] = [{ result in
                continuation.resume(with: result)
            }]

            task.resume()
        }
    }

    /// 특정 URL의 다운로드를 취소합니다.
    ///
    /// - Parameter url: 취소할 다운로드의 URL
    func cancelDownload(for url: URL) {
        activeTasks[url]?.cancel()
        cleanup(for: url)
    }

    /// 모든 진행 중인 다운로드를 취소합니다.
    func cancelAllDownloads() {
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
        progressHandlers.removeAll()
        completionHandlers.removeAll()
    }

    private func cleanup(for url: URL) {
        activeTasks.removeValue(forKey: url)
        progressHandlers.removeValue(forKey: url)
        completionHandlers.removeValue(forKey: url)
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let originalURL = downloadTask.originalRequest?.url else { return }

        // 임시 파일을 영구 위치로 즉시 이동 (시스템이 삭제하기 전에)
        // moveItem을 사용하면 파일 복사 없이 포인터만 이동하므로 효율적
        let permanentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.moveItem(at: location, to: permanentURL)

            Task {
                await handleDownloadCompletion(
                    for: originalURL,
                    location: permanentURL,
                    error: downloadTask.error
                )
            }
        } catch {
            Task {
                await handleDownloadError(for: originalURL, error: error)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let originalURL = downloadTask.originalRequest?.url else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        Task {
            await handleProgress(for: originalURL, progress: progress)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let originalURL = task.originalRequest?.url,
              let error = error else { return }

        Task {
            await handleDownloadError(for: originalURL, error: error)
        }
    }

    private func handleDownloadCompletion(
        for url: URL,
        location: URL,
        error: Error?
    ) {
        let handlers = completionHandlers[url] ?? []
        for handler in handlers {
            if let error = error {
                handler(.failure(error))
            } else {
                handler(.success(location))
            }
        }
        cleanup(for: url)
    }

    private func handleProgress(for url: URL, progress: Double) {
        progressHandlers[url]?(progress)
    }

    private func handleDownloadError(for url: URL, error: Error) {
        let handlers = completionHandlers[url] ?? []
        for handler in handlers {
            handler(.failure(error))
        }
        cleanup(for: url)
    }
}

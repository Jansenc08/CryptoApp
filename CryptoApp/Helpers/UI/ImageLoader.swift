//
//  ImageLoader.swift
//  CryptoApp
//
//  Image loading helper that integrates with existing CacheService
//

import UIKit
import Foundation

/// Lightweight image loader that uses the existing CacheService for optimal integration
@objc final class ImageLoader: NSObject {
    
    // MARK: - Singleton
    @objc static let shared = ImageLoader()
    
    // MARK: - Properties
    
    /// Track active downloads to prevent duplicates
    private var activeDownloads = Set<String>()

    /// Map URL -> operation for cancellation/promotion
    private var operationsByURL = [String: ImageDownloadOperation]()

    /// Coalesce multiple callbacks for the same URL
    private var completionsByURL = [String: [(UIImage?) -> Void]]()

    /// Serial queue to synchronize internal state
    private let syncQueue = DispatchQueue(label: "image.loader.sync")
    
    /// Operation queue for managing concurrent downloads
    private let downloadQueue = OperationQueue()
    
    /// URLs pending prefetch (lower priority)
    private var prefetchURLs = Set<String>()
    
    // MARK: - Configuration
    
    private struct Config {
        static let maxConcurrentDownloads = 6
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupDownloadQueue()
    }
    
    private func setupDownloadQueue() {
        downloadQueue.maxConcurrentOperationCount = Config.maxConcurrentDownloads
        downloadQueue.qualityOfService = .utility
    }
    
    // MARK: - Public Interface
    
    /// Load image with completion handler, using existing CacheService
    @objc(loadImageFrom:completion:)
    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        // 1. Check existing CacheService first (fastest)
        if let cachedImage = CacheService.shared.getCachedImage(for: urlString) {
            completion(cachedImage)
            return
        }

        // 2. If an operation is already in-flight, coalesce completion and promote priority
        var shouldStartDownload = false
        syncQueue.sync {
            // Queue completion
            var list = completionsByURL[urlString] ?? []
            list.append(completion)
            completionsByURL[urlString] = list

            if let op = operationsByURL[urlString] {
                // Promote prefetch to high priority if now visible
                if op.priority == .low { op.promoteToHighPriority() }
            } else {
                shouldStartDownload = true
            }
        }

        if shouldStartDownload {
            downloadImage(from: url, priority: .high)
        }
    }
    
    /// Prefetch images for upcoming cells (for scrolling optimization)
    @objc(prefetchImages:)
    func prefetchImages(urls: [String]) {
        for urlString in urls {
            guard !urlString.isEmpty,
                  let url = URL(string: urlString),
                  !isLoading(urlString: urlString),
                  CacheService.shared.getCachedImage(for: urlString) == nil else {
                continue
            }
            
            syncQueue.async { [weak self] in
                self?.prefetchURLs.insert(urlString)
            }
            
            // Start prefetch download with lower priority
            downloadImage(from: url, priority: .low)
        }
    }
    
    /// Cancel prefetch operations
    @objc func cancelPrefetching() {
        downloadQueue.operations.forEach { operation in
            if let imageOp = operation as? ImageDownloadOperation, imageOp.priority == .low {
                imageOp.cancel()
            }
        }
        syncQueue.async { [weak self] in
            self?.prefetchURLs.removeAll()
        }
    }

    /// Cancel any in-flight load for a specific URL (called by reusable views on reuse)
    @objc(cancelLoadFor:)
    func cancelLoad(for urlString: String) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            if let op = self.operationsByURL[urlString] {
                op.cancel()
            }
            self.operationsByURL.removeValue(forKey: urlString)
            self.activeDownloads.remove(urlString)
            self.completionsByURL.removeValue(forKey: urlString)
            self.prefetchURLs.remove(urlString)
        }
    }
    
    // MARK: - Private Methods
    
    private func downloadImage(from url: URL, priority: Priority) {
        let urlString = url.absoluteString

        // Prevent duplicate downloads
        var shouldEnqueue = false
        syncQueue.sync {
            if !activeDownloads.contains(urlString) {
                activeDownloads.insert(urlString)
                shouldEnqueue = true
            }
        }
        guard shouldEnqueue else { return }

        let operation = ImageDownloadOperation(url: url, priority: priority) { [weak self] image in
            guard let self = self else { return }

            // Cache downsampled image
            if let image = image {
                CacheService.shared.storeCachedImage(image, for: urlString)
            }

            // Drain all coalesced completions
            var completions: [(UIImage?) -> Void] = []
            self.syncQueue.sync {
                completions = self.completionsByURL[urlString] ?? []
                self.completionsByURL.removeValue(forKey: urlString)
                self.operationsByURL.removeValue(forKey: urlString)
                self.activeDownloads.remove(urlString)
            }
            DispatchQueue.main.async {
                if completions.isEmpty {
                    // No coalesced completions, nothing to deliver
                } else {
                    completions.forEach { $0(image) }
                }
            }
        }

        // Track operation
        syncQueue.async { [weak self] in
            self?.operationsByURL[urlString] = operation
        }

        downloadQueue.addOperation(operation)
    }

    private func isLoading(urlString: String) -> Bool {
        var loading = false
        syncQueue.sync { loading = activeDownloads.contains(urlString) || operationsByURL[urlString] != nil }
        return loading
    }
}

// MARK: - Image Download Operation

private class ImageDownloadOperation: Operation, @unchecked Sendable {
    enum Priority {
        case high, low
    }
    
    private let url: URL
    let priority: Priority
    private let completion: (UIImage?) -> Void
    private var task: URLSessionDataTask?
    private let maxDimension: CGFloat = 64
    
    init(url: URL, priority: Priority, completion: @escaping (UIImage?) -> Void) {
        self.url = url
        self.priority = priority
        self.completion = completion
        super.init()
    }
    
    override func main() {
        guard !isCancelled else { return }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        // Use optimized URL session configuration
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15.0
        let session = URLSession(configuration: config)
        
        task = session.dataTask(with: url) { [weak self] data, response, error in
            defer { semaphore.signal() }
            
            guard let self = self, !self.isCancelled else { return }
            
            if let data = data, let image = downsampleImage(data: data, maxDimension: self.maxDimension) {
                DispatchQueue.main.async {
                    self.completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    self.completion(nil)
                }
            }
        }
        
        // Apply URLSession task priority based on operation priority
        switch priority {
        case .high: task?.priority = URLSessionTask.highPriority
        case .low: task?.priority = URLSessionTask.lowPriority
        }

        task?.resume()
        semaphore.wait()
    }
    
    override func cancel() {
        task?.cancel()
        super.cancel()
    }

    func promoteToHighPriority() {
        guard !isCancelled else { return }
        if priority == .low {
            // Note: URLSessionTask priority can be adjusted after resume
            task?.priority = URLSessionTask.highPriority
        }
    }
}

// MARK: - Priority Type Alias

private typealias Priority = ImageDownloadOperation.Priority

// MARK: - Image Downsampling

private func downsampleImage(data: Data, maxDimension: CGFloat) -> UIImage? {
    let options: [CFString: Any] = [
        kCGImageSourceShouldCache: false
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return nil }

    let scale = UIScreen.main.scale
    let downsampleOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension * scale)
    ]

    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else { return nil }
    return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
}

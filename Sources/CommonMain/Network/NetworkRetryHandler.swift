import Network
import Foundation

final class NetworkRetryHandler {
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkRetryQueue")
    private var onOnlineCallbacks: [() -> Void] = []
    private var isInternetAvailable = false
    
    private let testUrl = URL(string: "https://google.com")!
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            if path.status == .satisfied {
                self.checkInternetAccess { hasInternet in
                    if hasInternet && !self.isInternetAvailable {
                        self.isInternetAvailable = true
                        logger.info("[NetworkRetryHandler] internet became available.")
                        DispatchQueue.main.async {
                            self.onOnlineCallbacks.forEach { $0() }
                            self.onOnlineCallbacks.removeAll()
                        }
                    } else if !hasInternet {
                        self.isInternetAvailable = false
                        logger.info("[NetworkRetryHandler] Network available but no internet access")
                    }
                }
            } else {
                self.isInternetAvailable = false
                logger.info("[NetworkRetryHandler] Network not satisfied")
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    func retryWhenOnline(_ onOnline: @escaping () -> Void) {
        if isInternetAvailable {
            DispatchQueue.main.async {
                onOnline()
            }
        } else {
            onOnlineCallbacks.append(onOnline)
        }
    }
    
    private func checkInternetAccess(completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: testUrl)
        request.timeoutInterval = 5
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    deinit {
        monitor.cancel()
    }
}



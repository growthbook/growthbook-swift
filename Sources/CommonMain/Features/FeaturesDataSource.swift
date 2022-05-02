import Foundation


/// DataSource for Feature API
public class FeaturesDataSource {
    let dispatcher: NetworkProtocol
    
    init(dispatcher: NetworkProtocol = CoreNetworkClient()) {
        self.dispatcher = dispatcher
    }

    /// Executes API Call to fetch features
    func fetchFeatures(apiUrl: String, fetchResult: @escaping (Result<Data, Error>) -> Void) {
        dispatcher.consumeGETRequest(url: apiUrl, successResult: { data in
            fetchResult(.success(data))
        }, errorResult: { error in
            fetchResult(.failure(error))
        })
    }

}

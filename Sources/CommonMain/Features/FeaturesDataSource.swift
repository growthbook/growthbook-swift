import Foundation

/// DataSource for Feature API
class FeaturesDataSource {
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
    
    /// Executes API Call to fetch features and send data for remote eval
    func fetchRemoteEval(apiUrl: String, params: RemoteEvalParams?, fetchResult: @escaping (Result<Data, Error>) -> Void) {
        var payload: [String: Any] = [:]
        
        if let params = params {
            payload["attributes"] = params.attributes?.object
            payload["forcedFeatures"] = params.forcedFeatures?.arrayObject
            payload["forcedVariations"] = params.forcedVariations?.object
        }
                 
        dispatcher.consumePOSTRequest(url: apiUrl, params: payload) { data in
            fetchResult(.success(data))
        } errorResult: { error in
            fetchResult(.failure(error))
        }
    }
}

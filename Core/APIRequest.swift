//
//  APIRequest.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import os.log

public typealias APIRequestCompletion = (APIRequest.Response?, Error?) -> Void

public class APIRequest {
    
    private static let callbackQueue = DispatchQueue(label: "APIRequest callback queue", qos: .utility)
    
    public struct Response {
        
        var data: Data?
        var etag: String?
        
    }
    
    public enum HTTPMethod: String {
        case get = "GET"
        case head = "HEAD"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case connect = "CONNECT"
        case options = "OPTIONS"
        case trace = "TRACE"
        case patch = "PATCH"
    }
    
    @discardableResult
    public static func request(url: URL,
                               method: HTTPMethod = .get,
                               parameters: [String: String]? = nil,
                               completion: @escaping APIRequestCompletion) -> URLSessionDataTask {
        os_log("Requesting %s", log: generalLog, type: .debug, url.absoluteString)
                
        let session = URLSession.shared
        
        let url = url.addParams(parameters ?? [:])
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = APIHeaders().defaultHeaders
        urlRequest.httpMethod = method.rawValue

        let task = session.dataTask(with: urlRequest) {
            (data, response, error) in
            
            let httpResponse = response as? HTTPURLResponse
            
            os_log("Request for %s completed with response code: %s and headers %s",
                   log: generalLog,
                   type: .debug,
                   url.absoluteString,
                   String(describing: httpResponse?.statusCode),
                   String(describing: httpResponse?.allHeaderFields))
            
            if let error = error {
                completion(nil, error)
            } else if let error = httpResponse?.validateStatusCode(statusCode: 200..<300) { 
                completion(nil, error)
            } else {
                var etag = httpResponse?.headerValue(for: APIHeaders.Name.etag)
                
                // Handle weak etags
                etag = etag?.dropPrefix(prefix: "W/")
                completion(Response(data: data, etag: etag), nil)
            }
        }
        task.resume()
        return task
    }
}

public extension HTTPURLResponse {
        
    enum HTTPURLResponseError: Error {
        case invalidStatusCode
    }
    
    func validateStatusCode<S: Sequence>(statusCode acceptedStatusCodes: S) -> Error? where S.Iterator.Element == Int {
        return acceptedStatusCodes.contains(statusCode) ? nil : HTTPURLResponseError.invalidStatusCode
    }
    
    fileprivate func headerValue(for name: String) -> String? {
        let lname = name.lowercased()
        return allHeaderFields.filter { ($0.key as? String)?.lowercased() == lname }.first?.value as? String
    }
}

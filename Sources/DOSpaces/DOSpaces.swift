//
//  DigitalOceanSpaces.swift
//  App
//
//  Created by Simone Deriu on 15/05/2020.
//

import Vapor
import S3Signer
import Service
import SwiftyXMLParser

public final class DOSpaces : Service {
    
    var s3signer : S3Signer
    
    /// Configuration
    public private(set) var config: Config
    
    /// Initializer
    public init(_ config: Config, services: inout Services) throws {
        self.config = config
        s3signer = try S3Signer(S3Signer.Config(accessKey: config.accessKey , secretKey: config.secretKey , region: config.region))
        services.register(s3signer)
    }
    
    
    public struct Config: Service {
        
        
        let endpoint: String
        let cdn: Bool?
        /// AWS Access Key
        let accessKey: String
        
        /// AWS Secret Key
        let secretKey: String
        
        /// The region where S3 bucket is located.
        public let region: Region
        
        let securityToken : String?
        
        /// Initalizer
        public init(endpoint: String, accessKey: String, secretKey: String, region: Region, cdn: Bool?, securityToken: String? = nil) {
            self.endpoint = endpoint
            self.accessKey = accessKey
            self.secretKey = secretKey
            self.region = region
            self.cdn = cdn
            self.securityToken = securityToken
        }
    }
 
}

extension DOSpaces {
    
    /// Upload a file
    /// Return the url string of the file or the empty string if the file is not valid
    public func upload(_ req: Request, path: String, file: File, name: String?) throws -> Future<String> {
        let s3 = try req.makeS3Signer()
        let url = "\(self.config.endpoint)/\(path)/\( name ?? file.filename )"
        var headers = try s3.headers(for: .PUT, urlString: url, payload: Payload.bytes(file.data))
        headers.add(name: "x-amz-acl", value: "public-read")
        return try req.make(Client.self).put(url, headers: headers) { put in
            return put.http.body = HTTPBody(data: file.data)
        }.map { response in
            guard response.http.status == .ok else { throw Abort(response.http.status)}
            if(self.config.cdn ?? false){
                return url.replacingOccurrences(of: ".digitaloceanspaces", with: ".cdn.digitaloceanspaces")
            }
            return url
        }
    }
    
    ///Delete a file
    ///Return status 204 if deleted
    public func delete(_ req: Request, path: String, name: String) throws -> Future<HTTPStatus> {
        let s3 = try req.makeS3Signer()
        let url = "\(self.config.endpoint)/\(path)/\(name)"
        let headers = try s3.headers(for: .DELETE, urlString: url, payload: Payload.none )
        return try req.make(Client.self).delete(url, headers: headers).map(to: HTTPStatus.self){
            response in
            return response.http.status
        }
    }
    
    ///List all files in bucket
    ///Return a xml string representation of the bucket
    public func list(_ req: Request) throws -> Future<String> {
        let s3 = try req.makeS3Signer()
        let url = self.config.endpoint
        let headers = try s3.headers(for: .GET, urlString: url, payload: Payload.none )
        return try req.make(Client.self).get(url, headers: headers).map(to: String.self){ response in
            return response.http.body.description
        }
    }
    
    ///Get all the keys
    ///Return an array containing all the keys in the bucket
    public func keys(_ req: Request) throws -> Future<[String]> {
        return try req.DOSpaces().list(req).map{ xml in
            guard let data = xml.data(using: .utf8) else { throw Abort(.noContent) }
            let xml = XML.parse(data)
            var keys : [String] = []
            for key in xml.ListBucketResult.Contents {
                keys.append(key.Key.text ?? "")
            }
            return keys
        }
    }
}



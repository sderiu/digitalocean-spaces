//
//  DigitalOceanSpaces.swift
//  App
//
//  Created by Simone Deriu on 15/05/2020.
//

import Vapor
import S3Signer
import Service
import SWXMLHash

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
    /// If not provided, name will be set to a random 16 character string
    /// Return the url string of the file or the empty string if the file is not valid
    public func upload(_ req: Request, path: String, file: File?, name: String? = nil, _ permission: Permission? = .Public) throws -> Future<String> {
        guard let file = file else {
            return req.eventLoop.newSucceededFuture(result: "")
        }
        return try self.generateUnique(req, length: 16).flatMap(to: String.self){ random in
            var ext = ""
            if(file.ext != nil){ ext = "." + (file.ext ?? "") }
            let s3 = try req.makeS3Signer()
            let url = "\(self.config.endpoint)/\(path)/\( name ?? random )\(ext)"
            var headers = try s3.headers(for: .PUT, urlString: url, payload: Payload.bytes(file.data))
            headers.add(name: "x-amz-acl", value: "\(permission?.rawValue ?? "public-read")")
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
    }
    
    public func download(_ req: Request, url: URL) throws -> Future<Response> {
        let s3 = try req.makeS3Signer()
        let headers = try s3.headers(for: .GET, urlString: url, payload: Payload.none)
        return try req.make(Client.self).get(url, headers: headers)
            .map { response in
            guard response.http.status == .ok else { throw Abort(response.http.status)}
                guard response.http.body.data != nil else {
                    throw Abort(.noContent)
                }
                return response
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
    
    ///Check if a key exist in the bucket
    ///Return status 200 if exist
    public func exist(_ req: Request, key: String) throws -> Future<HTTPStatus> {
        let s3 = try req.makeS3Signer()
        let url = "\(self.config.endpoint)/\(key)"
        let headers = try s3.headers(for: .GET, urlString: url, payload: Payload.none )
        return try req.make(Client.self).get(url, headers: headers).map(to: HTTPStatus.self){ response in
            return response.http.status
        }
    }
    
    func list(_ req: Request, limit: Int? = 1000, marker: String? = "", appendTo: String? = "") throws -> Future<String> {
        let s3 = try req.makeS3Signer()
        let url = self.config.endpoint + "?max-keys=\(limit ?? 1000)" + "&marker=" + (marker ?? "")
        let headers = try s3.headers(for: .GET, urlString: url, payload: Payload.none )
        return try req.make(Client.self).get(url, headers: headers).flatMap(to: String.self){ response in
            var responseText = response.http.body.description
            if appendTo != "" {
                responseText = responseText.replacingOccurrences(of: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>", with: "")
            }
            var str = (appendTo ?? "") + responseText
            guard let data = str.data(using: .utf8)
                else { throw Abort(.noContent) }
            let xml = SWXMLHash.parse(data)
            if xml["ListBucketResult"]["NextMarker"].element?.text != nil &&
                xml["ListBucketResult"]["NextMarker"].element?.text != marker{
                let marker = xml["ListBucketResult"]["NextMarker"].element?.text
                return try self.list(req, marker: marker ?? "", appendTo: str)
            }
            else {
                str = str.replacingOccurrences(of: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>", with: "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root>")
                str = str + "</root>"
                return req.eventLoop.newSucceededFuture(result: str)
            }
        }
    }
    
    
    ///Get all the keys
    ///Return an array containing all the keys in the bucket
    public func keys(_ req: Request) throws -> Future<[String]> {
        return try req.DOSpaces().list(req).map{ xml in
            guard let data = xml.data(using: .utf8)
                else { throw Abort(.noContent) }
            let xml = SWXMLHash.parse(data)
            
            var keys : [String] = []
            
            for x in xml["root"]["ListBucketResult"].all{
                for r in x["Contents"].all{
                    keys.append(r["Key"].element?.text ?? "")
                }
            }
            return keys
        }
    }
    
    
    func random(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    func generateUnique(_ req: Request, length: Int) throws -> Future<String> {
        let unique = self.random(length: length)
        return try req.DOSpaces().exist(req, key: unique).flatMap(to: String.self){ exist in
            if exist == .ok { return try self.generateUnique(req, length: length) }
            else { return req.eventLoop.newSucceededFuture(result: unique) }
        }
    }
    
    public enum Permission: String {
        case Public = "public-read"
        case Private = "private"
    }

}



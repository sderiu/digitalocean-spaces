//
//  DigitalOceanSpaces.swift
//  App
//
//  Created by Simone Deriu on 15/05/2020.
//

import Vapor
import S3Signer
import Service

public final class DOSpaces : Service {
        
    var s3signer : S3Signer
    
    /// Configuration
    public private(set) var config: Config
    
    /// Initializer
    public init(_ config: Config) throws {
        self.config = config
        s3signer = try S3Signer(S3Signer.Config(accessKey: config.accessKey , secretKey: config.secretKey , region: config.region))
    }
    
    
    public struct Config: Service {
        
        
        let endpoint: String
        
        /// AWS Access Key
        let accessKey: String
        
        /// AWS Secret Key
        let secretKey: String
        
        /// The region where S3 bucket is located.
        public let region: Region
        
        let securityToken : String?
        
        /// Initalizer
        public init(endpoint: String, accessKey: String, secretKey: String, region: Region, securityToken: String? = nil) {
            self.endpoint = endpoint
            self.accessKey = accessKey
            self.secretKey = secretKey
            self.region = region
            self.securityToken = securityToken
        }
    }
    

    
 
}

extension DOSpaces {
    
    public func upload(_ req: Request, path: String, file: File, name: String?) throws -> Future<String> {
         let s3 = try req.makeS3Signer()
         let url = "\(try req.DOSpaces().config.endpoint)\(path)/\( name ?? file.filename ).\(file.ext ?? "")"
         var headers = try s3.headers(for: .PUT, urlString: url, payload: Payload.bytes(file.data))
         headers.add(name: "x-amz-acl", value: "public-read")
         return try req.make(Client.self).put(url, headers: headers) { put in
             return put.http.body = HTTPBody(data: file.data)
             }.map { _ in
                 return url
         }
     }
}

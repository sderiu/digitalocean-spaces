//
//  Container+DOSpaces.swift
//  App
//
//  Created by Simone Deriu on 15/05/2020.
//

import Foundation
import Vapor

extension Container {
    
    public func DOSpaces() throws -> DOSpaces {
        return try make()
    }
    
}

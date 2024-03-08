//
//  Codable+toJson.swift
//  TalerWallet
//
//  Created by Ivan Avalos on 08/03/24.
//  Copyright © 2024 Taler. All rights reserved.
//

import Foundation

extension Encodable {
    func toJSON(_ encoder: JSONEncoder = JSONEncoder()) -> String? {
        let e = encoder
        e.outputFormatting = .prettyPrinted
        if let data = try? e.encode(self) {
            let result = String(decoding: data, as: UTF8.self)
            return String(result)
        }

        return nil
    }
}

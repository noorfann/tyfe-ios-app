//
//  ActiveABTests.swift
//  
//
//  
//
import SwiftUI

struct ActiveABTests: Codable {
    
    private(set) var boolTest: Bool
    private(set) var enumTest: EnumTestOption

    init(
        boolTest: Bool,
        enumTest: EnumTestOption
    ) {
        self.boolTest = boolTest
        self.enumTest = enumTest
    }
    
    enum CodingKeys: String, CodingKey {
        case boolTest = "_202411_BoolTest"
        case enumTest = "_202411_EnumTest"
    }
    
    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "test\(CodingKeys.boolTest.rawValue)": boolTest,
            "test\(CodingKeys.enumTest.rawValue)": enumTest.rawValue
        ]
        return dict.compactMapValues({ $0 })
    }
    
    mutating func update(boolTest newValue: Bool) {
        boolTest = newValue
    }
    
    mutating func update(enumTest newValue: EnumTestOption) {
        enumTest = newValue
    }
}

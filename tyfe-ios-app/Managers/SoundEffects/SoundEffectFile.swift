//
//  SoundEffectFile.swift
//  tyfe-ios-app
//
//  Created by Nick Sarno on 1/12/25.
//
import Foundation

// Use this to register sound effects in the application.
// Add the file to the bundle (ie. in SoundEffectFiles folder) and create an enum case!

enum SoundEffectFile: String, Equatable {
    case start
    case finish
    case checklist
    
    var fileName: String {
        switch self {
        case .start:
            return "start.wav"
        case .finish:
            return "finish.wav"
        case .checklist:
            return "checklist.wav"
        }
    }
    
    var url: URL {
        let path = Bundle.main.path(forResource: fileName, ofType: nil)!
        return URL(fileURLWithPath: path)
    }
}

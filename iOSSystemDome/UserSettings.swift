//
//  UserSettings.swift
//  iOSSystemDome
//
//  Created by liuyihua on 2023/11/7.
//

import Foundation

class UserSettings: ObservableObject {
    @Published var inputLevelValue: String {
        didSet {
            UserDefaults.standard.setValue(inputLevelValue, forKey: "inputLevelValue")
        }
    }
    @Published var inputMaxValue: String {
        didSet {
            UserDefaults.standard.setValue(inputMaxValue, forKey: "inputMaxValue")
        }
    }

    init() {
        self.inputLevelValue = UserDefaults.standard.string(forKey: "inputLevelValue") ?? ""
        self.inputMaxValue = UserDefaults.standard.string(forKey: "inputMaxValue") ?? ""

    }
}

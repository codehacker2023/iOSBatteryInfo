//
//  DeviceInfo.swift
//  iOSSystemDome
//
//  Created by liuyihua on 2023/11/7.
//

import Foundation

struct DeviceInfo: Codable {
    let battery: String
    let cpu: String
    let freq: String
    let inch: String
    let mem: String
    let ppi: String
    let resolution: String
}

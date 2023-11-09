//
//  SystemInfoView.swift
//  iOSSystemDome
//
//  Created by liuyihua on 2023/11/6.
//

import SwiftUI
import UIKit

func estimateRemainingUsageTime() -> String {
    let batteryLevel = UIDevice.current.batteryLevel

    // 电池充电速率（每分钟消耗的电量）
    let dischargeRate: Float = 1.0 / 60.0

    // 计算剩余使用时间（单位：分钟）
    let remainingTime = batteryLevel / dischargeRate

    // 格式化为小时和分钟
    let hours = Int(remainingTime / 60)
    let minutes = Int(remainingTime.truncatingRemainder(dividingBy: 60))

    return "\(hours)小时 \(minutes)分钟"
}

// 获取所有类型类型
func loadAllDeviceInfoData() -> [String: DeviceInfo]? {
    if let path = Bundle.main.path(forResource: "DeviceInfo", ofType: "plist") {
        if let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            var deviceInfoDict: [String: DeviceInfo] = [:]
            for (key, value) in dict {
                if let infoDict = value as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: infoDict, options: [])
                {
                    do {
                        let deviceInfo = try JSONDecoder().decode(DeviceInfo.self, from: data)
                        deviceInfoDict[key] = deviceInfo
                    } catch {
                        print("Failed to decode DeviceInfo for key: \(key). Error: \(error)")
                    }
                }
            }
            return deviceInfoDict
        }
        return nil
    }
    return nil
}

// 获取系统信息
func getDeviceInfoData(_ model: String?, _ dict: [String: DeviceInfo]) -> DeviceInfo? {
    if let model = model {
        for (key, value) in dict {
            if key.contains(model) {
                return value
            }
        }
    } else {
        return nil
    }
    return nil
}

func getDeviceModel() -> String? {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let deviceModel = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    return deviceModel
}

class BatteryObserver: ObservableObject {
    @Published var batteryState: UIDevice.BatteryState = UIDevice.current.batteryState
    @Published var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published var battery: String = ""

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(batteryStateChanged), name: UIDevice.batteryStateDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(lowPowerModeDidChange), name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)
    }

    deinit {
        UIDevice.current.isBatteryMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func batteryStateChanged() {
        DispatchQueue.main.async {
            self.batteryState = UIDevice.current.batteryState
        }
    }

    @objc func lowPowerModeDidChange() {
        DispatchQueue.main.async {
            self.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

struct BatteryStatusView: View {
    @ObservedObject private var batteryObserver = BatteryObserver()
    let device = UIDevice.current
    @State private var currentDeviceInfo: DeviceInfo?
    @State private var showingMaxBatteryAlert = false
    @State private var showingbatteryLevelAlert = false
    @State private var showingErrorAlert = false
    @State private var showingErrorAlert_level = false

    private let alertTitleMax = "输入电池实际容量"
    private let alertMessageMax = "如果您更换过电池,可以将电池实际容量输入到下方区域,以更好的评估电池。"
    private let alertTitleLevel = "输入电池健康值"
    private let alertMessageLevel = "前往 系统“设置-电池-电池健康”中查看电池最大容量，并在下方区域输入，以更好的评估电池。"

    private let alertBtn_cancel = "取消"
    private let alertBtn_done = "确定"

    @AppStorage("inputMaxValue") var inputMaxValue: String = ""
    @AppStorage("inputLevelValue") var inputLevelValue: String = ""

    // 设计容量
    var designBatteryStr: String {
        return currentDeviceInfo?.battery ?? "N/A"
    }

    // 当前电量
    var currentBatteryStr: String {
        var battery = currentDeviceInfo?.battery ?? ""
        if battery.contains("mAh") {
            battery = battery.replacingOccurrences(of: "mAh", with: "")
        }
        var batteryValue = Double(battery) ?? 0

        let batteryLevel = device.batteryLevel

        // 实际电量的基础上处理
        if !inputMaxValue.isEmpty {
            let reality = Double(inputMaxValue)!
            batteryValue = reality
        }

        // 当前等级还是需要的
        batteryValue = batteryValue * Double(batteryLevel)

        // 在实际电量的基础上处理%
        if !inputLevelValue.isEmpty {
            batteryValue = batteryValue * Double(inputLevelValue)! / 100
        }

        return "(\(Int(batteryValue))mAh) \(Int(device.batteryLevel * 100))%"
    }

    // 实际电量值str
    var realityValue: String {
        if !inputMaxValue.isEmpty {
            var level = 1.0
            if !inputLevelValue.isEmpty {
                level = Double(Int(inputLevelValue)!) / 100
            }
            let max = Double(inputMaxValue)! * level
            return "\(Int(max))mAh"
        } else {
            return "点击输入实际电量"
        }
    }

    // 健康值str
    var healthValue: String {
        if !inputLevelValue.isEmpty {
            return "\(Int(inputLevelValue)!)%"
        } else {
            return "点击输入健康值"
        }
    }

    var body: some View {
        List {
            Section {
                ExtractedView("连接状态", batteryStateString())
                ExtractedView("当前电量", currentBatteryStr)
                ExtractedView("设计容量", designBatteryStr)
                ExtractedView("预计可用", estimateRemainingUsageTime())
                ExtractedView("低电量模式", batteryObserver.isLowPowerModeEnabled ? "是" : "否")
            } header: {
                Text("电池")
            }

            Section {
                ExtractedView("电池实际电量", realityValue)
                    .contentShape(Rectangle()) // 指定可点击的区域
                    .onTapGesture {
                        showingMaxBatteryAlert = true
                    }
                ExtractedView("电池健康值", healthValue)
                    .onTapGesture {
                        showingbatteryLevelAlert = true
                    }
            } header: {
                Text("电池健康值")
            } footer: {
                Text("这是相对于新电池而言的电池容量,容量较低可能导致充电后,电池使用时间的缩短。")
            }
            Section {
                ExtractedView("详细报告", "点击操作")
            } header: {
                Text("电池周期")
            }
        }
        .onAppear {
            batteryMonitoringEnabled()
            getDeviceInfoModel()
        }
        .alert(alertTitleMax, isPresented: $showingMaxBatteryAlert, actions: {
            TextField("实际容量, 如: \(designBatteryStr)", text: $inputMaxValue)
                .font(.caption)
                .keyboardType(.numberPad)
            Button(alertBtn_done, role: .none, action: {
                if Int(inputMaxValue) ?? 0 > 10000 {
                    inputMaxValue = String(inputMaxValue.prefix(4))
                    showingErrorAlert = true
                }
            })
            Button(alertBtn_cancel, role: .cancel, action: {})
        }) {
            Text(alertMessageMax)
        }

        .alert(alertTitleLevel, isPresented: $showingbatteryLevelAlert, actions: {
            TextField("最大容量,如: 95%", text: $inputLevelValue)
                .font(.caption)
                .keyboardType(.numberPad)
            Button(alertBtn_done, role: .none, action: {
                if Int(inputLevelValue) ?? 0 > 100 {
                    inputLevelValue = String(inputLevelValue.prefix(2))
                    showingErrorAlert_level = true
                }
            })
            Button(alertBtn_cancel, role: .cancel, action: {})
        }) {
            Text(alertMessageLevel)
        }

        ErrorAlertView(isPresented: $showingErrorAlert, messageType: 0) {
            showingMaxBatteryAlert = true
        }
        ErrorAlertView(isPresented: $showingErrorAlert_level, messageType: 1) {
            showingbatteryLevelAlert = true
        }
    }

    // 手动刷新电池状态
    func batteryMonitoringEnabled() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryObserver.batteryState = UIDevice.current.batteryState
    }

    func getDeviceInfoModel() {
        if let deviceModel = getDeviceModel(), let dict = loadAllDeviceInfoData() {
            currentDeviceInfo = getDeviceInfoData(deviceModel, dict)
        }
    }

    // 电池状态结果
    func batteryStateString() -> String {
        switch batteryObserver.batteryState {
        case .unknown:
            return "未知"
        case .unplugged:
            return "放电中"
        case .charging:
            return "充电中"
        case .full:
            return "已充满"
        @unknown default:
            return "未知"
        }
    }
}

struct ErrorAlertView: View {
    @Binding var isPresented: Bool
    var messageType: Int
    private let alertBtn_cancel = "取消"
    private let alertBtn_restart = "重新输入"
    private let alertTitleError = "输入错误"
    private let alertMessageError_battery = "输入的值必须在1到10000之间。"
    private let alertMessageError_level = "输入的值必须在1到100之间。"
    var primaryButtonAction: (() -> Void)?

    var body: some View {
        VStack {}
            .alert(alertTitleError, isPresented: $isPresented, actions: {
                Button(alertBtn_restart, role: .none, action: {
                    primaryButtonAction?() // Call primary button action
                })
                Button(alertBtn_cancel, role: .cancel, action: {})
            }) {
                Text(messageType == 0 ? alertMessageError_battery : alertMessageError_level)
            }
    }
}

struct SystemInfoView: View {
    let device = UIDevice.current

    var body: some View {
        NavigationStack {
            BatteryStatusView()
                .navigationTitle("电池信息")
        }

//        VStack {
//            //            Text("Device Name: \(device.name)")
//            //            Text("Device Model: \(device.model)")
//            //            Text("Device localizedModel: \(device.localizedModel)")
//            //            Text("System Name: \(device.systemName)")
//            //            Text("System Version: \(device.systemVersion)")
//            //            Text("Device Identifier: \(device.identifierForVendor?.uuidString ?? "N/A")")
//            //            Text("Total Memory: \(ProcessInfo.processInfo.physicalMemory) bytes")
//            //            Text("Used Memory: \(usedMemoryString() ?? "N/A")")
//            //            Text("Total Storage: \(totalDiskSpaceString() ?? "N/A")")
//            //            Text("Available Storage: \(availableDiskSpaceString() ?? "N/A")")
//        }
    }

    func usedMemoryString() -> String? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMemory = info.phys_footprint
            return ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory)
        } else {
            return nil
        }
    }

    func totalDiskSpaceString() -> String? {
        do {
            let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let resourceValues = try url.resourceValues(forKeys: [.volumeTotalCapacityKey])
            let totalCapacity = resourceValues.volumeTotalCapacity ?? 0
            return ByteCountFormatter.string(fromByteCount: Int64(totalCapacity), countStyle: .file)
        } catch {
            print("Error: \(error)")
            return nil
        }
    }

    func availableDiskSpaceString() -> String? {
        do {
            let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let resourceValues = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            let availableCapacity = resourceValues.volumeAvailableCapacity ?? 0
            return ByteCountFormatter.string(fromByteCount: Int64(availableCapacity), countStyle: .file)
        } catch {
            print("Error: \(error)")
            return nil
        }
    }
}

#Preview {
    SystemInfoView()
}

struct ExtractedView: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundStyle(.blue)
        }
    }
}

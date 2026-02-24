import SwiftUI
import AppKit

final class ImagerViewModel: ObservableObject {

    // MARK: - Published state

    @Published var imagePath = ""
    @Published var bmapPath = ""
    @Published var selectedDevice = ""
    @Published var devices: [DiskDevice] = []

    @Published var progressPercentage = 0
    @Published var outputText = ""
    @Published var statusMessage = "就绪"
    @Published var isImaging = false

    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var successMessage = ""
    @Published var showConfirmation = false
    @Published var showPasswordPrompt = false

    private var service: ImagingService?

    // MARK: - Computed helpers

    var selectedDeviceObject: DiskDevice? {
        devices.first { $0.identifier == selectedDevice }
    }

    var imageFileName: String {
        guard !imagePath.isEmpty else { return "" }
        return URL(fileURLWithPath: imagePath).lastPathComponent
    }

    var bmapFileName: String {
        guard !bmapPath.isEmpty else { return "" }
        return URL(fileURLWithPath: bmapPath).lastPathComponent
    }

    var isReadyToWrite: Bool {
        !imagePath.isEmpty && !bmapPath.isEmpty && !selectedDevice.isEmpty
    }

    // MARK: - Setup

    func checkWriter() {
        if ImagingService.findWriter() == nil {
            errorMessage = "找不到 mms-writer 工具。\n请先运行 swift build 构建项目。"
            showError = true
        }
    }

    func refreshDevices() {
        devices = DeviceManager.listRemovableDevices()
        selectedDevice = devices.first?.identifier ?? ""
        if devices.isEmpty {
            statusMessage = "未检测到可用设备"
        } else {
            statusMessage = "找到 \(devices.count) 个可用设备"
        }
    }

    // MARK: - File browsing

    func browseImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "选择镜像文件"
        panel.message = "选择 .img 或 .img.gz 文件"

        if panel.runModal() == .OK, let url = panel.url {
            imagePath = url.path
        }
    }

    func browseBmap() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "选择 Bmap 文件"
        panel.message = "选择 .bmap 文件"

        if panel.runModal() == .OK, let url = panel.url {
            bmapPath = url.path
        }
    }

    // MARK: - Drag & Drop (uses legacy kUTTypeFileURL for macOS 10.15)

    func handleDrop(of providers: [NSItemProvider]) -> Bool {
        let fileURLTypeID = "public.file-url"
        for provider in providers {
            provider.loadItem(forTypeIdentifier: fileURLTypeID, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                let path = url.path
                DispatchQueue.main.async {
                    if path.hasSuffix(".bmap") {
                        self.bmapPath = path
                    } else if path.hasSuffix(".img") || path.hasSuffix(".img.gz") || path.hasSuffix(".gz") {
                        self.imagePath = path
                    }
                }
            }
        }
        return true
    }

    // MARK: - Imaging flow: validate → confirm → password → start

    func startImaging() {
        guard !imagePath.isEmpty else {
            errorMessage = "请选择镜像文件"
            showError = true
            return
        }
        guard !bmapPath.isEmpty else {
            errorMessage = "请选择 Bmap 文件"
            showError = true
            return
        }
        guard !selectedDevice.isEmpty else {
            errorMessage = "请选择目标设备"
            showError = true
            return
        }
        showConfirmation = true
    }

    func confirmWrite() {
        showPasswordPrompt = true
    }

    func performImaging(password: String) {
        outputText = ""
        progressPercentage = 0
        statusMessage = "烧录中..."
        isImaging = true

        let svc = ImagingService()
        self.service = svc

        svc.onProgress = { [weak self] pct in
            DispatchQueue.main.async { self?.progressPercentage = pct }
        }
        svc.onOutput = { [weak self] line in
            DispatchQueue.main.async { self?.outputText += line + "\n" }
        }
        svc.onFinished = { [weak self] success, message in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isImaging = false
                if success {
                    self.progressPercentage = 100
                    self.statusMessage = "烧录完成"
                    self.successMessage = message
                    self.showSuccess = true
                } else {
                    self.statusMessage = "烧录失败"
                    self.errorMessage = message
                    self.showError = true
                }
            }
        }

        svc.start(
            imagePath: imagePath,
            bmapPath: bmapPath,
            devicePath: selectedDevice,
            password: password
        )
    }

    func cancelImaging() {
        service?.cancel()
    }
}

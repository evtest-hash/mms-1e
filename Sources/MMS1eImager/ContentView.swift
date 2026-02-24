import SwiftUI
import AppKit
import Combine

// MARK: - SF Symbol wrapper (macOS 11+) with text fallback (10.15)

struct SysImage: View {
    let name: String
    let fallback: String

    var body: some View {
        if #available(macOS 11.0, *) {
            Image(systemName: name)
        } else {
            Text(fallback)
        }
    }
}

// MARK: - Main View

struct ContentView: View {
    @ObservedObject var vm = ViewModelHolder.shared.vm
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            VStack(spacing: 16) {
                fileSection
                deviceSection
                progressSection
            }
            .padding(20)
            .onDrop(of: ["public.file-url"], isTargeted: $dropTargeted) { providers in
                vm.handleDrop(of: providers)
            }
            .overlay(
                Group {
                    if dropTargeted { dropOverlay }
                }
            )

            Divider()
            actionBar
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert(isPresented: $vm.showError) {
            Alert(
                title: Text("错误"),
                message: Text(vm.errorMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .sheet(isPresented: $vm.showConfirmation) {
            WriteConfirmationView(
                device: vm.selectedDeviceObject ?? vm.devices.first!,
                imageName: vm.imageFileName
            ) {
                vm.confirmWrite()
            }
        }
        .sheet(isPresented: $vm.showPasswordPrompt) {
            PasswordPromptView { password in
                vm.performImaging(password: password)
            }
        }
        .onAppear {
            vm.refreshDevices()
            vm.checkWriter()
        }
        .onReceive(vm.$showSuccess.filter { $0 }) { _ in
            let alert = NSAlert()
            alert.messageText = "烧录完成"
            alert.informativeText = vm.successMessage
            alert.alertStyle = .informational
            alert.addButton(withTitle: "好")
            alert.runModal()
            vm.showSuccess = false
        }
    }

    // MARK: - Drop overlay

    private var dropOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.15))

            VStack(spacing: 12) {
                SysImage(name: "arrow.down.doc.fill", fallback: "⬇")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
                Text("拖放镜像或 Bmap 文件")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                SysImage(name: "sdcard.fill", fallback: "SD")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("MMS-1e SD 卡烧录工具")
                    .font(.system(size: 16, weight: .semibold))
                Text("使用 bmap 快速写入镜像到 SD 卡")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - File Section

    private var fileSection: some View {
        SectionCard(step: 1, icon: "doc.on.doc", iconFallback: "📄", title: "选择文件",
                    complete: !vm.imagePath.isEmpty && !vm.bmapPath.isEmpty) {
            VStack(spacing: 0) {
                fileRow(
                    icon: "opticaldisc", iconFB: "💿",
                    label: "镜像文件",
                    hint: "拖放或点击浏览 (.img / .img.gz)",
                    fileName: vm.imageFileName,
                    path: vm.imagePath,
                    action: vm.browseImage,
                    clear: { vm.imagePath = "" }
                )

                Divider().padding(.horizontal, 4)

                fileRow(
                    icon: "map", iconFB: "🗺",
                    label: "Bmap 文件",
                    hint: "拖放或点击浏览 (.bmap)",
                    fileName: vm.bmapFileName,
                    path: vm.bmapPath,
                    action: vm.browseBmap,
                    clear: { vm.bmapPath = "" }
                )
            }
        }
    }

    private func fileRow(icon: String, iconFB: String, label: String, hint: String,
                         fileName: String, path: String,
                         action: @escaping () -> Void,
                         clear: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            SysImage(name: icon, fallback: iconFB)
                .font(.system(size: 16))
                .foregroundColor(path.isEmpty ? .secondary : .blue)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                if path.isEmpty {
                    Text(label).font(.body.weight(.medium))
                    Text(hint).font(.caption).foregroundColor(.secondary)
                } else {
                    Text(fileName).font(.body.weight(.medium)).lineLimit(1)
                    Text(URL(fileURLWithPath: path).deletingLastPathComponent().path)
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }

            Spacer()

            if !path.isEmpty {
                Text("✓")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)

                Button(action: clear) {
                    Text("✕")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button("浏览…", action: action)
                .controlSize(.small)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Device Section

    private var deviceSection: some View {
        SectionCard(step: 2, icon: "externaldrive", iconFallback: "💾", title: "选择设备",
                    complete: !vm.selectedDevice.isEmpty) {
            if vm.devices.isEmpty {
                emptyDeviceView
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Picker("", selection: $vm.selectedDevice) {
                            ForEach(vm.devices) { device in
                                Text(device.displayName).tag(device.identifier)
                            }
                        }
                        .labelsHidden()

                        refreshButton
                    }

                    if let device = vm.selectedDeviceObject {
                        deviceDetailRow(device)
                    }
                }
            }
        }
    }

    private var emptyDeviceView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("未检测到可用设备")
                    .font(.callout.weight(.medium))
                    .foregroundColor(.secondary)
                Text("请插入 SD 卡后点击刷新")
                    .font(.caption)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
            Spacer()
            refreshButton
        }
    }

    private var refreshButton: some View {
        Button(action: { vm.refreshDevices() }) {
            SysImage(name: "arrow.clockwise", fallback: "⟳")
        }
        .controlSize(.small)
    }

    private func deviceDetailRow(_ device: DiskDevice) -> some View {
        HStack(spacing: 12) {
            detailChip(text: device.protocolType)
            detailChip(text: device.size)
            if device.removable {
                detailChip(text: "可移除")
            }
            Spacer()
        }
    }

    private func detailChip(text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color(NSColor.quaternaryLabelColor).opacity(0.3))
            )
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        SectionCard(step: 3, icon: "arrow.down.to.line", iconFallback: "⬇", title: "烧录进度",
                    complete: vm.progressPercentage >= 100 && !vm.isImaging) {
            VStack(spacing: 8) {
                ProgressBarView(value: Double(vm.progressPercentage) / 100.0,
                                tint: progressTint)
                    .frame(height: 8)

                HStack(spacing: 0) {
                    Text("\(vm.progressPercentage)%")
                        .font(.caption.bold())
                        .foregroundColor(progressTint)

                    Spacer()

                    if vm.isImaging {
                        SpinnerView()
                            .frame(width: 14, height: 14)
                            .padding(.trailing, 6)
                    }

                    Text(vm.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                logView
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var progressTint: Color {
        if vm.progressPercentage >= 100 && !vm.isImaging { return .green }
        if vm.isImaging { return .blue }
        return .secondary
    }

    private var logView: some View {
        ScrollView {
            Text(vm.outputText.isEmpty ? "等待开始…" : vm.outputText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(vm.outputText.isEmpty ? Color(NSColor.tertiaryLabelColor) : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .frame(maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            Text(vm.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            if vm.isImaging {
                Button("取消") { vm.cancelImaging() }
            }

            Button(action: { vm.startImaging() }) {
                Text("开始烧录")
                    .frame(minWidth: 100)
            }
            .disabled(!vm.isReadyToWrite || vm.isImaging)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let step: Int
    let icon: String
    let iconFallback: String
    let title: String
    let complete: Bool
    let content: () -> Content

    init(step: Int, icon: String, iconFallback: String, title: String,
         complete: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.step = step
        self.icon = icon
        self.iconFallback = iconFallback
        self.title = title
        self.complete = complete
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(complete ? Color.green : Color.blue)
                        .frame(width: 22, height: 22)

                    if complete {
                        Text("✓")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(step)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }

                HStack(spacing: 6) {
                    SysImage(name: icon, fallback: iconFallback)
                    Text(title)
                }
                .font(.headline)
            }

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }
}

// MARK: - ProgressBar (replaces ProgressView, macOS 10.15)

struct ProgressBarView: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.separatorColor).opacity(0.3))

                RoundedRectangle(cornerRadius: 4)
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * CGFloat(min(value, 1.0))))
            }
        }
    }
}

// MARK: - Spinner (replaces ProgressView(), macOS 10.15)

struct SpinnerView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSProgressIndicator {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.startAnimation(nil)
        return indicator
    }
    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {}
}

// MARK: - Write Confirmation

struct WriteConfirmationView: View {
    let device: DiskDevice
    let imageName: String
    let onConfirm: () -> Void

    @Environment(\.presentationMode) var presentationMode
    @State private var understood = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("⚠️")
                    .font(.system(size: 44))

                Text("确认写入操作")
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            VStack(spacing: 0) {
                confirmRow(label: "镜像文件", value: imageName)
                Divider().padding(.horizontal, 12)
                confirmRow(label: "目标设备", value: device.mediaName)
                Divider().padding(.horizontal, 12)
                confirmRow(label: "设备路径", value: device.identifier, mono: true)
                Divider().padding(.horizontal, 12)
                confirmRow(label: "设备容量", value: device.size)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
            )
            .padding(.horizontal, 28)

            HStack(spacing: 8) {
                Text("🔴")
                Text("此操作将不可逆地擦除目标设备上的全部数据。")
                    .font(.callout)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)

            Toggle(isOn: $understood) {
                Text("我已确认目标设备正确，了解数据将被清除")
                    .font(.callout)
            }
            .toggleStyle(CheckboxToggleStyle())
            .padding(.horizontal, 28)
            .padding(.top, 14)

            HStack(spacing: 14) {
                Button("取消") { presentationMode.wrappedValue.dismiss() }

                Button(action: {
                    onConfirm()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("🔥 确认写入")
                        .frame(minWidth: 90)
                }
                .disabled(!understood)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .frame(width: 440)
    }

    private func confirmRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)

            if mono {
                Text(value)
                    .font(.system(.callout, design: .monospaced))
            } else {
                Text(value)
                    .font(.callout.weight(.medium))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

// MARK: - Password Prompt

struct PasswordPromptView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var password = ""
    let onSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("🔒")
                .font(.system(size: 40))

            Text("需要管理员权限")
                .font(.headline)

            Text("写入 SD 卡需要管理员密码")
                .font(.subheadline)
                .foregroundColor(.secondary)

            SecureField("输入密码", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 260)

            HStack(spacing: 16) {
                Button("取消") { presentationMode.wrappedValue.dismiss() }

                Button("确定") { submit() }
                    .disabled(password.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 360, height: 250)
    }

    private func submit() {
        guard !password.isEmpty else { return }
        onSubmit(password)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Singleton holder for ViewModel (replaces @StateObject)

final class ViewModelHolder {
    static let shared = ViewModelHolder()
    let vm = ImagerViewModel()
    private init() {}
}

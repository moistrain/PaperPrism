import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var agent: AgentService
    @State private var testResult = ""
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("外部 Agent 工具")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("连接你日常使用的命令行 Agent，为翻译、精读与引用识别提供智能能力。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(ReadingTheme.secondaryInk)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("可执行文件")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Label(
                        agent.isConfigured ? "已配置" : "尚未配置",
                        systemImage: agent.isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle"
                    )
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(agent.isConfigured ? ReadingTheme.accent : ReadingTheme.danger)
                }

                HStack {
                    TextField("选择 Agent 或兼容适配脚本", text: $agent.executablePath)
                        .textFieldStyle(.roundedBorder)
                    Button("选择…") {
                        chooseExecutable()
                    }
                }
            }
            .padding(13)
            .background(ReadingTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("启动参数")
                    .font(.system(size: 12, weight: .semibold))
                TextEditor(text: $agent.argumentsText)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 92)
                    .padding(7)
                    .background(ReadingTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("每行一个参数。PaperPrism 会把完整任务通过标准输入发送给该进程，并从标准输出读取 JSON。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(ReadingTheme.mutedInk)
            }

            VStack(alignment: .leading, spacing: 9) {
                Label("凭据与数据去向", systemImage: "lock.shield")
                    .font(.system(size: 12, weight: .semibold))
                Text("公开版不保存任何模型密钥，也不捆绑 Agent。请在所选工具中完成登录或密钥配置；文本会按该工具的隐私规则处理。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(ReadingTheme.secondaryInk)
                    .lineSpacing(3)
            }
            .padding(13)
            .background(ReadingTheme.accentSoft.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            HStack {
                Button {
                    test()
                } label: {
                    if isTesting {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("检查配置", systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ReadingTheme.accent)
                .disabled(isTesting)

                Text(testResult)
                    .font(.system(size: 11.5))
                    .foregroundStyle(
                        testResult.localizedCaseInsensitiveContains("失败")
                            ? ReadingTheme.danger
                            : ReadingTheme.accent
                    )
            }

            HStack(spacing: 5) {
                Text("AGPL-3.0-or-later · 本软件不提供任何担保 ·")
                Link("查看源代码与许可", destination: URL(string: "https://github.com/moistrain/PaperPrism")!)
            }
            .font(.system(size: 10.5))
            .foregroundStyle(ReadingTheme.mutedInk)

            Spacer()
        }
        .padding(26)
        .background(ReadingTheme.appBackground)
    }

    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            agent.executablePath = url.path
        }
    }

    private func test() {
        isTesting = true
        testResult = ""
        Task {
            let result = await agent.testConnection()
            switch result {
            case .success(let message):
                testResult = message
            case .failure(let error):
                testResult = "失败：\(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}

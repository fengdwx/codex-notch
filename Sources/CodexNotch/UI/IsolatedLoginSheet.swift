import AppKit
import SwiftUI

struct IsolatedLoginSheet: View {
    @ObservedObject var service: AccountsService
    let appLanguage: AppLanguage
    let onDismiss: () -> Void

    @State private var copiedLink = false
    @State private var copyFeedbackTask: Task<Void, Never>?
    @State private var isDetailsExpanded = false

    private var loginState: IsolatedLoginState {
        service.isolatedLoginState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(appLanguage.localized(
                        chinese: "通过浏览器登录 ChatGPT 账号",
                        english: "Sign in with Browser"
                    ))
                    .font(.headline)

                    Text(appLanguage.localized(
                        chinese: "在独立隔离沙盒中完成 OAuth 授权，不会退出或中断当前正在运行的 Codex 会话。",
                        english: "Completes OAuth in an isolated sandbox without signing out or interrupting your active Codex session."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                stepRow(
                    number: "1",
                    text: appLanguage.localized(
                        chinese: "在浏览器中打开登录页（获取链接后会自动打开默认浏览器）",
                        english: "Open the login page in your browser (opens automatically once ready)"
                    )
                )
                stepRow(
                    number: "2",
                    text: appLanguage.localized(
                        chinese: "登录目标 ChatGPT 账号并确认授权（若默认浏览器已登录主号，可复制链接到无痕窗口）",
                        english: "Sign in to the target account and approve access (copy the link for an incognito window if needed)"
                    )
                )
                stepRow(
                    number: "3",
                    text: appLanguage.localized(
                        chinese: "授权完成后将自动加密保存账号并刷新 5h / 7d 额度",
                        english: "Once approved, credentials are saved automatically and quotas refresh immediately"
                    )
                )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.07))
            )

            phaseCard

            if !loginState.statusLines.isEmpty {
                DisclosureGroup(
                    isExpanded: $isDetailsExpanded,
                    content: {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(loginState.statusLines.enumerated()), id: \.offset) { _, line in
                                    Text("• \(line)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxHeight: 84)
                    },
                    label: {
                        Text(appLanguage.localized(
                            chinese: "查看登录过程详情 (\(loginState.statusLines.count))",
                            english: "Login progress details (\(loginState.statusLines.count))"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                )
            }

            HStack {
                Spacer()
                switch loginState.phase {
                case .completed:
                    Button(appLanguage.localized(chinese: "完成", english: "Done")) {
                        closeSheet()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                case .failed, .cancelled, .idle:
                    Button(appLanguage.localized(chinese: "关闭", english: "Close")) {
                        closeSheet()
                    }
                    .keyboardShortcut(.cancelAction)
                case .startingServer, .waitingForBrowser, .importingCredentials:
                    Button(appLanguage.localized(chinese: "取消登录", english: "Cancel")) {
                        service.cancelWebLogin(language: appLanguage)
                        closeSheet()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(20)
        .frame(width: 460)
        .onChange(of: loginState.phase) { _, newPhase in
            if case .completed = newPhase {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    if case .completed = service.isolatedLoginState.phase {
                        closeSheet()
                    }
                }
            }
        }
        .onDisappear {
            copyFeedbackTask?.cancel()
            copyFeedbackTask = nil
        }
    }

    @ViewBuilder
    private var phaseCard: some View {
        switch loginState.phase {
        case .idle, .startingServer:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(appLanguage.localized(
                    chinese: "正在启动本地安全登录服务…",
                    english: "Starting local isolated login service…"
                ))
                .font(.callout)
                Spacer()
            }
            .padding(12)
            .background(statusCardBackground(color: .accentColor))

        case .waitingForBrowser:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(appLanguage.localized(
                        chinese: "正在等待浏览器完成登录授权…",
                        english: "Waiting for browser authorization…"
                    ))
                    .font(.callout.weight(.medium))
                    Spacer()
                }

                if let authURL = loginState.authURL {
                    HStack(spacing: 8) {
                        Button {
                            _ = NSWorkspace.shared.open(authURL)
                        } label: {
                            Label(
                                appLanguage.localized(chinese: "打开登录页", english: "Open Login Page"),
                                systemImage: "safari"
                            )
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            copyAuthorizationURL(authURL)
                        } label: {
                            Label(
                                copiedLink
                                    ? appLanguage.localized(chinese: "已复制链接", english: "Copied")
                                    : appLanguage.localized(chinese: "复制登录链接", english: "Copy Login Link"),
                                systemImage: copiedLink ? "checkmark" : "doc.on.doc"
                            )
                        }
                        .buttonStyle(.bordered)
                    }

                    if copiedLink {
                        Text(appLanguage.localized(
                            chinese: "已复制到剪贴板，可粘贴到无痕窗口或其他浏览器配置文件中登录。",
                            english: "Copied to clipboard. Paste into a private window or another browser profile if needed."
                        ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(statusCardBackground(color: .accentColor))

        case .importingCredentials:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(appLanguage.localized(
                    chinese: "授权已完成，正在保存账号凭据…",
                    english: "Authorized. Saving credentials…"
                ))
                .font(.callout)
                Spacer()
            }
            .padding(12)
            .background(statusCardBackground(color: .green))

        case .completed(let profile):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appLanguage.localized(
                        chinese: "账号「\(profile.shortLabel)」添加成功",
                        english: "Signed in as \(profile.shortLabel)"
                    ))
                    .font(.callout.weight(.semibold))
                    if let email = profile.email {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(statusCardBackground(color: .green))

        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                Button {
                    service.startWebLogin(language: appLanguage)
                } label: {
                    Label(
                        appLanguage.localized(chinese: "重新发起网页登录", english: "Retry Browser Login"),
                        systemImage: "arrow.clockwise"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(statusCardBackground(color: .red))

        case .cancelled:
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
                Text(appLanguage.localized(chinese: "已取消本次网页登录。", english: "Browser login cancelled."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            .background(statusCardBackground(color: .secondary))
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusCardBackground(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(color.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(color.opacity(0.24), lineWidth: 0.75)
            }
    }

    private func copyAuthorizationURL(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
        copiedLink = true
        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            copiedLink = false
        }
    }

    private func closeSheet() {
        if loginState.phase.isInProgress {
            service.cancelWebLogin(language: appLanguage)
        }
        service.resetWebLoginState()
        onDismiss()
    }
}

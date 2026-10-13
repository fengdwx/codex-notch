import Foundation

enum ResetCreditFeedback {
    static func message(
        _ result: Result<ResetCreditConsumptionOutcome, Error>,
        refreshed: Bool,
        language: AppLanguage
    ) -> String {
        let text: String
        switch result {
        case .success(.reset):
            text = language.localized(chinese: "服务已确认重置成功。", english: "The service confirmed that your usage was reset.")
        case .success(.alreadyRedeemed):
            text = language.localized(chinese: "这次重置机会此前已使用，本次没有再次重置。", english: "This reset has already been used. No new reset was performed.")
        case .success(.nothingToReset):
            text = language.localized(chinese: "当前没有符合条件的额度需要重置，未消耗重置机会。", english: "No current usage window is eligible for a reset. No reset credit was consumed.")
        case .success(.noCredit):
            text = language.localized(chinese: "这次重置机会已不可用，请查看更新后的列表。", english: "This reset is no longer available. Check the updated list.")
        case .failure(let error):
            text = errorMessage(error, language: language)
        }
        return text + "\n\n" + language.localized(
            chinese: refreshed ? "已重新读取额度与重置次数。" : "额度刷新失败，当前显示可能未更新。请稍后再查看。",
            english: refreshed ? "Usage and saved resets have been fetched again." : "Usage could not be refreshed; displayed values may be stale. Check again shortly."
        )
    }

    private static func errorMessage(_ error: Error, language: AppLanguage) -> String {
        if let error = error as? ResetCreditRedemptionError {
            switch error {
            case .accountChanged:
                return language.localized(chinese: "登录账号已变化，未提交重置。请查看新账号的额度后再试。", english: "The signed-in account changed. No reset was submitted. Review the new account's usage first.")
            case .unavailable:
                return language.localized(chinese: "这次重置已到期或不可用，未提交重置。", english: "This reset has expired or is unavailable. No reset was submitted.")
            case .busy:
                return language.localized(chinese: "已有重置请求正在处理。", english: "A reset request is already in progress.")
            }
        }
        if error is CodexAuthError || (error as? CodexUsageError) == .reauthenticationRequired {
            return language.localized(chinese: "登录状态已失效，请在 Codex 重新登录后再试。", english: "Your sign-in has expired. Sign in to Codex again and retry.")
        }
        if let error = error as? CodexUsageError {
            let status: Int?
            switch error {
            case .httpStatus(let value), .resetHTTPStatus(let value, _): status = value
            default: status = nil
            }
            if let status {
                return language.localized(
                    chinese: "服务未能完成请求（HTTP \(status)）。请先核对额度和重置次数；应用不会自动重试。",
                    english: "The service could not complete the request (HTTP \(status)). Check usage and saved resets first; the app will not retry automatically."
                )
            }
        }
        return language.localized(
            chinese: "未能确认重置结果。请先核对额度和重置次数，再决定是否重试；应用不会自动重试。",
            english: "The reset result could not be confirmed. Check usage and saved resets before retrying; the app will not retry automatically."
        )
    }
}

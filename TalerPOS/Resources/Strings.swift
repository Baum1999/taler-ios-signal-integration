/*
 * This file is part of GNU Taler
 * (C) 2026 Bohdan, Volodymyr Potuzhnyi
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING. If not, see <http://www.gnu.org/licenses/>
 */

import Foundation

/// Localized string accessors.
/// All accessors resolve from the active LanguageManager bundle so that
/// in-app language changes apply immediately without restart.
enum S {
    private static var b: Bundle { LanguageManager.shared.bundle }
    private static var t: String { "Localizable" }

    private static func s(_ key: String) -> String {
        NSLocalizedString(key, tableName: t, bundle: b, comment: "")
    }

    private static func s(_ key: String, _ arg: CVarArg) -> String {
        String(format: NSLocalizedString(key, tableName: t, bundle: b, comment: ""), arg)
    }

    private static func s(_ key: String, _ arg1: CVarArg, _ arg2: CVarArg) -> String {
        String(format: NSLocalizedString(key, tableName: t, bundle: b, comment: ""), arg1, arg2)
    }

    // MARK: - Menu / Navigation
    static var menuOrder: String { s("menu_order") }
    static var menuAmountEntry: String { s("menu_amount_entry") }
    static var menuHistory: String { s("menu_history") }
    static var menuSettings: String { s("menu_settings") }
    static var menuReload: String { s("menu_reload") }

    // MARK: - Products
    static var productCategoryAll: String { s("product_category_all_objects") }
    static var productCategoryUncategorized: String { s("product_category_uncategorized") }
    static var productUnavailable: String { s("product_unavailable") }
    static var productOutOfStock: String { s("product_out_of_stock") }
    static var productWrongCurrency: String { s("product_wrong_currency") }

    // MARK: - Order
    static func orderLabelTitle(_ id: String) -> String { s("order_label_title", id) }
    static func orderTotal(_ amount: String) -> String { s("order_total", amount) }
    static var orderRestart: String { s("order_restart") }
    static var orderUndo: String { s("order_undo") }
    static var orderPrevious: String { s("order_previous") }
    static var orderNext: String { s("order_next") }
    static var orderCustom: String { s("order_custom") }
    static var orderComplete: String { s("order_complete") }
    static func orderCompleteWithAmount(_ amount: String) -> String { s("order_complete_with_amount", amount) }
    static var orderDelete: String { s("order_delete") }
    static var orderCustomProduct: String { s("order_custom_product") }
    static var orderCustomAdd: String { s("order_custom_add_button") }
    static var orderCustomProductDefault: String { s("order_custom_product_default") }

    // MARK: - Amount Entry
    static var amountEntryLabel: String { s("amount_entry_label") }
    static var amountEntryCreateOrder: String { s("amount_entry_create_order_charge") }
    static var amountEntryClear: String { s("amount_entry_clear") }
    static var amountEntryProductDescription: String { s("amount_entry_product_description") }
    static var amountEntryErrorZero: String { s("amount_entry_error_zero") }
    static var amountEntryBackspace: String { s("amount_entry_backspace") }
    static var amountEntryErrorWrongCurrency: String { s("amount_entry_error_wrong_currency") }

    // MARK: - Config
    static var configLabel: String { s("config_label") }
    static var configMerchantUrl: String { s("config_merchant_url") }
    static var configUsername: String { s("config_username") }
    static var configPassword: String { s("config_password") }
    static var configOk: String { s("config_ok") }
    static var configAuthError: String { s("config_auth_error") }
    static var configErrorNetwork: String { s("config_error_network") }
    static var configErrorCategory: String { s("config_error_category") }
    static var configErrorMalformed: String { s("config_error_malformed") }
    static var configErrorUnknown: String { s("config_error_unknown") }
    static var configFetching: String { s("config_fetching") }
    static var configSavePassword: String { s("config_save_password") }

    // MARK: - Payment
    static var paymentIntro: String { s("payment_intro") }
    static var paymentClaimed: String { s("payment_claimed") }
    static var paymentCancel: String { s("payment_cancel") }
    static var paymentReceived: String { s("payment_received") }
    static var paymentBackButton: String { s("payment_back_button") }
    static func paymentOrderId(_ id: String) -> String { s("payment_order_id", id) }
    static var paymentProcessLabel: String { s("payment_process_label") }
    static var paymentFetchingLink: String { s("payment_fetching_link") }
    static var paymentShareUri: String { s("payment_share_uri") }
    static var paymentCopyUri: String { s("payment_copy_uri") }
    static var forceDeleteTitle: String { s("force_delete_dialog_title") }
    static var forceDeleteMessage: String { s("force_delete_dialog_message") }
    static var forceDeleteConfirm: String { s("force_delete_dialog_confirm") }

    // MARK: - History
    static var historyLabel: String { s("history_label") }
    static var historyRefresh: String { s("history_refresh") }
    static func historyRefNo(_ id: String) -> String { s("history_ref_no", id) }
    static var historyUnpaid: String { s("history_status_unpaid") }
    static var historyPaid: String { s("history_status_paid") }
    static var historyPaymentPending: String { s("history_status_payment_pending") }
    static var historyPaymentClaimed: String { s("history_status_payment_claimed") }
    static var historyRefundPending: String { s("history_status_refund_pending") }
    static var historyRefunded: String { s("history_status_refunded") }
    static var historyShowPayment: String { s("history_show_payment") }
    static var historyShowRefund: String { s("history_show_refund") }
    static var historyRefund: String { s("history_refund") }

    // MARK: - Refund
    static var refundAmount: String { s("refund_amount") }
    static var refundReason: String { s("refund_reason") }
    static var refundAbort: String { s("refund_abort") }
    static var refundConfirm: String { s("refund_confirm") }
    static var refundErrorInvalidAmount: String { s("refund_error_invalid_amount") }
    static var refundErrorZero: String { s("refund_error_zero") }
    static var refundErrorDeadline: String { s("refund_error_deadline") }
    static var refundErrorAlreadyRefunded: String { s("refund_error_already_refunded") }
    static var refundIntro: String { s("refund_intro") }
    static var refundStateMissing: String { s("refund_state_missing") }
    static func refundErrorMaxAmount(_ amount: String) -> String { s("refund_error_max_amount", amount) }

    // MARK: - Settings
    static var settingsAppTitle: String { s("settings_app_title") }
    static var settingsInitialOrderLabel: String { s("settings_initial_order_label") }
    static var settingsLanguageLabel: String { s("settings_language_label") }
    static var settingsLanguageSystemDefault: String { s("settings_language_system_default") }
    static var settingsInstanceTitle: String { s("settings_instance_title") }
    static var settingsInstanceButton: String { s("settings_instance_button") }
    static var settingsLogoutButton: String { s("settings_logout_button") }
    static var settingsInstanceDescription: String { s("settings_instance_description") }

    // MARK: - Errors
    static var errorHistory: String { s("error_history") }
    static var errorPayment: String { s("error_payment") }
    static var errorOrderCreation: String { s("error_order_creation") }
    static var errorInventoryUnavailable: String { s("error_inventory_unavailable") }
    static var errorDeleteOrder: String { s("error_delete_order") }

    // MARK: - Common Dialogs
    static var commonError: String { s("common_error") }
    static var commonOk: String { s("common_ok") }

    // MARK: - Config Validation
    static var configErrorEmptyUrl: String { s("config_error_empty_url") }
    static var configErrorEmptyToken: String { s("config_error_empty_token") }

    // MARK: - Config Mode
    static var configModeManual: String { s("config_mode_manual") }
    static var configModeQr: String { s("config_mode_qr") }
    static var configQrHint: String { s("config_qr_hint") }
    static var configQrError: String { s("config_qr_error") }
    static var configCameraPermission: String { s("config_camera_permission") }

    // MARK: - MFA / Challenge
    static var mfaChallengeTitle: String { s("mfa_challenge_title") }
    static func mfaChallengeMessage(_ channel: String, _ info: String) -> String { s("mfa_challenge_message", channel, info) }
    static var mfaChallengeCodeHint: String { s("mfa_challenge_code_hint") }
    static func mfaChallengeCodeIncomplete(_ count: Int) -> String { s("mfa_challenge_code_incomplete", count) }
    static var mfaChooseTitle: String { s("mfa_choose_title") }
    static var mfaChallengeInvalid: String { s("mfa_challenge_invalid") }
    static var mfaChallengeRetry: String { s("mfa_challenge_retry") }
    static var mfaChallengeFailed: String { s("mfa_challenge_failed") }
    static var mfaEnterCode: String { s("mfa_enter_code") }
    static var mfaResendCode: String { s("mfa_resend_code") }
    static var mfaVerify: String { s("mfa_verify") }
    static var mfaCancel: String { s("mfa_cancel") }
    static func mfaResendFailed(_ error: String) -> String { s("mfa_resend_failed", error) }
    static func mfaRequestFailed(_ error: String) -> String { s("mfa_request_failed", error) }

    // MARK: - Brand
    static var appName: String { s("app_name") }
    static var appNameShort: String { s("app_name_short") }
    static var projectName: String { s("project_name") }

    // MARK: - Session
    static var sessionExpiredToast: String { s("session_expired_toast") }
}

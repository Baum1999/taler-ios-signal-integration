/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation

enum BankDialectString {
    case deleteExchange     // button title
    case warningText1       // first warning, simple
    case warningText2       // second warning
    case warningText3       // consequence for 2nd, with currency name
}

func localizedString(_ key: BankDialectString, forDialect: BankDialect?, _ option: String = "") -> String {
    if forDialect == .gls {
        switch key {
            case .deleteExchange:
                return String(localized: "GLS.Exchange.Delete.Button", defaultValue: "Terminate contract", comment: "button title")

            case .warningText1:
                return String(localized: "GLS.Exchange.Delete.Warning1", defaultValue: "Are you sure you want to terminate this contract?")

            case .warningText2:
                return String(localized: "GLS.Exchange.Delete.Warning2", defaultValue: "You still have digital money in your wallet. Terminate anyway?")

            case .warningText3:
                return String(localized: "GLS.Exchange.Delete.Warning3", defaultValue: "You will loose all \(option) of this contract.", comment: "Currency")
        }
    }
    // more dialects here... 
    switch key {
        case .deleteExchange:
            return String(localized: "Exchange.Delete.Button", defaultValue: "Delete payment service", comment: "button title")

        case .warningText1:
            return String(localized: "Exchange.Delete.Warning1", defaultValue: "Are you sure you want to delete this payment service?")

        case .warningText2:
            return String(localized: "Exchange.Delete.Warning2", defaultValue: "This payment service is in use. Delete anyway?")

        case .warningText3:
            return String(localized: "Exchange.Delete.Warning3", defaultValue: "You will loose all \(option) of this payment service.", comment: "Currency")
    }
}

//
//  CustomFormatters.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//
import UIKit
import DGCharts


class PriceFormatter: NSObject, AxisValueFormatter {
    private let formatter: NumberFormatter

    override init() {
        formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        formatter.locale = Locale(identifier: "en_US_POSIX") 
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}


class DateValueFormatter: NSObject, AxisValueFormatter {
    private var dateFormatter = DateFormatter()
    private var referenceDates: [Date] = []

    override init() {
        super.init()
        dateFormatter.dateFormat = "dd/MM"
    }

    func updateDates(_ newDates: [Date]) {
        self.referenceDates = newDates
        let interval = newDates.last?.timeIntervalSince(newDates.first ?? Date()) ?? 0
        dateFormatter.dateFormat = interval < 86400 ? "HH:mm" : "dd/MM"
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = Date(timeIntervalSince1970: value)
        return dateFormatter.string(from: date)
    }
}

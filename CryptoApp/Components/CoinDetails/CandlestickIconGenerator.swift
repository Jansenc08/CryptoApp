//
//  CandlestickIconGenerator.swift
//  CryptoApp
//
//  Created by Assistant on 1/31/25.
//

import UIKit

struct CandlestickIconGenerator {
    
    static func generateCandlestickIcon(size: CGSize = CGSize(width: 20, height: 20)) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Calculate dimensions
            let width = size.width
            let height = size.height
            let candleWidth = width * 0.25
            let wickWidth: CGFloat = 1.5
            
            // Left candlestick (bearish/red)
            let leftCenterX = width * 0.25
            drawCandlestick(
                context: cgContext,
                centerX: leftCenterX,
                height: height,
                candleWidth: candleWidth,
                wickWidth: wickWidth,
                color: UIColor.systemRed,
                isBullish: false
            )
            
            // Right candlestick (bullish/green)
            let rightCenterX = width * 0.75
            drawCandlestick(
                context: cgContext,
                centerX: rightCenterX,
                height: height,
                candleWidth: candleWidth,
                wickWidth: wickWidth,
                color: UIColor.systemGreen,
                isBullish: true
            )
        }
    }
    
    private static func drawCandlestick(context: CGContext, centerX: CGFloat, height: CGFloat, candleWidth: CGFloat, wickWidth: CGFloat, color: UIColor, isBullish: Bool) {
        
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(wickWidth)
        
        // Calculate vertical positions
        let topPadding = height * 0.1
        let bottomPadding = height * 0.1
        let availableHeight = height - topPadding - bottomPadding
        
        // Wick positions
        let wickTop = topPadding
        let wickBottom = height - bottomPadding
        
        // Body positions (different for bullish/bearish)
        let bodyHeight = availableHeight * 0.6
        let bodyTop: CGFloat
        let bodyBottom: CGFloat
        
        if isBullish {
            // Bullish: body in lower portion
            bodyBottom = wickBottom - availableHeight * 0.15
            bodyTop = bodyBottom - bodyHeight
        } else {
            // Bearish: body in upper portion
            bodyTop = wickTop + availableHeight * 0.15
            bodyBottom = bodyTop + bodyHeight
        }
        
        // Draw upper wick
        context.move(to: CGPoint(x: centerX, y: wickTop))
        context.addLine(to: CGPoint(x: centerX, y: bodyTop))
        context.strokePath()
        
        // Draw lower wick
        context.move(to: CGPoint(x: centerX, y: bodyBottom))
        context.addLine(to: CGPoint(x: centerX, y: wickBottom))
        context.strokePath()
        
        // Draw body
        let bodyRect = CGRect(
            x: centerX - candleWidth / 2,
            y: bodyTop,
            width: candleWidth,
            height: bodyHeight
        )
        
        if isBullish {
            // Bullish candle: hollow (stroke only)
            context.setLineWidth(1.5)
            context.stroke(bodyRect)
        } else {
            // Bearish candle: filled
            context.fill(bodyRect)
        }
    }
}

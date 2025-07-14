//
//  Double+Abbreviation.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 10/7/25.
//

import Foundation

extension Double {
    /// Converts large numbers to abbreviated strings (e.g., 1.5B, 2.3M)
    func abbreviatedString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        
        if self >= 1_000_000_000_000 {
            return formatter.string(from: NSNumber(value: self / 1_000_000_000_000))! + "T"
        } else if self >= 1_000_000_000 {
            return formatter.string(from: NSNumber(value: self / 1_000_000_000))! + "B"
        } else if self >= 1_000_000 {
            return formatter.string(from: NSNumber(value: self / 1_000_000))! + "M"
        } else if self >= 1_000 {
            return formatter.string(from: NSNumber(value: self / 1_000))! + "K"
        } else {
            return formatter.string(from: NSNumber(value: self))!
        }
    }
}

// MARK: - Combine Extensions for Enhanced Error Handling

import Combine

extension Publisher {
    /// Retry with exponential backoff delay
    func retryWithExponentialBackoff(maxRetries: Int, initialDelay: Double = 1.0) -> AnyPublisher<Output, Failure> {
        return self.catch { error -> AnyPublisher<Output, Failure> in
            guard maxRetries > 0 else {
                return Fail(error: error).eraseToAnyPublisher()
            }
            
            return (1...maxRetries).publisher
                .flatMap { retryCount -> AnyPublisher<Output, Failure> in
                    let delay = initialDelay * pow(2.0, Double(retryCount - 1))
                    //print("🔄 Retry attempt \(retryCount) after \(delay) seconds")
                    
                    return Just(())
                        .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
                        .flatMap { _ in
                            return self
                        }
                        .eraseToAnyPublisher()
                }
                .first()
                .catch { _ in
                    return Fail(error: error)
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    /// Retry with custom retry strategy
    func retryWithStrategy<S: Scheduler>(
        maxRetries: Int,
        retryDelay: @escaping (Int) -> S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> AnyPublisher<Output, Failure> {
        return self.catch { error -> AnyPublisher<Output, Failure> in
            guard maxRetries > 0 else {
                return Fail(error: error).eraseToAnyPublisher()
            }
            
            return (1...maxRetries).publisher
                .flatMap { retryCount -> AnyPublisher<Output, Failure> in
                    let delay = retryDelay(retryCount)
                    
                    return Just(())
                        .delay(for: delay, scheduler: scheduler)
                        .flatMap { _ in
                            return self
                        }
                        .eraseToAnyPublisher()
                }
                .first()
                .catch { _ in
                    return Fail(error: error)
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

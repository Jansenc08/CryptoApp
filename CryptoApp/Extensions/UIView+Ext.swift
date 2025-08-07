//
//  UIView+Ext.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 4/8/25.
//

import UIKit

extension UIView {
    
    func addSubviews(_ views: UIView...) {
        for view in views {
            addSubview(view)
        }
    }
    
    func addSubviews(contentsOf views: [UIView]) {
        for view in views {
            addSubview(view)
        }
    }
}

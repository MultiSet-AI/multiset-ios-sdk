/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import CoreGraphics

public enum MSSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48
}

public enum MSRadius {
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 10
    public static let lg: CGFloat = 14
    public static let xl: CGFloat = 20
    public static let pill: CGFloat = 999
}

public enum MSSize {
    /// Apple's minimum comfortable hit target.
    public static let minTouchTarget: CGFloat = 44
    /// The height every text field and button stands at, so a form reads as one column
    /// of controls rather than a stack of different-sized boxes. A `minHeight` at every
    /// use, never a fixed one: at accessibility text sizes a control has to grow.
    public static let control: CGFloat = 52
    public static let iconSm: CGFloat = 16
    public static let iconMd: CGFloat = 20
    public static let iconLg: CGFloat = 28
    public static let thumbnail: CGFloat = 56
}

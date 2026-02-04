import Cocoa

/// 统一设计系统 - 所有 UI 组件应使用这些变量以保持一致性
enum DesignTokens {

    // MARK: - Colors

    enum Colors {
        /// 选择遮罩背景色
        static let overlayDim = NSColor.black.withAlphaComponent(0.35)

        /// 选中区域边框色
        static let selectionBorder = NSColor.white

        /// 悬停高亮填充色
        static let hoverFill = NSColor.systemBlue.withAlphaComponent(0.25)

        /// 悬停高亮边框色
        static let hoverBorder = NSColor.systemBlue

        /// 裁剪区域外部遮罩
        static let cropOverlay = NSColor.black.withAlphaComponent(0.5)

        /// 编辑状态边框色
        static let editingBorder = NSColor.systemBlue.withAlphaComponent(0.6)

        /// 工具栏背景色
        static let toolbarBackground = NSColor.windowBackgroundColor

        /// 默认标注颜色
        static let annotationDefault = NSColor.systemRed
    }

    // MARK: - Spacing (基于 4pt 栅格)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Border

    enum Border {
        static let widthThin: CGFloat = 1
        static let widthMedium: CGFloat = 2
        static let widthThick: CGFloat = 3

        static let radiusSmall: CGFloat = 4
        static let radiusMedium: CGFloat = 6
        static let radiusLarge: CGFloat = 8
    }

    // MARK: - Sizes

    enum Sizes {
        static let toolbarHeight: CGFloat = 44
        static let buttonMinWidth: CGFloat = 70
        static let iconButtonSize: CGFloat = 28
        static let colorWellSize: CGFloat = 24
        static let separatorHeight: CGFloat = 24
        static let zoomSliderWidth: CGFloat = 100
        static let zoomLabelWidth: CGFloat = 44
    }

    // MARK: - Typography

    enum Typography {
        static func caption() -> NSFont {
            NSFont.systemFont(ofSize: 11, weight: .regular)
        }

        static func captionMono() -> NSFont {
            NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        }

        static func body() -> NSFont {
            NSFont.systemFont(ofSize: 13, weight: .regular)
        }

        static func bodyMedium() -> NSFont {
            NSFont.systemFont(ofSize: 13, weight: .medium)
        }

        static func annotation(size: CGFloat) -> NSFont {
            NSFont.systemFont(ofSize: size, weight: .medium)
        }
    }

    // MARK: - Animation

    enum Animation {
        static let durationFast: TimeInterval = 0.1
        static let durationNormal: TimeInterval = 0.15
        static let durationSlow: TimeInterval = 0.25
    }

    // MARK: - Shadow

    enum Shadow {
        static func standard() -> NSShadow {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.shadowBlurRadius = 8
            return shadow
        }

        static func floating() -> NSShadow {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
            shadow.shadowOffset = NSSize(width: 0, height: -4)
            shadow.shadowBlurRadius = 12
            return shadow
        }
    }
}

// MARK: - SwiftUI Bridge

import SwiftUI

extension DesignTokens.Colors {
    static var overlayDimSwiftUI: Color {
        Color.black.opacity(0.35)
    }

    static var selectionBorderSwiftUI: Color {
        Color.white
    }
}

extension DesignTokens.Spacing {
    static var xsSwiftUI: CGFloat { xs }
    static var sSwiftUI: CGFloat { s }
    static var mSwiftUI: CGFloat { m }
    static var lSwiftUI: CGFloat { l }
}

import AppKit
import Testing
@testable import TinCal

/// 状态栏点击命中判定：内点 / 边界 / 外点。
///
/// 背景：`handleOutsideClick` 曾按 `event.window` 身份排除按钮，实测不可靠（global monitor
/// 路径下 window 为 nil），会误关刚展开的面板；现改为坐标命中，这里是该防线的回归锁。
@Test func hitWhenPointIsInsideFrame() {
    let frame = NSRect(x: 100, y: 0, width: 135, height: 22)

    #expect(StatusBarHitTest.contains(pointInSuperview: NSPoint(x: 120, y: 10), buttonFrame: frame))
}

@Test func missWhenPointIsOutsideFrame() {
    let frame = NSRect(x: 100, y: 0, width: 135, height: 22)

    #expect(!StatusBarHitTest.contains(pointInSuperview: NSPoint(x: 99, y: 10), buttonFrame: frame))
    #expect(!StatusBarHitTest.contains(pointInSuperview: NSPoint(x: 240, y: 10), buttonFrame: frame))
}

@Test func boundaryUsesRectContainsSemantics() {
    // 与 NSRect.contains 一致：左/下边界含，右/上边界不含。
    let frame = NSRect(x: 100, y: 0, width: 135, height: 22)

    #expect(StatusBarHitTest.contains(pointInSuperview: NSPoint(x: 100, y: 0), buttonFrame: frame))
    #expect(!StatusBarHitTest.contains(pointInSuperview: NSPoint(x: 235, y: 10), buttonFrame: frame))
    #expect(!StatusBarHitTest.contains(pointInSuperview: NSPoint(x: 120, y: 22), buttonFrame: frame))
}

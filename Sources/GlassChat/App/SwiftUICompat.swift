import SwiftUI

/// `@Local` — 与 `@State` 完全等价的本地视图状态包装器。
///
/// 背景: macOS 26+ SDK 把 `@State` 宏化 (SwiftUIMacros), 而该宏插件只随
/// 完整版 Xcode 发布; 仅安装 Command Line Tools 时编译会失败。
/// 这里用「组合 SwiftUI.State」的方式实现等价能力:
/// SwiftUI 的动态属性发现机制会递归扫描值类型存储属性,
/// 因此内部持有的 `SwiftUI.State` 依然会被正确安装与刷新。
///
/// 用法与 @State 一致: `@Local private var draft = ""`, 投影值 `$draft`
/// 得到 `Binding`。安装完整 Xcode 后可全局替换回 `@State`。
@propertyWrapper
struct Local<Value>: DynamicProperty {
    private var inner: SwiftUI.State<Value>

    init(wrappedValue: Value) {
        inner = SwiftUI.State(wrappedValue: wrappedValue)
    }

    init(initialValue: Value) {
        inner = SwiftUI.State(initialValue: initialValue)
    }

    var wrappedValue: Value {
        get { inner.wrappedValue }
        nonmutating set { inner.wrappedValue = newValue }
    }

    var projectedValue: Binding<Value> {
        inner.projectedValue
    }
}

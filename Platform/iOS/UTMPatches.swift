//
// Copyright © 2022 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit

/// Handles Obj-C patches to fix SwiftUI issues
final class UTMPatches {
    static private var isPatched: Bool = false
    
    /// Installs the patches
    /// TODO: Some thread safety/race issues etc
    static func patchAll() {
        UIViewController.patchViewController()
        UIPress.patchPress()
        UIWindow.patchWindow()
    }
}

fileprivate extension NSObject {
    static func patch(_ original: Selector, with swizzle: Selector, class cls: AnyClass?) {
        let originalMethod = class_getInstanceMethod(cls, original)!
        let swizzleMethod = class_getInstanceMethod(cls, swizzle)!
        method_exchangeImplementations(originalMethod, swizzleMethod)
    }
}

/// We need to set these when the VM starts running since there is no way to do it from SwiftUI right now
extension UIViewController {
    private static var _childForHomeIndicatorAutoHiddenStorage: [UIViewController: UIViewController] = [:]
    
    @objc private dynamic var _childForHomeIndicatorAutoHidden: UIViewController? {
        Self._childForHomeIndicatorAutoHiddenStorage[self]
    }
    
    @objc dynamic func setChildForHomeIndicatorAutoHidden(_ value: UIViewController?) {
        if let value = value {
            Self._childForHomeIndicatorAutoHiddenStorage[self] = value
        } else {
            Self._childForHomeIndicatorAutoHiddenStorage.removeValue(forKey: self)
        }
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    private static var _childViewControllerForPointerLockStorage: [UIViewController: UIViewController] = [:]
    
    @objc private dynamic var _childViewControllerForPointerLock: UIViewController? {
        Self._childViewControllerForPointerLockStorage[self]
    }
    
    @objc dynamic func setChildViewControllerForPointerLock(_ value: UIViewController?) {
        if let value = value {
            Self._childViewControllerForPointerLockStorage[self] = value
        } else {
            Self._childViewControllerForPointerLockStorage.removeValue(forKey: self)
        }
        setNeedsUpdateOfPrefersPointerLocked()
    }
    
    /// SwiftUI currently does not provide a way to set the View Conrtoller's home indicator or pointer lock
    fileprivate static func patchViewController() {
        patch(#selector(getter: Self.childForHomeIndicatorAutoHidden),
              with: #selector(getter: Self._childForHomeIndicatorAutoHidden),
              class: Self.self)
        patch(#selector(getter: Self.childViewControllerForPointerLock),
              with: #selector(getter: Self._childViewControllerForPointerLock),
              class: Self.self)
    }
}

extension UIPress {
    @objc static weak var pressResponderOverride: UIResponder?
    
    @objc private dynamic var _responder: UIResponder? {
        Self.pressResponderOverride ?? self._responder
    }
    
    /// On iOS 15.0, there is a bug where SwiftUI does not propogate the presses event down
    /// to a child view controller. This is not seen in iOS 14.5 or iOS 15.1.
    fileprivate static func patchPress() {
        if #available(iOS 15.0, *) {
            if #unavailable(iOS 15.1) {
                patch(#selector(getter: Self.responder),
                      with: #selector(getter: Self._responder),
                      class: Self.self)
            }
        }
    }
}

private var IndirectPointerTouchIgnoredHandle: Int = 0

/// Patch to allow ignoring indirect touch when capturing pointer
extension UIWindow {
    /// When true, `sendEvent(_:)` will ignore any indirect touch events.
    @objc var isIndirectPointerTouchIgnored: Bool {
        set {
            let number = NSNumber(booleanLiteral: newValue)
            objc_setAssociatedObject(self, &IndirectPointerTouchIgnoredHandle, number, .OBJC_ASSOCIATION_ASSIGN)
        }
        
        get {
            let number = objc_getAssociatedObject(self, &IndirectPointerTouchIgnoredHandle) as? NSNumber
            return number?.boolValue ?? false
        }
    }
    
    /// Replacement `sendEvent(_:)` function
    /// - Parameter event: The event to dispatch.
    @objc private func xxx_sendEvent(_ event: UIEvent) {
        if isIndirectPointerTouchIgnored && event.type == .touches {
            event.touches(for: self)?.forEach { touch in
                if touch.type == .indirectPointer {
                    // for some reason, if we just ignore the event, future touch events get messed up
                    // so as an alternative, we still pass the event through but with a modified coordinate
                    touch.perform(Selector(("_setLocationInWindow:resetPrevious:")),
                                  with: CGPoint(x: -1, y: -1),
                                  with: true)
                }
            }
        }
        xxx_sendEvent(event)
    }
    
    fileprivate static func patchWindow() {
        patch(#selector(sendEvent),
              with: #selector(xxx_sendEvent),
              class: Self.self)
    }
}

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

import Foundation
import Virtualization

@available(macOS 12, *)
class VMDisplayAppleDisplayWindowController: VMDisplayAppleWindowController {
    var appleView: VZVirtualMachineView! {
        mainView as? VZVirtualMachineView
    }
    
    var supportsReconfiguration: Bool {
        guard #available(macOS 14, *) else {
            return false
        }
        guard let display = appleVM.apple?.graphicsDevices.first?.displays.first else {
            return false
        }
        return display.value(forKey: "_supportsReconfiguration") as? Bool ?? false
    }
    
    private var aspectRatioLocked: Bool = false
    
    @Setting("FullScreenAutoCapture") private var isFullScreenAutoCapture: Bool = false
    
    override func windowDidLoad() {
        mainView = VZVirtualMachineView()
        captureMouseToolbarButton.image = captureMouseToolbarButton.alternateImage // show capture keyboard image
        super.windowDidLoad()
    }
    
    override func enterLive() {
        appleView.virtualMachine = appleVM.apple
        if #available(macOS 14, *) {
            appleView.automaticallyReconfiguresDisplay = true
        }
        super.enterLive()
    }
    
    override func enterSuspended(isBusy busy: Bool) {
        if !busy {
            NSCursor.unhide() // in case it's hidden by the VM view
        }
        appleView.virtualMachine = nil
        captureMouseToolbarButton.state = .off
        captureMouseButtonPressed(self)
        super.enterSuspended(isBusy: busy)
    }
    
    @available(macOS 12, *)
    private func windowSize(for display: UTMAppleConfigurationDisplay) -> CGSize {
        let currentScreenScale = window?.screen?.backingScaleFactor ?? 1.0
        let useHidpi = display.pixelsPerInch >= 226
        let scale = useHidpi ? currentScreenScale : 1.0
        return CGSize(width: CGFloat(display.widthInPixels) / scale, height: CGFloat(display.heightInPixels) / scale)
    }
    
    override func updateWindowFrame() {
        guard let window = window else {
            return
        }
        guard let primaryDisplay = appleConfig.displays.first else {
            return //FIXME: add multiple displays
        }
        let size = windowSize(for: primaryDisplay)
        let frame = window.frameRect(forContentRect: CGRect(origin: window.frame.origin, size: size))
        window.contentAspectRatio = size
        aspectRatioLocked = true
        window.minSize = NSSize(width: 400, height: 400)
        window.setFrame(frame, display: false, animate: true)
        super.updateWindowFrame()
    }
    
    override func resizeConsoleButtonPressed(_ sender: Any) {
        updateWindowFrame()
    }
    
    override func captureMouseButtonPressed(_ sender: Any) {
        appleView!.capturesSystemKeys = captureMouseToolbarButton.state == .on
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        if isFullScreenAutoCapture {
            captureMouseToolbarButton.state = .on
            captureMouseButtonPressed(self)
        }
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        if isFullScreenAutoCapture {
            captureMouseToolbarButton.state = .off
            captureMouseButtonPressed(self)
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        if aspectRatioLocked && supportsReconfiguration {
            window!.resizeIncrements = NSSize(width: 1.0, height: 1.0)
            aspectRatioLocked = false
        }
    }
}

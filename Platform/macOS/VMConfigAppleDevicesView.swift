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

import SwiftUI

struct VMConfigAppleDevicesView: View {
    @Binding var config: UTMAppleConfigurationDevices
    
    var body: some View {
        Form {
            Toggle("Enable Balloon Device", isOn: $config.hasBalloon)
            Toggle("Enable Entropy Device", isOn: $config.hasEntropy)
            if #available(macOS 12, *) {
                Toggle("Enable Sound", isOn: $config.hasAudio)
                Toggle("Enable Keyboard", isOn: $config.hasKeyboard)
                VMConfigConstantPicker("Pointer", selection: $config.pointer)
            }
        }
    }
}

struct VMConfigAppleDevicesView_Previews: PreviewProvider {
    @State static private var config = UTMAppleConfigurationDevices()
    static var previews: some View {
        VMConfigAppleDevicesView(config: $config)
    }
}
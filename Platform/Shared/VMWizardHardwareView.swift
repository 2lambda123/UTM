//
// Copyright © 2021 osy. All rights reserved.
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
#if canImport(Virtualization)
import Virtualization
#endif

struct VMWizardHardwareView: View {
    @ObservedObject var wizardState: VMWizardState
    
    var minCores: Int {
        #if canImport(Virtualization)
        VZVirtualMachineConfiguration.minimumAllowedCPUCount
        #else
        1
        #endif
    }
    
    var maxCores: Int {
        #if canImport(Virtualization)
        VZVirtualMachineConfiguration.maximumAllowedCPUCount
        #else
        Int(sysctlIntRead("hw.ncpu"))
        #endif
    }
    
    var minMemory: UInt64 {
        #if canImport(Virtualization)
        VZVirtualMachineConfiguration.minimumAllowedMemorySize
        #else
        UInt64(8 * wizardState.bytesInMib)
        #endif
    }
    
    var maxMemory: UInt64 {
        #if canImport(Virtualization)
        VZVirtualMachineConfiguration.maximumAllowedMemorySize
        #else
        sysctlIntRead("hw.memsize")
        #endif
    }
    
    var body: some View {
        #if os(macOS)
        Text("Hardware")
            .font(.largeTitle)
        #endif
        List {
            if !wizardState.useVirtualization {
                Section {
                    VMConfigStringPicker(selection: $wizardState.systemArchitecture, rawValues: UTMLegacyQemuConfiguration.supportedArchitectures(), displayValues: UTMLegacyQemuConfiguration.supportedArchitecturesPretty())
                        .onChange(of: wizardState.systemArchitecture) { newValue in
                            if let newValue = newValue {
                                wizardState.systemTarget = defaultTarget(for: newValue)
                            } else {
                                wizardState.systemTarget = nil
                            }
                        }
                } header: {
                    Text("Architecture")
                }
                
                Section {
                    VMConfigStringPicker(selection: $wizardState.systemTarget, rawValues: UTMLegacyQemuConfiguration.supportedTargets(forArchitecture: wizardState.systemArchitecture), displayValues: UTMLegacyQemuConfiguration.supportedTargets(forArchitecturePretty: wizardState.systemArchitecture))
                } header: {
                    Text("System")
                }

            }
            Section {
                RAMSlider(systemMemory: $wizardState.systemMemory) { _ in
                    if wizardState.systemMemory < minMemory {
                        wizardState.systemMemory = minMemory
                    } else if wizardState.systemMemory > maxMemory {
                        wizardState.systemMemory = maxMemory
                    }
                }
            } header: {
                Text("Memory")
            }
            
            Section {
                HStack {
                    Stepper(value: $wizardState.systemCpuCount, in: minCores...maxCores) {
                        Text("CPU Cores")
                    }
                    NumberTextField("", number: $wizardState.systemCpuCount, prompt: "Default", onEditingChanged: { _ in
                        guard wizardState.systemCpuCount != 0  else {
                            return
                        }
                        if wizardState.systemCpuCount < minCores {
                            wizardState.systemCpuCount = minCores
                        } else if wizardState.systemCpuCount > maxCores {
                            wizardState.systemCpuCount = maxCores
                        }
                    })
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("CPU")
            }
            
            
            
            if !wizardState.useAppleVirtualization && wizardState.operatingSystem == .Linux {
                Section {
                    Toggle("Enable hardware OpenGL acceleration (experimental)", isOn: $wizardState.isGLEnabled)
                } header: {
                    Text("Hardware OpenGL Acceleration")
                }
                
            }
        }
        .navigationTitle(Text("Hardware"))
        .textFieldStyle(.roundedBorder)
        .onAppear {
            if wizardState.useVirtualization {
                #if arch(arm64)
                wizardState.systemArchitecture = "aarch64"
                #elseif arch(x86_64)
                wizardState.systemArchitecture = "x86_64"
                #else
                #error("Unsupported architecture.")
                #endif
                wizardState.systemTarget = nil
            }
            if wizardState.systemArchitecture == nil {
                wizardState.systemArchitecture = "x86_64"
            }
            if wizardState.systemTarget == nil {
                wizardState.systemTarget = defaultTarget(for: wizardState.systemArchitecture!)
            }
        }
    }
    
    private func sysctlIntRead(_ name: String) -> UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return value
    }
    
    private func defaultTarget(for architecture: String) -> String {
        let targets = UTMLegacyQemuConfiguration.supportedTargets(forArchitecture: architecture)
        let index = UTMLegacyQemuConfiguration.defaultTargetIndex(forArchitecture: architecture)
        return targets![index]
    }
}

struct VMWizardHardwareView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()
    
    static var previews: some View {
        VMWizardHardwareView(wizardState: wizardState)
    }
}

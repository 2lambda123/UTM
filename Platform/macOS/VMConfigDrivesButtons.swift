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

struct VMConfigNewDriveButton: View {
    @ObservedObject var config: UTMQemuConfiguration
    let qemuSystem: UTMQemuConfigurationSystem?
    @EnvironmentObject private var data: UTMData
    @State private var newDrivePopover: Bool = false
    @StateObject private var newQemuDrive: UTMQemuConfigurationDrive = .init()
    @State private var newAppleDriveSize: Int = 0
    @State private var importDrivePresented: Bool = false

    var body: some View {
        Button {
            newDrivePopover.toggle()
        } label: {
            Label("New Drive", systemImage: "externaldrive.badge.plus")
        }
        .help("Add a new drive.")
        .fileImporter(isPresented: $importDrivePresented, allowedContentTypes: [.item], onCompletion: importDrive)
        .onChange(of: newDrivePopover, perform: { showPopover in
            if showPopover {
                if let qemuSystem = qemuSystem {
                    newQemuDrive.reset(forArchitecture: qemuSystem.architecture, target: qemuSystem.target)
                } else {
                    newAppleDriveSize = 10240
                }
            }
        })
        .popover(isPresented: $newDrivePopover, arrowEdge: .top) {
            VStack {
                if let qemuSystem = qemuSystem {
                    VMConfigDriveCreateView(config: newQemuDrive, system: qemuSystem)
                } else {
                    VMConfigAppleDriveCreateView(driveSize: $newAppleDriveSize)
                }
                HStack {
                    Spacer()
                    Button(action: { importDrivePresented.toggle() }, label: {
                        if qemuSystem != nil && newQemuDrive.isRemovable {
                            Text("Browse…")
                        } else {
                            Text("Import…")
                        }
                    }).help("Select an existing disk image.")
                    Button(action: { addNewDrive(newQemuDrive) }, label: {
                        Text("Create")
                    }).help("Create an empty drive.")
                }
            }.padding()
        }
    }

    private func importDrive(result: Result<URL, Error>) {
        data.busyWorkAsync {
            switch result {
            case .success(let url):
                if true { //FIXME: need to merge with apple config
                    let config = await config
                    let name = url.lastPathComponent
                    if config.drives.contains(where: { image in
                        image.imageURL?.lastPathComponent == name
                    }) {
                        throw NSLocalizedString("An image already exists with that name.", comment: "VMConfigDrivesButton")
                    }
                    await newQemuDrive.imageURL = url
                    DispatchQueue.main.async {
                        let copy = newQemuDrive.copy()
                        config.drives.append(copy)
                    }
                } else if let appleConfig = await config as? UTMLegacyAppleConfiguration {
                    let name = url.lastPathComponent
                    if appleConfig.diskImages.contains(where: { image in
                        image.imageURL?.lastPathComponent == name
                    }) {
                        throw NSLocalizedString("An image already exists with that name.", comment: "VMConfigDrivesButton")
                    }
                    let image = DiskImage(importImage: url)
                    DispatchQueue.main.async {
                        appleConfig.diskImages.append(image)
                    }
                }
                break
            case .failure(let err):
                throw err
            }
        }
    }

    private func addNewDrive(_ newQemuDrive: UTMQemuConfigurationDrive) {
        newDrivePopover = false // hide popover
        data.busyWorkAsync {
            if let _ = qemuSystem {
                DispatchQueue.main.async {
                    let copy = newQemuDrive.copy()
                    config.drives.append(copy)
                }
            } else if let appleConfig = await config as? UTMLegacyAppleConfiguration {
                let image = await DiskImage(newSize: newAppleDriveSize)
                DispatchQueue.main.async {
                    appleConfig.diskImages.append(image)
                }
            }
        }
    }
}


struct VMConfigDrivesButtons: View {
    @ObservedObject var config: UTMQemuConfiguration
    @Binding var selectedDriveIndex: Int?
    
    @StateObject private var newQemuDrive: VMDriveImage = VMDriveImage()
    @State private var newAppleDriveSize: Int = 0
    @State private var importDrivePresented: Bool = false
    
    var countDrives: Int {
        if true { //FIXME: need to merge with apple config
            return config.drives.count
        } else if let appleConfig = config as? UTMLegacyAppleConfiguration {
            return appleConfig.diskImages.count
        } else {
            return 0
        }
    }
    
    var body: some View {
        Group {
            if #available(macOS 12, *) {
                if let index = selectedDriveIndex {
                    if index != 0 {
                        Button {
                            moveDriveUp(fromIndex: index)
                        } label: {
                            Label("Move Up", systemImage: "chevron.up")
                        }.help("Make boot order priority higher.")
                    }
                    if index != countDrives - 1 {
                        Button {
                            moveDriveDown(fromIndex: index)
                        } label: {
                            Label("Move Down", systemImage: "chevron.down")
                        }.help("Make boot order priority lower.")
                    }
                }
            } else { // SwiftUI BUG: macOS 11 doesn't support the conditional views above
                Button {
                    moveDriveUp(fromIndex: selectedDriveIndex!)
                } label: {
                    Label("Move Up", systemImage: "chevron.up")
                }.help("Make boot order priority higher.")
                .disabled(selectedDriveIndex == nil || selectedDriveIndex == 0)
                Button {
                    moveDriveDown(fromIndex: selectedDriveIndex!)
                } label: {
                    Label("Move Down", systemImage: "chevron.down")
                }.help("Make boot order priority lower.")
                .disabled(selectedDriveIndex == nil || selectedDriveIndex == countDrives - 1)
            }
        }.labelStyle(.titleOnly)
    }
    
    func moveDriveUp(fromIndex index: Int) {
        withAnimation {
            if true {  //FIXME: need to merge with apple config
                config.drives.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
            } else if let appleConfig = config as? UTMLegacyAppleConfiguration {
                appleConfig.diskImages.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
            }
            selectedDriveIndex = index - 1
        }
    }
    
    func moveDriveDown(fromIndex index: Int) {
        withAnimation {
            if true { //FIXME: need to merge with apple config
                config.drives.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
            } else if let appleConfig = config as? UTMLegacyAppleConfiguration {
                appleConfig.diskImages.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
            }
            selectedDriveIndex = index + 1
        }
    }
}

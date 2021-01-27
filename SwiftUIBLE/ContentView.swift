//
//  ContentView.swift
//  SwiftUIBLE
//
//  Created by hai on 26/1/21.
//  Copyright © 2021 biorithm. All rights reserved.
//  26 JAN 2021 scan BLE with swiftui
//  - need override init() to create CBCentralManager()
//  - implement CBCentralManagerDelegate with
// 27 JAN 2020 select a peripheral then connect
//  - select a peripheral
//  - connect a peripheral
//  - discover services
//  - list show services 

import Foundation
import SwiftUI
import CoreBluetooth

extension CBPeripheral : Identifiable {
    
}

extension CBService: Identifiable {
    
}

struct ConnectedDeviceView: View {
    @ObservedObject var sot: BLEManager
    var body: some View {
        VStack{
            Text("\(String(self.sot.connectedPeripheral.identifier.uuidString.prefix(4))) - \(self.sot.connectedPeripheral.name ?? "")")
                .lineLimit(1)
                .font(.largeTitle)
            
            List(self.sot.gatProfile){gat in
                Text("\(String(gat.uuid.uuidString.prefix(4))) - \(gat.uuid)")
                    .lineLimit(1)
            }
        }
    }
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var peripherals = [CBPeripheral]()
    @Published var isSwitchedOn = false
    @Published var isScanning = false
    @Published var gatProfile = [CBService]()
    
    var readCharacteristicValue: String = ""
    var readCharacteristicHex: String = ""
    var myCentral: CBCentralManager!
    var connectedPeripheral: CBPeripheral!
    
    override init() {
        super.init()
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isSwitchedOn = true
            print("BLE power on")
        }
        else {
            isSwitchedOn = false
            print("BLE power off")
        }
    }
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        var peripheralFound = false
        for blePeripheral in peripherals {
            if blePeripheral.identifier == peripheral.identifier {
                peripheralFound = true
                break
            }
        }
        
        if !peripheralFound {
            print(peripheral)
            peripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected to \(peripheral.name ?? "unknown")")
        peripheral.readRSSI()
        peripheral.discoverServices(nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        print("RSSI \(RSSI)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Discover service")
        
        if  error != nil  {
            print("Discover service error")
        } else {
            for service in peripheral.services! {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("service \(service)")
        gatProfile.append(service)
        
        if let characteristics  = service.characteristics {
            print("Discover \(characteristics.count) characteristic")
            for characteristic in characteristics {
                print("--> \(characteristic.uuid.uuidString)")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        print("Read value from BLE Characteristic \(characteristic)")
        
        if let value = characteristic.value {
            
            if let stringValue = String(data: value, encoding: .ascii) {
                self.readCharacteristicValue = stringValue
            }
            
            if characteristic.uuid == CBUUID(string: "0x2A19") {
                self.readCharacteristicValue = "\(characteristic.value![0])"
            }
            
            let charSet = CharacterSet(charactersIn: "<>")
            let nsdataStr = NSData.init(data: value)
            let valueHex = nsdataStr.description.trimmingCharacters(in:charSet).replacingOccurrences(of: " ", with: "")
            self.readCharacteristicHex = "0x\(valueHex)"
        }
        
        print("Call delegate")
        //        delegate?.blePeripheralOnRead?(peripheral: self)
    }
    
    func scan(){
        print("start scanning ")
        self.isScanning = true
        myCentral.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func stopScanning() {
        print("stopScanning")
        self.isScanning = false
        self.myCentral.stopScan()
    }
    
    func connectDevice(device: CBPeripheral) {
        self.myCentral?.connect(device, options: nil)
        self.connectedPeripheral =  device
        self.connectedPeripheral.delegate = self
    }
}

struct BLEPeripheralTableView : View {
    @ObservedObject var sot = BLEManager()
    @State var isConnectedDevice = false
    @State var connectedDevice: CBPeripheral!
    var body: some View {
        NavigationView{
            ZStack{
                NavigationLink(destination: ConnectedDeviceView(sot: self.sot),
                               isActive: self.$isConnectedDevice){
                                EmptyView()}
                List(self.sot.peripherals){device in
                    HStack{
                        Text("uuid: \(String(device.identifier.uuidString.prefix(4))) -name:\(String(device.name?.prefix(6) ?? "Unknow")) -rssi:")
                            .lineLimit(1)
                        Spacer()
                        Button(action: {}){
                            Text("Connect")
                                .frame(width: 80, height: 30)
                                .background(Color.green)
                                .foregroundColor(Color.white)
                                .cornerRadius(5)
                                .gesture(TapGesture().onEnded({self.didTapConnectButton(device: device)}))
                        }
                    }
                }
            }
            .navigationBarTitle(Text("BLE"))
            .navigationBarItems(trailing: Button(action: {self.scanBLEDevices()}){
                Text(self.sot.isScanning ? "stop" : "scan" )
            })
        }
    }
    
    func scanBLEDevices(){
        self.sot.isScanning ? self.sot.stopScanning() : self.sot.scan()
    }
    
    func didTapConnectButton(device: CBPeripheral){
        print("connect to device")
        self.isConnectedDevice = true
        self.connectedDevice = device
        self.sot.connectDevice(device: device)
    }
}

struct ContentView: View {
    var body: some View {
        BLEPeripheralTableView()
    }
}

//  MIT @taisukef http://fukuno.jig.jp/1401

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager:CBCentralManager!
    var blueToothReady = false
    var connectingPeripheral: CBPeripheral!
    
    var konashi2 = false
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startUpCentralManager()
    }
    func startUpCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    func discoverDevices() {
        centralManager.scanForPeripheralsWithServices(nil, options: nil)
    }
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {

        // 複数個対応するためには配列にいれよう
        output("Discovered", data: peripheral.name!)
        if !peripheral.name!.hasPrefix("konashi") {
            return
        }
        konashi2 = peripheral.name!.hasPrefix("konashi2")
        
        connectingPeripheral = peripheral
        centralManager.stopScan()
        centralManager.connectPeripheral(peripheral, options: nil)
    }
    func centralManagerDidUpdateState(central: CBCentralManager) { //BLE status
        var msg = ""
        switch (central.state) {
        case .PoweredOff:
            msg = "CoreBluetooth BLE hardware is powered off"
            print("\(msg)")
        case .PoweredOn:
            msg = "CoreBluetooth BLE hardware is powered on and ready"
            blueToothReady = true;
        case .Resetting:
            msg = "CoreBluetooth BLE hardware is resetting"
        case .Unauthorized:
            msg = "CoreBluetooth BLE state is unauthorized"
        case .Unknown:
            msg = "CoreBluetooth BLE state is unknown"
        case .Unsupported:
            msg = "CoreBluetooth BLE hardware is unsupported on this platform"
        }
        output("State", data: msg)
        
        if blueToothReady {
            discoverDevices()
        }
    }
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        peripheral.delegate = self
        if konashi2 {
            peripheral.discoverServices([CBUUID(string: "229BFF00-03FB-40DA-98A7-B0DEF65C2D4B")]) // koshian / konashi2
        } else {
            peripheral.discoverServices([CBUUID(string: "FF00")]) // konashi
        }
        output("Connected", data: peripheral.name!)
    }
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        for servicePeripheral in peripheral.services! {
            output("Service", data: servicePeripheral.UUID)
            peripheral.discoverCharacteristics(nil, forService: servicePeripheral)
        }
    }
    @IBAction func refreshBLE(sender: UIButton) {
        centralManager.scanForPeripheralsWithServices(nil, options: nil)
    }
    var charUartConfig: CBCharacteristic!
    var charUartSetBoundRate: CBCharacteristic!
    var charUartTXD: CBCharacteristic!
    var charUartRXD: CBCharacteristic!
    var konashi: CBPeripheral!
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        // koshian charactericstics http://konashi.ux-xu.com/documents/
        konashi = peripheral
        for charactericsx in service.characteristics! {
            output("Characteristic", data: charactericsx.UUID.UUIDString)

            // UUID 3010 - UART config
            if charactericsx.UUID.UUIDString == "3010" || charactericsx.UUID.UUIDString == "229B3010-03FB-40DA-98A7-B0DEF65C2D4B" {
                charUartConfig = charactericsx
            }
            // UUID 3011 - UART Set Bound Rate
              if charactericsx.UUID.UUIDString == "3011" || charactericsx.UUID.UUIDString == "229B3011-03FB-40DA-98A7-B0DEF65C2D4B" {
                charUartSetBoundRate = charactericsx
            }
            // UUID 3012 - UART TX
            if charactericsx.UUID.UUIDString == "3012" || charactericsx.UUID.UUIDString == "229B3012-03FB-40DA-98A7-B0DEF65C2D4B" {
                charUartTXD = charactericsx
            }
            // UUID 3013 - UART RX Notification
            if charactericsx.UUID.UUIDString == "3013" || charactericsx.UUID.UUIDString == "229B3013-03FB-40DA-98A7-B0DEF65C2D4B" {
                charUartRXD = charactericsx
                
//                peripheral.readValueForCharacteristic(charUartRXD)
            }
            /*
            // UUID 3000 - PIO Setting
            if charactericsx.UUID.UUIDString == "3000" || charactericsx.UUID.UUIDString == "229B3000-03FB-40DA-98A7-B0DEF65C2D4B" {
                let data8:[UInt8] = [ 0x02 ]
                let data: NSData = NSData(bytes:data8, length:1)
                peripheral.writeValue(data, forCharacteristic: charactericsx, type: CBCharacteristicWriteType.WithoutResponse)
            }
            // UUID 3002 - PIO Output
            if charactericsx.UUID.UUIDString == "3002" || charactericsx.UUID.UUIDString == "229B3002-03FB-40DA-98A7-B0DEF65C2D4B" {
                let data8:[UInt8] = [ 0x02 ]
                let data: NSData = NSData(bytes:data8, length:1)
                peripheral.writeValue(data, forCharacteristic: charactericsx, type: CBCharacteristicWriteType.WithoutResponse)
            }
            */
        }
        setBaudRate()
    }
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if let error = error {
            print("notify status change error: \(error)")
        } else {
            print("notify status changed: \(characteristic.isNotifying)")
        }
    }
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?)
    {
        if let error = error {
            print("notify error: \(error)")
            return
        }
        
        if let data: NSData = characteristic.value {
            output("Data", data: data)
            
            var buf = Array<Int8>(count: data.length - 1, repeatedValue: 0)
            data.getBytes(&buf, range: NSRange(location: 1, length: data.length - 1)) // 本当は先頭のbyteを長さを使いたい
            for c in buf {
                print("\(c)")
            }
        }
    }
    func setBaudRate() {
        let data8c0:[UInt8] = [ 0x0 ]
        let datac0 = NSData(bytes: data8c0, length:1)
        konashi.writeValue(datac0, forCharacteristic: charUartConfig, type: CBCharacteristicWriteType.WithoutResponse)

        
        var data8:[UInt8] = [ 0x00, 0x28 ] // 9600 // koshian は9600bpsのみ / 2400/9600 konashi
        if (konashi2) {
            data8 = [ 0x01, 0xe0 ] // 115200 // for konashi2
        }
        let data: NSData = NSData(bytes:data8, length:2)
        konashi.writeValue(data, forCharacteristic: charUartSetBoundRate, type: CBCharacteristicWriteType.WithoutResponse)
    
        let data8c1:[UInt8] = [ 0x1 ]
        let datac1 = NSData(bytes: data8c1, length:1)
        konashi.writeValue(datac1, forCharacteristic: charUartConfig, type: CBCharacteristicWriteType.WithoutResponse)
        
        konashi.setNotifyValue(true, forCharacteristic: charUartRXD) // 必要
    }
    // --
    var data: [UInt8]?
    var ndatasent = 0
    var timer: NSTimer!
    func sendText(str: String) {
        if konashi2 {
            var data = [UInt8](("\u{00}" + str + "\n").utf8)
            data[0] = (UInt8)(data.count - 1)
            let data1: NSData = NSData(bytes: data, length: data.count)
            konashi.writeValue(data1, forCharacteristic: charUartTXD, type: CBCharacteristicWriteType.WithoutResponse)
        } else {
            data = [UInt8]((str + "\n").utf8)
            ndatasent = 0
            timer = NSTimer.scheduledTimerWithTimeInterval(0.05, target: self, selector: #selector(ViewController.send), userInfo: nil, repeats: true)
        }
    }
    func send() {
        let data8:[UInt8] = [ data![ndatasent] ]
        let data1: NSData = NSData(bytes:data8, length:1)
        konashi.writeValue(data1, forCharacteristic: charUartTXD, type: CBCharacteristicWriteType.WithoutResponse)
        print("txd: \(data8)")
        ndatasent += 1
        if ndatasent == data!.count {
            timer!.invalidate()
            timer = nil
        }
    }
    func output(description: String, data: AnyObject){
        print("\(description): \(data)")
    }
    // ---
    @IBOutlet weak var input: UITextField!
    @IBAction func btn(sender: AnyObject) {
        sendText(input.text!)
        input.text = ""
    }
    @IBAction func esc(sender: AnyObject) {
        sendText("\u{1b}")
    }
}
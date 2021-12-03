//
//  ViewController.swift
//  DroneController
//
//  Created by Ponk on 03/12/2021.
//

import UIKit
import DJISDK

class ViewController: UIViewController {
    
    let commonValue:Float = 0.5
    var lastTime = 0.0
    var stopNow = false

    @IBOutlet weak var connectionStateLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func buttonConnectSparkClicked(_ sender: Any) {
        trySparkConnection()
    }
    @IBAction func buttonTakeOff(_ sender: Any) {
        takeOff()
    }
    @IBAction func buttonStop(_ sender: Any) {
        stop()
    }
    @IBAction func buttonLanding(_ sender: Any) {
        landing()
    }
    @IBAction func buttonArc(_ sender: Any) {
        arcAim()
    }
    
    @IBAction func buttonSequence(_ sender: Any) {
        sequence()
    }
}

extension ViewController {
    func trySparkConnection() {
    
        guard let connectedKey = DJIProductKey(param: DJIParamConnection) else {
            NSLog("Error creating the connectedKey")
            return;
        }
        print("on a bien la clef: \(connectedKey)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            DJISDKManager.keyManager()?.startListeningForChanges(on: connectedKey, withListener: self, andUpdate: { (oldValue: DJIKeyedValue?, newValue : DJIKeyedValue?) in
                print(" \(newValue) ")
                if let newVal = newValue {
                    if newVal.boolValue {
                         DispatchQueue.main.async {
                            self.productConnected()
                        }
                    }
                }
            })
            DJISDKManager.keyManager()?.getValueFor(connectedKey, withCompletion: { (value:DJIKeyedValue?, error:Error?) in
                print("key:  \(value) ")
                if let unwrappedValue = value {
                    if unwrappedValue.boolValue {
                        // UI goes on MT.
                        DispatchQueue.main.async {
                            self.productConnected()
                        }
                    }
                }
            })
        }
    }
    
   
    
    func productConnected() {
        guard let newProduct = DJISDKManager.product() else {
            NSLog("Product is connected but DJISDKManager.product is nil -> something is wrong")
            return;
        }
     
        if let model = newProduct.model {
            self.connectionStateLabel.text = "\(model) is connected \n"
            Spark.instance.airCraft = DJISDKManager.product() as? DJIAircraft
            
        }
        
        //Updates the product's firmware version - COMING SOON
        newProduct.getFirmwarePackageVersion{ (version:String?, error:Error?) -> Void in
            
            if let _ = error {
                self.connectionStateLabel.text = self.connectionStateLabel.text! + "Firmware Package Version: \(version ?? "Unknown")"
            }else{
                
            }
            
            print("Firmware package version is: \(version ?? "Unknown")")
        }
        
    }
    
    func productDisconnected() {
        self.connectionStateLabel.text = "Disconnected"
        print("Disconnected")
    }
}


// Spark control
extension ViewController {
    

    struct Movement {

        enum MovementType {
            case forward,backward,left,right,up,down,rotateRight,rotateLeft
        }

        var value:Float
        var type:MovementType
    }
    func getSpark() -> DJIAircraft? {
        if let mySpark = DJISDKManager.product() as? DJIAircraft {
            return mySpark
        }
        return nil
    }
    
    func flightAction(action: @escaping ((DJIFlightController) -> ())) {
        if let s = getSpark()?.flightController {
            action(s)
        }
    }
    
    func controllerAction(action: @escaping ((DJIMobileRemoteController) -> ())) {
        if let s = getSpark()?.mobileRemoteController {
            action(s)
        }
    }
    
    
    func takeOff() {
        flightAction { s in
            s.startTakeoff(completion: { (err) in
                print(err.debugDescription)
                print("take off ended")
            })
        }
    }
    func landing () {
        flightAction { s in
            s.startLanding(completion: { (err) in
                print(err.debugDescription)
                print("landging ended")
            })
        }
    }
    
    func sequence() {
        takeOff()
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
            self.arcAim {
                self.landing()
            }
        }

    }
    
    func arcAim(finished: (() -> ())? = nil) {
        sendCommand(Movement(value: -0.3, type: .left))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendCommand(Movement(value: 0.7, type: .rotateRight))
            self.sendCommand(Movement(value: 0.1, type: .forward))
            
            self.lastTime = NSDate.timeIntervalSinceReferenceDate
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.95) {
                self.stop()
                finished?()
            }
        }

    }
    
    func sendCommand(_ movement:Movement) {
        controllerAction { mobileRemote in
            switch movement.type {
            case .forward,.backward:
                mobileRemote.rightStickVertical = movement.value
            case .left,.right:
                mobileRemote.rightStickHorizontal = movement.value
            case .up,.down:
                mobileRemote.leftStickVertical = movement.value
            case .rotateLeft,.rotateRight:
                mobileRemote.leftStickHorizontal = movement.value
            }
        }
    }
    func stop() {
        stopNow = true
        controllerAction { mobileRemote in
            mobileRemote.leftStickVertical = 0.0
            mobileRemote.leftStickHorizontal = 0.0
            mobileRemote.rightStickHorizontal = 0.0
            mobileRemote.rightStickVertical = 0.0
        }
    }
}




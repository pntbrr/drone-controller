//
//  ViewController.swift
//  DroneController
//
//  Created by Ponk on 03/12/2021.
//

import UIKit
import DJISDK



func asyncDelay(delay: Double, completion: @escaping (() -> ())) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        completion()
    }
}


class ViewController: UIViewController {
    
    let commonValue:Float = 0.5
    var lastTime = 0.0
    var stopNow = false
    
    var allSpherosConnected = false
    var peerTalkConnected = false
    
    let greenGrape:UIColor = UIColor(red: 150/255, green: 255/255, blue: 10/255, alpha: 1)
    let purpleGrape:UIColor = UIColor(red: 140/255, green: 0/255, blue: 205/255, alpha: 1)

    @IBOutlet weak var connectionStateLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        PeerTalkManager.instance.onConnect { address in
            print("connected to \(address)")
            self.peerTalkConnected = true
            if (self.allSpherosConnected) {
                PeerTalkManager.instance.send(message: "spheros connected")
            }
        }
        PeerTalkManager.instance.onMessage { message in
            if message == "rise" {
                // On mettra le délai de la séquence ici
                self.arcSun {
                    PeerTalkManager.instance.send(message: "start arc:8")
                }
            }
            if message == "grow" {
                self.grapeRipens(colorFrom: self.greenGrape, colorTo: self.purpleGrape, duration: 8)
            }
            if message == "start" {
                SharedToyBox.instance.bolts.forEach { bolt in
                    print("bolt")
                    bolt.setMainLed(color: self.greenGrape)
                    bolt.setFrontLed(color: self.greenGrape)
                    bolt.setBackLed(color: self.greenGrape)
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.trySparkConnection()
        }
        DispatchQueue.main.async {
            self.connectSpheros {
                print("spheros connected")
                if (self.peerTalkConnected) {
                    PeerTalkManager.instance.send(message: "spheros connected")
                }
            }
        }
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
        arcSun()
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
            self.connectionStateLabel.textColor = .systemGreen
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

// Spheros control
extension ViewController {
    
    func connectSpheros(spherosConnected: (() -> ())? = nil) {
        // SB-313C - SB-A729 - SB-6C4C
        SharedToyBox.instance.searchForBoltsNamed(["SB-A729", "SB-6C4C"]) { err in
            if err == nil {
                if(SharedToyBox.instance.bolts.count == 2) {
                    
                    SharedToyBox.instance.bolts.forEach { bolt in
                        bolt.setStabilization(state: SetStabilization.State.off)
                        
                        bolt.setMainLed(color: .blue)
                        bolt.setFrontLed(color: .blue)
                        bolt.setBackLed(color: .blue)
                    }
                    
                    spherosConnected?()
                    self.allSpherosConnected = true
                } else {
                    print("Missed to connect to all spheros needed")

                }
            } else {
                print("Failed to connect : \(String(describing: err))")
            }
        }
    }
    
    func grapeRipens(colorFrom: UIColor, colorTo: UIColor, duration: Int) {
        let timing = 1 / 8
        let interpolationArray2 = self.colorInterpolation(colorFrom: colorFrom, colorTo: colorTo, duration: duration)
        let percent = Double(interpolationArray2.count) / 100 * 80
            
        SharedToyBox.instance.bolts.forEach { bolt in
                for t in 0...( interpolationArray2.count - 1) {
                    if Double(t) <= round(percent) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(timing * t)) {
                            bolt.setMainLed(color: interpolationArray2[t])
                            bolt.setFrontLed(color: interpolationArray2[t])
                            bolt.setBackLed(color: interpolationArray2[t])
                        }
                    }
                }
            }
        }
    
func colorInterpolation(colorFrom: UIColor, colorTo: UIColor, duration:Int = 1) -> [UIColor] {
        // pour 1s 30 x 33ms
        let steps = 10 * duration
        var interpolationArray:[UIColor] = []
        
        let color1 = colorFrom.rgbValues()
        let color2 = colorTo.rgbValues()
        
        let pasR = (color2.r - color1.r) / CGFloat(steps)
        let pasG = (color2.g - color1.g) / CGFloat(steps)
        let pasB = (color2.b - color1.b) / CGFloat(steps)
        
        var currentR = color1.r
        var currentG = color1.g
        var currentB = color1.b
        
        for _ in 0...(steps-1) {
   
            currentR += pasR
            currentG += pasG
            currentB += pasB
                                                
            let color:UIColor = UIColor(red: currentR, green: currentG, blue: currentB, alpha: 1)
                                
            interpolationArray.append(color)
        }
        return interpolationArray
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
    
    
    func takeOff(finished: (() -> ())? = nil) {
        flightAction { s in
            s.startTakeoff(completion: { (err) in
                print(err.debugDescription)
                print("take off ended")
            })
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { // 5.0
                finished?()
            }
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
    
    func sequence(takeOffFinished: (() -> ())? = nil) {
        takeOff {
            takeOffFinished?()
            self.sendCommand(Movement(value: 0.6, type: .up))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.stop()
                self.arcAim {
                    self.landing()
                }
            }
        }
    }
    
    func arcAim(finished: (() -> ())? = nil) {
        sendCommand(Movement(value: -0.25, type: .left))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendCommand(Movement(value: 0.55, type: .rotateRight))
            self.sendCommand(Movement(value: 0.095, type: .forward))
            
            self.lastTime = NSDate.timeIntervalSinceReferenceDate
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.3) {
                self.stop()
                self.sendCommand(Movement(value: -1, type: .rotateLeft))
                self.sendCommand(Movement(value: -1, type: .down))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.sendCommand(Movement(value: 0, type: .rotateLeft))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.stop()
                    finished?()
                }
            }
        }

    }
    
    func arcSun(takeOffFinished: (() -> ())? = nil) {
        self.takeOff {
            takeOffFinished?()
            let upCommand = Float(0.7)
            let downCommand = Float(-1.1)
            let leftCommand = Float(-0.32)
            let backwardCommand = Float(0.0)
            let forwardCommand = Float(0.0)
            let totalTime = 8.0
            let verticalPrecision = 10
            
            for i in 1...verticalPrecision {
                let progress = Float(i) / Float(verticalPrecision)
                asyncDelay(delay: (totalTime / 2.0) * Double(progress)) {
                    self.sendCommand(Movement(value: upCommand * (1 - progress), type: .up))
                    self.sendCommand(Movement(value: -backwardCommand * (1 - progress), type: .backward))
                }
            }
            
            self.sendCommand(Movement(value: upCommand, type: .up))
            self.sendCommand(Movement(value: leftCommand, type: .left))
            asyncDelay(delay: totalTime / 2.0) {
                
                for i in 1...verticalPrecision {
                    let progress = Float(i) / Float(verticalPrecision)
                    asyncDelay(delay: (totalTime / 2.0) * Double(progress)) {
                        self.sendCommand(Movement(value: downCommand * (progress), type: .up))
                        self.sendCommand(Movement(value: forwardCommand * (progress), type: .forward))
                    }
                }
                self.sendCommand(Movement(value: downCommand / Float(verticalPrecision), type: .down))
                asyncDelay(delay: totalTime / 2.0) {
//                    self.stop()
                    self.sendCommand(Movement(value: -1, type: .down))
                    self.sendCommand(Movement(value: 0, type: .forward))
                    self.landing()
                    asyncDelay(delay: 2.0) {
                        self.stop()
                    }
                }
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

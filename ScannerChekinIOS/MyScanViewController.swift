//
//  MyScanViewController.swift
//  ScannerChekin
//
//  Created by Alejandro Ruiz Ponce on 14/11/2018.
//  Copyright © 2018 Alejandro Ruiz Ponce. All rights reserved.
//

import UIKit
import SwiftOCR
import AVFoundation
import CoreMotion

protocol ProcessMRZ {
    func processMRZ(mrz:MRZParser)
}

class MyScanViewController: PassportScannerController {
    
    /// Delegate set by the calling controler so that we can pass on ProcessMRZ events.
    var delegate: ProcessMRZ?
    var isFlash: Bool = false
    var effect: UIVisualEffect!
    var orientationLast = UIInterfaceOrientation(rawValue: 0)!
    var motionManager: CMMotionManager?
    var turned: Bool = false
    
    @IBOutlet var blurEffect: UIVisualEffectView!
    @IBOutlet var orientationView: UIView!
    // the .StartScan and .EndScan are IBOutlets and can be linked to your own buttons
    @IBOutlet var buttonClose: UIButton!
    @IBOutlet var flashButton: UIButton!
    @IBOutlet var infoLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad();
        
        blurEffect.isHidden = true
        
        orientationView.layer.cornerRadius = 10
        
        buttonClose.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
        flashButton.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
        infoLabel.layer.masksToBounds = true
        infoLabel.layer.cornerRadius = 8.0
        infoLabel.layer.backgroundColor = #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)
        self.debug = true // So that we can see what's going on (scan text and quality indicator)
        self.accuracy = 1  // 1 = all checksums should pass (is the default so we could skip this line)
        self.mrzType = .auto // Performs a little better when set to td1 or td3
        //self.showPostProcessingFilters = false // Set this to true to to give you a good indication of the scan quality
        
        initializeMotionManager()
        animateIn()
        
    }
    
    func initializeMotionManager() {
        motionManager = CMMotionManager()
        motionManager?.accelerometerUpdateInterval = 0.2
        motionManager?.gyroUpdateInterval = 0.2
        motionManager?.startAccelerometerUpdates(to: (OperationQueue.current)!, withHandler: {
            (accelerometerData, error) -> Void in
            if error == nil {
                self.outputAccelertionData((accelerometerData?.acceleration)!)
            }
            else {
                print("\(error!)")
            }
        })
    }
    
    func outputAccelertionData(_ acceleration: CMAcceleration) {
        var orientationNew: UIInterfaceOrientation
        if acceleration.x >= 0.75 {
            orientationNew = .landscapeLeft
            print("landscapeLeft")
        }
        else if acceleration.x <= -0.75 {
            orientationNew = .landscapeRight

            if !turned {
                turned = true
                animateOut()
            }
        }
        else if acceleration.y <= -0.75 {
            orientationNew = .portrait
            if turned {
                animateIn()
                turned = false
            }
            
        }
        else if acceleration.y >= 0.75 {
            orientationNew = .portraitUpsideDown
            print("portraitUpsideDown")
        }
        else {
            // Consider same as last time
            return
        }
        
        if orientationNew == orientationLast {
            return
        }
        orientationLast = orientationNew
    }

    
    func animateIn() {
        //print("MOSTRANDO POPUP")
        self.view.addSubview(orientationView)
        orientationView.center = self.view.center
        
        orientationView.transform = CGAffineTransform.init(scaleX: 1.3, y: 1.3)
        orientationView.alpha = 0
        
        UIView.animate(withDuration: 0.4) {
            self.blurEffect.isHidden = false
            self.orientationView.alpha = 1
            self.orientationView.transform = CGAffineTransform.identity
        }
    }
    
    func animateOut(){
        //print("OCULTANDO POPUP")
        UIView.animate(withDuration: 0.3, animations: {
            self.orientationView.transform = CGAffineTransform.init(scaleX: 1.3, y: 1.3)
            self.orientationView.alpha = 0
            self.blurEffect.isHidden = true
        }) { (sucess: Bool) in
            self.orientationView.removeFromSuperview()
        }
    }

    
    @IBAction func setFlash(_ sender: Any) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else {
            return
        }
        
        do {
            if !isFlash{
                try device.lockForConfiguration()
                try device.setTorchModeOn(level: 1)
                device.unlockForConfiguration()
                isFlash = true
            } else {
                try device.lockForConfiguration()
                try device.torchMode = .off
                device.unlockForConfiguration()
                isFlash = false
            }
            
            
        } catch {
            print("Torch is not working.")
        }
     }
    
 
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.StartScan(sender: self)
    }
    
    /**
     Called by the PassportScannerController when there was a succesfull scan
     
     :param: mrz The scanned MRZ
     */
    override func successfulScan(mrz: MRZParser) {
        print("mrz: {\(mrz.description)\n}")
        delegate?.processMRZ(mrz: mrz)
        self.dismiss(animated: true, completion: nil)
    }
    
    /**
     Called by the PassportScannerController when the 'close' button was pressed.
     */
    override func abortScan() {
        self.dismiss(animated: true, completion: nil)
    }
    
}

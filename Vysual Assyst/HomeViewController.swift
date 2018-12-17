//
//  FirstViewController.swift
//  Vysual Assyst
//
//  Created by Shawn Patel on 12/16/18.
//  Copyright © 2018 Shawn Patel. All rights reserved.
//

import UIKit
import ARKit
import CoreML
import Vision
import AudioToolbox

class HomeViewController: UIViewController {
    
    @IBOutlet weak var sceneView: ARSCNView!
    
    var timer: Timer!
    var initialLoad: Bool!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initialLoad = true
        
        // Gesture Implementation
        let shortPressRecognizer = UITapGestureRecognizer(target: self, action: #selector(detectDistance(sender:)))
        sceneView.addGestureRecognizer(shortPressRecognizer)
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(detectObject(sender:)))
        sceneView.addGestureRecognizer(longPressRecognizer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Configure AR Scene
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration, options: .resetTracking)
        
        // Initiate Timer to Update Distance
        timer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(updateDistance), userInfo: nil, repeats: true)
    }
    
    @objc func detectDistance(sender: UITapGestureRecognizer) {
        let distance = getDistance()
        
        if distance != -1 {
            print(distance)
            
            if initialLoad {
                initialLoad = false
            }
        } else {
            if initialLoad {
                print("Move Device")
            } else {
                print("Error")
            }
        }
    }
    
    @objc func detectObject(sender: UILongPressGestureRecognizer) {
        
    }
    
    @objc func updateDistance() {
        let distance = getDistance()
        
        if distance <= 1 && distance >= 0 {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
    }
    
    func getDistance() -> Double {
        let hitTest = sceneView.hitTest(CGPoint(x: 0.5, y: 0.5), types: [.existingPlaneUsingExtent, .featurePoint])
        if let distance = hitTest.first?.distance {
            let roundedDistance = Double(round(100 * (distance * 3.28084)) / 100)
            
            return roundedDistance
        } else {
            return -1
        }
    }
}

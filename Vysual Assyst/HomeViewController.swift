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
import AVFoundation
import AudioToolbox

class HomeViewController: UIViewController {
    
    @IBOutlet weak var info: UIBarButtonItem!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var object: UILabel!
    @IBOutlet weak var objectLabel: UILabel!
    @IBOutlet weak var scene: UILabel!
    @IBOutlet weak var sceneLabel: UILabel!
    @IBOutlet weak var crosshair: UIImageView!
    @IBOutlet weak var distance: UILabel!
    
    let synth = AVSpeechSynthesizer()
    
    var imageTimer: Timer!
    var distanceTimer: Timer!
    var player: AVAudioPlayer?
    var strokeTextAttributes: [NSAttributedString.Key : Any]!
    
    var turnOffBeep: Bool!
    
    var hitTestCoordinatesX: Float!
    var hitTestCoordinatesY: Float!
    var hitTestCoordinatesZ: Float!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        info.accessibilityLabel = "Instructions"
        
        sceneView.autoenablesDefaultLighting = true
        crosshair.image = crosshair.image?.withRenderingMode(.alwaysTemplate)
        
        synth.delegate = self
        
        strokeTextAttributes = [
            NSAttributedString.Key.strokeColor : UIColor.black,
            NSAttributedString.Key.foregroundColor : UIColor.white,
            NSAttributedString.Key.strokeWidth : -4.0,
            NSAttributedString.Key.font : UIFont.boldSystemFont(ofSize: 25)
        ]
        
        turnOffBeep = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Configure AR Scene
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration, options: .resetTracking)
        
        // Initiate Timer to Update Distance & Object
        imageTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(processImage), userInfo: nil, repeats: true)
        distanceTimer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(processDistance), userInfo: nil, repeats: true)
        
        // Check for Camera Authorization
        if UserDefaults.standard.bool(forKey: "isFirstLaunch") == false {
            if AVCaptureDevice.authorizationStatus(for: .video) !=  .authorized {
                let alert = UIAlertController(title: "Camera Disabled", message: "Vysual Assyst is unable to function without access to the camera. Would you like to enable the camera permission in settings?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
                    let settingsUrl = URL(string: UIApplication.openSettingsURLString)!
                    UIApplication.shared.open(settingsUrl)
                }))
                alert.addAction(UIAlertAction(title: "No", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            UserDefaults.standard.set(false, forKey: "isFirstLaunch")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
        }
        
        sceneView.session.pause()
        imageTimer.invalidate()
        distanceTimer.invalidate()
        
        object.isHidden = true
        objectLabel.isHidden = true
        scene.isHidden = true
        sceneLabel.isHidden = true
        distance.isHidden = true
    }
    
    @objc func processDistance() {
        let distance = getDistance()
        let maxDistance = UserDefaults.standard.float(forKey: "distanceAlert")
        
        if distance != -1 {
            DispatchQueue.main.async {
                self.crosshair.tintColor = UIColor.green
                self.distance.attributedText = NSAttributedString(string: String(distance) + " ft", attributes: self.strokeTextAttributes)
                self.distance.isHidden = false
            }
        } else {
            DispatchQueue.main.async {
                self.crosshair.tintColor = UIColor.red
                self.distance.attributedText = NSAttributedString(string: "Error", attributes: self.strokeTextAttributes)
                self.distance.isHidden = false
            }
        }
        
        if distance <= maxDistance && distance >= 0 {
            let feedbackSupportLevel: Int = UIDevice.current.value(forKey: "_feedbackSupportLevel") as! Int
            
            if feedbackSupportLevel == 0 {
                // <= iPhone 6
                
                if UserDefaults.standard.bool(forKey: "haptics") {
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                }
            } else if feedbackSupportLevel >= 1 {
                // >= iPhone 6s
                
                if UserDefaults.standard.bool(forKey: "haptics") {
                    AudioServicesPlaySystemSound(1520)
                }
            }
            
            if UserDefaults.standard.bool(forKey: "sound") && !turnOffBeep {
                guard let path = Bundle.main.path(forResource: "Short_Beep", ofType: "m4a") else {
                    print("File does not exist.")
                    return
                }
                let url = URL(fileURLWithPath: path)
                
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
                    
                    player = try AVAudioPlayer(contentsOf: url)
                    player?.play()
                } catch let error {
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    @objc func processImage() {
        let image = sceneView.snapshot()
        
        analyze(object: image)
        analyze(scene: image)
    }
    
    func getDistance() -> Float {
        let hitTest = sceneView.hitTest(sceneView.center, types: [.existingPlaneUsingExtent, .featurePoint])
        
        if let distance = hitTest.first?.distance {
            let roundedDistance = Float(round(100 * (distance * 3.28084)) / 100)
            
            let hitTestCoordinates = hitTest.first?.worldTransform.columns.3
            hitTestCoordinatesX = hitTestCoordinates?.x
            hitTestCoordinatesY = hitTestCoordinates?.y
            hitTestCoordinatesZ = hitTestCoordinates?.z
            
            return roundedDistance
        } else {
            hitTestCoordinatesX = nil
            hitTestCoordinatesY = nil
            hitTestCoordinatesZ = nil
            
            return -1
        }
    }
    
    func analyze(object: UIImage) {
        guard let model = try? VNCoreMLModel(for: MobileNet().model) else {
            fatalError("Can't load MobileNet model.")
        }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else {
                fatalError("Unexpected result type from VNCoreMLRequest.")
            }
            
            DispatchQueue.main.async { [weak self] in
                let items = topResult.identifier.components(separatedBy: ", ")
                let item = items[0].capitalized
                
                self?.object.attributedText = NSAttributedString(string: item, attributes: self?.strokeTextAttributes)
                self?.object.isHidden = false
                self?.objectLabel.isHidden = false
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: CIImage(image: object)!)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }
    
    func analyze(scene: UIImage) {
        guard let model = try? VNCoreMLModel(for: GoogLeNetPlaces().model) else {
            fatalError("Can't load MobileNet model.")
        }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else {
                fatalError("Unexpected result type from VNCoreMLRequest.")
            }
            
            DispatchQueue.main.async { [weak self] in
                let items = topResult.identifier.components(separatedBy: ", ")
                let item = items[0].capitalized.replacingOccurrences(of: "_", with: " ")
                
                self?.scene.attributedText = NSAttributedString(string: item, attributes: self?.strokeTextAttributes)
                self?.scene.isHidden = false
                self?.sceneLabel.isHidden = false
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: CIImage(image: scene)!)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }
    
    func create3DText(text: String, xPos: Float, yPos: Float, zPos: Float) {
        let ARText = SCNText(string: text, extrusionDepth: 1)
        ARText.font = UIFont.systemFont(ofSize: 13)
        ARText.flatness = 0
        ARText.firstMaterial?.diffuse.contents = UIColor.green
        
        let node = SCNNode()
        node.pivot = SCNMatrix4Rotate(node.pivot, Float.pi, 0, 1, 0)
        node.position = SCNVector3(x: xPos, y: yPos, z: zPos)
        node.scale = SCNVector3(0.005, 0.005, 0.005)
        node.geometry = ARText
        
        let parentNode = SCNNode()
        parentNode.position = SCNVector3(x: xPos - 0.1, y: yPos, z: zPos)
        parentNode.addChildNode(node)
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        
        let constraint = SCNLookAtConstraint(target: cameraNode)
        constraint.isGimbalLockEnabled = true
        node.constraints = [constraint]
        
        sceneView.scene.rootNode.addChildNode(parentNode)
    }
    
    func speak(text: String) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        } catch let error {
            print(error.localizedDescription)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        turnOffBeep = true
        
        synth.speak(utterance)
    }
    
    @IBAction func refresh(_ sender: UIBarButtonItem) {
        // Wipe
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
        }
        
        sceneView.session.pause()
        imageTimer.invalidate()
        distanceTimer.invalidate()
        
        // Restore
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration, options: .resetTracking)
        
        imageTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(processImage), userInfo: nil, repeats: true)
        distanceTimer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(processDistance), userInfo: nil, repeats: true)
    }
}

extension HomeViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        turnOffBeep = false
    }
}

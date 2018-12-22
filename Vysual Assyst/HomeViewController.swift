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
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var object: UILabel!
    @IBOutlet weak var distance: UILabel!
    
    let synth = AVSpeechSynthesizer()
    
    var timer: Timer!
    var player: AVAudioPlayer?
    
    var turnOffBeep: Bool!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        synth.delegate = self
        
        turnOffBeep = false
        
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
        timer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(verifyDistance), userInfo: nil, repeats: true)
    }
    
    @objc func detectDistance(sender: UITapGestureRecognizer) {
        let distance = getDistance()
        
        if distance != -1 {
            speak(text: String(distance))
            print(distance)
            
        } else {
            AudioServicesPlaySystemSound(1521)
        }
    }
    
    @objc func detectObject(sender: UILongPressGestureRecognizer) {
        let image = sceneView.snapshot()
        
        if sender.state == UIGestureRecognizer.State.began {
            analyze(image: image)
        }
    }
    
    func analyze(image: UIImage) {
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
                
                self?.speak(text: item)
                
                self?.object.text = item
                self?.object.isHidden = false
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: CIImage(image: image)!)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }
    
    @objc func verifyDistance() {
        let distance = getDistance()
        let maxDistance = UserDefaults.standard.float(forKey: "distanceAlert")
        
        if distance != -1 {
            DispatchQueue.main.async {
                self.distance.text = String(distance) + " ft"
                self.distance.isHidden = false
            }
        } else {
            DispatchQueue.main.async {
                self.distance.text = "Error"
            }
        }
        
        if distance <= maxDistance && distance >= 0 {
            let feedbackSupportLevel: Int = UIDevice.current.value(forKey: "_feedbackSupportLevel") as! Int
            
            if feedbackSupportLevel == 0 {
                // <= iPhone 6
                
                if UserDefaults.standard.bool(forKey: "haptics") {
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                }
            } else if feedbackSupportLevel == 1 {
                // = iPhone 6s
                
                if UserDefaults.standard.bool(forKey: "haptics") {
                    AudioServicesPlaySystemSound(1520)
                }
            } else if feedbackSupportLevel == 2 {
                // >= iPhone 7
                
                if UserDefaults.standard.bool(forKey: "haptics") {
                    let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
                    impactGenerator.prepare()
                    impactGenerator.impactOccurred()
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
    
    func getDistance() -> Float {
        let hitTest = sceneView.hitTest(CGPoint(x: 0.5, y: 0.5), types: [.existingPlaneUsingExtent, .featurePoint])
        if let distance = hitTest.first?.distance {
            let roundedDistance = Float(round(100 * (distance * 3.28084)) / 100)
            
            return roundedDistance
        } else {
            return -1
        }
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
}

extension HomeViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        turnOffBeep = false
    }
}

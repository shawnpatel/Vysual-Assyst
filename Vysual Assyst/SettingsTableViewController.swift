//
//  SettingsTableViewController.swift
//  Vysual Assyst
//
//  Created by Shawn Patel on 12/20/18.
//  Copyright © 2018 Shawn Patel. All rights reserved.
//

import UIKit
import AVFoundation
import AudioToolbox

class SettingsSliderUITableViewCell: UITableViewCell {
    @IBOutlet weak var sliderName: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var sliderValue: UILabel!
}

class SettingsSwitchUITableViewCell: UITableViewCell {
    @IBOutlet weak var switchName: UILabel!
    @IBOutlet weak var `switch`: UISwitch!
}

class SettingsTableViewController: UITableViewController {
    
    @IBOutlet var settingsTableView: UITableView!
    
    var player: AVAudioPlayer?
    
    var settingsOptionsType: [String]!
    var settingsOptionsName: [String]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        settingsOptionsType = ["Slider", "Switch", "Switch"]
        settingsOptionsName = ["Distance Alert", "Haptics", "Sound"]
        
        settingsTableView.delegate = self
        settingsTableView.dataSource = self
        settingsTableView.allowsSelection = false
        settingsTableView.estimatedRowHeight = 50
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsOptionsType.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if settingsOptionsType[indexPath.row] == "Slider" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SliderUI", for: indexPath) as! SettingsSliderUITableViewCell
            
            cell.slider.tag = indexPath.row
            cell.sliderName.text = settingsOptionsName[indexPath.row]
            
            if settingsOptionsName[indexPath.row] == "Distance Alert" {
                cell.slider.minimumValue = 0.5
                cell.slider.maximumValue = 2.0
                
                let sliderValue = UserDefaults.standard.float(forKey: "distanceAlert")
                cell.slider.value = sliderValue
                cell.sliderValue.text = String(sliderValue) + " ft"
            }
            
            cell.slider.addTarget(self, action: #selector(sliderValueChanged(sender:)), for: .valueChanged)
            
            return cell
        } else if settingsOptionsType[indexPath.row] == "Switch" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchUI", for: indexPath) as! SettingsSwitchUITableViewCell
            cell.switch.tag = indexPath.row
            cell.switch.onTintColor = UIColor(red: 254/256, green: 200/256, blue: 8/256, alpha: 1)
            cell.switchName.text = settingsOptionsName[indexPath.row]
            
            if settingsOptionsName[indexPath.row] == "Haptics" {
                cell.switch.isOn = UserDefaults.standard.bool(forKey: "haptics")
            } else if settingsOptionsName[indexPath.row] == "Sound" {
                cell.switch.isOn = UserDefaults.standard.bool(forKey: "sound")
            }
            
            cell.switch.addTarget(self, action: #selector(switchValueChanged(sender:)), for: .valueChanged)
            
            return cell
        }
        
        return UITableViewCell()
    }
    
    @objc func sliderValueChanged(sender: UISlider) {
        if sender.tag == 0 {
            let distanceAlertSliderValue = Float(round(100 * sender.value) / 100)
            UserDefaults.standard.set(distanceAlertSliderValue, forKey: "distanceAlert")
        }
        
        settingsTableView.reloadData()
    }
    
    @objc func switchValueChanged(sender: UISwitch) {
        if sender.tag == 1 {
            UserDefaults.standard.set(sender.isOn, forKey: "haptics")
            
            if sender.isOn == true {
                playHaptics()
            }
        } else if sender.tag == 2 {
            UserDefaults.standard.set(sender.isOn, forKey: "sound")
            
            if sender.isOn == true {
                playSound()
            }
        }
    }
    
    func playHaptics() {
        let feedbackSupportLevel: Int = UIDevice.current.value(forKey: "_feedbackSupportLevel") as! Int
        
        if feedbackSupportLevel == 0 {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        } else if feedbackSupportLevel >= 1 {
            AudioServicesPlaySystemSound(1519)
        }
    }
    
    func playSound() {
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

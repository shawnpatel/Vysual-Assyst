//
//  SettingsTableViewController.swift
//  Vysual Assyst
//
//  Created by Shawn Patel on 12/20/18.
//  Copyright © 2018 Shawn Patel. All rights reserved.
//

import UIKit

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
        } else if sender.tag == 2 {
            UserDefaults.standard.set(sender.isOn, forKey: "sound")
        }
    }
}

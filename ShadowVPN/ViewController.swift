//
//  ViewController.swift
//  ShadowVPN
//
//  Created by code8 on 16/11/25.
//  Copyright © 2016年 code8. All rights reserved.
//

import NetworkExtension
import UIKit
import Foundation
import CocoaLumberjack
import CocoaLumberjackSwift
class ViewController: UITableViewController , UITextFieldDelegate  {
    
    var textFields:     [UITextField]       = []
    var textFieldCells: [[UITableViewCell]] = [[UITableViewCell]]()
    var routingCell:    UITableViewCell?  = nil
    var cells: [[UITableViewCell]]          = []
    var bediting: Bool                       = false
    var connectCell:   UITableViewCell? = nil
    var settings : SettingModel? = nil
    var manager : NETunnelProviderManager? = nil
    var connectbutton : UIButton? = nil
    
    override func viewDidLoad() {
        DDLog.removeAllLoggers()
        DDLog.add(DDTTYLogger.sharedInstance(), with: DDLogLevel.debug)
        
        let fileLogger: DDFileLogger = DDFileLogger() // File Logger
        fileLogger.rollingFrequency = TimeInterval(60*60*24)  // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger , with: DDLogLevel.debug)
        
        
        super.viewDidLoad()
        self.navigationItem.title="ShadowVPN";

        self.navigationItem.rightBarButtonItem=UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.edit,target:self,action: #selector(ViewController.editConf))
        
        let button=UIButton(type: UIButtonType.infoLight)
        button.addTarget(self, action: #selector(ViewController.openLogView), for: UIControlEvents.touchUpInside)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
        self.settings = SettingModel.settingsFromAppGroupContainer()! 
        self.setUpCells()
        self.fillConfigInfo()
        self.connectCell = self.createConnectCell()
        //self.setConfEdit(bedit: true)
        self.startEditing()
        NETunnelProviderManager.loadAllFromPreferences { (managers : [NETunnelProviderManager]?,error: Error?)->Void in
            if (managers?.count)! > 0 {
                self.manager = managers?[0]
            }else{
               self.manager = NETunnelProviderManager()
            }
            self.applicationDidBecomeActive()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillShow(aNotification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHide(aNotification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.vpnManagerStatusChanage), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        
    }
    
    func fillConfigInfo() {
        
        textFields[0].text = settings?.hostname
        textFields[1].text = String(format: "%d", settings?.port ?? 1234)
        textFields[2].text = settings?.password ?? ""
        textFields[3].text = settings?.clientIP ?? "10.0.7.2"
        textFields[4].text = settings?.subnetMasks ?? "255.255.255.0"
        textFields[5].text = String(format: "%d",settings?.MTU ?? 1432)
        textFields[6].text = settings?.DNS ?? "8.8.8.8"
        textFields[7].text = settings?.chinaDNS ?? "223.5.5.5"
        
        
    }
    
    private func createConnectCell()  -> UITableViewCell{
        let cell = UITableViewCell(style : UITableViewCellStyle.default,reuseIdentifier : nil)
        cell.textLabel?.text = ""
        let screenSize = UIScreen.main.bounds
        let button = UIButton(type: UIButtonType.custom)
        button.setTitle("connect", for: UIControlState.normal)
        button.setTitleColor(UIColor.red, for: UIControlState.normal)
        button.frame = CGRect(x:0,y:0,width:screenSize.size.width,height:40)

        cell.addSubview(button)
        self.connectbutton  = button
        button.addTarget(self, action: #selector(ViewController.beginConncet), for: UIControlEvents.touchUpInside)
        return cell
    }
    
    private func newCell(title:String) -> UITableViewCell
    {
        let cell : UITableViewCell = UITableViewCell(style : UITableViewCellStyle.default,reuseIdentifier : nil)
        cell.textLabel?.text=title;
        let screenSize: CGRect = UIScreen.main.bounds
        let textfield  : UITextField = UITextField(frame: CGRect(x:140,y:0,width:screenSize.size.width-140,height:40))
        self.textFields.append(textfield)
        textfield.delegate=self
        textfield.autocorrectionType = UITextAutocorrectionType.no
        textfield.autocapitalizationType = UITextAutocapitalizationType.none
        cell.addSubview(textfield)
        return cell
    }
    
    private func  setUpCells()
    {
        routingCell = UITableViewCell(style: UITableViewCellStyle.value1, reuseIdentifier: nil)
        routingCell?.textLabel?.text="Routing"
        routingCell?.detailTextLabel?.text="chroute"
        
        textFieldCells  = [[newCell(title: "Host"),newCell(title: "Port"),newCell(title: "Password")],[newCell(title: "Client IP"),newCell(title: "SubnetMasks"),newCell(title: "MTU")],[newCell(title: "Global DNS"),newCell(title: "China DNS")],[routingCell!]]
        textFields[0].placeholder = GlobalConst.kHostPlaceholder
        textFields[1].placeholder = GlobalConst.kPortPlaceholder
        textFields[2].placeholder = GlobalConst.kPwdPlaceholder
        textFields[3].placeholder = GlobalConst.kClientIPPlaceholder
        textFields[4].placeholder = GlobalConst.kSubnetMasksPlaceholder
        textFields[5].placeholder = GlobalConst.kMTUPlaceholder
        textFields[6].placeholder = GlobalConst.kGDNSAddressPlaceholder
        textFields[7].placeholder = GlobalConst.kCDNSAddressPlaceholder
    }
    
    
    func startEditing() {
        self.setConfEdit(bedit: true)
        textFields.first?.becomeFirstResponder()
    }
    
    func  setConfEdit(bedit : Bool)
    {
        bediting=bedit
        
        for textFiled in textFields {
            textFiled.isEnabled=bediting
        }
        
        if bediting {
            cells = textFieldCells
            routingCell?.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done,target:self,action: #selector(ViewController.editConfDone))
        }else {
            cells =  Array(textFieldCells)
            cells.append([connectCell!])
            routingCell?.accessoryType = UITableViewCellAccessoryType.none
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.edit,target:self,action: #selector(ViewController.editConf))

        }
        self.tableView.reloadData()
    }
    
    func editConfDone()
    {
        settings?.hostname =  textFields[0].text
        settings?.port =  Int(textFields[1].text!)
        settings?.password =  textFields[2].text
        settings?.clientIP =  textFields[3].text
        settings?.subnetMasks =  textFields[4].text
        settings?.MTU =  Int(textFields[5].text!)
        settings?.DNS =  textFields[6].text
        settings?.chinaDNS = textFields[7].text
        
        do{
            try settings?.validate()
        }catch{
            NSLog("setting error")
            return
        }
        
        settings?.saveSettingsToAppGroupContainer()
        self.setConfEdit(bedit: false)
    }
    
    func editConf() {
        NSLog("edit conf")
        self.setConfEdit(bedit: true)
    }
    func openLogView(){
        NSLog("open Log View")
    }
    func beginConncet(){
        DDLogDebug("connect")
        if manager?.connection.status == NEVPNStatus.disconnected || manager?.connection.status == NEVPNStatus.invalid{
            let neprotocol = NETunnelProviderProtocol()
            neprotocol.serverAddress = settings?.hostname
     
            manager?.protocolConfiguration = neprotocol
            manager?.isEnabled = true
            manager?.isOnDemandEnabled = false
            manager?.saveToPreferences(completionHandler: { (error : Error?)->Void in
                if error != nil {
                    print("error")
                    return
                }
                
                do {
                    
                    try self.manager?.connection.startVPNTunnel(options:nil)
                }catch {
                    print("start error")
                }
            })
        }else{
            manager?.connection.stopVPNTunnel()
        }
        
    }
    func vpnManagerStatusChanage(){
        let status =  manager?.connection.status
        if status == NEVPNStatus.invalid {
            
        }else if status == NEVPNStatus.disconnected{
            self.connectbutton?.isEnabled = true
            self.connectbutton?.setTitle("Connect", for: UIControlState.normal)
        }else if status == NEVPNStatus.connecting{
            self.connectbutton?.isEnabled = false
              self.connectbutton?.setTitle("Connecting", for: UIControlState.normal)
          
        }else if status == NEVPNStatus.reasserting{
            self.connectbutton?.isEnabled = false
          
        }else if status == NEVPNStatus.connected{
            self.connectbutton?.isEnabled = true
            self.connectbutton?.setTitle("Disconnect", for: UIControlState.normal)
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return cells.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.section][indexPath.row]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: false)
        let cell : UITableViewCell = self.tableView.cellForRow(at: indexPath)!
        if  cell == self.connectCell {
            
        }else if cell == self.routingCell && self.bediting == true {
            let vc = DDSelectionViewController(option: GlobalConst.kRoutingModeTitles )
            vc.title = "Routing"
             func completionHanlder (title : String,index : Int)->Bool
            {
                routingCell?.detailTextLabel?.text = title;
                self.navigationController?.popViewController(animated: true)
                self.settings?.routingMode = RoutingMode(rawValue: index)
                return true
                
            }
            vc.completionHanlder = completionHanlder
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return  15
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let cell = self.tableView.cellForRow(at: indexPath)
        if cell  == self.connectCell {
            return true
        }else if cell == self.routingCell{
            return true
        }
        return false
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
 
    func keyboardWillShow(aNotification : NSNotification){
        self.moveTextViewForKeyboard(aNotification: aNotification,up: true)
    }
    
    func keyboardWillHide(aNotification : NSNotification){
         self.moveTextViewForKeyboard(aNotification: aNotification,up: false)
    }
    
    func moveTextViewForKeyboard(aNotification : NSNotification, up:Bool){
        let tmp : Dictionary<String,AnyObject> = aNotification.userInfo as!  Dictionary<String,AnyObject>
        let duration : NSNumber = tmp[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber
        let animationDuration : Double = duration.doubleValue
        
        let curve :NSNumber = tmp[UIKeyboardAnimationCurveUserInfoKey] as! NSNumber
        let animationCurve: Int = curve.intValue
        
        let keyboardEndFrame :CGRect = tmp[UIKeyboardFrameEndUserInfoKey] as! CGRect

        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationCurve(UIViewAnimationCurve(rawValue: animationCurve)!)
        UIView.setAnimationDuration(animationDuration)
        
        var insets : UIEdgeInsets = self.tableView.contentInset
        if up == true {
            insets.bottom = keyboardEndFrame.size.height
        }else{
            insets.bottom = 0;
        }
        tableView.contentInset = insets
        self.view.layoutIfNeeded()
        UIView.commitAnimations()
    }
    func applicationDidBecomeActive(){
        manager?.loadFromPreferences(completionHandler: { (error : Error?) in
                self.vpnManagerStatusChanage()
            })
    }
}



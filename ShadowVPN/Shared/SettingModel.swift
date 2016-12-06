//
//  SettingModel.swift
//  ShadowVPN
//
//  Created by code8 on 16/11/26.
//  Copyright © 2016年 code8. All rights reserved.
//

import Foundation
let kConfigurationKey = "shadowVpnConfiguration"
var SettingsModelErrorDomain : String? = nil
enum SettinValidateError: Error {
    
    case InvalidHost
    case InvalidPort
    case InvalidIP
    case InvalidPassword
    case InvalidSubNetMasks
    case InvalidDNS
    case InvalidMTU
    
}

enum RoutingMode :Int {
   case RoutingModeAll = 0
   case RoutingModeChnroute = 1
   case  RoutingModeBestroutetb = 2
}

class SettingModel :NSObject,NSCoding{
    var hostname   :String?
    var port       :Int? = 0
    var clientIP   :String?
    var password   :String?
    var subnetMasks:String?
    var chinaDNS   :String?
    var DNS        :String?
    var MTU        :Int? =  0
    var routingMode:RoutingMode? = nil
    static func settingsFromAppGroupContainer()->SettingModel?{
        
        let sharedDefaults = UserDefaults(suiteName: GlobalConst.kAppGroupIdentifier)
        let oriData = sharedDefaults?.object(forKey: kConfigurationKey)
        if  oriData != nil {
            let unarchiver = NSKeyedUnarchiver(forReadingWith:oriData as! Data)
            //通过归档时设置的关键字Checklist还原lists
            let settings = unarchiver.decodeObject(forKey: "SettingModel") as! SettingModel
            //结束解码
            unarchiver.finishDecoding()
            return settings
        }
        return SettingModel()
        
    }
    
    func saveSettingsToAppGroupContainer(){
        let sharedDefaults = UserDefaults(suiteName: GlobalConst.kAppGroupIdentifier)
        let data = NSMutableData()
        let archive  = NSKeyedArchiver(forWritingWith: data)
        archive.encode(self, forKey: "SettingModel")
        archive.finishEncoding()
        sharedDefaults?.set(data , forKey:kConfigurationKey)
        sharedDefaults?.synchronize()
   
    }

    func  validate() throws {
        if self.hostname == nil{
            throw SettinValidateError.InvalidHost
        }
        if self.port == nil {
            throw SettinValidateError.InvalidPort
        }
        if !isValidIpv4Address(self.clientIP) {
            throw SettinValidateError.InvalidIP
        }
        if self.password == nil {
            throw SettinValidateError.InvalidPassword
        }
        if !isValidIpv4Address(self.subnetMasks){
            throw SettinValidateError.InvalidSubNetMasks
        }
        if !isValidIpv4Address(self.chinaDNS){
            throw SettinValidateError.InvalidDNS
        }
        if !isValidIpv4Address(self.DNS){
            throw SettinValidateError.InvalidDNS
        }
        if !(self.MTU != nil) {
            throw SettinValidateError.InvalidMTU
        }

    }
    
    func encode(with aCoder: NSCoder) {
        
        aCoder.encode(self.hostname, forKey:"hostname")
        aCoder.encode(self.port, forKey:"port")
        aCoder.encode(self.clientIP, forKey:"clientIP")
        aCoder.encode(self.password, forKey:"password")
        aCoder.encode(self.subnetMasks, forKey:"subnetMasks")
        aCoder.encode(self.DNS, forKey:"DNS")
        aCoder.encode(self.MTU, forKey:"MTU")
        aCoder.encode(self.routingMode?.rawValue, forKey:"routingMode")
        aCoder.encode(self.chinaDNS, forKey: "chinaDNS")
    }
    
    required init?(coder aDecoder: NSCoder){
        self.hostname = aDecoder.decodeObject(forKey: "hostname") as! String
        self.port = aDecoder.decodeObject(forKey: "port") as! Int
        self.clientIP = aDecoder.decodeObject(forKey: "clientIP") as! String
        self.password = aDecoder.decodeObject(forKey: "password") as! String
        self.subnetMasks = aDecoder.decodeObject(forKey: "subnetMasks") as! String
        self.chinaDNS = aDecoder.decodeObject(forKey: "chinaDNS") as? String
        self.DNS = aDecoder.decodeObject(forKey: "DNS") as! String
        self.MTU = aDecoder.decodeObject(forKey: "MTU") as! Int
        self.routingMode =  RoutingMode(rawValue : aDecoder.decodeObject(forKey: "routingMode") as! Int)
        
    }
    override init(){
        super.init()
    }
}

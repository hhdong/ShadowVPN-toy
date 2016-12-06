//
//  NetworkInterfaceManagerInterfaceDidChange.swift
//  ShadowVPN
//
//  Created by code8 on 16/11/30.
//  Copyright © 2016年 code8. All rights reserved.
//

import Foundation

let NetworkInterfaceManagerInterfaceDidChange = "NetworkInterfaceManagerInterfaceDidChange"

class NetworkInterfaceManager{
    public var WWANValid : Bool  =  false
    public var WiFiValid : Bool  =  false
    public var monitoring: Bool  =  false
    public static var instance : NetworkInterfaceManager? = nil
    public static  func sharedInstance()-> NetworkInterfaceManager{
        if instance == nil{
            instance = NetworkInterfaceManager()
        }
        return instance!
    }
    
    public func updateInterfaceInfo(){
        var interface : UnsafeMutablePointer<ifaddrs>? = nil
        let previousWWAN = WWANValid
        let previousWIFI = WiFiValid
        //http://stackoverflow.com/questions/25626117/how-to-get-ip-address-in-swift
        if getifaddrs(&interface)==0 {
           var  ptr = interface
            while ptr != nil {
                defer{ptr = ptr?.pointee.ifa_next}
                let flag = Int32((ptr?.pointee.ifa_flags)!)
                var addr = ptr?.pointee.ifa_addr.pointee
                var up = false
                if (flag & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
                    if addr?.sa_family == UInt8(AF_INET) || addr?.sa_family == UInt8(AF_INET6){
                        var hostname = [CChar](repeating:0,count : Int(NI_MAXHOST))
                        if (getnameinfo(&addr!, socklen_t((addr?.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)==0){
                             let address = String(cString :hostname)
                             up = self.isValidIPAddress(IPAddress: address)
                        
                        }
                    }
                }
                if String(cString : (interface?.pointee.ifa_name)!) == "en0" {
                    WiFiValid = up
                }else if String(cString : (interface?.pointee.ifa_name)!) ==  "pdp_ip0" {
                    WWANValid  = up
                }
            
            }
            freeifaddrs(interface)
        }
        
        if monitoring && ( WiFiValid != previousWIFI || WWANValid != previousWWAN)  {
            //发出noti
            NotificationCenter.default.post(Notification(name:Notification.Name(rawValue:NetworkInterfaceManagerInterfaceDidChange), object : nil))
            monitoring = false
        }
    }
    
    func isValidIPAddress(IPAddress : String)->Bool{
        if IPAddress.lengthOfBytes(using: String.Encoding.utf8) == 0  {
            return false
        }
        if IPAddress == "0.0.0.0" {
            return false
        }
        if IPAddress.hasPrefix("169.254"){
            return false
        }
        return true
    }
    
    func monitorInterfaceChange(){
        monitoring  =  true 
    }
}

//
//  VPNUtils.swift
//  ShadowVPN
//
//  Created by code8 on 16/11/27.
//  Copyright © 2016年 code8. All rights reserved.
//

import Foundation


func isValidIpv4Address(_ ipv4Adress : String?)->Bool{
    if ipv4Adress != nil {
        let addressArr = ipv4Adress?.characters.split(separator: ".")
        if addressArr?.count == 4 {
            for singleAddr in addressArr! {
               
                let sinleAddrIntValue = Int(String(singleAddr))
                if sinleAddrIntValue! <= 0 && sinleAddrIntValue! > 255
                {
                    return false
                }
            }
        }else
        {
            return false
        }
        
    }
    return true
}

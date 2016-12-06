//
//  DNSPacket.swift
//  ShadowVPN
//
//  Created by code8 on 16/11/28.
//  Copyright © 2016年 code8. All rights reserved.
//

import Foundation

class DNSPacket : NSObject{
    
    var identifier : UInt16 = 0
    var queryDomains : NSArray? = nil
    var rawData : NSData? = nil
    var hexString : String = ""
    init?(data : NSData){
        super.init()
        if data.length < 12 {
            NSLog("packet too short")
        }
        rawData = data
        let scanner : BinaryDataScanner = BinaryDataScanner(data: data, littleEndian: false)
        //前两个自己为标识符
        self.hexString = data.toHex()!
        identifier = scanner.read16()!
        scanner.skipTo(n: 4)
        let count = scanner.read16()
        let domains = NSMutableArray()
        scanner.skipTo(n: 12)
  
        //取出所有的DNS里的地址
        for _ in 0..<Int(count!) {
            let  domain :  NSMutableString = NSMutableString()
            var domainLength = 0
            var b = scanner.readByte()
            while b != UInt8(0) {
                //单个域名的长度
                let len = Int(b!)
                if scanner.remain == 0 {
                    return nil
                }
                //读取
                let  sdomain = scanner.readString(len: len)
                domain.append(sdomain!)
                //中间以.作为分割
                domain.append(".")
                //domainLength++
                domainLength += len
                //循环读取
                b = scanner.readByte()
                //domainLength++
                domainLength += 1
            }
            //跳3个字节
            scanner.advanceBy(n: 3)
            if scanner.remain <= 0 {
                return nil
            }
            //删除最后一个点
            domain.deleteCharacters(in:  NSMakeRange(domain.length-1, 1))
            domains.add(domain)
        }
        queryDomains = domains
        rawData = data
        print("hello")
    }
}

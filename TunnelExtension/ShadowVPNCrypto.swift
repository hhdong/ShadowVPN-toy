//
//  ShadowVPNCrypto.swift
//  ShadowVPN
//
//  Created by code8 on 16/11/27.
//  Copyright © 2016年 code8. All rights reserved.
//

import Foundation


class ShadowVPNCrypto :NSObject{
    
    let SHADOWVPN_ZERO_BYTES = 32
    let SHADOWVPN_OVERHEAD_LEN = 24
    let SHADOWVPN_PACKET_OFFSET = 8
    let BUFFER_SIZE = 2000
    
    let key : UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: 32)
 
    func crypto_secretbox_salsa208poly1305_swift(c : UnsafeMutablePointer<UInt8> , m : UnsafePointer<UInt8> ,mlen : UInt64,n : UnsafePointer<UInt8>, k : UnsafePointer<UInt8>) -> Int{
        if mlen < 32 {
            return -1
        }
        
        crypto_stream_salsa208_xor(c, m, mlen, n, k)
        crypto_onetimeauth_poly1305(c + 16,c + 32,mlen - UInt64(32),c);
        
        for index in 0...15 {
            c[index] = UInt8(0)
        }
        memset(c,0,16)
        return 0
    }
    
    func crypto_secretbox_salsa208poly1305_open_swift(m : UnsafeMutablePointer<UInt8> ,c : UnsafePointer<UInt8>, clen : UInt64,n : UnsafePointer<UInt8>, k : UnsafePointer<UInt8> )-> Int{
        let subkey : UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: 32)
        if clen<32  {
            subkey.deinitialize()
            subkey.deallocate(capacity: 32)
            return -1
        }
        crypto_stream_salsa208(subkey,UInt64(32),n,k);
        let r = crypto_onetimeauth_poly1305_verify(c + 16,c + 32,UInt64(clen - 32),subkey)
        if( r != 0){
            subkey.deinitialize()
            subkey.deallocate(capacity: 32)
            return -2
        }
        crypto_stream_salsa208_xor(m,c,UInt64(clen),n,k);
        subkey.deinitialize()
        subkey.deallocate(capacity: 32)
        memset(m, 0, 32)
        return 0
    }
    
    
    public func setPassword(password : String){
       SVCrypto.setPassword(password)
//        if sodium_init() == -1 {
//            return
//        }
//        
//        randombytes_set_implementation(&randombytes_salsa20_implementation)
//        randombytes_stir()
//        var data = NSData(data : password.data(using: String.Encoding.utf8)!)
//        let c : UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity:data.length)
//        data.getBytes(c, length : data.length)
//        let r = crypto_generichash(key,32,c,UInt64(data.length) ,nil,0)
//        if r == 0{
//        }
    }
    
    public func encryptData(data :NSData)->NSData?{
        let data = SVCrypto.encrypt(with: (data as NSData) as Data!, userToken: nil)
        if data == nil {
            return nil
        }
        return NSData(data: data!)
//        let inBuffer : UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: BUFFER_SIZE)
//        let outBuffer : UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: BUFFER_SIZE)
//        let nonce : UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: 8)
//        
//        memset(inBuffer,0,BUFFER_SIZE)
//        memset(outBuffer,0,BUFFER_SIZE)
//        data.getBytes(inBuffer + SHADOWVPN_ZERO_BYTES, length: BUFFER_SIZE - SHADOWVPN_ZERO_BYTES)
//        randombytes(nonce, 8)
//        let r = crypto_secretbox_salsa208poly1305_swift( c : outBuffer, m : inBuffer,   mlen : ((data.length as NSNumber).uint64Value  + UInt64(SHADOWVPN_ZERO_BYTES)), n : nonce, k : key)
//        if(r != 0){
//            inBuffer.deinitialize()
//            outBuffer.deinitialize()
//            nonce.deinitialize()
//            inBuffer.deallocate(capacity: BUFFER_SIZE)
//            outBuffer.deallocate(capacity: BUFFER_SIZE)
//            nonce.deallocate(capacity: 8)
//            
//            return nil
//        }
//        memcpy(outBuffer+8, nonce, 8)
//        
//        let resultData : NSData = NSData(bytes: outBuffer+SHADOWVPN_PACKET_OFFSET, length: SHADOWVPN_OVERHEAD_LEN+data.length)
//        inBuffer.deinitialize()
//        outBuffer.deinitialize()
//        nonce.deinitialize()
//        inBuffer.deallocate(capacity: BUFFER_SIZE)
//        outBuffer.deallocate(capacity: BUFFER_SIZE)
//        nonce.deallocate(capacity: 8)
//        return resultData
    }
    
    public func decryptData(data :NSData)->NSData?{
          let data = SVCrypto.decrypt(with: (data as NSData) as Data!, userToken: nil)
        if data == nil {
            return nil
        }
        return NSData(data: data!)
//        let inBuffer : UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: BUFFER_SIZE)
//        let outBuffer : UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: BUFFER_SIZE)
//        memset(inBuffer,0,BUFFER_SIZE)
//        memset(outBuffer,0,BUFFER_SIZE)
//
//        data.getBytes(inBuffer + SHADOWVPN_PACKET_OFFSET, length: BUFFER_SIZE - SHADOWVPN_PACKET_OFFSET)
//        let nonce : UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: 8)
//        
//        memcpy(nonce, inBuffer+8, 8)
//        let r : Int = crypto_secretbox_salsa208poly1305_open_swift(m: outBuffer, c: inBuffer, clen: UInt64( (data.length as NSNumber).uint64Value + UInt64(SHADOWVPN_PACKET_OFFSET)), n: nonce, k: key)
//        if r != 0 {
//            inBuffer.deinitialize()
//            outBuffer.deinitialize()
//            nonce.deinitialize()
//
//            inBuffer.deallocate(capacity: BUFFER_SIZE)
//            outBuffer.deallocate(capacity: BUFFER_SIZE)
//            nonce.deallocate(capacity: 8)
//            return nil
//        }
//        let resultData : NSData = NSData(bytesNoCopy: outBuffer+SHADOWVPN_ZERO_BYTES, length: data.length - SHADOWVPN_OVERHEAD_LEN)
//        inBuffer.deinitialize()
//        outBuffer.deinitialize()
//        nonce.deinitialize()
//
//        inBuffer.deallocate(capacity: BUFFER_SIZE)
//        outBuffer.deallocate(capacity: BUFFER_SIZE)
//        nonce.deallocate(capacity: 8)
//        return resultData
    }
    
    deinit{
        key.deallocate(capacity: 32)
    }
}

//
//  BinaryDataScanner.swift
//  ShadowVPN
//
//  Created by code8 on 16/11/28.
//  Copyright © 2016年 code8. All rights reserved.
//

import Foundation

public protocol BinaryReadable {
    var littleEndian: Self { get }
    var bigEndian: Self { get }
}

extension UInt8: BinaryReadable {
    public var littleEndian: UInt8 { return self }
    public var bigEndian: UInt8 { return self }
}

extension UInt16: BinaryReadable {}

extension UInt32: BinaryReadable {}

extension UInt64: BinaryReadable {}

public class BinaryDataScanner {
    var data : NSData? = nil
    var littleEndian :Bool = false
    var current : UnsafeRawPointer? = nil
    var remain : Int = 0
    var position : Int{
        get {
            return data!.length - remain
        }
    }
    
    public init( data : NSData ,littleEndian : Bool){
        self.data = data
        self.littleEndian = littleEndian
        self.current = data.bytes
        self.remain = data.length
    }
    
    public func read< T : BinaryReadable >()->T? {
        if remain <  MemoryLayout<T>.size{
            return nil
        }
        let tCurrent = UnsafePointer<T>(current?.assumingMemoryBound(to: T.self))
        let v  = tCurrent?[0]
        current = UnsafeRawPointer(tCurrent?.successor())
        remain -= MemoryLayout<T>.size
        return littleEndian ? v?.littleEndian : v?.bigEndian
    }
    
    public func skipTo(n: Int){
        remain =  (data?.length)! - n
        current = UnsafeRawPointer(data?.bytes.advanced(by: n))
    }
    
    public func readString(len : Int) ->String? {
        if remain < len {
            return nil
        }
        let tmpPoint = UnsafeMutablePointer<UInt8>.allocate(capacity: len+1)
        tmpPoint[len] = UInt8(0)
        let tCurren = UnsafePointer<CChar>(current?.assumingMemoryBound(to: CChar.self))
        memcpy(tmpPoint, tCurren, len)
        remain -= len
        current = UnsafeRawPointer(tCurren!+len)
        let cpstr = String(cString: tmpPoint)
        tmpPoint.deinitialize()
        tmpPoint.deallocate(capacity: len)
        return cpstr
    }
    
    public func advanceBy(n:Int){
        remain -= n
        current = current?.advanced(by: n)
    }
    
    public func readByte()-> UInt8?{
        return read()
    }
    
    public func read16()-> UInt16?{
        return read()
    }
    
    public func read32()-> UInt32?{
        return read()
    }
}

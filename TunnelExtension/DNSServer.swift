//
//  DNSServer.swift
//  ShadowVPN
//
//  Created by code8 on 16/11/29.
//  Copyright © 2016年 code8. All rights reserved.
//

import Foundation
import NetworkExtension
import CocoaAsyncSocket

class DNSServerQuery :NSObject {
    var domains : NSArray? = nil
    var clientAddress : NSData? = nil
    var packet : DNSPacket? = nil
}

class DNSServer :NSObject, GCDAsyncUdpSocketDelegate{

    var dispatchQueue : DispatchQueue? = nil
    var outgoinSessionReady : Bool? = nil
    var socket : GCDAsyncUdpSocket? = nil
    var queries : NSMutableArray? = nil
    var waittingQueriesMap : NSMutableDictionary? = nil
    var whitelistSession : NWUDPSession? = nil
    var blacklistSession : NWUDPSession? = nil
    var queryIDCounter: UInt16? = nil
    var whitelistSuffixSet : NSMutableSet? = nil
    
    override init() {
        super.init()
        queryIDCounter = UInt16(0)
        queries = NSMutableArray(capacity: 10)
        waittingQueriesMap = NSMutableDictionary(capacity: 10)
        dispatchQueue = DispatchQueue(label :"DNSServer")
        socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: dispatchQueue)
        var whitelistSuffixStr :String? = nil
        do{
            whitelistSuffixStr = try NSString(contentsOfFile: Bundle.main.path(forResource: "china_domains", ofType: "txt")!, encoding: String.Encoding.utf8.rawValue) as String

        }catch{
            return
        }
        whitelistSuffixSet = NSMutableSet()
        whitelistSuffixStr?.enumerateLines(invoking: { (line, stop) in
            self.whitelistSuffixSet?.add(line)
        })
    }
    
    func startServer() {
        do{
            try socket?.bind(toPort: 53)
            
        }catch{
            print("bind error")
            return
        }
        do{
            try socket?.beginReceiving()
        }catch{
            print("receive error")
            return
        }
    }
    
    func stopServer() {
        socket?.synchronouslySetDelegate(nil)
        socket?.close()
    }
 
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        let dns  = DNSPacket(data:data as NSData)

        let query = DNSServerQuery()
        query.domains = dns?.queryDomains
        query.clientAddress = address as NSData
        query.packet = dns
        
        queries?.add(query)
        self.processQuery()
    }
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?){
        print(tag)
        
    }
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
        print(tag)
    }
    func processQuery(){
        if outgoinSessionReady != true {
            return
        }
        if queries?.count == 0{
            return
        }
        let query = queries?.firstObject as! DNSServerQuery
        queries?.removeObject(at: 0)
        let data : NSMutableData = query.packet?.rawData?.mutableCopy() as! NSMutableData
        if Int32(queryIDCounter!) == UINT16_MAX {
            queryIDCounter = 0
        }
        queryIDCounter = queryIDCounter! + UInt16(1)
        let queryId = queryIDCounter
        var tmData = queryIDCounter?.bigEndian
        data.replaceBytes(in: NSMakeRange(0, 2), withBytes: &(tmData))
        var session :NWUDPSession? = nil
        if self.isDomain(domain: query.packet?.queryDomains?.firstObject as! String, domainSet: whitelistSuffixSet!){
            session = whitelistSession
        }else{
            session = blacklistSession
        }
        session?.writeDatagram(data as Data, completionHandler: { (error : Error?)->Void in
            if (error != nil) {
                self.queries?.add(query as Any)
            }else{
                self.waittingQueriesMap?[queryId!] = query
            }
        })
        
    }
    
    func setupOutGoinConnectionWithTunnelProvider(provider: NEPacketTunnelProvider,chinaDNS : String,globalDNS : String)
    {
        whitelistSession = provider.createUDPSession(to: NWHostEndpoint(hostname : chinaDNS , port : "53"), from: nil)
        blacklistSession = provider.createUDPSessionThroughTunnel(to: NWHostEndpoint(hostname:globalDNS, port:"53"), from: nil)
               blacklistSession?.setReadHandler({ (datagrams : [Data], error : Error?) in
            if error != nil {
                
            }
            else{
                self.processResponse(datagrams: datagrams as NSArray)
            }
        }, maxDatagrams: Int(INT32_MAX))
        whitelistSession?.setReadHandler({ (datagrams : [Data], error : Error?) in
            if error != nil {
                
            }
            else{
                self.processResponse(datagrams: datagrams as NSArray)
            }
        }, maxDatagrams: Int(INT32_MAX))
        //侦听session的state
        whitelistSession?.addObserver(self, forKeyPath: "state", options:[NSKeyValueObservingOptions.new, NSKeyValueObservingOptions.initial], context: nil)
        blacklistSession?.addObserver(self, forKeyPath: "state", options:[NSKeyValueObservingOptions.new, NSKeyValueObservingOptions.initial], context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath?.compare("state") == ComparisonResult.orderedSame{
            //let session = object as! NWUDPSession
            outgoinSessionReady = whitelistSession?.state == NWUDPSessionState.ready && blacklistSession?.state == NWUDPSessionState.ready
            if outgoinSessionReady! && (dispatchQueue != nil){
                dispatchQueue?.async {
                    self.processQuery()
                }
            }
        }else{
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    
    }
    //处理来自远端的回应
    func processResponse(datagrams : NSArray) {
        dispatchQueue?.async {
            for data in datagrams {
                let nsdata =  data as! NSData
                let scanner = BinaryDataScanner(data: data as! NSData, littleEndian: false)
                let queryId = scanner.read16()
                if queryId == nil {
                    return
                }
                if self.waittingQueriesMap?[queryId] == nil {
                    return
                }
                let query = self.waittingQueriesMap?[queryId] as! DNSServerQuery
                
                if  query == nil{
                    return
                }else{
                    let addr = query.clientAddress?.bytes.bindMemory(to: sockaddr_in.self, capacity:1)
                    
                    let string = String(cString: inet_ntoa((addr?.pointee.sin_addr)!))
                    print(string)
                    let mdata =  nsdata.mutableCopy() as! NSMutableData
                    let identifier : UInt16 = (query.packet?.identifier)!
                    var tmData = identifier.bigEndian
                    //更换标识符
                    mdata.replaceBytes(in: NSMakeRange(0, 2), withBytes: &(tmData))
                    self.socket?.send(mdata as Data, toAddress: query.clientAddress as! Data, withTimeout: 10, tag: 0)
                }
            }
        }
    }
    //域名是否在白名单里
    func isDomain(domain: String ,domainSet : NSSet ) -> Bool {
        var ptr = domain
        while(ptr != ""){
            if domainSet.contains(ptr){
                return true
            }
            let range = ptr.range(of: ".")
            if (range == nil || ((range != nil) && (range?.isEmpty)!)) {
                return false
            }
            ptr = ptr.substring(with:Range<String.Index>(uncheckedBounds: (lower: (range?.upperBound)!, upper: ptr.endIndex)))
        }
        return false
    }

}

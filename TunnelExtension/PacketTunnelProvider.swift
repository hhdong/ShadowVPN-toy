//
//  PacketTunnelProvider.swift
//  TunnelExtension
//
//  Created by code8 on 16/11/27.
//  Copyright © 2016年 code8. All rights reserved.
//

import NetworkExtension
import CocoaLumberjack
import CocoaLumberjack
import CocoaLumberjackSwift
let ShadowVPNTunnelProviderErrorDomain = "ShadowVPNTunnelProviderErrorDomain"

func synchronizd(lock: AnyObject, closure:()->()) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock);
}

enum  TunnelProviderErrorCode : Int {
    case TunnelProviderErrorCodeInvalidConfiguration = 0
    case TunnelProviderErrorCodeDNSFailed = 1
}

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    
    var udpsession : NWUDPSession? = nil
    var sharedDefaults :UserDefaults? = nil
    
    var hostIPAddress : String? = nil
      var outgoinBuffer : NSMutableArray? = nil
//    
      var dispatchQueue : DispatchQueue? = nil
    var settings : SettingModel? = nil
    var dnsServer : DNSServer? = nil
    var systemServer : String? = nil
    let vpnCrypto : ShadowVPNCrypto = ShadowVPNCrypto()
    var lastPath  : NWPath? = nil
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
	
        DDLog.removeAllLoggers()
        DDLog.add(DDTTYLogger.sharedInstance(),with : DDLogLevel.debug)
        DDLogDebug("statart tunnel ")
        // Add code here to start the process of connecting the tunnel.
        outgoinBuffer  = NSMutableArray(capacity: 100)
        dispatchQueue = DispatchQueue(label :"TunnelProvider")
        NotificationCenter.default.addObserver(self, selector: #selector(PacketTunnelProvider.interfaceDidChange), name: NSNotification.Name(rawValue: NetworkInterfaceManagerInterfaceDidChange), object: nil)
     
        dispatchQueue?.async {
            let setting = SettingModel.settingsFromAppGroupContainer()!
            self.settings = setting
            do{
                 try self.settings?.validate()
//                 self.addObserver(self, forKeyPath: "defaultPath", options: NSKeyValueObservingOptions(rawValue: 0), context: nil)
                 self.vpnCrypto.setPassword(password: (self.settings?.password)!)
                 self.startConnectionWithCompletionHandler(completionHandler: completionHandler)
                
            }catch{
         
                let newError = NSError(domain: ShadowVPNTunnelProviderErrorDomain , code: TunnelProviderErrorCode.TunnelProviderErrorCodeInvalidConfiguration.rawValue, userInfo: [NSLocalizedDescriptionKey : "no config settings"])
                completionHandler(newError)
                return 
            }
           
            
        }
	}
    //route dns  mtu
    func prepareTunnelNetworkSettings()-> NEPacketTunnelNetworkSettings {
        let nesettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress:self.hostIPAddress!)
        nesettings.iPv4Settings = NEIPv4Settings(addresses: [(self.settings?.clientIP)!], subnetMasks:[(self.settings?.subnetMasks)!])
        let routingMode = self.settings?.routingMode
        if routingMode == RoutingMode.RoutingModeChnroute{
            self.setupChnroute(settings: nesettings.iPv4Settings!)
        }else if routingMode == RoutingMode.RoutingModeBestroutetb {
            self.setupBestroutetb(settings: nesettings.iPv4Settings!)
        }else{
            nesettings.iPv4Settings?.includedRoutes = []
            nesettings.iPv4Settings?.excludedRoutes = []
        }
        var includedRoutes = nesettings.iPv4Settings?.includedRoutes ?? [NEIPv4Route]()
        var excludedRoutes = nesettings.iPv4Settings?.excludedRoutes ?? [NEIPv4Route]()
        
        includedRoutes.append(NEIPv4Route.default())
        includedRoutes.append(NEIPv4Route(destinationAddress:   (self.settings?.DNS)!  ,subnetMask:"255.255.255.255"))
        excludedRoutes.append(NEIPv4Route(destinationAddress:   (self.settings?.chinaDNS)!  ,subnetMask:"255.255.255.255"))
        
        nesettings.iPv4Settings?.includedRoutes = includedRoutes
        nesettings.iPv4Settings?.excludedRoutes = excludedRoutes
        
        nesettings.dnsSettings = NEDNSSettings(servers: ["127.0.0.1"])
      //nesettings.dnsSettings = NEDNSSettings(servers: ["223.5.5.5"])
        nesettings.mtu = NSNumber(integerLiteral:  (self.settings?.MTU)!)
       
        return nesettings
    }

    func startConnectionWithCompletionHandler(completionHandler: @escaping (NSError?) -> Void){


         self.loadSystemDNSServer()
        let result = self.dnsResolveWithHost(host: (self.settings?.hostname)!)

        if result.count==0 {
            let error = NSError(domain: ShadowVPNTunnelProviderErrorDomain , code: TunnelProviderErrorCode.TunnelProviderErrorCodeInvalidConfiguration.rawValue, userInfo: [NSLocalizedDescriptionKey : "no Dns failed"])
            completionHandler(error)
            return
        }

        self.hostIPAddress = result.firstObject as! String?

   
        let nesettings = self.prepareTunnelNetworkSettings()
        //建立隧道
        self.setTunnelNetworkSettings(nesettings, completionHandler: { (error : Error?)->Void in
    
            if (error != nil) {
                completionHandler(error as NSError?)
            }else{
                completionHandler(nil)
                self.dispatchQueue?.async {
                    self.setupUDPSession()
                    self.setupDNSSer()
//                    NetworkInterfaceManager.sharedInstance().monitorInterfaceChange()
                    self.readTun()
                }
            }
        })
    }
//    //网络发生变化需要重新链接
    func  interfaceDidChange(){
        dispatchQueue?.async {
            print("hello")
            self.reasserting = true
            self.releaseUDPSession()
            self.releaseDNSServer()
            self.setTunnelNetworkSettings(nil, completionHandler: { (error : Error?)->Void in
                if (error != nil) {
                    self.cancelTunnelWithError(error)
                }else{
                    self.dispatchQueue?.async {
                        self.startConnectionWithCompletionHandler(completionHandler: {  (error : NSError?)->Void in
                            if error != nil {
                                self.cancelTunnelWithError(error)
                            }else{
                                self.reasserting = false
                            }
                        })
                    }
                }
            })

        }
    }
    //DNS服务
    func setupDNSSer(){
        dnsServer = DNSServer()
        dnsServer?.setupOutGoinConnectionWithTunnelProvider(provider: self, chinaDNS: (settings?.chinaDNS ?? systemServer)!, globalDNS: (settings?.DNS)!)
        dnsServer?.startServer()
    }
    //系统的DNS服务
    func loadSystemDNSServer(){
           // res_init()
        res_9_init()
        if _res.nscount>0 {
            let addr  = _res.nsaddr_list.0.sin_addr
            systemServer = String(cString:inet_ntoa(addr))
        }else{
            systemServer = nil
        }
        
        
    }
    //建立与远程主机的UDP链接
    func setupUDPSession(){
        if udpsession != nil {
            return
        }
       
        let endpoint = NWHostEndpoint(hostname: hostIPAddress!, port: String(format: "%d",(settings?.port)!))
        udpsession = self.createUDPSession(to: endpoint, from: nil)
        udpsession?.setReadHandler({ (datagrams : [Data], error : Error?)->Void in
            if(error != nil){
                return
            }else{
                self.processUDPIncomingDatagrams(datagrams: datagrams)
            }
        }, maxDatagrams: Int(INT32_MAX))
        
    }
    //处理从远程主机发来的数据包，需要解密
    func processUDPIncomingDatagrams(datagrams : [Data] )
    {
        var result =  [NSData]()
        var protocols = [NSNumber]()
        
        for (index,data) in datagrams.enumerated(){
            let decryptedData = vpnCrypto.decryptData(data: NSData(data:data))
            if decryptedData == nil {
                DDLogDebug("decrydata form incoming session failed!")
                return
            }
            result.append(decryptedData! as NSData)
            protocols.append(NSNumber(value: AF_INET))
        }
        //写入隧道中
        self.packetFlow.writePackets(result as [Data], withProtocols: protocols)
    }
    //读取隧道的数据
    func readTun(){
        self.packetFlow.readPackets { (packets : [Data], protocols :[NSNumber]) in
            var datas = [Any]()
            for (idx, data) in packets.enumerated() {
                if protocols[idx].int32Value != AF_INET{
                    return
                }
                let encrytedData = self.vpnCrypto.encryptData(data: NSData(data:data))
                if encrytedData == nil{
                    return
                }
                datas.append(encrytedData as Any)
            }
            synchronizd(lock: self, closure: {
                (self.outgoinBuffer?.addObjects(from: datas ))!
            })
            self.processOutgoingBuffer()
            //循环
            self.readTun()
            
        }
    }
    //把上一步加密的数据发送到远程服务器里面
    func processOutgoingBuffer(){
        if udpsession == nil || udpsession?.state != NWUDPSessionState.ready {
            return
        }
        var datas :[Any]? = nil
        synchronizd(lock: self, closure:{
            if outgoinBuffer?.count == 0 {
                return
            }
            datas = outgoinBuffer?.copy() as! [Any]?
            outgoinBuffer?.removeAllObjects()
        })
        udpsession?.writeMultipleDatagrams(datas as! [Data], completionHandler: { (error : Error?)->Void in
            if error != nil {
                //处理失败的情况
                synchronizd(lock: self, closure: {
                    self.outgoinBuffer?.addObjects(from: datas! )
                })
            }
        })
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
//        if (object as! NWUDPSession) == udpsession && keyPath == "state" {
//            
//            if udpsession?.state == NWUDPSessionState.failed || udpsession?.state == NWUDPSessionState.cancelled {
//                self.processOutgoingBuffer()
//            }else {
//                
//            }
//            //不够规范
//        }else if (object as! PacketTunnelProvider) == self && keyPath == "defaultPath" {
//            if self.defaultPath?.status == NWPathStatus.satisfied && (self.defaultPath?.isEqual(to: self.lastPath!)==false) {
//                if self.lastPath != nil{
//                    self.lastPath = self.defaultPath
//                }else{
//                    //net work change
//                     NetworkInterfaceManager.sharedInstance().updateInterfaceInfo()
//                }
//            }
//           
//        }else{
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
//        }
        
    }
    
    func releaseUDPSession(){
        if udpsession != nil{
       //     udpsession?.removeObserver(self, forKeyPath: "state")
            udpsession = nil
        }
     
    }
    
    func releaseDNSServer(){
        if dnsServer != nil{
            dnsServer?.stopServer()
            dnsServer = nil
 
        }
    }
    //从系统解析host的地址
    
    func dnsResolveWithHost(host : String)->NSArray{
        let cfs = host as CFString
        let hostRef = CFHostCreateWithName(kCFAllocatorDefault, cfs)
        let result = CFHostStartInfoResolution(hostRef.takeUnretainedValue(),CFHostInfoType.addresses, nil)
        var darwinresult = DarwinBoolean(false)
        if result == true {
            let addresses = CFHostGetAddressing(hostRef.takeUnretainedValue() ,&darwinresult)
            
            let resultArray = NSMutableArray()
            for i in 0..<CFArrayGetCount(addresses?.takeUnretainedValue()){
                let saData  = CFArrayGetValueAtIndex(addresses?.takeUnretainedValue(), i)
                let manData : CFData = Unmanaged<CFData>.fromOpaque(saData!).takeUnretainedValue()
                let remoteAddr = CFDataGetBytePtr(manData)
                
                remoteAddr?.withMemoryRebound(to: sockaddr_in.self, capacity: 1){addr in
                    let string = String(cString: inet_ntoa(addr.pointee.sin_addr))
                    resultArray.add(string)
                }
            }
            return resultArray as NSArray
        }else
        {
            return NSArray()
        }
        
    }

    
    func setupChnroute(settings : NEIPv4Settings){
        var data :String? = nil
        do{
            data = try NSString(contentsOfFile: Bundle.main.path(forResource: "chnroutes", ofType: "txt")!, encoding: String.Encoding.utf8.rawValue) as String
            
        }catch{
            return
        }
        var routes =  [NEIPv4Route]()
        data?.enumerateLines(invoking: { (line, stop) in
            let comps = line.components(separatedBy: " ")
            let route = NEIPv4Route(destinationAddress: comps[0], subnetMask: comps[1])
            if routes.count <= 6000{
             routes.append(route)
            }
        })
        
        settings.excludedRoutes = routes
        settings.includedRoutes = routes
    }
    //best route
    func setupBestroutetb(settings : NEIPv4Settings){
        var data :String? = nil
        do{
            data = try NSString(contentsOfFile: Bundle.main.path(forResource: "bestroutetb", ofType: "txt")!, encoding: String.Encoding.utf8.rawValue) as String
            
        }catch{
            return
        }
        var excludeRoutes = [NEIPv4Route]()
        var includeRoutes = [NEIPv4Route]()
    
        data?.enumerateLines(invoking: { (line, stop) in
            let comps = line.components(separatedBy: " ")
            let route = NEIPv4Route(destinationAddress: comps[0], subnetMask: comps[1])
            //属于vpn网关 需要特殊处理，需要走隧道
            if comps[2] == "vpn_gateway" {
                includeRoutes.append(route)
            }else{
                excludeRoutes.append(route)
            }
           
            
        })
        
        settings.excludedRoutes = excludeRoutes
        settings.includedRoutes = includeRoutes
        
    }
    

	override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
		 //Add code here to start the process of stopping the tunnel.
        dispatchQueue?.async {
            self.releaseDNSServer()
            self.releaseUDPSession()
            completionHandler()
        }
	}

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        
        guard let messageString = String(data: messageData, encoding: String.Encoding.utf8)
        else{
                    completionHandler?(nil)
                return
        }
        DDLogDebug(messageString)
		let responseData = "Hello app".data(using: String.Encoding.utf8)
		completionHandler?(responseData)
	}

}

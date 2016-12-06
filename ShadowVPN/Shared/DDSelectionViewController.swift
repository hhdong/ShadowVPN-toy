//
//  DDSelectionViewController.swift
//  ShadowVPN
//
//  Created by code8 on 16/11/27.
//  Copyright © 2016年 code8. All rights reserved.
//

import Foundation
import UIKit

class DDSelectionViewController :UITableViewController {
    
    var  options :[String]?  = nil
    var  cells   :[UITableViewCell] = []
    
    public var cellSetUpBlock : ((UITableViewCell,String,Int)->(Void)?)? = nil
    public var completionHanlder : ((String,Int)->Bool)? = nil
    
    
    public init(option _options: [String])
    {
         super.init(style: UITableViewStyle.grouped)
         options = Array(_options)
        var index = 0
        for title in options! {
            let cell : UITableViewCell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: nil)
            cell.textLabel?.text = title
            cellSetUpBlock?(cell,title,index)
            cells.append(cell)
            index += 1
        }
        self.tableView.reloadData()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    //tableview override
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return self.cells[indexPath.row]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            self.completionHanlder!((self.options?[indexPath.row])!,indexPath.row)
        
    }
}

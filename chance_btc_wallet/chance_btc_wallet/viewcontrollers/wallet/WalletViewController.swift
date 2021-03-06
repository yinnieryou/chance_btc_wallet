//
//  WalletViewController.swift
//  Chance_wallet
//
//  Created by Chance on 16/1/19.
//  Copyright © 2016年 Chance. All rights reserved.
//

import UIKit
import Foundation

class WalletViewController: BaseViewController {
    
    /// MARK: - 成员变量
    @IBOutlet var labelUserName: UILabel!
    @IBOutlet var labelUserAccount: UILabel!
    @IBOutlet var viewUser: UIView!
    @IBOutlet var buttonSend: UIButton!
    @IBOutlet var buttonReceive: UIButton!
    @IBOutlet var tableViewTransactions: UITableView!
    @IBOutlet var tableViewUserMenu: UITableView!
    
    let kHeightOfUserMenuCell: CGFloat = 50       //选择账户的高度
    
    var dropdownView: LMDropdownView!
    var userName = ""
    var address = ""
    var balance: BTCAmount = 0
    var refreshTimer: Timer?              //刷新数据定时器
    var transactions = [UserTransaction]()
    var logining = false
    var currentAccount: CHBTCAcount?           //当前账户
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        //注册一个通知用于更新钱包账户
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.updateUserWallet),
            name: NSNotification.Name(rawValue: "updateUserWallet"),
            object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        //通知更新
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: "updateUserWallet"),
            object: nil)
        
        //创建刷新定时器，获取最新的交易记录
        if self.refreshTimer == nil {
            self.refreshTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.updateUserWallet), userInfo: nil, repeats: true)
        }
        
        //刷新用户列表
        self.updateUserMenuSize()
        self.tableViewUserMenu.reloadData()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        //停止定时器
        self.refreshTimer?.invalidate()
        self.refreshTimer = nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

// MARK: - 控制器方法
extension WalletViewController {
    
    /**
     配置UI
     */
    func setupUI() {

        //self.updateUserMenuSize()
    }
    
    
    /// 更新用户列表菜单的高度
    func updateUserMenuSize() {
        //保证钱包是存在
        guard CHBTCWallet.checkBTCWalletExist() else {
                return
        }
        
        let count = CHBTCWallet.sharedInstance.getAccounts().count
        //导航栏弹出下拉菜单的尺寸适应当前view的宽度
        self.tableViewUserMenu.frame = CGRect(x: 0, y: 0,
                                              width: self.view.bounds.width,
                                              height: min(self.view.bounds.height * 2/3, CGFloat(count + 1) * self.kHeightOfUserMenuCell))
        
    }
    
    /**
     点击导航栏上标题按钮
     
     - parameter sender:
     */
    @IBAction func handleNavTitleButtonPress(_ sender: AnyObject?) {
        self.tableViewUserMenu.reloadData()
        // Init dropdown view
        if self.dropdownView == nil {
            self.dropdownView = LMDropdownView()
            self.dropdownView.delegate = self;
            self.dropdownView.closedScale = 1;
            self.dropdownView.blurRadius = 5;
            self.dropdownView.blackMaskAlpha = 0.5;
            self.dropdownView.animationDuration = 0.5;
            self.dropdownView.animationBounceHeight = 20;
            self.dropdownView.contentBackgroundColor = UIColor(hex: 0x2E3F53)
        }
        
        if self.dropdownView.isOpen {
            self.dropdownView.hide()
        } else {
            self.dropdownView.show(
                from: self.navigationController, withContentView: self.tableViewUserMenu)
        }
    }
    
    /**
     更新账户
     
     - parameter obj:
     */
    func updateUserWallet() {
        //保证钱包是存在
        guard CHBTCWallet.checkBTCWalletExist() else {
            return
        }
        
        let accounts = CHBTCWallet.sharedInstance.getAccounts()
        for account in accounts {
            if account.index == CHBTCWallet.sharedInstance.selectedAccountIndex {
                self.currentAccount = account       //记录当前账户对象
                self.userName = account.userNickname
                self.address = account.address.string
                
                self.labelUserName.text = self.userName
                //获取账户余额
                self.getUserAccountByWebservice()
                self.getUserTransactionsByWebservice()
                
                
            }
        }
    }
    
    /**
     调用获取账户接口
     */
    func getUserAccountByWebservice() {
        let nodeServer = CHWalletWrapper.selectedBlockchainNode.service
        nodeServer.userBalance(address: self.address) {
            (message, userBalance) -> Void in
            if message.code == ApiResultCode.Success.rawValue {
                self.balance = Int64(userBalance.balanceSat) + Int64(userBalance.unconfirmedBalanceSat)
                self.labelUserAccount.text = "฿ \(BTCAmount.stringWithSatoshiInBTCFormat(self.balance))"
            }
            
        }
    }
    
    /**
     获取交易记录
     */
    func getUserTransactionsByWebservice() {
        let nodeServer = CHWalletWrapper.selectedBlockchainNode.service
        nodeServer.userTransactions(
            address: self.address, from: "0", to: "", limit: "20") {
                (message, userTransactions, page) -> Void in
                if message.code == ApiResultCode.Success.rawValue {
                    self.transactions = userTransactions
                    self.tableViewTransactions.reloadData()
                }
        }
        
        /*
        InsightRemoteService.sharedInstance.userTransactions(
            self.address, from: "0", to: "20") {
                (message, userTransactions, page) -> Void in
                if message.code! == ApiResultCode.Success.rawValue {
                    self.transactions = userTransactions
                    self.tableViewTransactions.reloadData()
                }
        }
        */
    }
    
    /**
     点击收币
     
     - parameter sender:
     */
    @IBAction func handleReceivePress(_ sender: AnyObject?) {
        
        guard let vc = StoryBoard.wallet.initView(type: BTCReceiveViewController.self) else {
            return
        }
        vc.address = self.address
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    /**
     点击付币
     
     - parameter sender:
     */
    @IBAction func handleSendPress(_ sender: AnyObject?) {
        self.showMultiSigTransactionMenu()
    }
    
    /**
     弹出多重签名发送btc选择的菜单
     */
    func showMultiSigTransactionMenu() {
        let actionSheet = UIAlertController(title: "You can".localized(), message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Send Bitcoin".localized(), style: UIAlertActionStyle.default, handler: {
            (action) -> Void in
            self.gotoBTCSendView()
        }))
        
        //多重签名账户可以粘贴别人的签名交易
        actionSheet.addAction(UIAlertAction(title: "Paste from Clipboard".localized(), style: UIAlertActionStyle.default, handler: {
            (action) -> Void in
            let pasteboard = UIPasteboard.general
            if pasteboard.string?.length ?? 0 > 0 {
                self.gotoMultiSigTransactionView(pasteboard.string!)
            } else {
                SVProgressHUD.showInfo(withStatus: "Clipboard is empty".localized())
            }
        }))
        
    
        actionSheet.addAction(UIAlertAction(title: "Cancel".localized(), style: UIAlertActionStyle.cancel, handler: {
            (action) -> Void in
            
        }))
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    /**
     进入多重签名交易表单界面，进行签名
     */
    func gotoMultiSigTransactionView(_ message: String) {
        
        //初始表单
        do {
            let mtx = try MultiSigTransaction(json: message)
            
            guard let vc = StoryBoard.wallet.initView(type: BTCMultiSigTransactionViewController.self) else {
                return
            }
            vc.currentAccount = self.currentAccount!
            vc.multiSigTx = mtx
            self.navigationController?.pushViewController(vc, animated: true)
            
        } catch {
            SVProgressHUD.showError(withStatus: "Transaction decode error".localized())
        }
        
    }
    
    
    /**
     进入发送比特币界面
     */
    func gotoBTCSendView() {
        guard let vc = StoryBoard.wallet.initView(type: BTCSendViewController.self) else {
            return
        }
        vc.btcAccount = self.currentAccount!
        vc.availableTotal = self.balance
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    
    
    /**
     选择何种账户类型创建
     Normal Account：普通的HDM单签账户，由其私钥完全控制。
     Multi-Sig Account：多重签名合约账户，由联合的公钥组成的一个赎回脚本导出的地址。
     */
    func showCreateAccountTypeMenu() {
        let actionSheet = UIAlertController(title: "Create new account".localized(), message: "Which account type you need".localized(), preferredStyle: UIAlertControllerStyle.actionSheet)
        
        /// 进入HDM账户创建界面
        actionSheet.addAction(UIAlertAction(title: "Normal Account".localized(), style: UIAlertActionStyle.default, handler: {
            (action) -> Void in
            self.gotoCreateHDMAccount()
        }))
        
        //进入创建多签账户界面
        actionSheet.addAction(UIAlertAction(title: "Multi-Sig Account".localized(), style: UIAlertActionStyle.default, handler: {
            (action) -> Void in
            self.gotoCreateMultiSigView()
        }))
        
        
        actionSheet.addAction(UIAlertAction(title: "Cancel".localized(), style: UIAlertActionStyle.cancel, handler: {
            (action) -> Void in
            
        }))
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    
    /// 进入HDM账户创建界面
    func gotoCreateHDMAccount() {
        guard let vc = StoryBoard.account.initView(type: CreateHDMAccountViewController.self) else {
            return
        }
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    
    /// 进入创建多签账户界面
    func gotoCreateMultiSigView() {
        guard let vc = StoryBoard.account.initView(type: MultiSigAccountCreateViewController.self) else {
            return
        }
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - 实现导航栏弹出下拉菜单功能
extension WalletViewController: LMDropdownViewDelegate {
    
    func dropdownViewWillShow(_ dropdownView: LMDropdownView!) {
        self.tabBarController?.tabBar.isUserInteractionEnabled = false;
    }
    
    func dropdownViewDidHide(_ dropdownView: LMDropdownView!) {
        self.tabBarController?.tabBar.isUserInteractionEnabled = true;
        
    }
}

// MARK: - 表格代理方法
extension WalletViewController: UITableViewDelegate, UITableViewDataSource {
    
    
    /**
     是否自己与自己交易
     
     - parameter tx:
     
     - returns:
     */
    func isTransactionToSelf(_ tx: UserTransaction) -> Bool {
        //输出输入的所有地址
        var addresses = [String]()
        for txunit in tx.vinTxs {
            addresses.append(txunit.address)
        }
        
        for txunit in tx.voutTxs {
            addresses.append(txunit.address)
        }
        
        //清除所有与自己相同的元素，如果数组为0则，这个交易是发给自己的
        let filteredAddresses = self.filteredAddresses(addresses)
        if filteredAddresses.0.count == 0 {
            return true;
        } else {
            return false;
        }
    }
    
    /**
     过滤重复的地址
     
     - parameter addresses:
     
     - returns: 不重复的地址，所有地址合成成一个字符串
     */
    func filteredAddresses(_ addresses: [String]) -> ([String], String) {
        //清除重复地址
        var filteredAddresses = Array(Set(addresses))
        
        let indexForCurrentUser = filteredAddresses.index(of: self.address)
        if indexForCurrentUser != nil && indexForCurrentUser != NSNotFound {
            filteredAddresses.remove(at: indexForCurrentUser!)
        }
        
        let addressString = NSMutableString()
        
        for (i, address) in filteredAddresses.enumerated() {
            
            // Truncate if we have more then one.
            if filteredAddresses.count > 1 {
                let shortenedAddress = address.substring(to: address.characters.index(address.startIndex, offsetBy: 10))
                addressString.append("\(shortenedAddress)…")
            } else {
                addressString.append(address)
            }
            
            // Add a comma and space if this is not the last
            if (i != filteredAddresses.count - 1) {
                addressString.append(", ")
            }
        }
        
        return (filteredAddresses, String(addressString))
    }
    
    /**
     拼接发送或接收的地址
     
     - parameter txs:
     
     - returns:
     */
    func addressesString(_ txs: [TransactionUnit]) -> String {
        var addresses = [String]()
        for tx in txs {
            addresses.append(tx.address)
        }
        return self.filteredAddresses(addresses).1
    }
    
    /**
     统计输入输出的交易记录总数
     
     - parameter tx:
     
     - returns:
     */
    func valueForIOPut(_ tx: TransactionUnit) -> BTCAmount {
        var amount: BTCAmount = 0;
        let address = tx.address
        var isForUserAddress = false;
        if (address == self.address) {
            isForUserAddress = true;
        }
        if (isForUserAddress) {
            amount = amount + tx.value
        }
        return amount;
    }
    
    /**
     统计单个用户单个交易的资金变动
     
     - parameter tx:
     
     - returns:
     */
    func valueForTransactionForCurrentUser(_ tx: UserTransaction) -> BTCAmount {
        var valueForWallet: BTCAmount = 0;
        if  self.isTransactionToSelf(tx) {
            //第一个输出就是全部的资金变动
            valueForWallet = tx.voutTxs[0].value
        } else {
            //计算发送的总金额
            var amountSent: BTCAmount = 0;
            for input in tx.vinTxs {
                amountSent = amountSent + self.valueForIOPut(input)
            }
            
            //计算接收的总金额
            var amountReceived: BTCAmount = 0;
            for output in tx.voutTxs {
                amountReceived = amountReceived + self.valueForIOPut(output)
            }
            
            valueForWallet = amountReceived - amountSent;
            // If it is sent, do not include fee.
            if (valueForWallet < 0) {
                let decimalFee = tx.fees * NSDecimalNumber(value: BTCCoin)
                let fee = BTCAmount(decimalFee.int64Value)
                valueForWallet = valueForWallet + fee
            }
        }
        
        return valueForWallet
    }

    
    func numberOfSections(in tableView: UITableView) -> Int {
        if tableView === self.tableViewUserMenu {
            return 1
        } else {
            return 1
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView === self.tableViewUserMenu {
            let accounts = CHBTCWallet.sharedInstance.getAccounts()
            return accounts.count + 1
        } else {
            return self.transactions.count
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if tableView === self.tableViewUserMenu {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "MenuItemCell") as! MenuItemCell
            
            cell.imageViewSelected.isHidden = true
            
            let accounts = CHBTCWallet.sharedInstance.getAccounts()
            if indexPath.row == accounts.count { //最后一行显示添加账户
                cell.labelMenuTitle.text = "Create new account".localized() //创建新账户
                cell.labelAddress.text = ""
            } else {
                
                let btcAccount = CHBTCWallet.sharedInstance.getAccount(by: indexPath.row)!
                if self.address == btcAccount.accountId {
                    cell.imageViewSelected.isHidden = false
                } else {
                    cell.imageViewSelected.isHidden = true
                }
                
                cell.labelMenuTitle.text = btcAccount.userNickname + "[\(btcAccount.accountType.typeName)]"
                cell.labelAddress.text = btcAccount.address.string
            }

            
            return cell
            
        } else {
            let cell: UserTransactionCell
            cell = tableView.dequeueReusableCell(withIdentifier: "UserTransactionCell") as! UserTransactionCell
            let tx = self.transactions[indexPath.row]
            
            //交易确认事件
            let localDateString = Date.getShortTimeByStamp(Int64(tx.blocktime))
            
            if (tx.confirmations == 0) {
                cell.labelTime.text = "unconfirmed".localized()
            } else {
                cell.labelTime.text = localDateString;
            }
            //交易的数量
            let transactionValue = self.valueForTransactionForCurrentUser(tx)
            let transactionAmountString = "฿ \(BTCAmount.stringWithSatoshiInBTCFormat(transactionValue))"
            cell.labelChange.text = transactionAmountString;
            
            // Change Color of Transaction Amount if is sent or received or to self
            let isTransactionToSelf = self.isTransactionToSelf(tx)
            if (isTransactionToSelf) {
                cell.labelChange.textColor =  UIColor(hex: 0x7d2b8b)
                cell.labelChange.text = "To: me".localized();
            } else {
                if (transactionValue < 0) {
                    //发送
                    cell.labelChange.textColor =  UIColor(hex: 0xf76b6b)
                    cell.labelAddress.text = "To:".localized() + " \(self.addressesString(tx.voutTxs))"
                } else {
                    // 接收
                    cell.labelChange.textColor =  UIColor(hex: 0x7fdf40)
                    cell.labelAddress.text = "From:".localized() + " \(self.addressesString(tx.vinTxs))"
                }
            }
            
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if tableView === self.tableViewUserMenu {
            return self.kHeightOfUserMenuCell
        } else {
            return 80
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView === self.tableViewUserMenu {
            
            let accounts = CHBTCWallet.sharedInstance.getAccounts()
            if indexPath.row == accounts.count { //最后一行显示添加账户
                self.showCreateAccountTypeMenu() //选择创建账户
            } else {
                
                let btcAccount = CHBTCWallet.sharedInstance.getAccount(by: indexPath.row)!
                self.currentAccount = btcAccount       //记录当前账户对象
                CHBTCWallet.sharedInstance.selectedAccountIndex = btcAccount.index //记录系统保存的选中用户
                self.userName = btcAccount.userNickname
                self.address = btcAccount.address.string
                
                self.labelUserName.text = self.userName
            }
            
            //通知更新
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: "updateUserWallet"),
                object: nil)
            
            self.dropdownView.hide()
            
        }
    }
    
}

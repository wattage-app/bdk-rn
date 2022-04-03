//
//  RnBdkModule.swift
//  RnBdkModule
//

//
import Foundation

class Progress : BdkProgress {
    func update(progress: Float, message: String?) {
        print("progress", progress, message as Any)
    }
}

let TAG = "RN-BDK"

@objc(RnBdkModule)
class RnBdkModule: NSObject {
    
    let descriptor = "wpkh([c258d2e4/84h/1h/0h]tpubDDYkZojQFQjht8Tm4jsS3iuEmKjTiEGjG6KnuFNKKJb5A6ZUCUZKdvLdSDWofKi4ToRCwb9poe1XdqfUnP4jaJjCB2Zwv11ZLgSbnZSNecE/0/*)"
    let changeDescriptor = "wpkh([c258d2e4/84h/1h/0h]tpubDDYkZojQFQjht8Tm4jsS3iuEmKjTiEGjG6KnuFNKKJb5A6ZUCUZKdvLdSDWofKi4ToRCwb9poe1XdqfUnP4jaJjCB2Zwv11ZLgSbnZSNecE/1/*)"
    let databaseConfig = DatabaseConfig.memory(junk: "")
    let blockchainConfig = BlockchainConfig.electrum(
        config: ElectrumConfig(url: "ssl://electrum.blockstream.info:60002", socks5: nil, retry: 5, timeout: nil, stopGap: 10))
    var wallet: Wallet
    let nodeNetwork = Network.testnet
    var testData: String = "Empty"
    
    @objc static func requiresMainQueueSetup() -> Bool {
        return false
    }

    override init() {
       self.wallet = try! Wallet.init(descriptor: descriptor, changeDescriptor: changeDescriptor, network: nodeNetwork, databaseConfig: databaseConfig, blockchainConfig: blockchainConfig)
       try! self.wallet.sync(progressUpdate: Progress(), maxAddressParam: nil)
    }

    func _seed(
        recover: Bool = false,
        mnemonic: String?,  
        password: String? = nil
    ) -> ExtendedKeyInfo {
        return !recover ? try! generateExtendedKey(network: nodeNetwork, wordCount:WordCount.words12, password: password)
        : try! restoreExtendedKey(network: nodeNetwork, mnemonic: mnemonic ?? "", password: password)
    }


    private func createRestoreWallet(keys: ExtendedKeyInfo) throws -> Wallet {
        do{
            let descriptor: String = createDescriptor(keys: keys)
            let changeDescriptor: String = createChangeDescriptor(keys: keys)
            wallet = try Wallet(descriptor: descriptor, changeDescriptor: changeDescriptor, network: nodeNetwork, databaseConfig: databaseConfig, blockchainConfig: blockchainConfig)
            try wallet.sync(progressUpdate: Progress(), maxAddressParam: nil)
            return wallet
        }
        catch {
            return error as! Wallet
        }
    }

    private func createDescriptor(keys: ExtendedKeyInfo)-> String {
        return ("wpkh(" + keys.xprv + "/84'/1'/0'/0/*)")
    }

    private func createChangeDescriptor(keys: ExtendedKeyInfo)-> String {
        return ("wpkh(" + keys.xprv + "/84'/1'/0'/1/*)")
    }

    @objc
    func genSeed(_ password: String? = nil, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        let seed = _seed(recover: false, mnemonic: "")
        resolve(seed.mnemonic)
    }

    @objc
    func createWallet(_ mnemonic: String? = "", password: String? = nil, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            let keys: ExtendedKeyInfo = _seed(recover: mnemonic != "" ? true : false, mnemonic: mnemonic, password: password)
            try createRestoreWallet(keys: keys)
            let responseObject = ["address": wallet.getNewAddress(), "mnemonic": keys.mnemonic]
            resolve(responseObject)
        }
        catch {
            return reject("Create Wallet Error", error.localizedDescription, error)
        }
    }

    @objc
    func restoreWallet(_ mnemonic: String, password: String? = nil, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            let keys: ExtendedKeyInfo = _seed(recover: true, mnemonic: mnemonic, password: password)
            let newWallet = try createRestoreWallet(keys: keys)
            resolve("Balance: \(try newWallet.getBalance()) Address: \(newWallet.getNewAddress())")
        }
        catch {
            return reject("Restore Wallet Error", error.localizedDescription, error)
        }
    }

    @objc
    func getNewAddress(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        resolve(self.wallet.getNewAddress())
    }

    @objc
    func getBalance(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            try! self.wallet.sync(progressUpdate: Progress(), maxAddressParam: nil)
            let balance = try self.wallet.getBalance()
            resolve(balance)
        }
        catch {
            return reject("Get Balance Error", error.localizedDescription, error)
        }
    }

    @objc
    func broadcastTx(_ recipient: String, amount: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock){
        do {
            let psbt: PartiallySignedBitcoinTransaction = try PartiallySignedBitcoinTransaction(wallet: wallet, recipient: wallet.getNewAddress(), amount: UInt64(truncating: amount), feeRate: nil)
            try wallet.sign(psbt: psbt)
            let transaction = try wallet.broadcast(psbt: psbt)
            print("Broadcast success", transaction)
            resolve(recipient)
        }
        catch let error {
            return reject("Transaction Error", error.localizedDescription, error)
        }
    }

}


// "Address: tb1qc0pnkezmhcpgt70lu5djpl8pyypmfl7tyt5jcs, \n Mnemonic: cushion merry upper hat mind tip fly ritual scheme civil disease since"
// address: tb1quveq827kjss05e9y5tsdgr6ypk0jzjr3p896wg  ,  Mnemonic: title screen science betray fiber brother differ sniff page put damage slender

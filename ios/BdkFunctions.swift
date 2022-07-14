import Foundation
class BdkProgress : Progress {
    func update(progress: Float, message: String?) {
        print("progress", progress, message as Any)
    }
}


class BdkFunctions: NSObject {
     var wallet: Wallet
     var blockChain: Blockchain
     let databaseConfig = DatabaseConfig.memory
     let  defaultBlockChainConfigUrl:String = "ssl://electrum.blockstream.info:60002"
     let defaultBlockChain = "ELECTRUM"
     let blockchainConfig = BlockchainConfig.electrum(
                                            config: ElectrumConfig(
                                                                  url: "ssl://electrum.blockstream.info:60002",
                                                                  socks5: nil,
                                                                  retry: 5,
                                                                  timeout: nil,
                                                                  stopGap: 10))
    let defaultNodeNetwork = "testnet"
    let defaultDescriptor = "wpkh([c258d2e4/84h/1h/0h]tpubDDYkZojQFQjht8Tm4jsS3iuEmKjTiEGjG6KnuFNKKJb5A6ZUCUZKdvLdSDWofKi4ToRCwb9poe1XdqfUnP4jaJjCB2Zwv11ZLgSbnZSNecE/0/*)"
    let defaultChangeDescriptor = "wpkh([c258d2e4/84h/1h/0h]tpubDDYkZojQFQjht8Tm4jsS3iuEmKjTiEGjG6KnuFNKKJb5A6ZUCUZKdvLdSDWofKi4ToRCwb9poe1XdqfUnP4jaJjCB2Zwv11ZLgSbnZSNecE/1/*)"
    
    
    override init() {
        self.blockChain = try! Blockchain(config: blockchainConfig)

        self.wallet = try! Wallet.init(descriptor: defaultDescriptor, changeDescriptor: defaultChangeDescriptor, network: Network.testnet, databaseConfig: databaseConfig)

        try? self.wallet.sync(blockchain: blockChain, progress: BdkProgress())

    }

    
    func sync(config:BlockchainConfig?) {
        try? self.wallet.sync(blockchain: Blockchain.init(config: config ?? blockchainConfig), progress: BdkProgress())
    }


    private func _seed(
        recover: Bool = false,
        mnemonic: String?,
        password: String? = nil
    ) throws -> ExtendedKeyInfo {
        do {
            if(!recover){
                return try generateExtendedKey(network: wallet.getNetwork() , wordCount: WordCount.words12, password: password)
            }
            else {
                return try restoreExtendedKey(network: wallet.getNetwork() , mnemonic: mnemonic ?? "", password: password)
            }
        } catch {
            throw error
        }
    }

    private func setNetwork(networkStr: String?)-> Network {
        switch (networkStr) {
            case "TESTNET" : return  Network.testnet
            case "BITCOIN" : return Network.bitcoin
            case "REGTEST" : return  Network.regtest
            case "SIGNET" : return Network.signet
            default : return Network.testnet
        }
    }
    
    
    private func createDefaultDescriptor(keys: ExtendedKeyInfo)-> String {
        return ("wpkh(" + keys.xprv + "/84'/1'/0'/0/*)")
    }

    private func createDefaultChangeDescriptor(keys: ExtendedKeyInfo)-> String {
        return ("wpkh(" + keys.xprv + "/84'/1'/0'/1/*)")
    }
    
    private func createRestoreWallet(
        keys: ExtendedKeyInfo,
        network:String,
        blockChainConfigUrl: String?,
        blockChainSocket5: String?,
        retry: String?,
        timeOut: String?,
        blockChain: String?
    ) throws -> Wallet {
        do{
            let descriptor: String = createDefaultDescriptor(keys: keys)
            let changeDescriptor: String = createDefaultChangeDescriptor(keys: keys)
            let config: BlockchainConfig = createDatabaseConfig(blockChainConfigUrl: blockChainConfigUrl, blockChainSocket5: blockChainSocket5, retry: retry, timeOut: timeOut, blockChain: blockChain)
            let walletNetwork: Network = setNetwork(networkStr: network)
            self.wallet = try Wallet.init(
                descriptor: descriptor,
                changeDescriptor: changeDescriptor,
                network: walletNetwork,
                databaseConfig: databaseConfig)
            self.sync(config: config)
            return self.wallet
        } catch {
            throw error
        }
    }
    
    
    private func createDatabaseConfig(
        blockChainConfigUrl: String?, blockChainSocket5: String?,
        retry: String?, timeOut: String?, blockChain: String?
    )-> BlockchainConfig {
        switch (blockChain) {
        case  "ELECTRUM" : return  BlockchainConfig.electrum(config:
                                                                ElectrumConfig(
                                                                    url: blockChainConfigUrl ?? self.defaultBlockChainConfigUrl, socks5: blockChainConfigUrl,
                                                                    retry: UInt8(retry ?? "") ?? 5, timeout: UInt8(timeOut ?? "") ?? 5,
                                                                    stopGap: 5
                                                                )
        )
        case "ESPLORA" :return  BlockchainConfig.esplora(config:
                                                            EsploraConfig(
                                                                baseUrl: blockChainConfigUrl ?? self.defaultBlockChainConfigUrl, proxy: nil,
                                                                concurrency: UInt8(retry ?? "") ?? 5, stopGap: UInt64(timeOut ?? "") ?? 5,
                                                                timeout: 5
                                                            )
        )
        default: return blockchainConfig


        }
    }


    func genSeed(password: String? = nil) throws -> ExtendedKeyInfo {
            do {
                let seed = try _seed(recover: false, mnemonic: "" )
                return seed

            } catch {
                throw error
            }
        }


    func createWallet(
        mnemonic: String? = "",
        password: String? = nil,
        network:String?,
        blockChainConfigUrl: String?,
        blockChainSocket5: String?,
        retry: String?,
        timeOut: String?,
        blockChain: String?
    ) throws -> [String: Any?] {
            do {
            let keys: ExtendedKeyInfo = try _seed(recover: mnemonic != "" ? true : false, mnemonic: mnemonic, password: password)
                
                let wallet = try createRestoreWallet(
                    keys: keys, network: network!,
                    blockChainConfigUrl: blockChainConfigUrl,
                    blockChainSocket5: blockChainSocket5,
                    retry:retry,
                    timeOut: timeOut,
                    blockChain: blockChain ?? defaultBlockChain
               )

                let addressInfo = try! self.wallet.getAddress(addressIndex: AddressIndex.new)
                let responseObject = [
                    "address": addressInfo.address,
                    "balance": try! wallet.getBalance(),
                    "mnemonic": keys.mnemonic,
                ] as [String : Any]
                return responseObject
            }
            catch {
                throw error
            }
        }

    
        func restoreWallet(
            mnemonic: String? = "",
            password: String? = nil,
            network:String?,
            blockChainConfigUrl: String?,
            blockChainSocket5: String?,
            retry: String?,
            timeOut: String?,
            blockChain: String?
        ) throws -> [String: Any?] {
            do {
                let keys: ExtendedKeyInfo = try _seed(recover:  true, mnemonic: mnemonic, password: password)
                let wallet = try createRestoreWallet(
                    keys: keys,
                    network: network!,
                    blockChainConfigUrl: blockChainConfigUrl!,
                    blockChainSocket5: blockChainSocket5!,
                    retry:retry!,
                    timeOut: timeOut!,
                    blockChain: blockChain ?? defaultBlockChain
                )
                let addressInfo = try! self.wallet.getAddress(addressIndex: AddressIndex.new)
                let responseObject = [
                    "address": addressInfo.address,
                    "balance": try! wallet.getBalance(),
                    "mnemonic": keys.mnemonic,
                ] as [String : Any]
                return responseObject
            }
            catch {
                throw error
            }
        }

    
    func getWallet()throws -> [String: Any?]{
        do {
           
            let addressInfo = try! self.wallet.getAddress(addressIndex: AddressIndex.new)
            let responseObject = [
                "address": addressInfo.address,
                "balance": try self.getBalance()
            ] as [String : Any]
            return responseObject
        }
        catch {
            throw error
        }
    }
        

    func getNewAddress() -> String{
        let addressInfo = try! self.wallet.getAddress(addressIndex:AddressIndex.new)
        return addressInfo.address
    }
    func getLastUnusedAddress() -> String{
        let addressInfo = try! self.wallet.getAddress(addressIndex:AddressIndex.lastUnused)
        return addressInfo.address
    }
    
    func getNetwork() -> Network{
            return self.wallet.getNetwork()
    }

    
 func getBalance() throws -> String {
     do {
        
         try! self.wallet.sync(blockchain: Blockchain.init(config: blockchainConfig), progress: BdkProgress())
                
         let balance = try self.wallet.getBalance()
         return String(balance)
            }
            catch {
                throw error
            }
        }
    
    /// Todo the following functions correct
    func transactionsList(pending: Bool? = false) throws -> [Any] {
        do {
            let transactions = try wallet.getTransactions()
            
            var confirmedTransactions: [Any] = []
            var pendingTransactions: [Any] = []
            for tx in transactions {
                // Confirmed transactions
                if case let .confirmed(details, confirmation) = tx {
                    let responseObject = [
                        "fee": details.fee!,
                        "received": details.received,
                        "sent": details.sent,
                        "txid": details.txid,
                        "block_height": confirmation.height,
                        "block_timestamp": confirmation.timestamp,
                    ] as [String : Any]
                    confirmedTransactions.append(responseObject)
                }
                // Pending transactions
                if case let .unconfirmed(details) = tx {
                    let responseObject = [
                        "fee": details.fee!,
                        "received": details.received,
                        "sent": details.sent,
                        "txid": details.txid,
                    ] as [String : Any]
                    pendingTransactions.append(responseObject)
                }
            }
            
            return pending==true ? pendingTransactions : confirmedTransactions
        } catch {
                throw error
            }
    }
    
    
    func pendingTransactionsList() throws -> Array<[String: Any?]> {
        return []
    }

    
    func broadcastTx(_ recipient: String, amount: NSNumber)  throws -> String {
           do {
               let txBuilder = TxBuilder().addRecipient(address: recipient, amount: UInt64(truncating: amount))
               let psbt = try txBuilder.finish(wallet: wallet)
               try blockChain.broadcast(psbt: psbt)
               let txid = psbt.txid()
               return  txid;
           }   catch {
               throw error
           }
       }
   }

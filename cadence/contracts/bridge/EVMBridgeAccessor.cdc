import "FungibleToken"
import "NonFungibleToken"

import "EVM"

import "IFlowEVMNFTBridge"

access(all) contract EVMBridgeAccessor {

    access(all) resource Accessor : EVM.BridgeAccessor {
        access(all) let bridgeAddress: Address

        init(_ bridgeAddress: Address) {
            self.bridgeAddress = bridgeAddress
        }
        
        access(all) fun bridgeNFT(nft: @{NonFungibleToken.NFT}, to: EVM.EVMAddress, fee: @{FungibleToken.Vault}) {
            let bridge = getAccount(self.bridgeAddress).contracts.borrow<&IFlowEVMNFTBridge>(name: "FlowEVMNFTBridge")
                ?? panic("No IFlowEVMNFTBridge contract found")
            bridge.bridgeNFTToEVM(token: <-nft, to: to, tollFee: <-fee)
        }
    }

    access(account) fun createAccessor(bridgeAddress: Address): @Accessor {
        return <- create Accessor(bridgeAddress)
    }

    init(bridgeAddress: Address) {
        self.account.storage.save(<-create Accessor(bridgeAddress), to: /storage/evmBridgeAccessor)
    }
}

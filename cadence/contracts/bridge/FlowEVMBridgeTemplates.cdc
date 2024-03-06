import "FungibleToken"
import "NonFungibleToken"

import "EVM"

import "FlowEVMBridgeUtils"

/// This contract serves Cadence code from chunked templates, replacing the contract name with the name derived from
/// given arguments - either Cadence Type or EVM contract address.
///
access(all) contract FlowEVMBridgeTemplates {
    /// Canonical path for the Admin resource
    access(all) let AdminStoragePath: StoragePath
    /// Chunked Hex-encoded Cadence contract code, to be joined on derived contract name
    access(self) let templateCodeChunks: {String: [[UInt8]]}

    /// Serves bridged asset contract code for a given type, deriving the contract name from the EVM contract info
    access(all) fun getBridgedAssetContractCode(evmContractAddress: EVM.EVMAddress, isERC721: Bool): [UInt8]? {
        let cadenceContractName: String = isERC721 ?
            FlowEVMBridgeUtils.deriveBridgedNFTContractName(from: evmContractAddress) :
            FlowEVMBridgeUtils.deriveBridgedTokenContractName(from: evmContractAddress)

        if isERC721 {
            return self.getBridgedNFTContractCode(contractName: cadenceContractName)
        } else {
            // TODO
            return nil
        }
    }

    access(self) fun getBridgedNFTContractCode(contractName: String): [UInt8]? {
        return self.joinChunks(self.templateCodeChunks["bridgedNFT"]!, with: String.encodeHex(contractName.utf8))
    }

    access(self) fun joinChunks(_ chunks: [[UInt8]], with name: String): [UInt8] {
        let nameBytes: [UInt8] = name.decodeHex()
        let code: [UInt8] = []
        for i, chunk in chunks {
            code.appendAll(chunk)
            // No need to append the contract name after the last chunk
            if i == chunks.length - 1 {
                break
            }
            code.appendAll(nameBytes)
        }
        return code
    }

    /// Resource enabling updates to the contract template code
    access(all) resource Admin {
        access(all) fun upsertContractCodeChunks(forTemplate: String, chunks: [String]) {
            let byteChunks: [[UInt8]] = []
            for chunk in chunks {
                byteChunks.append(chunk.decodeHex())
            }
            FlowEVMBridgeTemplates.templateCodeChunks[forTemplate] = byteChunks
        }
        access(all) fun addNewContractCodeChunks(newTemplate: String, chunks: [String]) {
            pre {
                FlowEVMBridgeTemplates.templateCodeChunks[newTemplate] == nil: "Code already exists for template"
            }
            self.upsertContractCodeChunks(forTemplate: newTemplate, chunks: chunks)
        }
    }


    // Flow CLI currently breaks flow.json on [String] in contract init - hard coding for the time being but needs new
    // hex on template changes
    // init(templateCodeChunks: {String: [String]}) {
    init() {
        self.AdminStoragePath = /storage/flowEVMBridgeTemplatesAdmin
        self.templateCodeChunks = {}
        // TODO: Replace chunks in init blocks with committing transaction
        //      Added here avoid need to reformat to Cadence JSON while developing
        let bridgedNFTHexChunks = [
            "696d706f7274204e6f6e46756e6769626c65546f6b656e2066726f6d203078663864366530353836623061323063370a696d706f7274204d6574616461746156696577732066726f6d203078663864366530353836623061323063370a696d706f727420566965775265736f6c7665722066726f6d203078663864366530353836623061323063370a696d706f72742046756e6769626c65546f6b656e2066726f6d203078656538323835366266323065326161360a696d706f727420466c6f77546f6b656e2066726f6d203078306165353363623665336634326137390a0a696d706f72742045564d2066726f6d203078663864366530353836623061323063370a0a696d706f7274204943726f7373564d2066726f6d203078663864366530353836623061323063370a696d706f7274204945564d4272696467654e46544d696e7465722066726f6d203078663864366530353836623061323063370a696d706f727420466c6f7745564d4272696467654e4654457363726f772066726f6d203078663864366530353836623061323063370a696d706f727420466c6f7745564d427269646765436f6e6669672066726f6d203078663864366530353836623061323063370a696d706f727420466c6f7745564d4272696467655574696c732066726f6d203078663864366530353836623061323063370a696d706f727420466c6f7745564d4272696467652066726f6d203078663864366530353836623061323063370a696d706f72742043726f7373564d4e46542066726f6d203078663864366530353836623061323063370a0a2f2f2f205468697320636f6e747261637420697320612074656d706c617465207573656420627920466c6f7745564d42726964676520746f20646566696e652045564d2d6e6174697665204e46547320627269646765642066726f6d20466c6f772045564d20746f20466c6f772e0a2f2f2f2055706f6e206465706c6f796d656e74206f66207468697320636f6e74726163742c2074686520636f6e7472616374206e616d65206973206465726976656420617320612066756e6374696f6e206f6620746865206173736574207479706520286865726520616e2045524337323120616b610a2f2f2f20616e204e46542920616e642074686520636f6e747261637427732045564d20616464726573732e20546865206465726976656420636f6e7472616374206e616d65206973207468656e206a6f696e65642077697468207468697320636f6e7472616374277320636f64652c200a2f2f2f207072657061726564206173206368756e6b7320696e20466c6f7745564d42726964676554656d706c61746573206265666f7265206265696e67206465706c6f79656420746f2074686520466c6f772045564d20427269646765206163636f756e742e0a2f2f2f0a2f2f2f204f6e206272696467696e672c2074686520455243373231206973207472616e7366657272656420746f2074686520627269646765277320436164656e63654f776e65644163636f756e742045564d206164647265737320616e642061206e6577204e4654206973206d696e7465642066726f6d0a2f2f2f207468697320636f6e747261637420746f20746865206272696467696e672063616c6c65722e204f6e2072657475726e20746f20466c6f772045564d2c2074686520726576657273652070726f6365737320697320666f6c6c6f776564202d2074686520746f6b656e206973206275726e65640a2f2f2f20696e207468697320636f6e747261637420616e642074686520455243373231206973207472616e7366657272656420746f2074686520646566696e656420726563697069656e742e20496e2074686973207761792c2074686520436164656e636520746f6b656e206163747320617320610a2f2f2f20726570726573656e746174696f6e206f6620626f7468207468652045564d204e465420616e642074687573206f776e6572736869702072696768747320746f2069742075706f6e206272696467696e67206261636b20746f20466c6f772045564d2e0a2f2f2f0a2f2f2f20546f20627269646765206265747765656e20564d732c20612063616c6c65722063616e20656974686572207573652074686520636f6e7472616374206d6574686f647320646566696e65642062656c6f772c206f72207573652074686520466c6f7745564d42726964676527730a2f2f2f206272696467696e67206d6574686f64732077686963682077696c6c2070726f6772616d61746963616c6c7920726f757465206272696467696e672063616c6c7320746f207468697320636f6e74726163742e0a2f2f2f0a2f2f20544f444f3a20496d706c656d656e74204e465420636f6e747261637420696e74657266616365206f6e636520763220617661696c61626c65206c6f63616c6c790a61636365737328616c6c2920636f6e747261637420",
            "203a204943726f7373564d2c204945564d4272696467654e46544d696e7465722c204e6f6e46756e6769626c65546f6b656e207b0a0a202020202f2f2f20506f696e74657220746f2074686520466163746f7279206465706c6f79656420536f6c696469747920636f6e7472616374206164647265737320646566696e696e672074686520627269646765642061737365740a2020202061636365737328616c6c29206c65742065766d4e4654436f6e7472616374416464726573733a2045564d2e45564d416464726573730a202020202f2f2f20506f696e74657220746f2074686520466c6f77204e465420636f6e7472616374206164647265737320646566696e696e672074686520627269646765642061737365742c207468697320636f6e7472616374206164647265737320696e207468697320636173650a2020202061636365737328616c6c29206c657420666c6f774e4654436f6e7472616374416464726573733a20416464726573730a202020202f2f2f204e616d65206f6620746865204e465420636f6c6c656374696f6e20646566696e656420696e2074686520636f72726573706f6e64696e672045524337323120636f6e74726163740a2020202061636365737328616c6c29206c6574206e616d653a20537472696e670a202020202f2f2f2053796d626f6c206f6620746865204e465420636f6c6c656374696f6e20646566696e656420696e2074686520636f72726573706f6e64696e672045524337323120636f6e74726163740a2020202061636365737328616c6c29206c65742073796d626f6c3a20537472696e670a202020202f2f2f2052657461696e206120436f6c6c656374696f6e20746f207265666572656e6365207768656e207265736f6c76696e6720436f6c6c656374696f6e204d657461646174610a202020206163636573732873656c6629206c657420636f6c6c656374696f6e3a2040436f6c6c656374696f6e0a0a202020202f2f2f2057652063686f6f736520746865206e616d65204e465420686572652c20627574207468697320747970652063616e206861766520616e79206e616d65206e6f770a202020202f2f2f20626563617573652074686520696e7465726661636520646f6573206e6f74207265717569726520697420746f20686176652061207370656369666963206e616d6520616e79206d6f72650a2020202061636365737328616c6c29207265736f75726365204e46543a2043726f7373564d4e46542e45564d4e4654207b0a0a202020202020202061636365737328616c6c29206c65742069643a2055496e7436340a202020202020202061636365737328616c6c29206c65742065766d49443a2055496e743235360a202020202020202061636365737328616c6c29206c6574206e616d653a20537472696e670a202020202020202061636365737328616c6c29206c65742073796d626f6c3a20537472696e670a0a202020202020202061636365737328616c6c29206c6574207572693a20537472696e670a202020202020202061636365737328616c6c29206c6574206d657461646174613a207b537472696e673a20416e795374727563747d0a0a2020202020202020696e6974280a2020202020202020202020206e616d653a20537472696e672c0a20202020202020202020202073796d626f6c3a20537472696e672c0a20202020202020202020202065766d49443a2055496e743235362c0a2020202020202020202020207572693a20537472696e672c0a2020202020202020202020206d657461646174613a207b537472696e673a20416e795374727563747d0a202020202020202029207b0a20202020202020202020202073656c662e6e616d65203d206e616d650a20202020202020202020202073656c662e73796d626f6c203d2073796d626f6c0a20202020202020202020202073656c662e6964203d2073656c662e757569640a20202020202020202020202073656c662e65766d4944203d2065766d49440a20202020202020202020202073656c662e757269203d207572690a20202020202020202020202073656c662e6d65746164617461203d206d657461646174610a20202020202020207d0a0a20202020202020202f2f2f2052657475726e7320746865206d65746164617461207669657720747970657320737570706f727465642062792074686973204e46540a202020202020202061636365737328616c6c2920766965772066756e20676574566965777328293a205b547970655d207b0a20202020202020202020202072657475726e205b0a20202020202020202020202020202020547970653c43726f7373564d4e46542e427269646765644d657461646174613e28292c0a20202020202020202020202020202020547970653c4d6574616461746156696577732e53657269616c3e28292c0a20202020202020202020202020202020547970653c4d6574616461746156696577732e4e4654436f6c6c656374696f6e446174613e28292c0a20202020202020202020202020202020547970653c4d6574616461746156696577732e4e4654436f6c6c656374696f6e446973706c61793e28290a2020202020202020202020205d0a20202020202020207d0a0a20202020202020202f2f2f205265736f6c7665732061206d65746164617461207669657720666f722074686973204e46540a202020202020202061636365737328616c6c292066756e207265736f6c766556696577285f20766965773a2054797065293a20416e795374727563743f207b0a2020202020202020202020207377697463682076696577207b0a202020202020202020202020202020202f2f20576520646f6e2774206b6e6f772077686174206b696e64206f662066696c65207468652055524920726570726573656e747320284950465320762048545450292c20736f2077652063616e2774207265736f6c766520446973706c617920766965770a202020202020202020202020202020202f2f20776974682074686520555249206173207468756d626e61696c202d207765206d61792061206e6577207374616e64617264207669657720666f722045564d204e465473202d207468697320697320696e746572696d0a202020202020202020202020202020206361736520547970653c43726f7373564d4e46542e427269646765644d657461646174613e28293a0a202020202020202020202020202020202020202072657475726e2043726f7373564d4e46542e427269646765644d65746164617461280a2020202020202020202020202020202020202020202020206e616d653a2073656c662e6e616d652c0a20202020202020202020202020202020202020202020202073796d626f6c3a2073656c662e73796d626f6c2c0a2020202020202020202020202020202020202020202020207572693a2043726f7373564d4e46542e5552492873656c662e757269292c0a20202020202020202020202020202020202020202020202065766d436f6e7472616374416464726573733a2073656c662e67657445564d436f6e74726163744164647265737328290a2020202020202020202020202020202020202020290a202020202020202020202020202020206361736520547970653c4d6574616461746156696577732e53657269616c3e28293a0a202020202020202020202020202020202020202072657475726e204d6574616461746156696577732e53657269616c280a20202020202020202020202020202020202020202020202073656c662e69640a2020202020202020202020202020202020202020290a202020202020202020202020202020206361736520547970653c4d6574616461746156696577732e4e4654436f6c6c656374696f6e446174613e28293a0a202020202020202020202020202020202020202072657475726e20",
            "2e7265736f6c7665436f6e747261637456696577287265736f75726365547970653a2073656c662e6765745479706528292c2076696577547970653a20547970653c4d6574616461746156696577732e4e4654436f6c6c656374696f6e446174613e2829290a202020202020202020202020202020206361736520547970653c4d6574616461746156696577732e4e4654436f6c6c656374696f6e446973706c61793e28293a0a202020202020202020202020202020202020202072657475726e20",
            "2e7265736f6c7665436f6e747261637456696577287265736f75726365547970653a2073656c662e6765745479706528292c2076696577547970653a20547970653c4d6574616461746156696577732e4e4654436f6c6c656374696f6e446973706c61793e2829290a2020202020202020202020207d0a20202020202020202020202072657475726e206e696c0a20202020202020207d0a0a20202020202020202f2f2f207075626c69632066756e6374696f6e207468617420616e796f6e652063616e2063616c6c20746f206372656174652061206e657720656d70747920636f6c6c656374696f6e0a202020202020202061636365737328616c6c292066756e20637265617465456d707479436f6c6c656374696f6e28293a20407b4e6f6e46756e6769626c65546f6b656e2e436f6c6c656374696f6e7d207b0a20202020202020202020202072657475726e203c2d20",
            "2e637265617465456d707479436f6c6c656374696f6e286e6674547970653a2073656c662e676574547970652829290a20202020202020207d0a0a20202020202020202f2a202d2d2d2043726f7373564d4e465420636f6e666f726d616e6365202d2d2d202a2f0a20202020202020202f2f0a20202020202020202f2f2f2052657475726e73207468652045564d20636f6e74726163742061646472657373206f6620746865204e46540a202020202020202061636365737328616c6c292066756e2067657445564d436f6e74726163744164647265737328293a2045564d2e45564d41646472657373207b0a20202020202020202020202072657475726e20",
            "2e67657445564d436f6e74726163744164647265737328290a20202020202020207d0a0a20202020202020202f2f2f2053696d696c617220746f204552433732312e746f6b656e555249206d6574686f642c2072657475726e732074686520555249206f6620746865204e465420776974682073656c662e65766d49442061742074696d65206f66206272696467696e670a202020202020202061636365737328616c6c292066756e20746f6b656e55524928293a20537472696e67207b0a20202020202020202020202072657475726e2073656c662e7572690a20202020202020207d0a202020207d0a0a2020202061636365737328616c6c29207265736f7572636520436f6c6c656374696f6e3a204e6f6e46756e6769626c65546f6b656e2e436f6c6c656374696f6e2c2043726f7373564d4e46542e45564d4e4654436f6c6c656374696f6e207b0a20202020202020202f2f2f2064696374696f6e617279206f66204e465420636f6e666f726d696e6720746f6b656e7320696e6465786564206f6e2074686569722049440a202020202020202061636365737328636f6e74726163742920766172206f776e65644e4654733a20407b55496e7436343a20",
            "2e4e46547d0a20202020202020202f2f2f204d617070696e67206f662045564d2049447320746f20466c6f77204e4654204944730a202020202020202061636365737328636f6e747261637429206c65742065766d4944546f466c6f7749443a207b55496e743235363a2055496e7436347d0a0a202020202020202061636365737328616c6c29207661722073746f72616765506174683a2053746f72616765506174680a202020202020202061636365737328616c6c2920766172207075626c6963506174683a205075626c6963506174680a0a2020202020202020696e6974202829207b0a20202020202020202020202073656c662e6f776e65644e465473203c2d207b7d0a20202020202020202020202073656c662e65766d4944546f466c6f774944203d207b7d0a2020202020202020202020206c657420636f6c6c656374696f6e44617461203d20",
            "2e7265736f6c7665436f6e747261637456696577280a20202020202020202020202020202020202020207265736f75726365547970653a20547970653c40",
            "2e4e46543e28292c0a202020202020202020202020202020202020202076696577547970653a20547970653c4d6574616461746156696577732e4e4654436f6c6c656374696f6e446174613e28290a202020202020202020202020202020202920617321204d6574616461746156696577732e4e4654436f6c6c656374696f6e446174610a20202020202020202020202073656c662e73746f7261676550617468203d20636f6c6c656374696f6e446174612e73746f72616765506174680a20202020202020202020202073656c662e7075626c696350617468203d20636f6c6c656374696f6e446174612e7075626c6963506174680a20202020202020207d0a0a20202020202020202f2f2f2052657475726e732061206c697374206f66204e46542074797065732074686174207468697320726563656976657220616363657074730a202020202020202061636365737328616c6c2920766965772066756e20676574537570706f727465644e4654547970657328293a207b547970653a20426f6f6c7d207b0a20202020202020202020202072657475726e207b20547970653c40",
            "2e4e46543e28293a2074727565207d0a20202020202020207d0a0a20202020202020202f2f2f2052657475726e732077686574686572206f72206e6f742074686520676976656e20747970652069732061636365707465642062792074686520636f6c6c656374696f6e0a20202020202020202f2f2f204120636f6c6c656374696f6e20746861742063616e2061636365707420616e7920747970652073686f756c64206a7573742072657475726e20747275652062792064656661756c740a202020202020202061636365737328616c6c2920766965772066756e206973537570706f727465644e46545479706528747970653a2054797065293a20426f6f6c207b0a202020202020202020202072657475726e2074797065203d3d20547970653c40",
            "2e4e46543e28290a20202020202020207d0a0a20202020202020202f2f2f2052656d6f76657320616e204e46542066726f6d2074686520636f6c6c656374696f6e20616e64206d6f76657320697420746f207468652063616c6c65720a2020202020202020616363657373284e6f6e46756e6769626c65546f6b656e2e5769746864726177207c204e6f6e46756e6769626c65546f6b656e2e4f776e6572292066756e20776974686472617728776974686472617749443a2055496e743634293a20407b4e6f6e46756e6769626c65546f6b656e2e4e46547d207b0a2020202020202020202020206c657420746f6b656e203c2d2073656c662e6f776e65644e4654732e72656d6f7665286b65793a2077697468647261774944290a202020202020202020202020202020203f3f2070616e69632822436f756c64206e6f7420776974686472617720616e204e46542077697468207468652070726f76696465642049442066726f6d2074686520636f6c6c656374696f6e22290a0a20202020202020202020202072657475726e203c2d746f6b656e0a20202020202020207d0a0a20202020202020202f2f2f2057697468647261777320616e204e46542066726f6d2074686520636f6c6c656374696f6e206279206974732045564d2049440a2020202020202020616363657373284e6f6e46756e6769626c65546f6b656e2e5769746864726177207c204e6f6e46756e6769626c65546f6b656e2e4f776e6572292066756e207769746864726177427945564d4944285f2069643a2055496e743634293a20407b4e6f6e46756e6769626c65546f6b656e2e4e46547d207b0a2020202020202020202020206c657420746f6b656e203c2d2073656c662e6f776e65644e4654732e72656d6f7665286b65793a206964290a202020202020202020202020202020203f3f2070616e69632822436f756c64206e6f7420776974686472617720616e204e46542077697468207468652070726f76696465642049442066726f6d2074686520636f6c6c656374696f6e22290a0a20202020202020202020202072657475726e203c2d746f6b656e0a20202020202020207d0a0a20202020202020202f2f2f205474616b65732061204e465420616e64206164647320697420746f2074686520636f6c6c656374696f6e732064696374696f6e61727920616e6420616464732074686520494420746f207468652065766d4944546f466c6f774944206d617070696e670a202020202020202061636365737328616c6c292066756e206465706f73697428746f6b656e3a20407b4e6f6e46756e6769626c65546f6b656e2e4e46547d29207b0a2020202020202020202020206c657420746f6b656e203c2d20746f6b656e206173212040",
            "2e4e46540a0a2020202020202020202020202f2f2061646420746865206e657720746f6b656e20746f207468652064696374696f6e6172792077686963682072656d6f76657320746865206f6c64206f6e650a20202020202020202020202073656c662e65766d4944546f466c6f7749445b746f6b656e2e65766d49445d203d20746f6b656e2e69640a2020202020202020202020206c6574206f6c64546f6b656e203c2d2073656c662e6f776e65644e4654735b746f6b656e2e69645d203c2d20746f6b656e0a0a20202020202020202020202064657374726f79206f6c64546f6b656e0a20202020202020207d0a0a20202020202020202f2f2f2052657475726e7320616e206172726179206f66207468652049447320746861742061726520696e2074686520636f6c6c656374696f6e0a202020202020202061636365737328616c6c2920766965772066756e2067657449447328293a205b55496e7436345d207b0a20202020202020202020202072657475726e2073656c662e6f776e65644e4654732e6b6579730a20202020202020207d0a0a20202020202020202f2f2f2052657475726e7320616e206172726179206f66207468652045564d2049447320746861742061726520696e2074686520636f6c6c656374696f6e0a202020202020202061636365737328616c6c2920766965772066756e2067657445564d49447328293a205b55496e743235365d207b0a20202020202020202020202072657475726e2073656c662e65766d4944546f466c6f7749442e6b6579730a20202020202020207d0a0a20202020202020202f2f2f2052657475726e732074686520436164656e6365204e46542e696420666f722074686520676976656e2045564d204e4654204944206966200a202020202020202061636365737328616c6c2920766965772066756e20676574436164656e636549442866726f6d2065766d49443a2055496e74323536293a2055496e7436343f207b0a20202020202020202020202072657475726e2073656c662e65766d4944546f466c6f7749445b65766d49445d203f3f2055496e7436342865766d4944290a20202020202020207d0a0a20202020202020202f2f2f20476574732074686520616d6f756e74206f66204e4654732073746f72656420696e2074686520636f6c6c656374696f6e0a202020202020202061636365737328616c6c2920766965772066756e206765744c656e67746828293a20496e74207b0a20202020202020202020202072657475726e2073656c662e6f776e65644e4654732e6b6579732e6c656e6774680a20202020202020207d0a0a20202020202020202f2f2f205265747269657665732061207265666572656e636520746f20746865204e46542073746f72656420696e2074686520636f6c6c656374696f6e206279206974732049440a202020202020202061636365737328616c6c2920766965772066756e20626f72726f774e4654285f2069643a2055496e743634293a20267b4e6f6e46756e6769626c65546f6b656e2e4e46547d3f207b0a20202020202020202020202072657475726e202673656c662e6f776e65644e4654735b69645d0a20202020202020207d0a0a20202020202020202f2f2f20426f72726f77207468652076696577207265736f6c76657220666f722074686520737065636966696564204e46542049440a202020202020202061636365737328616c6c2920766965772066756e20626f72726f77566965775265736f6c7665722869643a2055496e743634293a20267b566965775265736f6c7665722e5265736f6c7665727d3f207b0a2020202020202020202020206966206c6574206e6674203d202673656c662e6f776e65644e4654735b69645d2061732026",
            "2e4e46543f207b0a2020202020202020202020202020202072657475726e206e667420617320267b566965775265736f6c7665722e5265736f6c7665727d0a2020202020202020202020207d0a20202020202020202020202072657475726e206e696c0a20202020202020207d0a0a20202020202020202f2f2f204372656174657320616e20656d70747920636f6c6c656374696f6e0a202020202020202061636365737328616c6c292066756e20637265617465456d707479436f6c6c656374696f6e28293a20407b4e6f6e46756e6769626c65546f6b656e2e436f6c6c656374696f6e7d20207b0a20202020202020202020202072657475726e203c2d",
            "2e637265617465456d707479436f6c6c656374696f6e286e6674547970653a20547970653c40",
            "2e4e46543e2829290a20202020202020207d0a202020207d0a0a202020202f2f2f20637265617465456d707479436f6c6c656374696f6e206372656174657320616e20656d70747920436f6c6c656374696f6e20666f722074686520737065636966696564204e465420747970650a202020202f2f2f20616e642072657475726e7320697420746f207468652063616c6c657220736f207468617420746865792063616e206f776e204e4654730a2020202061636365737328616c6c292066756e20637265617465456d707479436f6c6c656374696f6e286e6674547970653a2054797065293a20407b4e6f6e46756e6769626c65546f6b656e2e436f6c6c656374696f6e7d207b0a202020202020202072657475726e203c2d2063726561746520436f6c6c656374696f6e28290a202020207d0a0a202020202f2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a0a202020202020202020202020476574746572730a202020202a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2f0a0a202020202f2f2f2052657475726e73207468652045564d20636f6e74726163742061646472657373206f6620746865204e4654207468697320636f6e747261637420726570726573656e74730a202020202f2f2f0a2020202061636365737328616c6c292066756e2067657445564d436f6e74726163744164647265737328293a2045564d2e45564d41646472657373207b0a202020202020202072657475726e2073656c662e65766d4e4654436f6e7472616374416464726573730a202020207d0a0a202020202f2f2f2046756e6374696f6e20746861742072657475726e7320616c6c20746865204d6574616461746120566965777320696d706c656d656e7465642062792061204e6f6e2046756e6769626c6520546f6b656e0a202020202f2f2f0a202020202f2f2f204072657475726e20416e206172726179206f6620547970657320646566696e696e672074686520696d706c656d656e7465642076696577732e20546869732076616c75652077696c6c20626520757365642062790a202020202f2f2f202020202020202020646576656c6f7065727320746f206b6e6f7720776869636820706172616d6574657220746f207061737320746f20746865207265736f6c7665566965772829206d6574686f642e0a202020202f2f2f0a2020202061636365737328616c6c2920766965772066756e20676574436f6e74726163745669657773287265736f75726365547970653a20547970653f293a205b547970655d207b0a202020202020202072657475726e205b0a202020202020202020202020547970653c4d6574616461746156696577732e4e4654436f6c6c656374696f6e446174613e28292c0a202020202020202020202020547970653c4d6574616461746156696577732e4e4654436f6c6c656374696f6e446973706c61793e28290a20202020202020205d0a202020207d0a0a202020202f2f2f2046756e6374696f6e2074686174207265736f6c7665732061206d65746164617461207669657720666f72207468697320636f6e74726163742e0a202020202f2f2f0a202020202f2f2f2040706172616d20766965773a205468652054797065206f6620746865206465736972656420766965772e0a202020202f2f2f204072657475726e20412073747275637475726520726570726573656e74696e67207468652072657175657374656420766965772e0a202020202f2f2f0a202020202f2f20544f444f3a20456e61626c652061737369676e6d656e742066726f6d20636f6e747261637455524928292076616c75652069662061636365737369626c6520696e2045524337323120636f6e74726163740a2020202061636365737328616c6c292066756e207265736f6c7665436f6e747261637456696577287265736f75726365547970653a20547970653f2c2076696577547970653a2054797065293a20416e795374727563743f207b0a2020202020202020737769746368207669657754797065207b0a2020202020202020202020206361736520547970653c4d6574616461746156696577732e4e4654436f6c6c656374696f6e446174613e28293a0a202020202020202020202020202020206c6574206964656e746966696572203d2022",
            "436f6c6c656374696f6e220a202020202020202020202020202020206c657420636f6c6c656374696f6e44617461203d204d6574616461746156696577732e4e4654436f6c6c656374696f6e44617461280a202020202020202020202020202020202020202073746f72616765506174683a2053746f7261676550617468286964656e7469666965723a206964656e74696669657229212c0a20202020202020202020202020202020202020207075626c6963506174683a205075626c696350617468286964656e7469666965723a206964656e74696669657229212c0a20202020202020202020202020202020202020207075626c6963436f6c6c656374696f6e3a20547970653c26",
            "2e436f6c6c656374696f6e3e28292c0a20202020202020202020202020202020202020207075626c69634c696e6b6564547970653a20547970653c26",
            "2e436f6c6c656374696f6e3e28292c0a2020202020202020202020202020202020202020637265617465456d707479436f6c6c656374696f6e46756e6374696f6e3a202866756e28293a20407b4e6f6e46756e6769626c65546f6b656e2e436f6c6c656374696f6e7d207b0a20202020202020202020202020202020202020202020202072657475726e203c2d",
            "2e637265617465456d707479436f6c6c656374696f6e286e6674547970653a20547970653c40",
            "2e4e46543e2829290a20202020202020202020202020202020202020207d290a20202020202020202020202020202020290a2020202020202020202020202020202072657475726e20636f6c6c656374696f6e446174610a2020202020202020202020206361736520547970653c4d6574616461746156696577732e4e4654436f6c6c656374696f6e446973706c61793e28293a0a202020202020202020202020202020206c6574206d65646961203d204d6574616461746156696577732e4d65646961280a202020202020202020202020202020202020202066696c653a204d6574616461746156696577732e4854545046696c65280a20202020202020202020202020202020202020202020202075726c3a202268747470733a2f2f6173736574732e776562736974652d66696c65732e636f6d2f3566363239346330633761386364643634336231633832302f3566363239346330633761386364613535636231633933365f466c6f775f576f72646d61726b2e737667220a2020202020202020202020202020202020202020292c0a20202020202020202020202020202020202020206d65646961547970653a2022696d6167652f7376672b786d6c220a20202020202020202020202020202020290a2020202020202020202020202020202072657475726e204d6574616461746156696577732e4e4654436f6c6c656374696f6e446973706c6179280a20202020202020202020202020202020202020206e616d653a202254686520466c6f77564d2042726964676564204e465420436f6c6c656374696f6e222c0a20202020202020202020202020202020202020206465736372697074696f6e3a20225468697320636f6c6c656374696f6e2077617320627269646765642066726f6d20466c6f772045564d2e222c0a202020202020202020202020202020202020202065787465726e616c55524c3a204d6574616461746156696577732e45787465726e616c55524c282268747470733a2f2f6272696467652e666c6f772e636f6d2f6e667422292c0a2020202020202020202020202020202020202020737175617265496d6167653a206d656469612c0a202020202020202020202020202020202020202062616e6e6572496d6167653a206d656469612c0a2020202020202020202020202020202020202020736f6369616c733a207b7d0a20202020202020202020202020202020290a20202020202020207d0a202020202020202072657475726e206e696c0a202020207d0a0a202020202f2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a0a2020202020202020496e7465726e616c204d6574686f64730a202020202a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2f0a0a202020202f2f2f20416c6c6f7773207468652062726964676520746f200a20202020616363657373286163636f756e74290a2020202066756e206d696e744e46542869643a2055496e743235362c20746f6b656e5552493a20537472696e67293a20404e4654207b0a202020202020202072657475726e203c2d637265617465204e4654280a2020202020202020202020206e616d653a2073656c662e6e616d652c0a20202020202020202020202073796d626f6c3a2073656c662e73796d626f6c2c0a20202020202020202020202065766d49443a2069642c0a2020202020202020202020207572693a20746f6b656e5552492c0a2020202020202020202020206d657461646174613a207b0a20202020202020202020202020202020224272696467656420426c6f636b223a2067657443757272656e74426c6f636b28292e6865696768742c0a2020202020202020202020202020202022427269646765642054696d657374616d70223a2067657443757272656e74426c6f636b28292e74696d657374616d700a2020202020202020202020207d0a2020202020202020290a202020207d0a0a20202020696e6974286e616d653a20537472696e672c2073796d626f6c3a20537472696e672c2065766d436f6e7472616374416464726573733a2045564d2e45564d4164647265737329207b0a202020202020202073656c662e65766d4e4654436f6e747261637441646472657373203d2065766d436f6e7472616374416464726573730a202020202020202073656c662e666c6f774e4654436f6e747261637441646472657373203d2073656c662e6163636f756e742e616464726573730a202020202020202073656c662e6e616d65203d206e616d650a202020202020202073656c662e73796d626f6c203d2073796d626f6c0a202020202020202073656c662e636f6c6c656374696f6e203c2d2063726561746520436f6c6c656374696f6e28290a0a2020202020202020466c6f7745564d427269646765436f6e6669672e6173736f63696174655479706528547970653c40",
            "2e4e46543e28292c20776974683a2073656c662e65766d4e4654436f6e747261637441646472657373290a2020202020202020466c6f7745564d4272696467654e4654457363726f772e696e697469616c697a65457363726f77280a202020202020202020202020666f72547970653a20547970653c40",
            "2e4e46543e28292c0a202020202020202020202020657263373231416464726573733a2073656c662e65766d4e4654436f6e7472616374416464726573730a2020202020202020290a202020207d0a7d0a"
        ]
        self.templateCodeChunks["bridgedNFT"] = []
        for chunk in bridgedNFTHexChunks {
            self.templateCodeChunks["bridgedNFT"]!.append(chunk.decodeHex())
        }

        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}

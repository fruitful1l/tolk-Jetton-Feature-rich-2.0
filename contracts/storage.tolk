struct JettonWalletStorage {
    owner: address
    minter: address
    balance: coins
}

fun JettonWalletStorage.saveData(self){
    contract.setData(self.toCell())
}

fun JettonWalletStorage.loadData(){
    return JettonWalletStorage.fromCell(contract.getData())
}

struct JettonMinterStorage {
    totalSupply: coins
    mintable: bool
    adminAddress: address
    jettonContent: cell
    jettonWalletCode: cell
}

fun JettonMinterStorage.saveData(self){
    contract.setData(self.toCell())
}

fun JettonMinterStorage.loadData(){
    return JettonMinterStorage.fromCell(contract.getData())
}
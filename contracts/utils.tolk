import "storage";
fun checkEitherForwardPayload(forwardPayload: slice): int asm 
    "LDDICT" // Throws 9 if Either bit = 1 and ref is not present
    "SWAP"
    "ISNULL"
    "<{"
        "DROP"
    "}>" "PUSHCONT"
    "<{"
        "ENDS" // Also throws 9 if slice is not empty
    "}>" "PUSHCONT"
    "IFELSE"

fun address.isAddressOfJettonWallet(self, ownerAddress: address, minterAddress: address, jettonWalletCode: cell) {
    val jwDeployed = calcDeployedJettonWallet(ownerAddress, minterAddress, jettonWalletCode);  
    return jwDeployed.addressMatches(self)
}

fun calcDeployedJettonWallet(ownerAddress: address, minterAddress: address, jettonWalletCode: cell): AutoDeployAddress {
    val emptyWalletStorage: JettonWalletStorage = {
        balance: 0,
        owner: ownerAddress,
        minter: minterAddress,
    };

    return {
        stateInit: {
            code: jettonWalletCode,
            data: emptyWalletStorage.toCell()
        }
    }
}


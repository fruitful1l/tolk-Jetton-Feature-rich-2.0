import "utils"
import "wallet"
import "messages"
import "constants"

type AllowedMessageToMinter =
    | ProvideWalletAddress
    | JettonBurnNotification
    | Mint
    | JettonUpdateContent
    | ChangeOwner
    | CloseMinting
    | ClaimTON


fun onInternalMessage(in: InMessage) {
    val msg = lazy AllowedMessageToMinter.fromSlice(in.body);

    match (msg) {
        ProvideWalletAddress => {
            assert (in.valueCoins > in.originalForwardFee + MINIMAL_MESSAGE_VALUE_BOUND) throw 501;

            var respondOwnerAddress: Cell<address>? = msg.includeAddress
                ? msg.ownerAddress.toCell()
                : null;

            var walletAddrBuilt: builder;
            if (msg.ownerAddress.getWorkchain() == BASECHAIN) {
                var storage = lazy MinterStorage.load();
                walletAddrBuilt = buildAddressOfJettonWallet(msg.ownerAddress, contract.getAddress(), storage.jettonWalletCode);
            } else {
                walletAddrBuilt = beginCell().storeAddressNone();
            }
            // we could respond `builder` (and it would be much more effective),
            // but we want to leave the type as `address` in a "Response" struct
            // (for clarity and future TypeScript wrappers, which can't be auto-generated for "builder");
            // in TVM 12, there will be a cheap instruction to avoid an intermediate cell creation
            val walletAddress = address.fromValidBuilder(walletAddrBuilt);

            val respondMsg = createMessage({
                bounce: true,
                dest: in.senderAddress,
                value: 0,
                body: ResponseWalletAddress {
                    queryId: msg.queryId,
                    jettonWalletAddress: walletAddress,
                    ownerAddress: respondOwnerAddress,
                }
            });
            respondMsg.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }
        
    }
}

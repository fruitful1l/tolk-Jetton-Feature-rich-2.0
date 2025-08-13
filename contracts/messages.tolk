type ForwardPayloadRemainder = RemainingBitsAndRefs

struct JettonData {
    totalSupply: int
    mintable: bool
    owner: address
    content: cell
    jettonWalletCode: cell
}

struct JettonWalletData {
    balance: int
    owner: address
    minter: address
    code: cell
}

struct JettonUpdateContent {
    queryId: uint64
    content: cell
}

struct CustomPayloadWithSendModes {
    mode: uint32
    forwardStateInit: ContractState?
}

struct(0xf8a7ea5) JettonTransfer {
    queryId: uint64;
    amount: coins;
    destination: address
    responseDestination: address
    customPayload: cell? 
    forwardTonAmount: coins
    forwardPayload: ForwardPayloadRemainder;
}

struct(0x178d4519) JettonTransferInternalWithStateInit {
    queryId: uint64
    amount: coins
    sender: address
    responseDestination: address
    forwardTonAmount: coins
    forwardStateInit: ContractState?
    forwardPayload: ForwardPayloadRemainder
}

struct(0x7362d09c) JettonNotification {
    queryId: uint64
    amount: coins
    sender: address
    forwardPayload: ForwardPayloadRemainder
}

struct(0x595f07bc) JettonBurn {
    queryId: uint64
    amount: coins
    responseDestination: address?
    customPayload: cell?
}

struct(0x7bdd97de) JettonBurnNotification {
    queryId: uint64;
    amount: coins;
    sender: address;
    responseDestination: address?;
}

struct(0xd53276db) JettonExcesses {
    queryId: uint64;
}

struct(0x2c76b973) ProvideWalletAddress {
    queryId: uint64;
    ownerAddress: address;
    includeAddress: bool
}

struct(0xd1735400) TakeWalletAddress {
    queryId: uint64
    walletAddress: address
    ownerAddress: Cell<address>? //It is Maybe ^Address, just encoded it like this
}

struct(0x642b7d07) Mint {
    queryId: uint64
    receiver: address
    mintMessage: JettonTransferInternalWithStateInit
}

struct(0x0000022) CloseMinting {}

struct(0x0000003) ChangeOwner {
    queryId: uint64
    newOwner: address
}

// provide_wallet_balance#7ac8d559 receiver:MsgAddress include_verify_info:Bool = InternalMsgBody
struct(0x7ac8d559) ProvideWalletBalance {
    receiver: address
    includeVerifyInfo: bool
}

struct VerifyInfo {
    owner: address
    minter: address
    code: cell
}

// verify_info$_ owner:MsgAddress minter:MsgAddress code:^Cell = VerifyInfo
// take_wallet_balance#ca77fdc2 balance:Coins verify_info:(Maybe VerifyInfo) = InternalMsgBody
struct(0xca77fdc2) TakeWalletBalance {
    balance: coins
    verifyInfo: VerifyInfo?
}

// claim_ton#0393b1ce receiver:MsgAddress = InternalMsgBody
struct(0x0393b1ce) ClaimTON {
    receiver: address
}

// extended messages, encoded in customPayload

const SendAllJettonsMode= 0x1;
const SendNotDeployReceiversJettonWallet  = 0x2;
const SendStateInitWithJettonNotification= 0x4;


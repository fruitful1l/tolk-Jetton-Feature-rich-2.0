import "constants";
import "storage";
import "messages";
import "utils"


type AllowedMessageToWallet =
    | JettonTransfer
    | JettonTransferInternalWithStateInit
    | ProvideWalletBalance
    | JettonBurn
    | ClaimTON


fun onBouncedMessage(in: InMessageBounced) {
    in.bouncedBody.skipBouncedPrefix();
    val msg = lazy BounceOpToHandle.fromSlice(in.bouncedBody);


    val restoreAmount = match (msg) {
        JettonTransferInternalWithStateInit => msg.jettonAmount,       // safe to fetch jettonAmount, because
        JettonBurnNotification => msg.jettonAmount,  // it's in the beginning of a message
    };

    var storage = lazy JettonWalletStorage.load();
    storage.jettonBalance += restoreAmount;
    storage.save();
}

fun onInternalMessage(in: InMessage) {
    val msg = lazy AllowedMessageToWallet.fromSlice(in.body);

    match(msg) {
        JettonTransfer => {
            
            var storage = lazy JettonWalletStorage.loadData();
            
            assert(msg.destination.getWorkchain() == BASECHAIN) throw 232;
            assert(in.senderAddress == storage.owner, 233);

            var forwardedMessagesCount = msg.forwardTonAmount ? 2 : 1;
            assert (in.valueCoins >
                msg.forwardTonAmount +
                // 3 messages: wal1->wal2,  wal2->owner, wal2->response
                // but last one is optional (it is ok if it fails)
                forwardedMessagesCount * in.originalForwardFee +
                (2 * gasForTransfer + minTonsForStorage)
            ) throw 234;

            match(msg.customPayload) {
                null => {
                    storage.balance -= msg.amount;
                    storage.saveData();
                    assert(storage.balance >= 0, 235);
                    checkEitherForwardPayload(msg.forwardPayload);
                
                    
                    val deployMsg = createMessage({
                        bounce: true,
                        dest: calcDeployedJettonWallet(msg.destination, storage.minter, contract.getCode()),
                        value: 0,
                        body: JettonTransferInternalWithStateInit {
                            queryId: msg.queryId,
                            amount: msg.amount,
                            sender: storage.owner,
                            responseDestination: msg.responseDestination,
                            forwardTonAmount: msg.forwardTonAmount,
                            forwardPayload: msg.forwardPayload,
                            forwardStateInit: null,
                        },
                    });
            

                    deployMsg.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
                },

                cell => {
                    val payload = CustomPayloadWithSendModes.fromCell(msg.customPayload);
                    val extendedActionMode = payload.mode;

                    var sendAmount = msg.amount;

                    if ((extendedActionMode & SendAllJettonsMode) != 0) {
                        sendAmount = storage.balance;
                    }

                    var forwardStateInit: ContractState? = null;

                    if ((extendedActionMode & SendStateInitWithJettonNotification) != 0) {
                        // internal transfer body creation could fail because of
                        // ref overflow (forwardPayload as inline), but that's okay since
                        // it will just reject
                       
                        assert(payload.forwardStateInit != null, 236);
                        forwardStateInit = payload.forwardStateInit!;
                        
                    }

                    storage.balance -= sendAmount;
                    storage.saveData();

                    if ((extendedActionMode & SendNotDeployReceiversJettonWallet) != 0) {
                    // this will bounce if the wallet wasn't already deployed, but it's okay and we handle it
                        val deployMsg = createMessage({
                        bounce: true,
                        dest: calcDeployedJettonWallet(msg.destination, storage.minter, contract.getCode()),
                        value: 0,
                        body: JettonTransferInternalWithStateInit {
                            queryId: msg.queryId,
                            amount: sendAmount,
                            sender: storage.owner,
                            responseDestination: msg.responseDestination,
                            forwardTonAmount: msg.forwardTonAmount,
                            forwardPayload: msg.forwardPayload,
                            forwardStateInit: forwardStateInit,
                        },
                        });
            

                        deployMsg.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
                    
                        return;
                    }

                    val deployMsg = createMessage({
                        bounce: true,
                        dest: calcDeployedJettonWallet(msg.destination, storage.minter, contract.getCode()),
                        value: 0,
                        body: JettonTransferInternalWithStateInit {
                            queryId: msg.queryId,
                            amount: msg.amount,
                            sender: storage.owner,
                            responseDestination: msg.responseDestination,
                            forwardTonAmount: msg.forwardTonAmount,
                            forwardPayload: msg.forwardPayload,
                            forwardStateInit: null,
                        },
                    });
            

                    deployMsg.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
                }
            }
        }
        JettonTransferInternalWithStateInit => {
            var storage = lazy JettonWalletStorage.loadData();
            if (in.senderAddress != storage.minter) {
                assert (in.senderAddress.isAddressOfJettonWallet(msg.sender, storage.minter, contract.getCode())) throw 237;
            }

            storage.balance += msg.amount;
            storage.saveData();

           
            var msgValue = in.valueCoins;
            var tonBalanceBeforeMsg = contract.getOriginalBalance() - msgValue;
            var storageFee = minTonsForStorage - min(tonBalanceBeforeMsg, minTonsForStorage);
            msgValue -= (storageFee + gasForTransfer);


            if(msg.forwardTonAmount) {
                msgValue -= (msg.forwardTonAmount + in.originalForwardFee);
                

                match(msg.forwardStateInit) {
                    ContractState => {
                        val autoAddress: AutoDeployAddress = {
                            stateInit: msg.forwardStateInit
                        };

                        var deployBuilder = autoAddress.buildAddress();
                        val deployAddress = address.fromValidBuilder(deployBuilder);
                        assert(deployAddress == storage.owner, 334);

                        val deployMsg = createMessage({
                            bounce: false,
                            dest: deployAddress,
                            value: msg.forwardTonAmount,
                            body: JettonNotification {
                                queryId: msg.queryId,
                                amount: msg.amount,
                                sender: msg.sender,
                                forwardPayload: msg.forwardPayload,
                            },
                        });
                        deployMsg.send(SEND_MODE_REGULAR);
                    },

                    null => {
                        val deployMsg = createMessage({
                            bounce: false,
                            dest: storage.owner,
                            value: msg.forwardTonAmount,
                            body: JettonNotification {
                                queryId: msg.queryId,
                                amount: msg.amount,
                                sender: msg.sender,
                                forwardPayload: msg.forwardPayload,
                            },
                        });
                        deployMsg.send(SEND_MODE_REGULAR);
                    }
                }

            
                reserveToncoinsOnBalance(max(tonBalanceBeforeMsg, minTonsForStorage), 2);

                if ((msg.responseDestination.isInternal()) & (msgValue > 0)) {
                    val cashbackMsg = createMessage({
                        bounce: false,
                        dest: msg.responseDestination,
                        value: msgValue,
                        body: JettonExcesses { queryId: msg.queryId},

                    });
                    cashbackMsg.send(SEND_MODE_CARRY_ALL_BALANCE | SEND_MODE_IGNORE_ERRORS)
                }
            }
        }
        ProvideWalletBalance => {
            val storage = lazy JettonWalletStorage.loadData();
            var info: VerifyInfo? = null;
            if(msg.includeVerifyInfo) {
                info = VerifyInfo {
                    minter: storage.minter,
                    owner: storage.owner,
                    code: contract.getCode(),
                }
            }

            val provideWallet = createMessage({
                bounce: true,
                dest: msg.receiver,
                value: 0,
                body: TakeWalletBalance {
                    balance: storage.balance,
                    verifyInfo: info
                },
            });
            provideWallet.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);  
        }
        JettonBurn => {
            var storage = lazy JettonWalletStorage.loadData();
            assert (in.senderAddress == storage.owner) throw 309;
            assert (storage.balance >= msg.amount) throw 400;
            storage.balance -= msg.amount;
            storage.saveData();

            val notifyMinterMsg = createMessage({
                bounce: true,
                dest: storage.minter,
                value: 0,
                body: JettonBurnNotification {
                    queryId: msg.queryId,
                    amount: msg.amount,
                    sender: storage.owner,
                    responseDestination: msg.responseDestination,
                }
            });
            notifyMinterMsg.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE | SEND_MODE_BOUNCE_ON_ACTION_FAIL);
        }
        ClaimTON => {
            var storage = lazy JettonWalletStorage.loadData();
            reserveToncoinsOnBalance(minTonsForStorage, RESERVE_MODE_EXACT_AMOUNT | RESERVE_MODE_BOUNCE_ON_ACTION_FAIL);

            val claimMsg = createMessage({
                bounce: true,
                dest: msg.receiver,
                value: 0,
            });

            claimMsg.send(SEND_MODE_CARRY_ALL_BALANCE);
        }

        else => {
            assert(in.body.isEmpty()) throw 0xFFFF
        },
    }

}
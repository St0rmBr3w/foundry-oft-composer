// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { IOFT } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

contract SendOFT is Script {
    using OptionsBuilder for bytes;
    
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /**
     * @notice Send OFT tokens to another chain
     * @param oftAddress The address of the OFT contract
     * @param dstEid The destination endpoint ID
     * @param to The recipient address (bytes32 format)
     * @param amountLD The amount to send in smallest unit (wei)
     * @param minAmountLD The minimum amount to receive in smallest unit (wei)
     * @param extraOptions Additional message options (can be empty)
     * @param composeMsg Compose message for the send operation (can be empty)
     * @param oftCmd OFT command for the send operation (can be empty)
     */
    function send(
        address oftAddress,
        uint32 dstEid,
        bytes32 to,
        uint256 amountLD,
        uint256 minAmountLD,
        bytes calldata extraOptions,
        bytes calldata composeMsg,
        bytes calldata oftCmd
    ) external {
        // Get the private key and derive the signer address
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(privateKey);
        
        console.log("Signer address:", signer);
        
        // Start broadcasting transactions with the private key
        vm.startBroadcast(privateKey);

        IOFT oft = IOFT(oftAddress);

        // Prepare send parameters
        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: to,
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: oftCmd
        });

        // Quote the send operation to get fees
        MessagingFee memory fee = oft.quoteSend(sendParam, false);

        console.log("Sending OFT tokens:");
        console.log("  From chain:", block.chainid);
        console.log("  To chain EID:", dstEid);
        console.log("  Amount:", amountLD);
        console.log("  Native fee:", fee.nativeFee);
        console.log("  LZ token fee:", fee.lzTokenFee);

        // Execute the send with the signer as refund address
        (MessagingReceipt memory receipt, ) = oft.send{value: fee.nativeFee}(sendParam, fee, signer);

        console.log("OFT tokens sent successfully!");
        console.log("  Message GUID:");
        console.logBytes32(receipt.guid);
        console.log("  Nonce:", receipt.nonce);

        vm.stopBroadcast();
    }
} 
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/console.sol";

/// @title Console Utilities
/// @notice Helper functions for cleaner console output
library ConsoleUtils {
    
    /// @notice Format an address to short form (0x1234...5678)
    function shortAddress(address addr) internal pure returns (string memory) {
        return string.concat(
            "0x",
            toHexString(uint160(addr), 40)
        );
    }
    
    /// @notice Format an address to short form (0x1234...5678)
    function shortAddressFormat(address addr) internal pure returns (string memory) {
        string memory full = toHexString(uint160(addr), 40);
        return string.concat(
            "0x",
            substring(full, 0, 4),
            "...",
            substring(full, 36, 40)
        );
    }
    
    /// @notice Print a header section
    function printHeader(string memory title) internal pure {
        console.log("");
        console.log("================================================================================");
        console.log(title);
        console.log("================================================================================");
    }
    
    /// @notice Print a sub-header
    function printSubHeader(string memory title) internal pure {
        console.log("");
        console.log(string.concat(">>> ", title));
        console.log("--------------------------------------------------------------------------------");
    }
    
    /// @notice Print a success message with checkmark
    function printSuccess(string memory message) internal pure {
        console.log(string.concat("  [OK] ", message));
    }
    
    /// @notice Print a skip message
    function printSkip(string memory message) internal pure {
        console.log(string.concat("  [--] ", message));
    }
    
    /// @notice Print an action message
    function printAction(string memory message) internal pure {
        console.log(string.concat("  [>>] ", message));
    }
    
    /// @notice Print a warning message
    function printWarning(string memory message) internal pure {
        console.log(string.concat("  [!!] WARNING: ", message));
    }
    
    /// @notice Print an error message
    function printError(string memory message) internal pure {
        console.log(string.concat("  [XX] ERROR: ", message));
    }
    
    /// @notice Print a key-value pair
    function printKV(string memory key, string memory value) internal pure {
        console.log(string.concat("  ", key, ": ", value));
    }
    
    /// @notice Print a pathway summary
    function printPathway(uint32 srcEid, uint32 dstEid, address srcOApp, address dstOApp) internal pure {
        console.log("");
        console.log(string.concat("  ", chainName(srcEid), " (", vm.toString(srcEid), ") --> ", chainName(dstEid), " (", vm.toString(dstEid), ")"));
        console.log(string.concat("  Source OApp: ", shortAddressFormat(srcOApp)));
        console.log(string.concat("  Dest OApp:   ", shortAddressFormat(dstOApp)));
    }
    
    /// @notice Get chain name from EID (simplified mapping)
    function chainName(uint32 eid) internal pure returns (string memory) {
        if (eid == 30101) return "Ethereum";
        if (eid == 30102) return "BSC";
        if (eid == 30106) return "Avalanche";
        if (eid == 30109) return "Polygon";
        if (eid == 30110) return "Arbitrum";
        if (eid == 30111) return "Optimism";
        if (eid == 30184) return "Base";
        return string.concat("Chain-", vm.toString(eid));
    }
    
    /// @notice Convert to hex string
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length);
        for (uint256 i = 2 * length; i > 0; ) {
            unchecked {
                i--;
                buffer[i] = bytes1(uint8(value & 0xf) + (uint8(value & 0xf) < 10 ? 48 : 87));
                value >>= 4;
            }
        }
        return string(buffer);
    }
    
    /// @notice Extract substring
    function substring(string memory str, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = strBytes[i];
        }
        return string(result);
    }
    
    /// @notice Print configuration summary
    function printConfigSummary(
        uint256 totalPathways,
        uint256 alreadyConfigured,
        uint256 toBeConfigured
    ) internal pure {
        console.log("");
        console.log("Configuration Summary:");
        console.log(string.concat("  Total pathways:      ", vm.toString(totalPathways)));
        console.log(string.concat("  Already configured:  ", vm.toString(alreadyConfigured)));
        console.log(string.concat("  To be configured:    ", vm.toString(toBeConfigured)));
        console.log("");
    }
    
    /// @notice Print a progress indicator
    function printProgress(uint256 current, uint256 total, string memory action) internal pure {
        console.log("");
        console.log(string.concat("[", vm.toString(current), "/", vm.toString(total), "] ", action));
    }
} 
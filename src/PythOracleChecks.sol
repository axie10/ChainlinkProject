// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {IPyth, PythStructs} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

contract PythOracle {
    IPyth public pyth;
    bytes32 public priceId;
    uint256 public constant MAX_AGE_SECONDS = 3600; // 1 hour
    int32 public constant MIN_ACCEPTABLE_EXPO = -18;
    uint256 public constant MIN_CONFIDENCE_RATIO = 10000; // basis points (e.g. 10_000 = 100x)

    /**
     * @param _pythContract The address of the Pyth contract on your network
     * @param _priceId The Pyth price feed ID (bytes32), e.g., for ETH/USD
     */
    constructor(address _pythContract, bytes32 _priceId) {
        pyth = IPyth(_pythContract);
        priceId = _priceId;
    }

    /**
     * Returns the latest price (with update logic handled externally)
     */
    function getLatestPrice(bytes[] calldata updateData) public payable returns (int64 price, uint64 conf, int32 expo) {
        updatePrice(updateData); // @audit Update Pyth's data
        PythStructs.Price memory priceData = pyth.getPriceNoOlderThan(priceId, MAX_AGE_SECONDS); // @audit Safe method to get not staled prices
        _validatePrice(priceData.price, priceData.conf, priceData.expo);
        return (priceData.price, priceData.conf, priceData.expo);
    }

    /**
     * Submits a price update (must provide valid updateData from off-chain)
     */
    function updatePrice(bytes[] calldata updateData) public payable {
        uint fee = pyth.getUpdateFee(updateData);
        require(msg.value >= fee, "Insufficient fee sent");
        pyth.updatePriceFeeds{value: fee}(updateData);
    }

    /// Implements Pyth’s “best practices” checks
    function _validatePrice(int64 price, uint64 confidence, int32 expo) internal pure {
        require(price > 0, "Oracle: invalid price"); // @audit Price must be positive

        require(expo >= MIN_ACCEPTABLE_EXPO, "Oracle: invalid expo"); // @audit Expo must be within acceptable range (not lower than -18)
        // 3. Confidence interval too wide or 0 (halted feed)
        require(
            confidence > 0 &&
            uint256(uint64(_abs(price))) * 1e4 / uint256(uint64(confidence)) > MIN_CONFIDENCE_RATIO,
            "Oracle: untrusted price"
        );
    }

    /// Helper to get absolute value of int64
    function _abs(int64 x) internal pure returns (int64) {
        return x >= 0 ? x : -x;
    }

    receive() external payable {}
}

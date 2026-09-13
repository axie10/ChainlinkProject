// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import {IPyth, PythStructs} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

contract PythOracle {
    IPyth public pyth;
    bytes32 public priceId;

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
    function getLatestPrice() public view returns (int64 price, uint64 conf, int32 expo) {
        PythStructs.Price memory priceData = pyth.getPriceUnsafe(priceId);
        return (priceData.price, priceData.conf, priceData.expo);
    }

    /**
     * Submits a price update (must provide valid updateData from off-chain)
     */
    function updatePrice(bytes[] calldata updateData) external payable {
        uint256 fee = pyth.getUpdateFee(updateData);
        require(msg.value >= fee, "Insufficient fee sent");
        pyth.updatePriceFeeds{value: fee}(updateData);
    }

    receive() external payable {}
}

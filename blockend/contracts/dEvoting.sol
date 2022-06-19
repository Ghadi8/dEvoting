// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title dEvoting platform
 * @author Ghadi Mhawej
 */

interface IdEvotingNFTContract {
    function balanceOf(address, uint256) external view returns (uint256);
}

contract dEvoting {
    address public owner;

    /// @notice valid token IDs that can interact with this contract
    uint256[] public validTokens;

    /// @notice NFT contract address of which holders can interact with this contract
    IdEvotingNFTContract dEvotingNFTContract;

    constructor(address _nftContract, uint256[] memory _tokenIDs) {
        owner = msg.sender;
        dEvotingNFTContract = IdEvotingNFTContract(_nftContract);
        validTokens = _tokenIDs;
    }
}

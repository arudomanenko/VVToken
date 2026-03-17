// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VotingResult is ERC721URIStorage, Ownable {
    uint256 public nextTokenId;
    address public votingContract;

    constructor() ERC721("VotingResult", "VR") Ownable(msg.sender) {}

    function setVotingContract(address _votingContract) external onlyOwner {
        require(votingContract == address(0), "Already set");
        votingContract = _votingContract;
    }

    function mintVotingResult(address to, string memory description) external {
        require(
            msg.sender == owner() || msg.sender == votingContract,
            "Not authorized to mint"
        );
        uint256 tokenId = nextTokenId;
        _mint(to, tokenId);
        _setTokenURI(tokenId, description);
        nextTokenId++;
    }

    function getVotingResult(
        uint256 tokenId
    ) public view returns (string memory) {
        return tokenURI(tokenId);
    }
}

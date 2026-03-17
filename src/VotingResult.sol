// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {
    ERC721URIStorage
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VotingResult is ERC721URIStorage, Ownable {
    uint256 public nextTokenId;

    mapping(address => bool) public authorizedMinters;

    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    constructor() ERC721("VotingResult", "VR") Ownable(msg.sender) {}

    function addMinter(address _votingContract) external onlyOwner {
        require(_votingContract != address(0), "Invalid address");
        authorizedMinters[_votingContract] = true;
        emit MinterAdded(_votingContract);
    }

    function removeMinter(address _votingContract) external onlyOwner {
        authorizedMinters[_votingContract] = false;
        emit MinterRemoved(_votingContract);
    }

    function mintVotingResult(address to, string memory description) external {
        require(
            msg.sender == owner() || authorizedMinters[msg.sender],
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

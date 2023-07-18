// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceToken is ERC20, Ownable {
    mapping(address => mapping (uint => bool)) voted;

    struct Proposal {
        string description;
        uint voteCount;
    }

    Proposal[] public proposals;

    constructor(uint256 initialSupply) ERC20("GovernanceToken", "GTK") {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function propose(string memory description) public {
        proposals.push(Proposal({
            description: description,
            voteCount: 0
        }));
    }

    function vote(uint proposalIndex) public {
        require(!voted[msg.sender][proposalIndex], "You have already voted on this proposal.");

        proposals[proposalIndex].voteCount += balanceOf(msg.sender);
        voted[msg.sender][proposalIndex] = true;
    }
}

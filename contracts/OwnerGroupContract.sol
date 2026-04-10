// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";

contract OwnerGroupContract is IOwnerGroupContract {

    uint private ownerCount = 0;
    mapping(address => bool) private owners;
    address[] private ownerList;
    mapping(address => uint256) private ownerIndex;

    // --- Multisig Proposal System ---
    struct Proposal {
        address target;
        bytes data;
        uint256 value;
        uint256 confirmCount;
        bool executed;
        uint256 createdAt;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    uint256 public constant PROPOSAL_EXPIRY = 7 days;

    event RegisterOwner(address indexed owner, address indexed addedBy);
    event UnRegisterOwner(address indexed owner, address indexed removedBy);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, address target, uint256 value, bytes data);
    event ProposalConfirmed(uint256 indexed proposalId, address indexed confirmer, uint256 confirmCount, uint256 required);
    event ProposalExecuted(uint256 indexed proposalId, address indexed executor);
    event ProposalRevoked(uint256 indexed proposalId, address indexed revoker);

    constructor(address[] memory initialOwners) {
        for (uint256 i = 0; i < initialOwners.length; i++) {
            require(initialOwners[i] != address(0), "Invalid owner");
            require(!owners[initialOwners[i]], "Duplicate owner");
            owners[initialOwners[i]] = true;
            ownerIndex[initialOwners[i]] = ownerList.length;
            ownerList.push(initialOwners[i]);
            ownerCount++;
        }
    }

    modifier onlyOwner() {
        require(owners[msg.sender], "Not owner");
        _;
    }

    // --- Owner Management ---

    function getOwnerCount() external view returns (uint) {
        return ownerCount;
    }

    function isOwner(address ownerAddress) external view returns (bool) {
        return owners[ownerAddress];
    }

    function getOwners() external view returns (address[] memory) {
        return ownerList;
    }

    function registerOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address");
        require(!owners[newOwner], "Already registered");

        owners[newOwner] = true;
        ownerIndex[newOwner] = ownerList.length;
        ownerList.push(newOwner);
        ownerCount++;

        emit RegisterOwner(newOwner, msg.sender);
    }

    function unRegisterOwner(address targetOwner) public onlyOwner {
        require(owners[targetOwner], "Not an owner");
        require(targetOwner != msg.sender, "Cannot remove self");
        require(ownerCount > 1, "Cannot remove last owner");

        owners[targetOwner] = false;
        ownerCount--;

        uint256 idx = ownerIndex[targetOwner];
        uint256 lastIdx = ownerList.length - 1;
        if (idx != lastIdx) {
            address lastOwner = ownerList[lastIdx];
            ownerList[idx] = lastOwner;
            ownerIndex[lastOwner] = idx;
        }
        ownerList.pop();
        delete ownerIndex[targetOwner];

        emit UnRegisterOwner(targetOwner, msg.sender);
    }

    // --- Multisig Proposal System ---

    /// @notice Returns the number of confirmations required
    /// @dev If ownerCount < 3, only 1 confirmation needed. Otherwise, majority (> 50%).
    function requiredConfirmations() public view returns (uint256) {
        if (ownerCount < 3) return 1;
        return (ownerCount / 2) + 1;
    }

    /// @notice Submit a proposal to call a target contract
    /// @param target The contract to call
    /// @param data The calldata (e.g., abi.encodeWithSignature("emergencyWithdrawETH(uint256)", amount))
    /// @param value ETH value to send with the call
    function submitProposal(address target, bytes calldata data, uint256 value) external onlyOwner returns (uint256) {
        require(target != address(0), "Invalid target");

        uint256 id = proposalCount++;
        proposals[id] = Proposal({
            target: target,
            data: data,
            value: value,
            confirmCount: 1,
            executed: false,
            createdAt: block.timestamp
        });
        confirmations[id][msg.sender] = true;

        emit ProposalCreated(id, msg.sender, target, value, data);
        emit ProposalConfirmed(id, msg.sender, 1, requiredConfirmations());

        // Auto-execute if only 1 confirmation needed
        if (requiredConfirmations() <= 1) {
            _executeProposal(id);
        }

        return id;
    }

    /// @notice Confirm an existing proposal
    function confirmProposal(uint256 proposalId) external onlyOwner {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(p.target != address(0), "Proposal does not exist");
        require(block.timestamp <= p.createdAt + PROPOSAL_EXPIRY, "Proposal expired");
        require(!confirmations[proposalId][msg.sender], "Already confirmed");

        confirmations[proposalId][msg.sender] = true;
        p.confirmCount++;

        emit ProposalConfirmed(proposalId, msg.sender, p.confirmCount, requiredConfirmations());

        // Auto-execute when threshold reached
        if (p.confirmCount >= requiredConfirmations()) {
            _executeProposal(proposalId);
        }
    }

    /// @notice Revoke your confirmation from a pending proposal
    function revokeConfirmation(uint256 proposalId) external onlyOwner {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(confirmations[proposalId][msg.sender], "Not confirmed");

        confirmations[proposalId][msg.sender] = false;
        p.confirmCount--;

        emit ProposalRevoked(proposalId, msg.sender);
    }

    function _executeProposal(uint256 proposalId) internal {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(p.confirmCount >= requiredConfirmations(), "Not enough confirmations");

        p.executed = true;
        (bool success, ) = p.target.call{value: p.value}(p.data);
        require(success, "Proposal execution failed");

        emit ProposalExecuted(proposalId, msg.sender);
    }

    /// @notice View proposal details
    function getProposal(uint256 proposalId) external view returns (
        address target, bytes memory data, uint256 value,
        uint256 confirmCount, bool executed, uint256 createdAt
    ) {
        Proposal storage p = proposals[proposalId];
        return (p.target, p.data, p.value, p.confirmCount, p.executed, p.createdAt);
    }

    /// @notice Check if a specific owner has confirmed a proposal
    function hasConfirmed(uint256 proposalId, address owner) external view returns (bool) {
        return confirmations[proposalId][owner];
    }

    /// @notice Get pending (non-executed, non-expired) proposals
    function getPendingProposals() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < proposalCount; i++) {
            if (!proposals[i].executed && block.timestamp <= proposals[i].createdAt + PROPOSAL_EXPIRY) {
                count++;
            }
        }
        uint256[] memory pending = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < proposalCount; i++) {
            if (!proposals[i].executed && block.timestamp <= proposals[i].createdAt + PROPOSAL_EXPIRY) {
                pending[idx++] = i;
            }
        }
        return pending;
    }

    receive() external payable {}
}

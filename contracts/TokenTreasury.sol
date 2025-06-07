// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC404} from "./libs/ERC404/interfaces/IERC404.sol";

contract TokenTreasury {
    address public admin;
    mapping(address => IERC404) public daoTokens;

    uint public proposalCount;

    struct Proposal {
        uint id;
        address proposer;
        string description;
        uint amount;             // 이더 또는 ERC-20 토큰 출금량
        address payable recipient;
        uint deadline;           // 투표 마감 시간
        uint yesVotes;
        uint noVotes;
        bool executed;
        mapping(address => bool) voters;
    }

    mapping(uint => Proposal) public proposals;

    event ProposalCreated(uint id, address proposer, string description, uint amount, address recipient, uint deadline);
    event Voted(uint proposalId, address voter, bool support);
    event Executed(uint proposalId);
    event RegisterDAOToken(address tokenAddress);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor(address owner) {
        admin = owner;        
    }

    function registerDAOToken(address tokenAddress) public onlyAdmin {
        
        daoTokens[tokenAddress] = IERC404(tokenAddress);        
        
        emit RegisterDAOToken(tokenAddress);
    }

    // 이더 입금 (payable)
    receive() external payable {}

    // 제안 생성
    function createProposal(address tokenAddress, string memory _desc, uint _amount, address payable _recipient, uint _votingPeriod) external returns (uint) {
        require(daoTokens[tokenAddress].balanceOf(msg.sender) > 0, "Need DAO tokens to propose");

        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.id = proposalCount;
        p.proposer = msg.sender;
        p.description = _desc;
        p.amount = _amount;
        p.recipient = _recipient;
        p.deadline = block.timestamp + _votingPeriod;

        emit ProposalCreated(p.id, msg.sender, _desc, _amount, _recipient, p.deadline);
        return p.id;
    }

    // 투표 (찬성 or 반대)
    function vote(address tokenAddress, uint _proposalId, bool support) external {
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp < p.deadline, "Voting ended");
        require(checkVotingQualification(tokenAddress), ">= 1% Need DAO tokens to vote");
        require(!p.voters[msg.sender], "Already voted");

        p.voters[msg.sender] = true;

        uint voterWeight = daoTokens[tokenAddress].balanceOf(msg.sender);
        if (support) {
            p.yesVotes += voterWeight;
        } else {
            p.noVotes += voterWeight;
        }

        emit Voted(_proposalId, msg.sender, support);
    }

    function checkVotingQualification(address tokenAddress) internal view returns (bool) {
        // 최소 투표할 수 있는 404 토큰 보유량 설정
        // balance × 100 >= total 1% 이상 토큰 홀더
        return daoTokens[tokenAddress].balanceOf(msg.sender) * 100 > daoTokens[tokenAddress].totalSupply();
    }

    // need to implement 
    // add onlyOnwer
    // 제안 실행 샘플 코드
    function executeProposal(uint _proposalId) external {
        Proposal storage p = proposals[_proposalId];

        require(block.timestamp >= p.deadline, "Voting not ended");
        require(!p.executed, "Already executed");
        require(p.yesVotes > p.noVotes, "Proposal not passed");
        require(address(this).balance >= p.amount, "Insufficient funds");

        p.executed = true;

        // 이더 출금
        p.recipient.transfer(p.amount);

        emit Executed(_proposalId);
    }

    // Treasury 잔액 조회
    function getBalance() external view returns (uint) {
        return address(this).balance;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract CrowdFund{

    event CampaignLaunch(uint indexed id, address indexed owner);
    event CampaignDeleted();
    event Pledge(uint id, address caller, uint amount);
    event UnPledge();
    event RefundClaimed(address claimer, uint amount);

    // enum CampaignStatus {
    //     STARTED,
    //     ENDED
    // }

    struct Campaign{
        uint id;
        string name;
        address creator;
        uint goal;
        uint startTime;
        uint endTime;
        uint pledged;
        bool claimed;
    }

    IERC20 public immutable token;

    uint public count;

    Campaign[] public campaigns;
    mapping (address => bool) public campaignByUser;
    mapping (address => mapping (uint => uint)) public pledgedByUser;

    constructor(address _token){
        token = IERC20(_token);
    }

    function launch(string memory _name, uint _goal, uint _startTime, uint _endTime) external {
        require(!campaignByUser[msg.sender], "Already one campaign is running");
        require(_startTime > block.timestamp && _endTime > _startTime);
        campaigns.push(Campaign({
            id: count,
            name: _name,
            creator: msg.sender,
            goal: _goal,
            startTime: _startTime,
            endTime: _endTime,
            pledged: 0,
            claimed: false
        }));
        campaignByUser[msg.sender] = true;
        emit CampaignLaunch(count, msg.sender);
        count++;
    }

    function cancel(uint id) external {
        // require(campaigns[id] && campaignByUser, "Don't have any campaign");
        Campaign memory camp = campaigns[id];
        require(msg.sender == camp.creator, "Not Owner");
        require(block.timestamp < camp.startTime, "Campaign Started");
        delete campaigns[id];
        emit CampaignDeleted();
    }

    function pledge(uint id, uint amount) external {
        Campaign storage camp = campaigns[id];
        require(block.timestamp > camp.startTime, "Campaign Not Started");
        camp.pledged = amount;
        pledgedByUser[msg.sender][id] += amount;
        token.transferFrom(msg.sender, address(this), amount);
        emit Pledge(id, msg.sender, amount);
    }

    function unpledge(uint id, uint amount) external {
        Campaign storage camp = campaigns[id];
        require(block.timestamp > camp.startTime, "Campaign Not Started");
        require(block.timestamp <= camp.endTime, "Campaign Ended");
        camp.pledged -= amount;
        pledgedByUser[msg.sender][id] -= amount;
        (bool success,) = payable(msg.sender).call{value:amount}("");
        require(success,"Transafer fail");
        emit UnPledge();
    }

    function claim(uint id) external {
        Campaign memory camp = campaigns[id];
        require(camp.pledged >= camp.goal, "Goal Is Not FullFilled");
        require(msg.sender == camp.creator, "Not Owner");
        (bool success,) = msg.sender.call{value:camp.pledged}("");
        require(success, "Transfer fail");
        camp.claimed = true;
    }

    function refund(uint id) external {
        Campaign storage camp = campaigns[id];
        require(camp.pledged <= camp.goal, "Goal Is FullFilled");
        require(block.timestamp <= camp.endTime, "Campaign Not Ended");
        require(pledgedByUser[msg.sender][id] > 0, "Token claimed");

        uint amount = pledgedByUser[msg.sender][id];
        camp.pledged -= amount;
        pledgedByUser[msg.sender][id] -= amount;
        (bool success,) = payable(msg.sender).call{value:amount}("");
        require(success,"Transafer fail");
        emit RefundClaimed(msg.sender, amount);
    }
}
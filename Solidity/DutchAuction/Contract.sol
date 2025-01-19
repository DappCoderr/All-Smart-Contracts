// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import {IERC721} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import {Pausable} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Pausable.sol";

contract DutchAuction is Pausable{

    error DutchAuction__InsufficientBalance();
    error DutchAuction__AuctionExpire();

    event NFTBrought(address indexed sender, uint indexed price, uint indexed nftId);

    uint private constant DURATION = 7 days;

    IERC721 public immutable nft;
    uint public immutable nftID;

    address payable public immutable seller;
    uint public immutable startingPrice;
    uint public immutable startAt;
    uint public immutable endAt;
    uint public immutable discountRate;
    
    constructor(address _nft, uint _nftId, uint _startingPrice, uint _discountRate){
        seller = payable(msg.sender);
        startingPrice = _startingPrice;
        discountRate = _discountRate;
        startAt = block.timestamp;
        endAt = startAt + DURATION;
        require(_startingPrice >= _discountRate * DURATION, "Starting Price is less then duration");
        nft = IERC721(_nft);
        nftID = _nftId;
    }

    function pauseContract() public {
        _pause();
    }

    function getPrice() public view returns(uint){
        uint timeElapsed = block.timestamp - startAt;
        uint discount = discountRate * timeElapsed;
        return startingPrice - discount;
    }

    function butNFT() external payable whenNotPaused {
        if(block.timestamp < endAt){
            revert DutchAuction__AuctionExpire();
        }
        uint price = getPrice();
        if(msg.value >= price){
            revert DutchAuction__InsufficientBalance();
        }
        nft.transferFrom(seller, msg.sender, nftID);
        uint refund = msg.value - price;
        emit NFTBrought(msg.sender, price, nftID);
        if(refund > 0){
            (bool success,) = msg.sender.call{value: refund}("");
            require(success, "Transfer fail");
        }
    }
}
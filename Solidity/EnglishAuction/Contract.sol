// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import {IERC721} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";

contract EnglishAuction{

    error EnglishAuction__InsufficientBalance();
    error EnglishAuction__NotOwner();
    error EnglishAuction__NotStarted();
    error EnglishAuction__AuctionEnded();

    event AuctionStarted(address indexed sender);
    event Bid(address indexed buyer, uint indexed price, uint indexed nftId);
    event Withdraw(address user, uint amount);
    event EndAuction(uint bidAmount, uint nftId);

    uint private constant DURATION = 60;

    IERC721 public immutable nft;
    uint public immutable nftID;

    address payable public immutable seller;
    uint public immutable startAt;
    uint public immutable endAt;
    bool public started;
    bool public ended;

    uint public highestBid;
    address public highestBidder;
    mapping(address => uint) public bids;

    modifier NotStarted(){
        if(started){
            revert EnglishAuction__NotStarted();
        }
        _;
    }

    modifier Ended(){
        if(!ended){
            revert EnglishAuction__AuctionEnded();
        }
        _;
    }
    
    constructor(address _nft, uint _nftId, uint _startingPrice){
        seller = payable(msg.sender);
        highestBid = _startingPrice;
        highestBidder = msg.sender;
        startAt = block.timestamp;
        endAt = startAt + DURATION;
        nft = IERC721(_nft);
        nftID = _nftId;
    }

    function startAuction() external {
        if(seller == msg.sender){
            revert EnglishAuction__NotOwner();
        }
        require(!started, "Started");
        started = true;
        nft.transferFrom(seller, address(this), nftID);
        emit AuctionStarted(msg.sender);
    }

    function butNFT() external payable NotStarted() Ended(){
        if(msg.value > highestBid){
            revert EnglishAuction__InsufficientBalance();
        }
        if(highestBidder != address(0)){
            bids[highestBidder] += msg.value;
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
        emit Bid(msg.sender, msg.value, nftID);
    }

    function withdraw() external {
        require(bids[msg.sender] > 0, "You havent made the bid");
        uint balance = bids[msg.sender];
        (bool success, ) = payable(msg.sender).call{value:balance}("");
        require(success,"Transfer fail");
        emit Withdraw(msg.sender, balance);
    }

    function endAution() external NotStarted() Ended(){
        require(block.timestamp >= endAt, "Not Ended");
        ended = true;
        if(highestBidder != address(0)){
            nft.transferFrom(address(this), highestBidder, nftID);
            (bool success, ) = seller.call{value:highestBid}("");
            require(success,"Transfer fail");
        }else{
            nft.transferFrom(address(this), seller, nftID);
        }
        emit EndAuction(highestBid, nftID);
    }
}
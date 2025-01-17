// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

contract MultiSignWallet {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txId);
    event Approve(address indexed owner, uint txId);
    event Execute(uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);

    //holds the owner of this wallet
    address[] public owners;

    //Check the owner is in the mapping or not
    mapping(address owner => bool ) public isOwner;

    //Require set the number of owner is required to approve the transactions
    uint required;

    //struct to transtion that will be send
    struct Transaction{
        address to;
        uint value;
        bytes32 data;
        bool executed;
    }

    modifier onlyOwner(){
        require(isOwner[msg.sender], "Not the owner");
        _;
    }

    modifier txnExists(uint txId){
        require(txId < transactions.length, "tx does not exit");
        _;
    }

    modifier notExecuted(uint txId){
        require(!transactions[txId].executed, "tx already executed");
        _;
    }

    modifier notApproved(uint txId){
        require(!approve[txId][msg.sender], "tx already approved");
        _;
    }

    //hold all the transaction struct info
    Transaction[] public transactions;

    //matain the list of approvers of the transation
    mapping (uint => mapping(address => bool)) public approve;


    constructor(address[] memory _owners, uint _requred){
        require(_owners.length > 0, "require owners");
        require(_requred > 0 && _requred > _owners.length, "invalid require number");
        for(uint i=0; i<_owners.length; i++){
            address owner = _owners[i];
            require(owner != address(0), "Not a valid address");
            require(!isOwner[owner],"Not a unique owner");
            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _requred;
    }

    receive() external payable { 
        emit Deposit(msg.sender, msg.value);
    }

    function submit(address _to, uint _value, bytes32 _data) external onlyOwner() {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        }));
        emit Submit(transactions.length - 1);
    }

    function approves(uint txId) external onlyOwner() notApproved(txId) notExecuted(txId) txnExists(txId) {
        approve[txId][msg.sender] = true;
        emit Approve(msg.sender, txId);
    }

    function getApprovalCount(uint txId) private view returns (uint count){
        for(uint i=0; i<owners.length; i++){
            if(approve[txId][owners[i]]){
                count += 1;
            }
        }
    }

    function execute(uint txId) external notExecuted(txId) txnExists(txId) {
        Transaction storage transaction = transactions[txId];
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx fail");
        emit Execute(txId);
    }

    function revoke(uint txId) external onlyOwner() notExecuted(txId) txnExists(txId){
        approve[txId][msg.sender] = false;
    }

}
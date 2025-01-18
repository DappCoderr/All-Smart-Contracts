// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

contract MultiSignWallet {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txId);
    event Approve(address indexed owner, uint txId);
    event ExecuteTransaction(address indexed sender, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);

    error MultiSignWallet__NotTheOwner();
    error MultiSignWallet__TransactionExists();
    error MultiSignWallet__TransactionAlreadyApproved();
    error MultiSignWallet__TransactionAlreadyExecuted();
    error MultiSignWallet__NoOwner();

    address[] public owners;

    mapping(address => bool ) public isOwner;

    uint required;

    struct Transaction{
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    modifier onlyOwner(){
        if(!isOwner[msg.sender]){
            revert MultiSignWallet__NotTheOwner();
        }
        _;
    }

    modifier txnExists(uint txId){
        if(txId < transactions.length){
            revert MultiSignWallet__TransactionExists();
        }
        _;
    }

    modifier notExecuted(uint txId){
        if(!transactions[txId].executed){
            revert MultiSignWallet__TransactionAlreadyExecuted();
        }
        _;
    }

    modifier notApproved(uint txId){
        if(!approve[txId][msg.sender]){
            revert MultiSignWallet__TransactionAlreadyApproved();
        }
        _;
    }

    Transaction[] public transactions;

    mapping (uint => mapping(address => bool)) public approve;

    constructor(address[] memory _owners, uint _requred){
        require(_owners.length > 0, "no owner");

        if(_owners.length > 0){
            revert MultiSignWallet__NoOwner();
        }
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

    function submitTransaction(address _to, uint _value, bytes calldata _data) external onlyOwner() {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        }));
        emit Submit(transactions.length - 1);
    }

    function approvesTransaction(uint txId) external onlyOwner() notApproved(txId) notExecuted(txId) txnExists(txId) {
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

    function executeTransaction(uint txId) external notExecuted(txId) txnExists(txId) {
        Transaction storage transaction = transactions[txId];
        transaction.executed = true;
        (bool success, bytes memory returnData) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx fail");
        emit ExecuteTransaction(msg.sender, txId);
    }

    function revokeTransaction(uint txId) external onlyOwner() notExecuted(txId) txnExists(txId){
        approve[txId][msg.sender] = false;
    }

    function getTransaction(uint idx) public view returns (address to, uint value, bytes memory data, bool executed){
        Transaction storage tran = transactions[idx];
        return(tran.to, tran.value, tran.data, tran.executed);
    }

    function getTransactionCount() public view returns (uint){
        return transactions.length;
    }

    function getOwnerCount() public view returns (uint){
        return owners.length;
    }
}
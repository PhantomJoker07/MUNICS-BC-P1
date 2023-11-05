// SPDX-License-Identifier: Unlicenced
pragma solidity ^0.8.18;

contract TokenContract {
    address public owner;
        struct Receivers {
        string name;
        uint256 tokens;
        }
    
    //
    uint tokenPrice = 5 ether;
    uint private weiToEther = 10**18;
    //

    mapping(address => Receivers) public users;

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
        }

    constructor(){
        owner = msg.sender;
        users[owner].tokens = 100;
        }

    function double(uint _value) public pure returns (uint){
        return _value*2;
        }

    function register(string memory _name) public{
        users[msg.sender].name = _name;
        }
        
    function giveToken(address _receiver, uint _amount) onlyOwner public{
        require(users[owner].tokens >= _amount);
        users[owner].tokens -= _amount;
        users[_receiver].tokens += _amount;
        }

    //
    function setTokenPrice(uint _price) onlyOwner public {
        if (_price >= 0){tokenPrice = _price*weiToEther;}
    }

    function buyToken(uint256 _amount) external payable {
        require(msg.value == _amount*tokenPrice);
        require(users[owner].tokens >= _amount);
        users[owner].tokens -= _amount;
        users[msg.sender].tokens += _amount;
        }
    function getTokenPrice () public view returns  (uint) {
        return tokenPrice;
    }
    //
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/token/ERC20/ERC20.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/math/SafeMath.sol";
// import "https://github.com/compound-finance/compound-protocol/blob/master/contracts/CToken.sol";

// interface cToken is IERC20 {
interface CToken {
    
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    function balanceOf(address account) external view returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);
    
    function redeem(uint256 redeemTokens) external returns (uint256);
    
}

contract Base is ERC20{
    using SafeMath for uint256;
    
    address public cTokenAsset;
    address public underlying;
    uint256 public totalStaked;
    
    constructor(address _ctoken, address _underlying) public ERC20("Bonds", "BND") {
        cTokenAsset = _ctoken;
        underlying = _underlying;
        ERC20(underlying).approve(cTokenAsset, type(uint256).max);
    }
    
    function issueBonds(uint256 _amount) external { // conversion 1 ctoken == 1 BND
        require(netDeposit() >= _amount, "Insufficient deposit");
        totalStaked = totalStaked.add(_amount);
        _mint(msg.sender, _amount);
    }

    function repayBonds(uint256 _amount) external {
        require(balanceOf(msg.sender) >= _amount, "Insufficient Balance");
        totalStaked = totalStaked.sub(_amount);
        _burn(msg.sender, _amount);
    }
    
    function regretDeposit() external { // sends back any leftover of ctokens in the contract that are not staked
        ERC20(cTokenAsset).transfer(msg.sender, netDeposit());
    }
    
    function netDeposit() public view returns (uint256) {
        return CToken(cTokenAsset).balanceOf(address(this)).sub(totalStaked);
    }
    
    // TODO: any other process/function that calls this one, could make use of the error-validation problem in minting/redeeming, exploit that
    function executeCompoundAction(uint256 _action, uint256 _amount) external {
        bytes memory data;
        
        if(_action == 0) {// transfer - output should be true and also it's not being checked for the balance of the user, instead it's the staked ctoken value
            require(ERC20(cTokenAsset).balanceOf(address(this)) >= _amount, "Insufficient deposit");
            data = abi.encodeWithSelector(CToken.transfer.selector, msg.sender, _amount);
        } else if(_action == 1) {// mint - output should be zero
            require(ERC20(underlying).balanceOf(address(this)) >= _amount, "Insufficient deposit");
            data = abi.encodeWithSelector(CToken.mint.selector, _amount);
        } else if(_action == 2) {// redeem - output should be zero
            require(ERC20(underlying).balanceOf(address(this)) >= _amount, "Insufficient deposit");
            data = abi.encodeWithSelector(CToken.mint.selector, _amount);
        }
        (bool success, bytes memory returnedData) = cTokenAsset.call(data);

        bool result = abi.decode(returnedData, (bool));
        require(success && result, "Transaction failed!");

        // require(success, "Transaction failed!");
    }

    // function executeCompoundActionGeneric(bytes memory _data) external returns (bool) {
    //     (bool success, bytes memory returnedData) = cTokenAsset.call(_data);
    //     // bool result = abi.decode(returnedData, (bool));
    //     // require(success && result, "Transaction failed!");
    //     require(success, "Transaction failed!");
    // }
}

// primary access point for users that wrap some of the actions above in a secure way
contract SafeActions {
    address private cTokenAsset;
    Base private base;
    
    constructor(address _ctoken, address _base) public {
        cTokenAsset = _ctoken;
        base = Base(_base);
    }
    // needs to be preallowed the underlying
    function depositAndIssue(uint256 _amount) external {
        ERC20(base.underlying()).transferFrom(msg.sender, address(base), _amount);
        base.executeCompoundAction(1, _amount);
        base.issueBonds(_amount); // it shouldn't be _amount, it should be `netDeposit` because it's in cTokens, so there are ctokens not being staked that can be removed with `regretDeposit`
        base.transfer(msg.sender, _amount);
    }
    
}

contract CTokenMock is ERC20 {
    
    address underlying;
    
    constructor (address _underlying) public ERC20("cUnderlying", "CUN") {
        underlying = _underlying;
    }
    
    function mint(uint256 mintAmount) external returns (uint256) {
        try ERC20(underlying).transferFrom(msg.sender, address(this), mintAmount) returns (bool success) {
            _mint(msg.sender, mintAmount*50);
            return success == true ? 0 : 1;
        } catch {
            return 2;
        }
    }
    
    function redeem(uint256 redeemTokens) external returns (uint256) {
        try this.assertBalance(msg.sender, redeemTokens) {
            _burn(msg.sender, redeemTokens);
            bool success = ERC20(underlying).transfer(msg.sender, redeemTokens/50);
            return success == true ? 0 : 1;
        } catch {
            return 2;
        }
    }
    
    function assertBalance(address _msgsender, uint256 redeemTokens) public view {
        require(balanceOf(_msgsender) >= redeemTokens, "Insufficient balance");
    }
}

contract UltraUnderlying is ERC20 {
    constructor () public ERC20("UltraUnderlying", "UU") {}
}

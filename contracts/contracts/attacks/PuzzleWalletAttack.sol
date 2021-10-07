// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

contract PuzzleAttack {
    function sendAllEth() external returns (bool) {
        uint256 contractBalance = address(this).balance;
        (bool success, bytes memory returndata) = address(msg.sender).call{ value: contractBalance }("");
        return success;
    }
}

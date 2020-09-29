pragma solidity ^0.5.16;

import "./SafeMath.sol";

contract TestToken {
    using SafeMath for uint;
    mapping(address => uint256) _balances;
    mapping (address => mapping (address => uint256)) private _allowed;

    constructor(uint256 total) public {
        _balances[msg.sender] = total;
    }

    function name() public pure returns (string memory) {
        return "TonEthereumGateToken";
    }

    function symbol() public pure returns (string memory) {
        return "TEG";
    }

    function transfer(address receiver, uint numTokens) public returns (bool) {
        require(numTokens <= _balances[msg.sender]);

        _balances[msg.sender] = _balances[msg.sender].sub(numTokens);
        _balances[receiver] = _balances[receiver].add(numTokens);

        return true;
    }

    function balanceOf(address tokenOwner) public view returns (uint) {
        return _balances[tokenOwner];
    }

    function decimals() public pure returns (uint) {
        return 6;
    }

    function allowance(
        address owner,
        address spender
    )
    public
    view
    returns (uint256)
    {
        return _allowed[owner][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = value;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    )
    public
    returns (bool)
    {
        require(value <= _balances[from]);
        require(value <= _allowed[from][msg.sender]);
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);

        return true;
    }
}

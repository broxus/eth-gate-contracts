pragma solidity >= 0.6.0;
pragma experimental ABIEncoderV2;
pragma AbiHeader expire;

interface Token {
    function transfer(uint tokenID, address recipient, uint amount) external;
    function swapBack(uint tokenID, uint amount, uint ethereumAddress) external;
}

contract TokenCaller {
    uint uniqueNonce = 123123;
    address tokenContract;
    uint owner;

    modifier onlyOwner()  {
        require(owner == msg.pubkey(), 135);
        tvm.accept();

        _;
    }

    constructor(address _tokenContract) public {
        require(msg.pubkey() == tvm.pubkey(), 100);
        tvm.accept();

        owner = msg.pubkey();
        tokenContract = _tokenContract;
    }

    function transferTokens(uint tokenID, address recipient, uint amount) onlyOwner public {
        Token(tokenContract).transfer(tokenID, recipient, amount);
    }

    function swapBackTokens(uint tokenID, uint amount, uint ethereumAddress) onlyOwner public {
        Token(tokenContract).swapBack(tokenID, amount, ethereumAddress);
    }
}

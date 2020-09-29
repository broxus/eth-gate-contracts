pragma solidity >= 0.6.0;
pragma experimental ABIEncoderV2;
pragma AbiHeader expire;

contract ERC20TokenGate {
    mapping(uint => mapping(address => uint256)) tokenUserBalance;

    bool paused = false;

    mapping(uint => bool) tokensSupported;
    mapping(uint => uint) tokenTotalSupply;
    mapping(uint => uint8) tokenEthereumDecimals;
    mapping(uint => uint8) tokenDecimals;
    mapping(uint => bytes[]) tokenName;
    mapping(uint => bytes[]) tokenSymbol;

    uint owner;
    uint uniqueNonce = 777123;

    modifier onlyOwner() {
        require(owner == msg.pubkey(), 135);
        tvm.accept();

        _;
    }

    modifier onlyUnpaused() {
        require(paused == false, 150);
        _;
    }


    event Transfer(uint tokenID, address indexed _from, address indexed _to, uint amount);
    event Burn(uint tokenID, address indexed account, uint amount);
    event Mint(uint tokenID, address indexed account, uint amount);
    event SwapBack(uint tokenID, address indexed account, uint amount, uint ethereumAddress);

    /**
        @dev Contract constructor

        @param tokenIds Unique IDs for tokens to be enabled
    */
    constructor(uint[] tokenIds) public {
        require(msg.pubkey() == tvm.pubkey(), 100);
        tvm.accept();

        owner = msg.pubkey();

        for (uint i=0; i<tokenIds.length; i++) {
            updateTokenSupport(tokenIds[i], true);
        }
    }

    /**
    @dev Check that the specific token supported

    @param tokenID - Token unique ID
*/
    function isTokenSupported(uint tokenID) public view returns(bool) {
        return tokensSupported[tokenID];
    }

    /**
    @dev Update token support status for specific token

        @param tokenId - Token unique ID
        @param supportStatus - Support status (enabled / disabled)
    */
    function updateTokenSupport(uint tokenId, bool supportStatus) public onlyOwner {
        tokensSupported[tokenId] = supportStatus;
    }

    function updateSupportStatuses(uint[] tokenIds, bool[] supportStatuses) public onlyOwner {
        for (uint i=0; i<tokenIds.length; i++) {
            updateTokenSupport(tokenIds[i], supportStatuses[i]);
        }
    }

    /**
        @dev Get balance for specific token and address

        @param tokenID Unique ID of the token
        @param account Address which balance to get
    */
    function balanceOf(uint tokenID, address account) public view returns (uint256) {
        return tokenUserBalance[tokenID][account];
    }

    /**
        @dev Get decimals for specific token. Important - probably it would be less
        than the actual decimals of the corresponding Ethereum token. To find the actual
        Ethereum decimals - use Ethereum decimals.

        @param tokenID Unique ID of the token
    */
    function decimals(uint tokenID) public view returns (uint8) {
        return tokenDecimals[tokenID];
    }

    /**
    @dev Get decimals for specific tokens, as it used in the Ethereum token.

    @param tokenID Unique ID of the token
*/
    function ethereumDecimals(uint tokenID) public view returns (uint8) {
        return tokenEthereumDecimals[tokenID];
    }

    /**
        @dev Get name for specific token

        @param tokenID Unique ID of the token
    */
    function name(uint tokenID) public view returns (bytes[]) {
        return tokenName[tokenID];
    }

    /**
        @dev Get symbol for specific token

        @param tokenID Unique ID of the token
    */
    function symbol(uint tokenID) public view returns (bytes[]) {
        return tokenSymbol[tokenID];
    }

    /**
        @dev Get total supply for specific token

        @param tokenID Unique ID of the token
    */
    function totalSupply(uint tokenID) public view returns (uint256) {
        return tokenTotalSupply[tokenID];
    }

    /**
        @dev Set up token details

        @param tokenID Unique ID of the token
        @param _decimals Token decimal places to use in TON token, usually less than the actual
        @param _ethereumDecimals Real decimals as it used in the Ethereum decimals
        @param _name Token name, like "Tether" or "Wrapped ETH"
        @param _symbol Token symbol, like USDC or DAI
    */
    function setUpToken(
        uint tokenID,
        uint8 _decimals,
        uint8 _ethereumDecimals,
        bytes[] _name,
        bytes[] _symbol
    ) public onlyOwner {
        require(_decimals <= _ethereumDecimals, 140);

        tokenDecimals[tokenID] = _decimals;
        tokenEthereumDecimals[tokenID] = _ethereumDecimals;
        tokenName[tokenID] = _name;
        tokenSymbol[tokenID] = _symbol;
    }

    /**
        @dev Transfer tokens from one wallet to another

        @param tokenID Unique ID of the token
        @param recipient Address for sending tokens to
        @param amount Amount of tokens to send
    */
    function transfer(uint tokenID, address recipient, uint amount) public onlyUnpaused {
        // Insufficient balance
        require(tokenUserBalance[tokenID][msg.sender] >= amount, 130);
        // Token not supported
        require(tokensSupported[tokenID], 125);

        tokenUserBalance[tokenID][msg.sender] = tokenUserBalance[tokenID][msg.sender] - amount;
        tokenUserBalance[tokenID][recipient] = tokenUserBalance[tokenID][recipient] + amount;

        emit Transfer(tokenID, msg.sender, recipient, amount);

        msg.sender.transfer({ flag:64 });
    }

    /**
        @dev Increase token balance for specific user. Called only by owner.
        User also receives N crystals

        @param crystalsToSend How much crystals to send to user
        @param tokenID Unique ID of the token
        @param recipient Address which balance to increase
        @param amount Amount of tokens to add
    */
    function mint(
        uint tokenID,
        uint128 crystalsToSend,
        address recipient,
        uint amount
    ) onlyOwner public {
        if (crystalsToSend > 0) {
            recipient.transfer(crystalsToSend, false, 1);
        }

        tokenTotalSupply[tokenID] = tokenTotalSupply[tokenID] + amount;
        tokenUserBalance[tokenID][recipient] = tokenUserBalance[tokenID][recipient] + amount;

        emit Mint(tokenID, recipient, amount);
    }

    /**
        @dev Decrease token balance for specific user. Decreases total supply also. Called only by owner.

        @param tokenID Unique ID of the token
        @param recipient Address which balance to decrease
        @param amount Amount of tokens to remove
    */
    function burn(uint tokenID, address recipient, uint amount) onlyOwner public {
        _burn(tokenID, recipient, amount);
        emit Burn(tokenID, recipient, amount);
    }

    /**
        @dev Update paused status. Allows to enable or disable transfers.

        @param status New status
    */
    function updatePaused(bool status) onlyOwner public {
        paused = status;
    }

    /**
        @dev Get current contract status
    */
    function getPaused() public view returns(bool) {
        return paused;
    }

    /**
        @dev Decrease token balance for specific user. Decreases total supply also. Internal only.

        @param tokenID Unique ID of the token
        @param recipient Address which balance to decrease
        @param amount Amount of tokens to remove
    */
    function _burn(uint tokenID, address recipient, uint amount) internal {
        tokenTotalSupply[tokenID] = tokenTotalSupply[tokenID] - amount;
        tokenUserBalance[tokenID][recipient] = tokenUserBalance[tokenID][recipient] - amount;
    }

    /**
        @dev Swap tokens back to Ethereum. Burns the user's tokens under the hood.this

        @param tokenID Unique ID of the token
        @param amount Amount of tokens to swap back
        @param ethereumAddress Ethereum address for revealing Ethereum tokens
    */
    function swapBack(uint tokenID, uint amount, uint ethereumAddress) public {
        // Insufficient balance
        require(tokenUserBalance[tokenID][msg.sender] >= amount, 130);
        // Token not supported
        require(tokensSupported[tokenID], 125);

        _burn(tokenID, msg.sender, amount);
        emit SwapBack(tokenID, msg.sender, amount, ethereumAddress);

        msg.sender.transfer({ flag:64 });
    }

    function transferGrams(address receiver, uint128 amount, bool bounce) onlyOwner public {
        receiver.transfer({ value: amount, bounce: bounce });
    }
}

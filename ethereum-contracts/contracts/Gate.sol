pragma solidity ^0.5.16;

pragma experimental ABIEncoderV2;

import "./interfaces/IToken.sol";
import "./SafeMath.sol";
import "./Pausable.sol";

library ECDSA {

    /**
     * @dev Recover signer address from a message by using their signature
     * @param hash bytes32 message, the hash is the signed message. What is recovered is the signer address.
     * @param signature bytes signature, the signature is generated using web3.eth.sign()
     */
    function recover(bytes32 hash, bytes memory signature)
    internal
    pure
    returns (address)
    {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Check the signature length
        if (signature.length != 65) {
            return (address(0));
        }

        // Divide the signature in r, s and v variables with inline assembly.
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
        if (v < 27) {
            v += 27;
        }

        // If the version is correct return the signer address
        if (v != 27 && v != 28) {
            return (address(0));
        } else {
            // solium-disable-next-line arg-overflow
            return ecrecover(hash, v, r, s);
        }
    }

    /**
      * toBytesPrefixed
      * @dev prefix a bytes32 value with "\x19Ethereum Signed Message:"
      * and hash the result
      */
    function toBytesPrefixed(bytes32 hash)
    internal
    pure
    returns (bytes32)
    {
        return keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
    }
}


contract Gate is Pausable {
    using SafeMath for uint;
    using UniversalERC20 for IToken;

    event LockTokens(
        address indexed tokenAddress,
        uint amount,
        address indexed fromAddress,
        uint receiverWorkChainId,
        uint receiverAddressBody
    );

    event RevealTokens(
        address indexed tokenAddress,
        uint amount,
        address indexed receiverAddress,
        uint receiptID
    );

    mapping(uint => bool) revealReceiptUsed;
    mapping(address => bool) tokensSupported;

    modifier tokenSupported(address tokenAddress) {
        require(tokensSupported[tokenAddress], "Token not supported");
        _;
    }

    modifier correctUpdateSupportSyntax(address[] memory tokenAddresses, bool[] memory supportStatuses) {
        require(tokenAddresses.length == supportStatuses.length, "Not the same amount of tokens and statuses");
        _;
    }

    constructor(
        address[] memory tokenAddresses
    ) public {
        for (uint i=0; i<tokenAddresses.length; i++) {
            updateTokenSupport(tokenAddresses[i], true);
        }
    }

    /**
        @dev Check that the specific token supported

        @param tokenAddress - Token contract's address
    */
    function isTokenSupported(address tokenAddress) public view returns(bool) {
        return tokensSupported[tokenAddress];
    }


    /**
        @dev Check that the specific receipt was used

        @param receiptID - Unique ID of the reveal receipt
    */
    function isReceiptUsed(uint receiptID) public view returns(bool) {
        return revealReceiptUsed[receiptID];
    }

    /**
        @dev Update token support status for specific token

        @param tokenAddress - Token contract's address
        @param supportStatus - Support status (enabled / disabled)
    */
    function updateTokenSupport(address tokenAddress, bool supportStatus) public onlyOwner {
        tokensSupported[tokenAddress] = supportStatus;
    }

    function updateMultipleTokenSupport(
        address[] memory tokenAddresses,
        bool[] memory supportStatuses
    ) public onlyOwner correctUpdateSupportSyntax(tokenAddresses, supportStatuses) {
        for (uint i=0; i<tokenAddresses.length; i++) {
            updateTokenSupport(tokenAddresses[i], supportStatuses[i]);
        }
    }

    /**
        @dev Lock some Ethereum tokens (DAI, USDT, MKR, ...)
        External monitoring will be checking for lockTokens event
        and then mint the same amount of tokens in TON

        @param tokenAddress - Token contract's address
        @param amount - Amount of tokens (with decimals)
        @param receiverWorkChainId - TON address workchain id for minting tokens to (0,1, ...)
        @param receiverAddressBody - TON address body for minting tokens to
    */
    function lockTokens(
        address tokenAddress,
        uint amount,
        uint receiverWorkChainId,
        uint receiverAddressBody
    ) tokenSupported(tokenAddress) whenNotPaused public {
        // Check the user's balance
        require(
            IToken(tokenAddress).balanceOf(msg.sender) >= amount,
            "Token balance insufficient"
        );
        require(
            IToken(tokenAddress).allowance(msg.sender, address(this)) >= amount,
            "Allowance insufficient"
        );

        // Transfer tokens from user to the
        IToken(tokenAddress).universalTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        // Emit the lock event
        emit LockTokens(tokenAddress, amount, msg.sender, receiverWorkChainId, receiverAddressBody);
    }

    using ECDSA for bytes32;

    /**
        @dev Reveal locked Ethereum tokens
        In case user have burned his TON tokens, the monitoring will use this function
        to send back the original Ethereum tokens

        @param receipt - ABI encoded receipt (token address, amount, receiver address, receipt ID)
        @param signature - Receipt signature
    */
    function revealTokens(
        bytes memory receipt,
        bytes memory signature
    ) public whenNotPaused {
        // Verify that the message's signer is the owner of the order
        address signer = keccak256(receipt).toBytesPrefixed().recover(signature);
        require(isOwner(signer), "Signer should be an owner");

        // Decode the receipt
        (
            address tokenAddress,
            uint amount,
            address receiverAddress,
            uint receiptID
        ) = abi.decode(
            receipt,
            (address, uint, address, uint)
        );

        require(tokensSupported[tokenAddress], "Token not supported");
        require(!revealReceiptUsed[receiptID], "Receipt ID already used");

        // Mark receipt as used
        revealReceiptUsed[receiptID] = true;

        // Send tokens to the user
        IToken(tokenAddress).universalTransfer(receiverAddress, amount);

        emit RevealTokens(tokenAddress, amount, receiverAddress, receiptID);
    }

    function getSigner(
        bytes memory receipt,
        bytes memory signature
    ) public pure returns(address) {
        address signer = keccak256(receipt).toBytesPrefixed().recover(signature);

        return signer;
    }

    function externalCallEth(
        address payable[] memory  _to,
        bytes[] memory _data,
        uint256[] memory ethAmount
    ) public onlyOwner payable {
        for(uint16 i = 0; i < _to.length; i++) {
            _cast(_to[i], _data[i], ethAmount[i]);
        }
    }

    function _cast(
        address payable _to,
        bytes memory _data,
        uint256 ethAmount
    ) internal {
        bytes32 response;

        assembly {
            let succeeded := call(
                sub(gas, 5000),
                _to,
                ethAmount,
                add(_data, 0x20),
                mload(_data),
                0,
                32
            )

            response := mload(0)
            switch iszero(succeeded)
            case 1 {
                revert(0, 0)
            }
        }
    }
}

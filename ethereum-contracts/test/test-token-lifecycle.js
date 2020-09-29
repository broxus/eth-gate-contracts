require('dotenv').config({
  path: './../.env',
});

const logger = require('mocha-logger');

const GateContract = artifacts.require("Gate");
const TokenContract = artifacts.require("TestToken");

const utils = require('@tonethereumgate/utils');
const assert = require('assert');

let gateContract;
let tokenContract;
let owner;
let receiptReceiver;

const lockAmount = "100";
const revealAmount = "90";
const receiptID = "123123";


/**
 * Get the receipt body and signature from specific account.
 *
 * @param tokenAddress
 * @param amount
 * @param receiverAddress
 * @param receiptID
 * @param signer
 * @returns {Promise<*[]>}
 */
const signReceipt = async ({ tokenAddress, amount, receiverAddress, receiptID, signer }) => {
  const revealReceiptEncoded = web3.eth.abi.encodeParameters(
    ['address', 'uint', 'address', 'uint'],
    [tokenAddress, amount, receiverAddress, receiptID],
  );
  
  const revealReceiptEncodedHash = web3
    .utils
    .soliditySha3(revealReceiptEncoded)
    .toString('hex');
  
  const receiptSignature = await web3
    .eth
    .sign(revealReceiptEncodedHash, signer);
  
  return [revealReceiptEncoded, receiptSignature];
};


contract('Testing token support', async (accounts) => {
  before(async() => {
    gateContract = await GateContract.deployed();
    tokenContract = await TokenContract.deployed();
    owner = accounts[0];
    receiptReceiver = accounts[1];
    
    logger.log(`Gate address: ${gateContract.address}`);
    logger.log(`Token address: ${tokenContract.address}`);
    logger.log(`Owner: ${owner}`);
  });
  
  it('Getting initial token support', async () => {
    const supportStatus = await gateContract.isTokenSupported.call(tokenContract.address);
    assert.deepStrictEqual(supportStatus, true, "Token support not enabled initially");
    
    logger.log(`Support status for ${tokenContract.address} - ${supportStatus}`);
  });
  
  it('Updating token support', async () => {
    await gateContract.updateTokenSupport.sendTransaction(tokenContract.address, false, {
      from: owner,
    });
  });
  
  it('Getting new token support', async () => {
    const supportStatus = await gateContract.isTokenSupported.call(tokenContract.address);
  
    assert.deepStrictEqual(supportStatus, false, "Token support not disabled");

    logger.log(`Support status for ${tokenContract.address} - ${supportStatus}`);
  });
  
  it('Trying to update support status by non owner', async () => {
    await utils.truffle.catchRevert(
      gateContract.updateTokenSupport.sendTransaction(
        tokenContract.address, false, {
        from: accounts[1],
      })
    );
    
    logger.log('Update failed, only owner can update tone support');
  });
  
  it('Trying to swap tokens with disabled token support', async () => {
    await utils.truffle.catchRevert(
      gateContract.lockTokens.sendTransaction(
        tokenContract.address,
        lockAmount,
        ...utils.ton.unpackTONAddress(process.env.TON_TOKEN_RECEIVER),
      )
    );
    
    logger.log("Token lock failed");
  });
  
  it('Enabling token support', async () => {
    await gateContract.updateTokenSupport.sendTransaction(
      tokenContract.address, true, {
      from: owner,
    });
  });
  
  it('Locking tokens', async () => {
    const gateTokenBalanceBeforeLock = await tokenContract
      .balanceOf
      .call(gateContract.address);

    await gateContract.lockTokens.sendTransaction(
      tokenContract.address,
      lockAmount,
      ...utils.ton.unpackTONAddress(process.env.TON_TOKEN_RECEIVER),
    );
  
    const gateTokenBalanceAfterLock = await tokenContract
      .balanceOf
      .call(gateContract.address);

    assert.deepStrictEqual(
      (gateTokenBalanceAfterLock - gateTokenBalanceBeforeLock).toString(),
      lockAmount,
      "Gate token balance differs from expected after token lock"
    );
  });
  
  it('Revealing tokens with owner signature', async () => {
    const gateTokenBalanceBeforeLock = await tokenContract
      .balanceOf
      .call(gateContract.address);

    const receiptReceiverTokenBalanceBeforeLock = await tokenContract
      .balanceOf
      .call(receiptReceiver);
    
    const [revealReceiptEncoded, revealReceiptSignature] = await signReceipt({
      tokenAddress: tokenContract.address,
      amount: revealAmount,
      receiverAddress: receiptReceiver,
      receiptID,
      signer: owner,
    });
    
    await gateContract
      .revealTokens
      .sendTransaction(revealReceiptEncoded, [revealReceiptSignature], {
        from: accounts[3], // Reveal should be able from any sender
      });

    const gateTokenBalanceAfterLock = await tokenContract
      .balanceOf
      .call(gateContract.address);

    const receiptReceiverTokenBalanceAfterLock = await tokenContract
      .balanceOf
      .call(receiptReceiver);
  
    assert.deepStrictEqual(
      gateTokenBalanceBeforeLock - gateTokenBalanceAfterLock,
      90,
      "Gate token balance differs from expected after token reveal",
    );

    assert.deepStrictEqual(
      receiptReceiverTokenBalanceAfterLock - receiptReceiverTokenBalanceBeforeLock,
      90,
      "Owner token balance differs from expected after token reveal",
    );
  });
  
  it('Try to reveal tokens with already used receipt', async () => {
    const [revealReceiptEncoded, revealReceiptSignature] = await signReceipt({
      tokenAddress: tokenContract.address,
      amount: revealAmount,
      receiverAddress: receiptReceiver,
      receiptID,
      signer: owner,
    });
    
    await utils.truffle.catchRevert(
      gateContract
        .revealTokens
        .sendTransaction(revealReceiptEncoded, [revealReceiptSignature], {
          from: accounts[3],
        }),
    );
  });
  
  it('Try to sign receipt with non-owner account', async () => {
    const [revealReceiptEncoded, revealReceiptSignature] = await signReceipt({
      tokenAddress: tokenContract.address,
      amount: revealAmount,
      receiverAddress: owner,
      receiptID,
      signer: accounts[2],
    });
  
    await utils.truffle.catchRevert(
      gateContract
        .revealTokens
        .sendTransaction(revealReceiptEncoded, [revealReceiptSignature]),
    );
  });
});

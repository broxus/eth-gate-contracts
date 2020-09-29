require('dotenv').config({
  path: './../.env',
});


const logger = require('mocha-logger');
const assert = require('assert');

const GateContract = artifacts.require("Gate");
const TokenContract = artifacts.require("TestToken");

let gateContract;
let tokenContract;
let owner;
let receiptReceiver;

contract('Test pausable functionality', async (accounts) => {
  before(async() => {
    gateContract = await GateContract.deployed();
    tokenContract = await TokenContract.deployed();
    owner = accounts[0];
    receiptReceiver = accounts[1];
    
    logger.log(`Gate address: ${gateContract.address}`);
    logger.log(`Token address: ${tokenContract.address}`);
    logger.log(`Owner: ${owner}`);
  });
  
  it('Get initial pausable status', async () => {
    const supportStatus = await gateContract.isTokenSupported.call(tokenContract.address);
    
    console.log(supportStatus);
  });
  
  it('Lock tokens', async () => {
  
  });
  
  it('Pause contract', async () => {
  
  });
  
  it('Try to lock or reveal tokens', async () => {
  
  });
  
  it('Unpause contract', async () => {
  
  });
});

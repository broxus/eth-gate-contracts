const Migrations = artifacts.require("Migrations");
const Gate = artifacts.require("Gate");
const Token = artifacts.require("TestToken");


const tokensToSupport = [
  '0xdac17f958d2ee523a2206206994597c13d831ec7', // Tether
  '0x6b175474e89094c44da98b954eedeac495271d0f', // Dai
  '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2', // Wrapped ETH
  '0x2260fac5e5542a773aa44fbcfedf7c193bc2c599', // Wrapped BTC
  '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48', // USDC
];
const tokenSupply = "10000000000000000";


module.exports = async function (deployer) {
  if (deployer.network_id === 1) { // Main net
    await deployer.deploy(Gate, tokensToSupport);
  } else {
    await deployer.deploy(Migrations);

    const tokenContract = await deployer.deploy(Token, tokenSupply);
    const gateContract = await deployer.deploy(
      Gate,
      [...tokensToSupport, tokenContract.address],
    );
  
    // Approve all the supply to the gate contract
    await tokenContract.approve(gateContract.address, tokenSupply);
  }
};

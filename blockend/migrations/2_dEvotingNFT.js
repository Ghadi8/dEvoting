const dEvotingNFTCont = artifacts.require("dEvotingNFT");

const { setEnvValue } = require("../utils/env-man");

const conf = require("../migration-parameters");

const setDEvotingNFT = (n, v) => {
  setEnvValue("../", `dEvotingNFT_ADDRESS${n.toUpperCase()}`, v);
};

module.exports = async (deployer, network, accounts) => {
  switch (network) {
    case "rinkeby":
      c = { ...conf.rinkeby };
      break;
    case "mainnet":
      c = { ...conf.mainnet };
      break;
    case "mumbai":
      c = { ...conf.mumbai };
    case "development":
    default:
      c = { ...conf.devnet };
  }

  // deploy Crowdfunding
  await deployer.deploy(
    dEvotingNFTCont,
    c.name,
    c.symbol,
    c.uri,
    c.tokenIds,
    c.tokenSupplies
  );

  const dEvotingNFT = await dEvotingNFTCont.deployed();

  if (dEvotingNFT) {
    console.log(
      `Deployed: dEvotingNFT
       network: ${network}
       address: ${dEvotingNFT.address}
       creator: ${accounts[0]}
    `
    );
    setDEvotingNFT(network, dEvotingNFT.address);
  } else {
    console.log("dEvotingNFT Deployment UNSUCCESSFUL");
  }
};

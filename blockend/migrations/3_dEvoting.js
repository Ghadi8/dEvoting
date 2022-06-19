const dEvotingCont = artifacts.require("dEvoting");
const dEvotingNFTCont = artifacts.require("dEvotingNFT");

const { setEnvValue } = require("../utils/env-man");

const conf = require("../migration-parameters");

const setDEvoting = (n, v) => {
  setEnvValue("../", `dEvoting_ADDRESS${n.toUpperCase()}`, v);
};

module.exports = async (deployer, network, accounts) => {
  // Getting the deployed dEvoting NFT contract
  const dEvotingNFT = await dEvotingNFTCont.deployed();

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
  await deployer.deploy(dEvotingCont, dEvotingNFT.address, c.NFTtokenIds);

  const dEvoting = await dEvotingCont.deployed();

  if (dEvoting) {
    console.log(
      `Deployed: dEvoting
         network: ${network}
         address: ${dEvoting.address}
         creator: ${accounts[0]}
      `
    );
    setDEvoting(network, dEvoting.address);
  } else {
    console.log("dEvoting Deployment UNSUCCESSFUL");
  }
};

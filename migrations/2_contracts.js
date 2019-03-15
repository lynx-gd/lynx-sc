var Lynx = artifacts.require("./Lynx.sol");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

module.exports = function(deployer) {
  deployer.deploy(Lynx, 60*60*24*178, 50, 60*60*24*14);
};

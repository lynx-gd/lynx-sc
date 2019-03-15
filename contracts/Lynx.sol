pragma solidity ^0.5.2;
contract Lynx {
  struct Asset {
    uint value;
    address owner;
    uint createdTime;
    uint lastTaxPaid;
  }
  Asset[] public assets;

  mapping(address => uint[]) public userToAssets;
  mapping(address => uint) public users;
  uint public totalEligbleUserAmount = 0;
  uint public userCounter = 0;
  uint public totalTaxCollected = 0;
  bool public declarationPeriod = false;
  uint public taxPercentage; //in mils
  uint public lastDeclarationPeriod;
  uint public epochPeriod;
  uint public declarationDuration;

  modifier isDeclarationPeriod() {
    require(declarationPeriod, "Not in declaration period");
    _;
  }

  modifier isEntryPeriod() {
    require(!declarationPeriod, "In declaration period");
    _;
  }

  modifier userIsMemeber() {
    require(users[msg.sender] > 0);
    _;
  }

  modifier countSender() {
    _;
    if (users[msg.sender] < lastDeclarationPeriod) {
      userCounter += 1;
      users[msg.sender] = lastDeclarationPeriod;
    }
  }

  constructor(uint _epochPeriod, uint _taxPercentage, uint _declarationDuration)
    public
  {
    epochPeriod = _epochPeriod;
    taxPercentage = _taxPercentage;
    declarationDuration = _declarationDuration;
    lastDeclarationPeriod = now;
  }

  function createAsset() external payable isEntryPeriod countSender returns(uint assetIndex) {
    require(msg.value > 0, "Must declare value");
    uint durationMultiplier = 1000 * epochPeriod / (lastDeclarationPeriod - now);
    Asset memory newAsset = Asset({ // Note that we multipled the duration multiplier by a 1000 already
      value: msg.value * durationMultiplier / taxPercentage,
      owner: msg.sender,
      createdTime: now,
      lastTaxPaid: lastDeclarationPeriod
    });
    uint assetIndex = assets.push(newAsset) - 1;
    userToAssets[msg.sender].push(assetIndex);
  }

  function setAssetValue(uint id) external payable isDeclarationPeriod countSender{
    require(assets[id].owner == msg.sender, "Sender not asset owner");
    require(msg.value > 0, "No tax sent");
    // Check if user hasn't claimed dividends yet
    if (users[msg.sender] == lastDeclarationPeriod - epochPeriod) {
      // Give him the dividend
      collectDivdend(msg.sender);
    }
    assets[id].value = msg.value * 1000 / taxPercentage;
    assets[id].lastTaxPaid = lastDeclarationPeriod;
  }

  function claimAsset(address currentOwner, uint idx)
    external
    payable
    userIsMemeber
    isEntryPeriod
    countSender
  {
    require(msg.value > 0, "No tax");

    uint assetIdx = userToAssets[currentOwner][idx];
    require(
      assets[assetIdx].lastTaxPaid < lastDeclarationPeriod,
      " Tax is paid"
    );
    switchOwners(currentOwner, idx, msg.sender);
    assets[assetIdx].owner = msg.sender;
    uint durationMultiplier = 1000 * epochPeriod / (lastDeclarationPeriod - now);
    assets[assetIdx].value = msg.value * durationMultiplier / taxPercentage;

  }

  function buyAsset(address payable currentOwner, uint idx)
    external
    payable
    userIsMemeber
    isEntryPeriod
    countSender
  {
    uint assetIdx = userToAssets[currentOwner][idx];
    require(
      assets[assetIdx].lastTaxPaid == lastDeclarationPeriod,
      "Tax is no paid, asset can be claimed"
    );
    require(msg.value > assets[assetIdx].value, "Not enough payment");
    switchOwners(currentOwner, idx, msg.sender);
    assets[assetIdx].owner = msg.sender;
    uint durationMultiplier = 1000 * epochPeriod / (lastDeclarationPeriod - now);
    uint purchasePrice = assets[assetIdx].value;
    assets[assetIdx].value = (msg.value - purchasePrice) * durationMultiplier / taxPercentage;
    currentOwner.transfer(purchasePrice);

  }

  function enterDeclerationPeriod() external {
    require(
      now > lastDeclarationPeriod + epochPeriod && !declarationPeriod,
      "Can't enter declarationPeriod"
    );
    declarationPeriod = true;
    lastDeclarationPeriod += epochPeriod;
    totalTaxCollected = address(this).balance;
  }

  function exitDeclerationPeriod() external {
    require(
      now > lastDeclarationPeriod + declarationDuration && declarationPeriod
    );
    declarationPeriod = false;
  }

  function collectDivdend(address payable user) public {
    require(users[msg.sender] == lastDeclarationPeriod - epochPeriod);
    users[msg.sender] = 0;
    user.transfer(totalTaxCollected / totalEligbleUserAmount);
  }

  function switchOwners(
    address currentOwner,
    uint currentOwnerIdx,
    address newOwner
  ) internal {
    userToAssets[newOwner].push(userToAssets[currentOwner][currentOwnerIdx]);
    userToAssets[currentOwner][currentOwnerIdx] = userToAssets[currentOwner][userToAssets[currentOwner].length - 1];
    userToAssets[currentOwner].length--;

  }
}

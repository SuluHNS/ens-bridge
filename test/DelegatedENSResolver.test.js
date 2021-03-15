const { expect } = require("chai");
const { namehash, labelhash } = require("@ensdomains/ensjs");
const { abi: resolverABI } = require('@ensdomains/resolver/build/contracts/Resolver.json');
const { ethers } = require("hardhat");

const hostNode = namehash('fuckingfucker.eth'),
      delegatedNode = namehash('fucking.badass');

describe("DelegatedENSResolver.sol", function() {
  let deployer, HostENS, DelegatedENS, ENSBridge, DelegatedResolver;

  beforeEach(async function() {
    deployer = ethers.provider.getSigner();
    deployer.address = await deployer.getAddress()
    // setup two separate ENS instances
    const ENS = await ethers.getContractFactory("ENSRegistry", deployer);
    HostENS = await ENS.deploy();
    DelegatedENS = await ENS.deploy();
    // deploy bridge resolver
    const DelegatedENSResolver = await ethers.getContractFactory("DelegatedENSResolver", deployer);
    console.log('ENS instances', HostENS.address, DelegatedENS.address);
    ENSBridge = await DelegatedENSResolver.deploy(HostENS.address, DelegatedENS.address);

    await Promise.all([
      HostENS.deployed(),
      DelegatedENS.deployed(),
      ENSBridge.deployed(),
    ]);

    console.log('Setting up tlds on host ENS...');

    // setup .eth and .badass tlds on their ENS systems
    await HostENS.setSubnodeOwner(namehash(''), labelhash('eth'), deployer.address);
    await DelegatedENS.setSubnodeOwner(namehash(''), labelhash('badass'), deployer.address);
    
    // add bridge from .eth ENS tosubdomain 
    console.log('Setting up subdomain on host ENS instance...');

    await HostENS.setSubnodeRecord(
      namehash('eth'),
      labelhash('fuckingfucker'),
      deployer.address, // owner
      ENSBridge.address, //resolver
      100000 // ttl
    );

    console.log('Deploying delegated resolver to delegated ENS instance...');
    const PublicResolver = await ethers.getContractFactory("PublicResolver", deployer);
    DelegatedResolver = await PublicResolver.deploy(DelegatedENS.address);
    await DelegatedResolver.deployed();

    console.log('Setting up subdomain on host ENS instance...');
    // add resolver on badass subdomain
    await DelegatedENS.setSubnodeRecord(
      namehash('badass'),
      labelhash('fucking'),
      deployer.address, // owner
      DelegatedResolver.address, //resolver
      100000 // ttl
    );
  })

  it('should have same owners for subdomains in both ens systems', async function() {
    expect(await HostENS.owner(hostNode)).to.equal(deployer.address);
    expect(await DelegatedENS.owner(delegatedNode)).to.equal(deployer.address);
  });

  it('should fetch resolver from delegated ENS after host ENS node is delegated', async function() {
     // setup bridge
     await ENSBridge.setENSDelegation(hostNode, delegatedNode);

     // check that correct resolver on .badass ENS is called when making request to .eth ENS subdomain
     expect(await ENSBridge.delegatedResolver(hostNode)).to.equal(DelegatedResolver.address);
  });

  it("Should resolve records on another ENS system through delegated resolver", async function() {
    // setup bridge
    await ENSBridge.setENSDelegation(hostNode, delegatedNode);

    // Bridge contract doesn't have resolver funcs in abi since it delegates all calls
    // Manually add resolver abi to bridge address
    const BridgeResolver = new ethers.Contract(ENSBridge.address, resolverABI, ethers.provider);

    // addr() should be same on both ENS nodes even though we only set on delegated resolver
    console.log('.badass addr', await DelegatedResolver['addr(bytes32)'](delegatedNode));
    console.log('.eth addr', await BridgeResolver['addr(bytes32)'](hostNode));
    expect(await DelegatedResolver['addr(bytes32)'](delegatedNode)).to.equal(await BridgeResolver['addr(bytes32)'](hostNode));

    const testAddr = ethers.Wallet.createRandom().address;
    await DelegatedResolver['setAddr(bytes32,address)'](delegatedNode, testAddr);
    // verify that .eth domain is getting resultsf rom delegated resolver
    expect(await BridgeResolver['addr(bytes32)'](hostNode)).to.equal(testAddr);
  });


});

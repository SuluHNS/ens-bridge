//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.4;

import "hardhat/console.sol";
import "@ensdomains/ens/contracts/ENS.sol";
import "@ensdomains/resolver/contracts/ResolverBase.sol";


contract DelegatedENSResolver is ResolverBase {
  ENS hostENS;
  ENS delegatedENS;
  bytes4 private constant DELEGATED_ENS_ID = bytes4(
    keccak256("setENSDelegation(bytes32 hostNode, bytes32 delegatedNode)")
  );

  event NodeDelegated(ENS hostENS, ENS delegatedENS, bytes32 hostNode, bytes32 delegateNode);
  event AuthorisationChanged(bytes32 indexed node, address indexed owner, address indexed target, bool isAuthorised);
  // ENSBridgeRegistrar 


   // host ENS node  -> delegate ENS node 
  mapping(bytes32 => bytes32) nodeMappings;
  /**
    * A mapping of authorisations. An address that is authorised for a name
    * may make any changes to the name that the owner could, but may not update
    * the set of authorisations.
    * node -> owner -> caller -> isAuthorised
  */
  mapping(bytes32 => mapping(address => mapping(address => bool))) public authorisations;

  constructor(ENS _hostENS, ENS _delegatedENS) {
    hostENS = _hostENS;
    delegatedENS = _delegatedENS;
  }

  /**
    * @dev Sets or clears an authorisation.
    * Authorisations are specific to the caller. Any account can set an authorisation
    * for any name, but the authorisation that is checked will be that of the
    * current owner of a name. Thus, transferring a name effectively clears any
    * existing authorisations, and new authorisations can be set in advance of
    * an ownership transfer if desired.
    *
    * @param hostNode The name to change the authorisation on.
    * @param target The address that is to be authorised or deauthorised.
    * @param _isAuthorised True if the address should be authorised, or false if it should be deauthorised.
  */
  function setAuthorisation(bytes32 hostNode, address target, bool _isAuthorised) external {
      authorisations[hostNode][msg.sender][target] = _isAuthorised;
      emit AuthorisationChanged(hostNode, msg.sender, target, _isAuthorised);
  }

  function isAuthorised(bytes32 hostNode) internal override view returns(bool) {
    address owner = hostENS.owner(hostNode);
    return owner == msg.sender || authorisations[hostNode][owner][msg.sender];
  }

 /**
  * @dev Sets a node on one ENS instance to an node on another ENS instance
  * @param hostNode The node on this ENS system to bridge over.
  * @param delegatedNode The node on delegated ENS system to resolve to.
  */
  function setENSDelegation(bytes32 hostNode, bytes32 delegatedNode) external authorised(hostNode) {
    nodeMappings[hostNode] = delegatedNode;
    emit NodeDelegated(hostENS, delegatedENS, hostNode, delegatedNode);
  }

  /**
  * @dev Checks if resolver on delegated ens node supports method being called on this reolver
  * This resolver will return false for any call to `supportsInterface(byes4)`
  * since it depends on the delegated resolvers returnvaluewhich we can't call without byts32 node
  * @param interfaceID the function signature being called
  * @param hostNode The node on this ENS instance being called
  */
  function supportsInterface(bytes4 interfaceID, bytes32 hostNode) external view returns (bool) {
    return interfaceID == DELEGATED_ENS_ID ||
      delegatedResolver(hostNode).supportsInterface(interfaceID);
  }

  /**
    * @dev Gets the resolver on delegated ENS system to call for node on this ENS system
    * @param hostNode The node on this ENS instance being called
  */
  function delegatedResolver(bytes32 hostNode) internal view returns (ResolverBase) {
    address resolver = delegatedENS.resolver( nodeMappings[hostNode] );
    require(resolver != address(0), 'Resolver not set in delegated ENS');
    return ResolverBase(resolver);
  }


  /**
  * @dev Pull function signature and ENS node from function paramters in resolver call
  * Assumes next 32 bytes after function signature is ENS node on all function calls
  * @param data msg.data.
  */
  function getCalldata(bytes calldata data)
    internal pure
    returns (bytes4 signature, bytes32 hostNode)
  {
    (signature, hostNode) = abi.decode(abi.encodePacked(data[0:36]), (bytes4, bytes32));
    return (signature, hostNode);
  }

  /**
    * @dev Fallback function that calls method on resolver in delegated ENS system
  */
  fallback() external {
    // apparently both these logBytes output same ata
    console.log('ENS Resolver data - ');
    console.logBytes(msg.data);
    console.log('ENS Resolver packd data - ');
    console.logBytes(abi.encodePacked(msg.data[0:36]));

    (bytes4 sig, bytes32 hostNode) = getCalldata(msg.data);
    require(this.supportsInterface(sig, hostNode), 'Unsupported function on delegated resolver');
    
    // use delegated ENS node instead of current ENS node in function call
    bytes32 delegatedNode = nodeMappings[hostNode];
    address(delegatedResolver(hostNode)).call(
      abi.encodeWithSelector(sig, delegatedNode) // todo append other msg.data at end
    );
  }
}

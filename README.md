ENS custom resolver for pulling records from a domain on another ENS root zone. This allows domains on any ENSRegistry contract to be called from any other ENS system with complete backwards compatibility and no updates to existing offchain and onchain integrations.

## How to use
1. Deploy `DelegatedENSResolver.sol` with your host ENS address (e.g. .eth) and your new ENS system's address (e.g. .badass)
2. Call `ENS.setResolver()` on your .eth domain with newly deployed ccontract address
3. Call `DelegatedENSResolver.setENSDelegation()` with your host ENS node that will pull records from your delegated ENS node on the other ENS system. E.g. `fuckingfucker.eth` to pull records from `fucking.badass`
4. Make sure your delegate ENS node (fucking.badass) has a public resolver and records set
5. To make calls to `DelegatdENSResolver`, you should use normal [Resolver ABI](https://github.com/ensdomains/resolvers/blob/master/contracts/Resolver.sol) attached to this contract address since these functions are not in our ABI but theoretically supports all `PublicResolver` methods.
6. You can call `DelegatdENSResolver.supportsInterface(functionSignature, hostNode)` and the contract checks if that method is avilable on the delegated resolver in other ENS system. Normal `supportsInterface(functionSignature)` will return false for everything except ERC165 ID since we can't know if a function is supported without knowing the node pull resolver from.

## How It Works
Currently it doesnt work but I think its almost there.
Uses Solidity's catchall `fallback()` function to route all requests from the traditional ENS system to a resolver that lives on another ENS system. It does this by storing a mapping of two nodes in each system, the host node that passes on calls and the delegated node that stores actual records. Presumably both nodes are owned by the same address but we don't make checks if the delegated node is owned by the same owner of the host ENS node since only the host ENS node owner can set this mapping.

Lets say you want to get the `addr()` for `fuckingfucke.eth`. This resolver looks up the node it delegates to, finds `fucking.badass`, calls the .badass registry to find the resolver for `fucking.badass`, replaces the 32 bytes of `fuckingfucker.eth`  ENS node with 32 bytes of `fucking.badass` ENS node in the transaction call data, calls .badass resolver, and returns the value back to original caller of `DelegatedENSResolver `contract.

Can check `tests/DelegatedENSResolver.test.js` for beginning of test suite

## Security Concerns
Im not a solidity dev or smart contract auditor but I'd assume its a huge security hole to make arbitrary function calls with arbitrary data to unknown smart contracts. Use at your own risk.

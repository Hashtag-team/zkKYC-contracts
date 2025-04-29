# ITest
**Author:**
Grigory Morgachev

This interface defines the functions, errors and events for the Test contract.


## Events
### NewContractAdded
For test: Emitted when a new utility contract template is registered.


```solidity
event NewContractAdded(address indexed _contractAddress, uint256 _fee, bool _isActive, uint256 _timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_contractAddress`|`address`|Address of the registered utility contract template.|
|`_fee`|`uint256`|Fee (in wei) required to deploy a clone of this contract.|
|`_isActive`|`bool`|Whether the contract is active and deployable.|
|`_timestamp`|`uint256`|Timestamp when the contract was added.|

## Errors
### ContractNotActive
*Reverts if the contract is not active*


```solidity
error ContractNotActive();
```


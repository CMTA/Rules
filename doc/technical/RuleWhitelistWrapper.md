# Rule Whitelist Wrapper

[TOC]

This rule allows to have several different whitelist rules, managed by different operators.

The rule will call each whitelist rule to know if during a transfer the address `from`or the address `to`is in the whitelist.
If this is the case, the rule return 0 (transfer valid) or an error otherwise.

## Schema

### Architecture

![ruleWhitelistWrapper.drawio](../schema/rule/ruleWhitelistWrapper.drawio.png)

### Graph

![surya_graph_Whitelist](../surya/surya_graph/surya_graph_RuleWhitelistWrapper.sol.png)

### Inheritance



## Details

### Architecture



### Admin

The default admin is the address put in argument(`admin`) inside the constructor. It is set in the constructor when the contract is deployed.

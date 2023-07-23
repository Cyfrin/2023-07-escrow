# CodeHawks Escrow Contract - Competition Details

<br/>
<p align="center">
<a href="https://codehawks.com" target="_blank">
<img src="https://res.cloudinary.com/droqoz7lg/image/upload/v1689080263/snhkgvtsidryjdtx0pce.png" width="400" alt="CodeHawks escrow contract">
</a>
</p>
<br/>

## Contest Details 

- Total Prize Pool: $40,000
  - HM Awards: $37,000
  - LQAG Awards: $3,000
- Starts July 24, 2023
- Ends August 5th, 2023
- nSLOC: ~182
- Complexity Score: ~106

### Project Overview

**Actors**

* Buyer: The purchaser of services, in this scenario, a project purchasing an audit.
* Seller: The seller of services, in this scenario, an auditor willing to audit a project.
* Arbiter: An impartial, trusted actor who can resolve disputes between the Buyer and Seller.
​
**Design considerations**
* The Arbiter is only compensated the `arbiterFee` amount if a dispute occurs.
* Once a dispute has been initiated it can not be canceled.
* ERC777 tokens should not be used as tokens for the `Escrow` contract given that it enables a malicious buyer to DOS `Escrow::resolveDispute`
* In case a smart contract calls `EscrowFactory::newEscrow`, given that the caller of this contract is in control of the salt, frontrunning is a possibility.
​
### Workflows

**Create an `Escrow`**

1. Buyer approves the payment contract to be handled by `EscrowFactory`.
2. Buyer calls `EscrowFactory::newEscrow`, inputs:
    1. The price.
    2. The payment token.
    3. The seller (auditor or person in charge of the audit).
    4. Arbiter.
    5. Arbiter fee: Fee to pay in case of a dispute is initialized.
    6. Salt: for `create2` `Escrow` deployment.


**Expected sucessful workflow**

1. The buyer creates an `Escrow` contract through `EscrowFactory::newEscrow`, depositing the funds.
2. The seller sends the buyer the report (off-chain).
3. The buyer acknowledges this report on-chain by calling `Escrow::confirmReceipt`. This sends the funds to the seller.

​
**Expected dispute workflow**

1. The buyer creates an `Escrow` contract through `EscrowFactory::newEscrow`, depositing the funds.
2. For any reason, the buyer or the seller can initiate a dispute through `Escrow::initiateDispute`.
3. The arbiter confers with both parties offchain. Arbiter then calls `Escrow::resolveDispute`, reimbursing either side accordingly, emptying the `Escrow`.
​

## Submissions 

- Submit to [CodeHawks](https://www.codehawks.com/contests/cljyfxlc40003jq082s0wemya)

## In Scope

All contracts in `src` are in scope.

*Note on `script` folder*:
The contracts in `script` are the scripts you can assume are going to be used to deploy and interact with the contracts. If they have an issue that will affect the overall security of the system, they are in scope. However, if they have a security issue that only affects the script and not the overall deployment of the stablecoin protocol, it is out of scope.

## Known Issues

* **Addresses other than the zero address (for example 0xdead) could prevent disputes from being resolved** - Before the `buyer` deploys a new `Escrow`, the `buyer` and `seller` should agree to the terms for the `Escrow`. If the `buyer` accidentally or maliciously deploys an `Escrow` with incorrect `arbiter` details, then the `seller` could refuse to provide their services. Given that the `buyer` is the actor deploying the new `Escrow` and locking the funds, it's in their best interest to deploy this correctly.
* **Large arbiter fee results in little/no `seller` payment** - In this scenario, the `seller` can decide to not perform the audit. If this is the case, the only way the `buyer` can receive any of their funds back is by initiating the dispute process, in which the `buyer` loses a large portion of their deposited funds to the `arbiter`. Therefore, the `buyer` is disincentivized to deploy a new `Escrow` in such a way.
* **Tokens with callbacks allow malicious sellers to DOS dispute resolutions** - Each supported token will be vetted to be supported. ERC777 should be discouraged.
* **`buyer` never calls `confirmReceipt`** - The terms of the `Escrow` are agreed upon by the `buyer` and `seller` before deploying it. The onus is on the `seller` to perform due diligence on the `buyer` and their off-chain identity/reputation before deciding to supply the `buyer` with their services.
* **`salt` input when creating an `Escrow` can be front-run**
* **`arbiter` is a trusted role**
* **User error such as `buyer` calling `confirmReceipt` too soon**
* **Non-`tokenAddress` funds locked**

# About

This project is meant to enable smart contract auditors (sellers) and smart contract protocols looking for audits (buyers) to connect using a credibly neutral option, with optional arbitration.

- [CodeHawks Escrow Contract - Competition Details](#codehawks-escrow-contract---competition-details)
  - [Contest Details](#contest-details)
    - [Project Overview](#project-overview)
    - [Workflows](#workflows)
  - [Submissions](#submissions)
  - [In Scope](#in-scope)
  - [Known Issues](#known-issues)
- [About](#about)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
- [Usage](#usage)
  - [Testing](#testing)
    - [Test Coverage](#test-coverage)
  - [Start a local node](#start-a-local-node)
  - [Deploy](#deploy)
  - [Deploy - Other Network](#deploy---other-network)
- [Deployment to a testnet or mainnet](#deployment-to-a-testnet-or-mainnet)
  - [Estimate gas](#estimate-gas)
- [Formatting](#formatting)
- [Acknowledgements](#acknowledgements)

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/Cyfrin/2023-07-escrow 
cd escrow 
forge build
```

# Usage

## Testing

```
forge test
```

### Test Coverage

```
forge coverage
```

and for coverage based testing: 

```
forge coverage --report debug
```


## Start a local node

```
make anvil
```

## Deploy

This will default to your local node. You need to have it running in another terminal in order for it to deploy.

```
make deploy
```

## Deploy - Other Network

[See below](#deployment-to-a-testnet-or-mainnet)



# Deployment to a testnet or mainnet

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables. You can add them to a `.env` file, similar to what you see in `.env.example`.

- `PRIVATE_KEY`: The private key of your account (like from [metamask](https://metamask.io/)). **NOTE:** FOR DEVELOPMENT, PLEASE USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.
  - You can [learn how to export it here](https://metamask.zendesk.com/hc/en-us/articles/360015289632-How-to-Export-an-Account-Private-Key).
- `SEPOLIA_RPC_URL`: This is url of the goerli testnet node you're working with. You can get setup with one for free from [Alchemy](https://alchemy.com/?a=673c802981)

Optionally, add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/).

1. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some tesnet ETH. You should see the ETH show up in your metamask.

2. Deploy

```
make deploy ARGS="--network sepolia"
```

## Estimate gas

You can estimate how much gas things cost by running:

```
forge snapshot
```

And you'll see and output file called `.gas-snapshot`


# Formatting


To run code formatting:
```
forge fmt
```


# Acknowledgements
- Inspiration for the codebase from [Ross Campbell](https://www.linkedin.com/in/ross-campbell-058153aa/)

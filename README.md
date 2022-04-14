# ASC

Generic algorithmic stable coin backed by certain underlyings

```bash
forge 0.1.0 (f01d2f7 2022-03-11T00:05:09.559922+00:00)

forge build

# run in separate terminal: ganache-cli -f https://mainnet.infura.io/v3/406b22e3688c42898054d22555f43271@14398694
forge test -f http://127.0.0.1:8545 -vvv
```

Note: Tests expect forked chain state to be after dfxCADC contract was deployed, but before rename to dfxCAD. Here the ganache block number is set to `14398694` to address this.

## Installation

Clone using the `--recursive` flag so it fetches the submodules:

```bash
git clone --recursive git@github.com:dfx-finance/asc.git
```

Or run this after regular cloning:

```bash
git submodule update --init
```

## Deployment

```
node v16.13.0

node --experimental-json-modules scripts/01-deploy-dfxcadc.js
```

## Verification

```bash
# export ETHERSCAN_API_KEY=AH56YE6FZWX7QHMR6JFV3FGHCNWCXCVKCV
forge verify-contract --compiler-version v0.8.12+commit.f00d7308 [CONTRACT ADDRESS] --constructor-args <ARGS> --num-of-optimizations 200 [CONTRACT_PATH:CONTRACT_NAME] [ETHERSCAN_API_KEY]
```

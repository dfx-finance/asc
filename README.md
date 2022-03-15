# ASC

Generic algorithmic stable coin backed by certain underlyings

```bash
forge 0.1.0 (f01d2f7 2022-03-11T00:05:09.559922+00:00)

forge build

# ganache-cli -f https://mainnet.infura.io/v3/406b22e3688c42898054d22555f43271
forge test -vvv
forge test -f http://127.0.0.1:8545 -vvv
```


## Deployment

```
node v16.13.0

node --experimental-json-modules scripts/01-deploy-dfxcadc.js
```
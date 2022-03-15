#!/bin/bash

forge verify-contract --compiler-version v0.8.12+commit.f00d7308 0x5172ADF501cbC4118Ebcb240cC0F95C87BF858BC --constructor-args 000000000000000000000000c9f05fa7049b32712c5d6675ebded167150475c4 --num-of-optimizations 200  ./src/oracles/DfxCadTWAP.sol:DfxCadTWAP $ETHERSCAN_API_KEY

forge verify-check xu8gm8fytwtamyhyndybgzhs6areumtqha96hyz3bqwpef9gie $ETHERSCAN_API_KEY
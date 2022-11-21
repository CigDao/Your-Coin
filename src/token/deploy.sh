#!/bin/bash

dfx deploy --network ic \
	--argument="(
        \"data:image/jpeg;base64,$(base64 icon.png)\",
        \"Your Coin\",
        \"YC\",
        8,
        100000000000000000000,
        principal \"$(dfx identity get-principal)\", 
        0,
        )"


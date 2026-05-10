#!/bin/bash

export SHELL=/bin/bash

wget https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.107.74/AdGuardHome_linux_386.tar.gz

tar xvf AdGuardHome_linux_386.tar.gz

tsu

./AdGuardHome

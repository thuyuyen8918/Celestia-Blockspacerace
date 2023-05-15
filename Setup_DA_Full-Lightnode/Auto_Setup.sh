#!/bin/bash

FULL_VER="v0.9.0"
LIGHT_VER="v0.8.1"

echo -e "\n\e[42mThe tool is used to setup your DA Full/Light Node in Celestia Blockspacerace Network!\e[0m"
echo -e "\n- Current Fullnode version: \033[0;31m${FULL_VER}\033[0m"
echo -e "\n- Current Lightnode version: \033[0;31m${LIGHT_VER}\033[0m"

echo -e "\nKindly provide your information"

echo -e "\nYour DA node type (type \033[0;31mfull\033[0m or \033[0;31mlight\033[0m): " 
read CEL_NODETYPE
if [[ ( $CEL_NODETYPE != "full" ) && ( $CEL_NODETYPE != "light" ) ]]; then
	echo -e "\n\033[0;31mYou selected wrong node type. Please rerun script.\033[0m"
	exit
fi

read -p "Your wallet name: " CEL_WALLET

echo -e "\nSeedphrase of your wallet (\033[0;31mLeave blank if new one\033[0m): "
read CEL_SEEDPHRASE

CEL_CHAINNAME="blockspacerace"


echo -e "\n\033[0;32mInstalling dependencies....\033[0m"; sleep 1;
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl build-essential git wget jq make gcc tmux chrony lz4 unzip


echo -e "\n\033[0;32mInstalling Go....\033[0m"; sleep 1;
ver="1.20.3"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile
go version


echo -e "\n\033[0;32mInstalling Celestia DA node....\033[0m"; sleep 1;
cd $HOME
rm -rf celestia-node
git clone https://github.com/celestiaorg/celestia-node.git
cd celestia-node/
if [[ $CEL_NODETYPE == "full" ]] 
then 
	git checkout tags/v0.9.0
else
	if [[ $CEL_NODETYPE == "light" ]]
	then 
		git checkout tags/v0.8.1
	fi 
fi 
make build
make install
make cel-key


echo "export CEL_WALLET=$CEL_WALLET" >> $HOME/.bash_profile
echo "export CEL_CHAINNAME=$CEL_CHAINNAME" >> $HOME/.bash_profile
echo "export CEL_NODETYPE=$CEL_NODETYPE" >> $HOME/.bash_profile
source $HOME/.bash_profile


if [[ $CEL_SEEDPHRASE == "" ]] 
then 
	# Create new wallet (Remember to write down seed phrases)
	./cel-key add $CEL_WALLET --keyring-backend test --node.type $CEL_NODETYPE --p2p.network $CEL_CHAINNAME
else 
	# Recover ur wallet with your seed phrase (optional)
 	echo $CEL_SEEDPHRASE | ./cel-key add $CEL_WALLET --keyring-backend test --node.type $CEL_NODETYPE --p2p.network $CEL_CHAINNAME --recover
fi 

# Save wallet address
CEL_WALLET_ADDR=$(./cel-key show $CEL_WALLET -a --node.type $CEL_NODETYPE --keyring-backend test --p2p.network $CEL_CHAINNAME | grep -e "^celestia")
echo "export CEL_WALLET_ADDR=$CEL_WALLET_ADDR" >> $HOME/.bash_profile
source $HOME/.bash_profile

# Initialize pre-configuration of your node
celestia $CEL_NODETYPE init --core.ip https://rpc-blockspacerace.pops.one --p2p.network $CEL_CHAINNAME

# Enable gateway
sed -i.bak -e "s/Enabled = .*/Enabled = true/" $HOME/.celestia-${CEL_NODETYPE}-blockspacerace-0/config.toml

# Setup systemD
sudo tee /etc/systemd/system/celestia-${CEL_NODETYPE}.service > /dev/null <<EOF
[Unit]
Description=celestia ${CEL_NODETYPE}
After=network-online.target

[Service]
User=$USER
ExecStart=$(which celestia) ${CEL_NODETYPE} start --core.ip https://rpc-blockspacerace.pops.one --gateway --gateway.addr 0.0.0.0 --gateway.port 26659 --keyring.accname ${CEL_WALLET} --p2p.network ${CEL_CHAINNAME} --metrics.tls=false --metrics --metrics.endpoint otel.celestia.tools:4318
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo -e "\n\033[0;32mStarting Celestia DA $CEL_NODETYPE node....\033[0m"; sleep 1;
sudo systemctl daemon-reload
sudo systemctl enable celestia-${CEL_NODETYPE}
sudo systemctl restart celestia-${CEL_NODETYPE}

sleep 10;

# Get info of Node ID and generate authentication token
AUTH_TOKEN=$(celestia $CEL_NODETYPE auth admin --p2p.network $CEL_CHAINNAME)
echo "export AUTH_TOKEN=$AUTH_TOKEN" >> $HOME/.bash_profile
source $HOME/.bash_profile

CEL_NODEID=$(curl -X POST -H "Authorization: Bearer $AUTH_TOKEN" -H 'Content-Type: application/json'  -d '{"jsonrpc":"2.0","id":0,"method":"p2p.Info","params":[]}' http://localhost:26658 | jq -r .result.ID)
echo "export CEL_NODEID=$CEL_NODEID"  >> $HOME/.bash_profile
source $HOME/.bash_profile


echo -e "\n\033[0;32mCongrat! You have finished setup of DA node\033[0m"; sleep 1;
echo -e "\nDetail info of your node:
- Chain-id: \033[0;31m${CEL_CHAINNAME}\033[0m
- Node type: \033[0;31m${CEL_NODETYPE}\033[0m
- Wallet name: \033[0;31m${CEL_WALLET}\033[0m
- Wallet addr: \033[0;31m${CEL_WALLET_ADDR}\033[0m
- Your nodeid: \033[0;31m${CEL_NODEID}\033[0m
"

#!/bin/sh
PLUGINS_DIR=/root/.btcpayserver/Plugins
PLUGIN_DIR=$PLUGINS_DIR/BTCPayServer.Plugins.MakePay
mkdir -p $PLUGIN_DIR
cd $PLUGIN_DIR
BASE=https://raw.githubusercontent.com/kraftstoffe/btcpay-coolify/master/plugins
wget -q $BASE/BTCPayServer.Plugins.MakePay.dll
wget -q $BASE/BTCPayServer.Plugins.MakePay.deps.json
wget -q $BASE/BTCPayServer.Plugins.MakePay.pdb
wget -q $BASE/BTCPayServer.Plugins.MakePay.staticwebassets.endpoints.json
echo "done"

#!/bin/sh
mkdir -p /root/.btcpayserver/Plugins/BTCPayServer.Plugins.MakePay
cd /root/.btcpayserver/Plugins/BTCPayServer.Plugins.MakePay
if [ ! -f BTCPayServer.Plugins.MakePay.dll ]; then
  wget -q -O /tmp/p.zip https://plugin-builder.btcpayserver.org/api/v1/plugins/makepay-payments/versions/1.7.5.0/download
  unzip -o /tmp/p.zip -d /root/.btcpayserver/Plugins/BTCPayServer.Plugins.MakePay
  rm /tmp/p.zip
fi
exec dotnet BTCPayServer.dll

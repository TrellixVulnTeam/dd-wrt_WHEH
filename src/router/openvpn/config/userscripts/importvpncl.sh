#!/bin/sh
# version: 0.3.0 beta, 19-aug-2022, by eibgrad
# for help download full script from eibgrads pastebin: curl -kLs bit.ly/ddwrt-installer|tr -d '\r'|sh -s -- --dir /tmp 2gg5ZdRY"
VAR_LIST='openvpncl_adv=0 openvpncl_auth=none openvpncl_blockmulticast=0 openvpncl_bridge=0 openvpncl_ca= openvpncl_certtype=0 openvpncl_cipher= openvpncl_client= \
openvpncl_config= openvpncl_dc1=CHACHA20-POLY1305 openvpncl_dc2=AES-128-GCM openvpncl_dc3=AES-256-GCM openvpncl_enable=0 openvpncl_fragment= openvpncl_fw=1 \
openvpncl_ip= openvpncl_key= openvpncl_killswitch=0 openvpncl_lzo=off openvpncl_mask= openvpncl_mit=1 openvpncl_mssfix=0 openvpncl_mtu=1400 openvpncl_multirem=0 \
openvpncl_nat=1 openvpncl_pkcs12= openvpncl_proto=udp4 openvpncl_randomsrv=0 openvpncl_remoteip=0.0.0.0 openvpncl_remoteport=1194 openvpncl_route= openvpncl_scramble=off \
openvpncl_scrmblpw=o54a72ReutDK openvpncl_spbr=0 openvpncl_splitdns=0 openvpncl_tls_btn=0 openvpncl_tlsauth= openvpncl_tlscip=0 openvpncl_tuntap=tun \
openvpncl_upauth=0 openvpncl_wdog=0 openvpncl_wdog_pingip=8.8.8.8 openvpncl_wdog_sleept=30'
UNVAR_LIST='openvpncl_pass openvpncl_remoteip2 openvpncl_remoteip3 openvpncl_remoteip4 openvpncl_remoteip5 openvpncl_remoteport2 openvpncl_remoteport3 \
openvpncl_remoteport4 openvpncl_remoteport5 openvpncl_static openvpncl_user '
PROTOCOL_LIST='udp udp4 udp6 tcp tcp4 tcp6 tcp-client tcp4-client tcp6-client'
CIPHER_LIST='CHACHA20-POLY1305 AES-256-GCM AES-192-GCM AES-128-GCM AES-256-CBC AES-192-CBC AES-128-CBC'
AUTH_LIST='sha512 sha256 sha1 md5 md4'
COMP_LZO_LIST='yes adaptive no'
COMPRESS_LIST='lz4 lz4-v2'
HANDLED_DIR_LIST='<ca> <cert> <key> <pkcs12> <secret> <tls-auth> <tls-crypt> auth auth-user-pass cipher comp-lzo compress data-cipher dev fragment \
key-direction mmsfix ncp-ciphers ns-cert-type pkcs12 port proto remote remote-cert-tls remote-random tls-auth tls-crypt verify-x509-name'
MAX_REMOTES=5
ADDN_CONFIG="/tmp/$(basename $0 .${0##*.}).$$.tmp"
total_remotes=0
default_port='1194'
to_lower() { echo "$@" | awk '{print tolower($0)}'; }
to_upper() { echo "$@" | awk '{print toupper($0)}'; }
get_field() { echo $line | awk "{print \$$1}"; }
get_textblock() {
sed -ne "/<$1>/,/<\/$1/{/<$1>/!{/<\/$1>/!p;};}" "$CONFIG_FILE" | \
sed  -r '/^[[:space:]]*(#|;|$)/d'
}
write_addn_config() { echo "$line" >> $ADDN_CONFIG; }
reset_nvram() {
local i
for i in $VAR_LIST; do nvram set "${i}"; done
for i in $UNVAR_LIST; do nvram unset "${i}"; done
[ ${nocommit+x} ] || nvram commit &>/dev/null
}
handle_auth() {
local auth="$(to_lower $(get_field 2))"
if echo $AUTH_LIST | grep -q "\\b$auth\\b"; then
nvram set openvpncl_auth="$auth"
else
write_addn_config
fi
}
handle_auth_user_pass() {
if [ "$(get_field 2)" ]; then
write_addn_config
else
nvram set openvpncl_upauth='1'
nvram set openvpncl_adv='1'
fi
}
handle_cipher() {
local i cipher="$(to_upper $(get_field 2))"
for i in 1 2 3; do nvram set openvpncl_dc${i}=''; done
if [ "$cipher" == 'NONE' ]; then
nvram set openvpncl_cipher='none'
nvram set openvpncl_dc1='none'
elif echo $CIPHER_LIST | grep -q "\\b$cipher\\b"; then
nvram set openvpncl_cipher="$cipher"
nvram set openvpncl_dc1="$cipher"
else
write_addn_config
fi
}
handle_comp_lzo() {
local comp_lzo="$(to_lower $(get_field 2))"
if [ ! "$comp_lzo" ]; then
nvram set openvpncl_lzo='adaptive'
nvram set openvpncl_adv='1'
elif echo $COMP_LZO_LIST | grep -q "\\b$comp_lzo\\b"; then
nvram set openvpncl_lzo="$comp_lzo"
nvram set openvpncl_adv='1'
else
write_addn_config
fi
}
handle_compress() {
local compress="$(to_lower $(get_field 2))"
if [ ! "$compress" ]; then
nvram set openvpncl_lzo='compress'
nvram set openvpncl_adv='1'
elif echo $COMPRESS_LIST | grep -q "\\b$compress\\b"; then
nvram set openvpncl_lzo="compress $compress"
nvram set openvpncl_adv='1'
else
write_addn_config
fi
}
handle_data_ciphers() {
local i cipher cipher_found
local ciphers="$(to_upper $(get_field 2 | tr ':' ' '))"
for i in 1 2 3; do nvram set openvpncl_dc${i}=''; done
[ "$ciphers" == 'NONE' ] && { nvram set openvpncl_dc1='none'; return; }
for i in 1 2 3; do
for cipher in $ciphers; do
if echo $CIPHER_LIST | grep -q "\\b$cipher\\b"; then
nvram set openvpncl_dc${i}="$cipher"
ciphers="$(echo $ciphers | sed s/\\b$cipher\\b//g)"
cipher_found=
continue 2
fi
done
break
done
[ ${cipher_found+x} ] || write_addn_config
}
handle_dev() {
local dev="$(to_lower $(get_field 2))"
if   [ "${dev:0:3}" == 'tun' ]; then
nvram set openvpncl_tuntap='tun'
elif [ "${dev:0:3}" == 'tap' ]; then
nvram set openvpncl_tuntap='tap'
nvram set openvpncl_bridge='1'
nvram set openvpncl_nat='0'
fi
}
handle_fragment() { nvram set openvpncl_fragment="$(get_field 2)"; }
handle_key_direction() {
[ "$(get_field 2)" != '1' ] && write_addn_config
}
handle_mssfix() { nvram set openvpncl_mssfix='1'; }
handle_ncp_ciphers() {
local i
for i in 1 2 3; do nvram set openvpncl_dc${i}=''; done
write_addn_config
}
handle_ns_cert_type() { handle_remote_cert_tls; }
handle_pkcs12() { [ "$(get_field 2)" ] && write_addn_config; }
handle_port() { default_port="$(get_field 2)"; }
handle_proto() {
local proto="$(to_lower $(get_field 2))"
if echo $PROTOCOL_LIST | grep -q "\\b$proto\\b"; then
proto="$(echo $proto | sed -r 's/^(udp|tcp)$/\14/;s/^tcp-/tcp4-/')"
proto="$(echo $proto | sed -r 's/^(tcp(|4|6))$/\1-client/')"
nvram set openvpncl_proto="$proto"
else
write_addn_config
fi
}
handle_remote() {
local ip="$(get_field 2)"
local port="$(get_field 3)"
local proto="$(to_lower $(get_field 4))"
if [ $((total_remotes)) -ge $MAX_REMOTES ]; then
write_addn_config
return
fi
if [[ ! "$proto" || "$proto" == "$(nvram get openvpncl_proto)" ]]; then
if [ $total_remotes -eq 0 ]; then
let $((total_remotes++))
nvram set openvpncl_remoteip="$ip"
[ "$port" ] && \
nvram set openvpncl_remoteport="$port" || \
nvram set openvpncl_remoteport="$default_port"
else
let $((total_remotes++))
nvram set openvpncl_remoteip${total_remotes}="$ip"
[ "$port" ] && \
nvram set openvpncl_remoteport${total_remotes}="$port" || \
nvram set openvpncl_remoteport${total_remotes}="$default_port"
nvram set openvpncl_multirem='1'
fi
else
write_addn_config
fi
}
handle_remote_cert_tls() {
if [ "$(to_lower $(get_field 2))" == 'server' ]; then
nvram set openvpncl_certtype='1'
nvram set openvpncl_adv='1'
fi
}
handle_tls_auth() { write_addn_config; }
handle_tls_crypt() { write_addn_config; }
handle_verify_x509_name() { write_addn_config; }
[ "$1" ] && CONFIG_FILE="$1" || CONFIG_FILE='/tmp/vpnupload.conf'
if [[ "$CONFIG_FILE" != '/dev/null' && ! -f "$CONFIG_FILE" ]]; then
echo "error: file not found: $CONFIG_FILE"
exit 1
fi
reset_nvram
[ -s "$CONFIG_FILE" ] || exit 0
grep -q '\r' "$CONFIG_FILE" && sed -i 's/\r//g' "$CONFIG_FILE"
nvram set openvpncl_enable='1'
lines="$(grep -E "^($(echo $HANDLED_DIR_LIST | \
tr ' ' '|'))([[:space:]]|$)" "$CONFIG_FILE")"
OIFS="$IFS"; IFS=$'\n'
for line in $lines; do
IFS="$OIFS"
dir="${line%%[[:space:]]*}"
case $dir in 'cipher'|'port'|'proto') handle_${dir//-/_};; esac
IFS=$'\n'
done
for line in $lines; do
IFS="$OIFS"
dir="${line%%[[:space:]]*}"
case $dir in
'cipher'|'port'|'proto') ;;
'<ca>') nvram set openvpncl_ca="$(get_textblock ca)";;
'<cert>') nvram set openvpncl_client="$(get_textblock cert)";;
'<key>') nvram set openvpncl_key="$(get_textblock key)";;
'<pkcs12>') nvram set openvpncl_pkcs12="$(get_textblock pkcs12)";;
'<secret>') nvram set openvpncl_static="$(get_textblock secret)";;
'<tls-auth>') nvram set openvpncl_tlsauth="$(get_textblock tls-auth)"
nvram set openvpncl_tls_btn='0';;
'<tls-crypt>') nvram set openvpncl_tlsauth="$(get_textblock tls-crypt)"
nvram set openvpncl_tls_btn='1';;
*) handle_${dir//-/_};;
esac
IFS=$'\n'
done
IFS="$OIFS"
[ -s $ADDN_CONFIG ] && nvram set openvpncl_config="$(cat $ADDN_CONFIG)"
[ ${nocommit+x} ] || nvram commit &>/dev/null
rm -f $ADDN_CONFIG
exit 0

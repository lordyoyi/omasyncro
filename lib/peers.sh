# Talking to the other machines over Tailscale.
#
# Every Linux machine on the tailnet that answers on $PORT is a peer: there is
# no list to maintain. One line per connection:
#   GET              -> the active state line
#   SET <state>      -> OK, then applied if newer
#   PULL             -> OK, then a library sync

# Prints "<ip> <hostname>" for each online Linux peer. Tests and unusual setups
# can set OMASYNCRO_PEERS="ip:port[=name] ...".
peers() {
  if [[ -n ${OMASYNCRO_PEERS:-} ]]; then
    local p
    for p in $OMASYNCRO_PEERS; do echo "${p%%=*} ${p#*=}"; done
    return
  fi
  tailscale status --json 2>/dev/null | jq -r '
    .Peer // {} | .[]
    | select(.Online and .OS == "linux")
    | [(.TailscaleIPs[] | select(test("^[0-9.]+$"))), .HostName] | @tsv' 2>/dev/null |
    while IFS=$'\t' read -r ip host; do echo "$ip:$PORT $host"; done
}

# send <ip:port> <line>: prints the first line of the reply.
send() {
  timeout 3 bash -c 'exec 3<>"/dev/tcp/${1%:*}/${1##*:}" && printf "%s\n" "$2" >&3 && head -n1 <&3' \
    _ "$1" "$2" 2>/dev/null
}

# Sends a line to every peer at once. Peers without omasyncro just refuse.
broadcast() {
  local ip host
  while read -r ip host; do
    send "$ip" "$1" >/dev/null &
  done < <(peers)
  wait
}

# One connection per instance (systemd Accept=yes); stdin/stdout are the socket.
serve() {
  local line ts origin theme bg
  # The socket only listens on the Tailscale address; this is a second fence.
  case ${REMOTE_ADDR:-} in
    "" | 127.0.0.1 | 100.*) ;;
    *) log "refused connection from $REMOTE_ADDR"; exit 1 ;;
  esac

  IFS= read -r -t 5 line || exit 0
  line=${line%$'\r'}
  case $line in
    GET)
      read_active
      active_line
      echo
      ;;
    SET$'\t'*)
      IFS=$'\t' read -r _ ts origin theme bg <<<"$line"
      echo OK
      exec >/dev/null </dev/null # hang up; applying a theme takes seconds
      active_offer "$ts" "$origin" "$theme" "$bg"
      ;;
    PULL)
      echo OK
      exec >/dev/null </dev/null
      library_sync
      ;;
    *) echo ERR ;;
  esac
}

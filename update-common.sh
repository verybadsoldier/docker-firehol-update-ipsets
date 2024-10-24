#!bin/sh

function should_skip {
  listname="$1"

  if [ -e "/etc/firehol/ipsets/$1.source" ]; then
    return 1
  fi

  for i in $FIREHOL_LISTS_SKIP; do
    if [ "$i" == $listname ]; then
        return 1
    fi
  done
  return 0
}


function add_rule_for_set {
  if [[ -z `${IPTABLES_CMD} -L FIREHOL_BLACKLIST | grep "match-set $1 src"` ]]; then
    ${IPTABLES_CMD} -I FIREHOL_BLACKLIST -m set --match-set $1 src -j DROP -m comment --comment "FireHOL: $1"
  fi
}

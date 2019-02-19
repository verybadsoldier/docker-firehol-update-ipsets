#!bin/sh

function should_skip {
  listname="$1"

  if [ -e "/etc/firehol/ipsets/$1.source" ]; then
    return 1
  fi

  for i in $SKIP_LISTS; do
    if [ "$i" == $listname ]; then
        return 1
    fi
  done
  return 0
}

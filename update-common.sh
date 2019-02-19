#!bin/sh

should_skip {
  listname="$1"
  for i in $SKIP_LISTS; do
    if [ "$i" == $listname ]; then
        return 1
    fi
  done
  return 0
}

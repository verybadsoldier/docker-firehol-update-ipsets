#!/bin/sh

docker run --name firehol-update-ipsets -it -d --restart=always --cap-add=NET_ADMIN --net=host verybadsoldier/firehol-update-ipsets

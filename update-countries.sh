#!/bin/bash
# Script to update IP Geo Scope lists for IPv4 AND IPv6
# Configurable via environment variables:
#   GEO_SCOPE_COUNTRIES: Space-separated ISO codes (default: de)
#   GEO_IPSET_NAME:      Base name of the ipset list (default: geo_scope)

# Configuration
COUNTRIES="${GEO_SCOPE_COUNTRIES:-de}"
IPSET_BASE="${GEO_IPSET_NAME:-geo_scope}"
MAXELEM=131072

if [[ -z "$COUNTRIES" ]]; then
    echo "Error: No countries specified in GEO_SCOPE_COUNTRIES."
    exit 1
fi

# Function to handle the update logic for a specific protocol family
update_set() {
    local family=$1       # inet (v4) or inet6 (v6)
    local set_name=$2     # e.g., geo_scope or geo_scope_v6
    local url_base=$3     # URL to download zones from

    local temp_set="tmp_${set_name}"
    local restore_file=$(mktemp)
    	
    echo "[$family] Starting update for set: $set_name"

    # Create temp set
    # Family determines if it stores IPv4 or IPv6 addresses
    ipset create "$temp_set" hash:net family "$family" hashsize 2048 maxelem $MAXELEM -exist
    ipset flush "$temp_set"

    # Loop through countries
    for country in $COUNTRIES; do
        # echo "  - Downloading $country ($family)..."
        
        # Download, filter for valid IPs (hex/colons for v6, dots/nums for v4), and format
        wget -qO - "${url_base}/${country}.zone" | \
        grep -E "^[0-9a-fA-F:.]" | \
        sed "s/^/add $temp_set /" >> "$restore_file"

        if [ ${PIPESTATUS[0]} -ne 0 ]; then
             echo "  ! Error downloading $country for $family from $url_base"
        fi
    done

    # Restore to temp set
    ipset restore < "$restore_file"

    # Create production set if missing
    ipset create "$set_name" hash:net family "$family" hashsize 2048 maxelem $MAXELEM -exist

    # Atomic Swap
    echo "  - Swapping $temp_set -> $set_name"
    ipset swap "$temp_set" "$set_name"

    # Cleanup
    ipset destroy "$temp_set"
    rm -f "$restore_file"
    
    local count=$(ipset list $set_name | grep 'Number of entries' | cut -d: -f2)
    echo "[$family] Success. Entries: $count"
}

# --- Execution ---

# 1. Update IPv4
update_set "inet" "${IPSET_BASE}" "http://www.ipdeny.com/ipblocks/data/countries"

# 2. Update IPv6
update_set "inet6" "${IPSET_BASE}_v6" "http://www.ipdeny.com/ipv6/ipaddresses/blocks"

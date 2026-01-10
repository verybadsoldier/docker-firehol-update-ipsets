#!/bin/bash
# Script to update IP Geo Scope (Country) lists
# Configurable via environment variables:
#   GEO_SCOPE_COUNTRIES: Space-separated ISO codes (default: de)
#   GEO_IPSET_NAME:      Name of the ipset list (default: geo_scope)

# Configuration
# Defaults are used if environment variables are not set
COUNTRIES="${GEO_SCOPE_COUNTRIES:-de}"
IPSET_NAME="${GEO_IPSET_NAME:-geo_scope}"

# Derived variables
TEMP_IPSET="${IPSET_NAME}_tmp"
MAXELEM=131072

# Safety check: Ensure we have at least one country
if [[ -z "$COUNTRIES" ]]; then
    echo "Error: No countries specified in GEO_SCOPE_COUNTRIES."
    exit 1
fi

echo "Starting update for Geo Scope: $COUNTRIES"
echo "Target IPSet: $IPSET_NAME"

# Create a temporary set
# We use 'create !' to avoid error if it exists, but we flush it to be sure it's clean
ipset create "$TEMP_IPSET" hash:net family inet hashsize 2048 maxelem $MAXELEM -exist
ipset flush "$TEMP_IPSET"

# Create a temporary file for the restore command
RESTORE_FILE=$(mktemp)

# Loop through countries and compile IPs
for country in $COUNTRIES; do
    echo "Downloading data for: $country"

    # Download directly to memory, filter for valid lines, and format for ipset restore
    # grep -E ensures we don't process HTML error pages
    wget -qO - "http://www.ipdeny.com/ipblocks/data/countries/$country.zone" | \
    grep -E "^[0-9]" | \
    sed "s/^/add $TEMP_IPSET /" >> "$RESTORE_FILE"

    # Check pipe status for the wget command
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Error: Failed to download list for $country. Aborting update."
        rm -f "$RESTORE_FILE"
        ipset destroy "$TEMP_IPSET"
        exit 1
    fi
done

echo "Restoring IPs to temporary set..."
ipset restore < "$RESTORE_FILE"

# Create the production set if it doesn't exist yet
# This ensures 'swap' has something to swap with
ipset create "$IPSET_NAME" hash:net family inet hashsize 2048 maxelem $MAXELEM -exist

echo "Swapping sets..."
# Atomic swap
ipset swap "$TEMP_IPSET" "$IPSET_NAME"

# Cleanup
ipset destroy "$TEMP_IPSET"
rm -f "$RESTORE_FILE"

echo "Success. Geo Scope updated."
echo "Total entries in $IPSET_NAME: $(ipset list $IPSET_NAME | grep 'Number of entries' | cut -d: -f2)"
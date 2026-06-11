#!/usr/bin/env bash
# Create + activate the three Support-tier subscriptions on Google Play.
#
# Mirrors the App Store products (pww_small/medium/large, monthly). Prices
# are anchored in SEK (matching Apple's SEK tiers for $1.99/$3.99/$5.99) and
# expanded to all Play regions via pricing:convertRegionPrices.
#
# DRY RUN by default: prints the resolved subscription JSON without creating.
# Pass --go to create and activate the base plans.
#
# Requires the merchant (payments) profile to exist on the developer account
# -- creation fails with a clear error otherwise.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=play-api.sh
. "$SCRIPT_DIR/play-api.sh"

# Play regions catalog version expected by the API; bump when Google rejects
# it (the error names the accepted version).
REGIONS_VERSION="2025/03"

GO=0
[ "${1:-}" = "--go" ] && GO=1

PLAY_TOKEN=$(play_token)
[ -n "$PLAY_TOKEN" ] || { echo "Could not mint Play access token" >&2; exit 1; }

# productId|title|SEK base price|benefit/description blurb
# Base prices are tax-EXCLUSIVE; convertRegionPrices adds Swedish VAT (25%),
# so 20/39/60 land at consumer prices ~25/49/75 kr -- matching Apple's SEK
# tiers for $1.99/$3.99/$5.99.
TIERS='pww_small|Small Supporter|20|A friendly nod to keep development caffeinated.
pww_medium|Medium Supporter|39|Helps cover developer account fees and signing costs.
pww_large|Large Supporter|60|Powers late-night feature sprints and new releases.'

echo "$TIERS" | while IFS='|' read -r PRODUCT_ID TITLE SEK BLURB; do
  echo "=== $PRODUCT_ID ($TITLE, $SEK SEK/month) ==="

  CONV=$(play_api POST "/pricing:convertRegionPrices" \
    -H "Content-Type: application/json" \
    -d "{\"price\": {\"currencyCode\": \"SEK\", \"units\": \"$SEK\"}}")
  play_check "$CONV" "pricing:convertRegionPrices"

  BODY=$(jq -n \
    --arg pkg "$PKG" --arg pid "$PRODUCT_ID" --arg title "$TITLE" --arg blurb "$BLURB" \
    --argjson conv "$CONV" \
    '{
      packageName: $pkg,
      productId: $pid,
      listings: [{
        languageCode: "en-US",
        title: $title,
        benefits: ["Supports ongoing development", "Purely cosmetic, nothing gated"],
        description: $blurb
      }],
      basePlans: [{
        basePlanId: "monthly",
        autoRenewingBasePlanType: {
          billingPeriodDuration: "P1M",
          gracePeriodDuration: "P14D",
          resubscribeState: "RESUBSCRIBE_STATE_ACTIVE",
          prorationMode: "SUBSCRIPTION_PRORATION_MODE_CHARGE_ON_NEXT_BILLING_DATE",
          legacyCompatible: true
        },
        regionalConfigs: [$conv.convertedRegionPrices[]
          | {regionCode: .regionCode, newSubscriberAvailability: true, price: .price}],
        otherRegionsConfig: {
          usdPrice: $conv.convertedOtherRegionsPrice.usdPrice,
          eurPrice: $conv.convertedOtherRegionsPrice.eurPrice,
          newSubscriberAvailability: true
        }
      }]
    }')

  if [ "$GO" -eq 0 ]; then
    jq -c '{productId, listings: [.listings[].title],
            regions: (.basePlans[0].regionalConfigs | length),
            sek: (.basePlans[0].regionalConfigs[] | select(.regionCode == "SE") | .price)}' <<<"$BODY"
    continue
  fi

  RESP=$(play_api POST "/subscriptions?productId=$PRODUCT_ID&regionsVersion.version=$REGIONS_VERSION" \
    -H "Content-Type: application/json" -d "$BODY")
  if jq -e '.error.status? == "ALREADY_EXISTS"' >/dev/null 2>&1 <<<"$RESP"; then
    echo "  already exists, skipping create"
  else
    play_check "$RESP" "subscriptions.create $PRODUCT_ID"
    echo "  created"
  fi

  RESP=$(play_api POST "/subscriptions/$PRODUCT_ID/basePlans/monthly:activate" \
    -H "Content-Type: application/json" -d '{}')
  play_check "$RESP" "basePlans.activate $PRODUCT_ID"
  echo "  base plan 'monthly' ACTIVE"
done

if [ "$GO" -eq 0 ]; then
  echo "DRY RUN done. Re-run with --go to create + activate."
else
  echo "=== Verifying ==="
  play_api GET "/subscriptions" |
    jq -c '.subscriptions[] | {productId, state: .basePlans[0].state}'
fi

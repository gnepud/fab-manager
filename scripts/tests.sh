#!/usr/bin/env bash

# Use this script to safely run the test suite after any database changes.
# This must be preferred over `rails test`.

stripe_public_key=${stripe_public_key:-${STRIPE_PUBLISHABLE_KEY:-}}
stripe_secret_key=${stripe_secret_key:-${STRIPE_API_KEY:-}}
oauth2_client_id=${oauth2_client_id:-${OAUTH_CLIENT_ID:-}}
oauth2_client_secret=${oauth2_client_secret:-${OAUTH_CLIENT_SECRET:-}}
oidc_client_id=${oidc_client_id:-${OIDC_CLIENT_ID:-}}
oidc_client_secret=${oidc_client_secret:-${OIDC_CLIENT_SECRET:-}}

if [[ -z "$stripe_public_key" || -z "$stripe_secret_key" || -z "$oauth2_client_id" || -z "$oauth2_client_secret" || -z "$oidc_client_id" || -z "$oidc_client_secret" ]]; then
  env_values=$(RAILS_ENV='test' bin/rails runner "puts [ENV['STRIPE_PUBLISHABLE_KEY'], ENV['STRIPE_API_KEY'], ENV['OAUTH_CLIENT_ID'], ENV['OAUTH_CLIENT_SECRET'], ENV['OIDC_CLIENT_ID'], ENV['OIDC_CLIENT_SECRET']]")
  stripe_public_key=${stripe_public_key:-$(sed -n '1p' <<< "$env_values")}
  stripe_secret_key=${stripe_secret_key:-$(sed -n '2p' <<< "$env_values")}
  oauth2_client_id=${oauth2_client_id:-$(sed -n '3p' <<< "$env_values")}
  oauth2_client_secret=${oauth2_client_secret:-$(sed -n '4p' <<< "$env_values")}
  oidc_client_id=${oidc_client_id:-$(sed -n '5p' <<< "$env_values")}
  oidc_client_secret=${oidc_client_secret:-$(sed -n '6p' <<< "$env_values")}
fi
if [[ -z "$stripe_public_key" ]]; then
  read -rp "STRIPE_PUBLISHABLE_KEY is not set. Please input the public key now. > " stripe_public_key </dev/tty
  if [[ -z "$stripe_public_key" ]]; then echo "Key was not set, exiting..."; exit 1; fi
fi

if [[ -z "$stripe_secret_key" ]]; then
  read -rp "STRIPE_API_KEY is not set. Please input the secret key now. > " stripe_secret_key </dev/tty
  if [[ -z "$stripe_secret_key" ]]; then echo "Key was not set, exiting..."; exit 1; fi
fi
if [[ -z "$oauth2_client_id" ]]; then
  read -rp "OAUTH_CLIENT_ID is not set. Please input the client ID now. > " oauth2_client_id </dev/tty
  if [[ -z "$oauth2_client_id" ]]; then echo "Key was not set, exiting..."; exit 1; fi
fi

if [[ -z "$oauth2_client_secret" ]]; then
  read -rp "OAUTH_CLIENT_SECRET is not set. Please input the client secret now. > " oauth2_client_secret </dev/tty
  if [[ -z "$oauth2_client_secret" ]]; then echo "Key was not set, exiting..."; exit 1; fi
fi
if [[ -z "$oidc_client_id" ]]; then
  read -rp "OIDC_CLIENT_ID is not set. Please input the client ID now. > " oidc_client_id </dev/tty
  if [[ -z "$oidc_client_id" ]]; then echo "Key was not set, exiting..."; exit 1; fi
fi

if [[ -z "$oidc_client_secret" ]]; then
  read -rp "OIDC_CLIENT_SECRET is not set. Please input the client secret now. > " oidc_client_secret </dev/tty
  if [[ -z "$oidc_client_secret" ]]; then echo "Key was not set, exiting..."; exit 1; fi
fi

STRIPE_PUBLISHABLE_KEY="$stripe_public_key" STRIPE_API_KEY="$stripe_secret_key" \
OAUTH_CLIENT_ID="$oauth2_client_id" OAUTH_CLIENT_SECRET="$oauth2_client_secret" \
OIDC_CLIENT_ID="$oidc_client_id" OIDC_CLIENT_SECRET="$oidc_client_secret" RAILS_ENV='test' bin/rails test "$@"

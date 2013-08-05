#!/bin/sh

# Parameter => STRING
# RESULT => echo ESCAPE_STR
function escape()
{
  local STR=$1
  local ESCAPE_STR=`echo -n ${STR} | sed -e 's/\//%2F/g' \
                                         -e 's/\+/%2B/g' \
                                         -e 's/:/%3A/g'  \
                                         -e 's/&/%26/g'  \
                                         -e 's/=/%3D/g'  `
  echo ${ESCAPE_STR}
}

# Parameter => BASE_STRING, KEY
# RESULT => echo SIGNATURE
function make_signature()
{
  local BASE_STRING=$1
  local KEY=$2
  local SIGNATURE=`echo -n ${BASE_STRING} | openssl dgst -sha1 -binary -hmac ${KEY} | base64`
  echo $SIGNATURE
}

# Parameter => CK, CS, TOKEN(string), TOKEN_SECRET(string)
# RESULT    => eval TOKEN, TOKEN_SECRET
function request_token()
{
  local CONSUMER_KEY=$1
  local CONSUMER_SECRET=$2
  local NONCE=`date +%N`
  local TIMESTAMP=`date +%s`
  local SIGNATURE_METHOD='HMAC-SHA1'
  local VERSION='1.0'
  local BASE_URL='https://api.twitter.com/oauth/request_token'

  local QUERY="oauth_consumer_key=${CONSUMER_KEY}&oauth_nonce=${NONCE}&oauth_signature_method=${SIGNATURE_METHOD}&oauth_timestamp=${TIMESTAMP}&oauth_version=${VERSION}"

  local ESCAPE_URL=`escape ${BASE_URL}`
  local ESCAPE_QUERY=`escape ${QUERY}`

  local BASE_STRING="GET&${ESCAPE_URL}&${ESCAPE_QUERY}"
  local SIGNATURE=`make_signature $BASE_STRING "${CONSUMER_SECRET}&"`
  local ESCAPE_SIGNATURE=`escape ${SIGNATURE}`

  local CURL_RESULT=`curl "${BASE_URL}?${QUERY}&oauth_signature=${ESCAPE_SIGNATURE}"`

  if [ "${CURL_RESULT}" = 'Failed to validate oauth signature and token' ]; then
    echo ${CURL_RESULT} 1>&2
    exit 1
  fi

  local F_OAUTH_TOKEN=`echo ${CURL_RESULT} | sed -E 's/^oauth_token=([a-zA-Z0-9]+)&.*$/\1/'`
  local F_OAUTH_TOKEN_SECRET=`echo ${CURL_RESULT} | sed -E 's/^.*oauth_token_secret=([a-zA-Z0-9]+)&.*$/\1/'`
  eval $3=$F_OAUTH_TOKEN
  eval $4=$F_OAUTH_TOKEN_SECRET
}

# Parameter => OAUTH_TOKEN, PIN(string)
# Result    => eval PIN
function get_pin()
{
  local REQUEST_TOKEN=$1
  echo "Please, access this URL: https://twitter.com/oauth/authorize?oauth_token=${REQUEST_TOKEN}"
  echo "and get the PIN code."
  echo -n "Enter your PIN code: "
  eval read $2
}

# Parameter => CONSUMER_KEY, CONSUMER_SECRET, REQUEST_TOKEN, REQUEST_TOKEN_SECRET, PIN, ACCESS_TOKEN(string), ACCESS_TOKEN_SECRET(string)
# Result => eval ACCESS_TOKEN, ACCESS_TOKEN_SECRET
function get_access_token()
{
  local CONSUMER_KEY=$1
  local CONSUMER_SECRET=$2
  local REQUEST_TOKEN=$3
  local REQUEST_TOKEN_SECRET=$4
  local PIN=$5
  local NONCE=`date +%N`
  local TIMESTAMP=`date +%s`
  local SIGNATURE_METHOD='HMAC-SHA1'
  local VERSION='1.0'
  local BASE_URL='https://twitter.com/oauth/access_token'

  local QUERY="oauth_consumer_key=${CONSUMER_KEY}&oauth_nonce=${NONCE}&oauth_signature_method=${SIGNATURE_METHOD}&oauth_timestamp=${TIMESTAMP}&oauth_token=${REQUEST_TOKEN}&oauth_verifier=${PIN}&oauth_version=${VERSION}"

  local ESCAPE_URL=`escape ${BASE_URL}`
  local ESCAPE_QUERY=`escape ${QUERY}`

  local BASE_STRING="GET&${ESCAPE_URL}&${ESCAPE_QUERY}"
  local SIGNATURE=`make_signature $BASE_STRING "${CONSUMER_SECRET}&${REQUEST_TOKEN_SECRET}"`
  local ESCAPE_SIGNATURE=`escape ${SIGNATURE}`
  local CURL_RESULT=`curl "${BASE_URL}?${QUERY}&oauth_signature=${ESCAPE_SIGNATURE}"`

  if [ "${CURL_RESULT}" = 'Failed to validate oauth signature and token' ]; then
    echo ${CURL_RESULT} 1>&2
    exit 1
  fi

  local F_ACCESS_TOKEN=`echo ${CURL_RESULT} | sed -E 's/^oauth_token=([a-zA-Z0-9]+-[a-zA-Z0-9]+)&.*$/\1/'`
  local F_ACCESS_TOKEN_SECRET=`echo ${CURL_RESULT} | sed -E 's/^.*oauth_token_secret=([a-zA-Z0-9]+)&.*$/\1/'`
  eval $6=$F_ACCESS_TOKEN
  eval $7=$F_ACCESS_TOKEN_SECRET
}

CONSUMER_KEY='y6kkE5CIMQaNkObjLPTA'
CONSUMER_SECRET='GvOfYPAfl97UldithrdnlbdL6Xzfxfhv08UYgmNAY'

request_token $CONSUMER_KEY $CONSUMER_SECRET OAUTH_TOKEN OAUTH_TOKEN_SECRET

get_pin $OAUTH_TOKEN PIN
echo "PIN is ${PIN}"

get_access_token $CONSUMER_KEY $CONSUMER_SECRET $OAUTH_TOKEN $OAUTH_TOKEN_SECRET $PIN ACCESS_TOKEN ACCESS_TOKEN_SECRET

echo $ACCESS_TOKEN
echo $ACCESS_TOKEN_SECRET

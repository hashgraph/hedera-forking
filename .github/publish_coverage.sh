#!/bin/bash

input=$(cat)

extract_table() {
  # Extract the table from the input:
  local table=$(echo "$input" | awk "/$1/ {flag=1} flag" | awk '!/╰/{print} /╰/ {exit}' | sed 's/+/|/g')

  # Replace the second line with the fourth line, and remove duplicate separator lines (keep only the first occurrence):
  echo "$(echo "$table" \
    | awk -v line4="$(echo "$table" | sed -n '4p')" 'NR==2 {$0=line4} 1' \
    | awk -v sep="$(echo "$table" | sed -n '4p')" '$0==sep{if(!found){found=1;print;} next;}{print}')"
}

comment_content=$(echo -e "$(extract_table "Test Suite")\n\n$(extract_table "% Statements")")

curl -L -X POST -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$GITHUB_PR_NUMBER/comments" \
  -d "$(jq -n --arg body "$comment_content" '{"body": $body'})"

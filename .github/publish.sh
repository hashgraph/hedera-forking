#!/bin/bash


input=$(cat)
processed_output=$(echo "$input" | awk '/Test Summary:/ {flag=1; next} flag' | tail -n +3 | awk '!/╰/{print} /╰/ {exit}' | sed 's/+/|/g')
line4=$(echo "$processed_output" | sed -n '4p')
modified_output=$(echo "$processed_output" | awk -v line4="$line4" 'NR==2 {$0=line4} 1')
final_output=$(echo -e "$modified_output\n\n$(echo "$input" | awk '/-╯/ {flag=1; next} flag')")
curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
  -X POST "https://api.github.com/repos/hedera-forking/issues/$GITHUB_PR_NUMBER/comments" \
  -d "{\"body\":\"TEST CONTENT\"}"

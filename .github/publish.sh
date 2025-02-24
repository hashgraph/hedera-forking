#!/bin/bash

input=$(cat)

test_summary=$(echo "$input" | awk '/Test Suite/ {flag=1} flag' |  awk '!/╰/{print} /╰/ {exit}' | sed 's/+/|/g')
test_summary_line4=$(echo "$test_summary" | sed -n '4p')
modified_test_summary=$(echo "$test_summary" | awk -v line4="$test_summary_line4" 'NR==2 {$0=line4} 1')

test_coverage=$(echo "$input" | awk '/\%\ Statements/ {flag=1} flag' |  awk '!/╰/{print} /╰/ {exit}' | sed 's/+/|/g')
test_coverage_line4=$(echo "$test_coverage" | sed -n '4p')
modified_test_coverage=$(echo "$test_coverage" | awk -v line4="$test_coverage_line4" 'NR==2 {$0=line4} 1')

final_output=$(echo -e "$modified_test_summary\n\n$modified_test_coverage")
comment_json=$(jq -n --arg body "$final_output" '{"body": $body'})

curl -L \
  -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$GITHUB_PR_NUMBER/comments" \
  -d "$comment_json"

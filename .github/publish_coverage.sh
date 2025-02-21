#!/bin/bash

GITHUB_TOKEN=""

PR_BASE_SHA=$(jq -r .pull_request.base.sha < "$GITHUB_EVENT_PATH")
PR_HEAD_SHA=$(jq -r .pull_request.head.sha < "$GITHUB_EVENT_PATH")

#get_changed_files() {
#    echo "Fetching changed files..."
  # PR_BASE_SHA=$(jq -r .pull_request.base.sha < "$GITHUB_EVENT_PATH")
   # PR_HEAD_SHA=$(jq -r .pull_request.head.sha < "$GITHUB_EVENT_PATH")
   # CHANGED_FILES=$(curl -s -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" \
    #    "$GITHUB_API/repos/$GITHUB_REPO/compare/$PR_BASE_SHA...$PR_HEAD_SHA" | jq -r '.files[].filename')
#}

calculate_lcov() {
    TOTAL_LINES_FOUND=0
    TOTAL_LINES_HIT=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^LF:(.*) ]]; then
            TOTAL_LINES_FOUND=$((TOTAL_LINES_FOUND + BASH_REMATCH[1]))
        elif [[ "$line" =~ ^LH:(.*) ]]; then
            TOTAL_LINES_HIT=$((TOTAL_LINES_HIT + BASH_REMATCH[1]))
        fi
    done < "lcov.info"
    if [[ "$TOTAL_LINES_FOUND" -eq 0 ]]; then
        echo "0.0"
    else
        echo "scale=2; ($TOTAL_LINES_HIT * 100) / $TOTAL_LINES_FOUND" | bc
    fi
}

coverage_ok() {
    local coverage_value="$1"
    if (( $(echo "$coverage_value >= 70" | bc -l) )); then
        echo "✅"
    else
        echo "❌"
    fi
}

ALL_FILES_COVERAGE=$(calculate_lcov)
CHANGED_FILES_COVERAGE="N/A"
CHANGED_FILES=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/hashgraph/hedera-forking/compare/871796bf3d8d9b920df6775714e34fa33fcc850a...2167c3d0db414f91ed33bf229e0891472a99afc7" | jq -r '.files[].filename')

if [[ -n "$CHANGED_FILES" ]]; then
    CHANGED_FILES_COVERAGE=$(calculate_lcov)
    if (( $(echo "CHANGED_FILES_COVERAGE >= 70" | bc -l) )); then
      echo "✅"
    else
      echo "❌"
    fi
    echo "Changed Files Coverage: $CHANGED_FILES_COVERAGE%"
fi


COMMENT_ID="[coverage-comment-id]: <> ($COMMENT_TITLE)"
COMMENT_BODY="$COMMENT_ID"$'\n\n'"## Coverage Report - $COMMENT_TITLE"$'\n\n'"### All Files Coverage: $(calculate_lcov | coverage_ok)"$'\n'
   # curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
   #     -X POST "https://api.github.com/repos/hedera-forking/issues/$GITHUB_PR_NUMBER/comments" \
   #     -d "{\"body\": \"$COMMENT_BODY\"}"
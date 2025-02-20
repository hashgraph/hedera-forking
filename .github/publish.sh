#!/bin/bash

# Define the coverage output file
COVERAGE_OUTPUT="coverage.log"
awk '/Test Summary:/ {flag=1; next} flag' "$COVERAGE_OUTPUT" | tail -n +3 | awk '!/╰/{print} /╰/ {exit}' | sed 's/+/|/g' > tmp

sed '2s/.*/'"$(sed -n '4p' tmp)"'/g' tmp > output.txt
echo "" >> output.txt
awk '/-╯/ {flag=1; next} flag' $COVERAGE_OUTPUT >> output.txt
rm tmp
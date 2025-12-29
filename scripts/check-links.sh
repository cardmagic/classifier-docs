#!/usr/bin/env bash
#
# check-links.sh - Check for broken links in markdown files
#
# Usage:
#   ./scripts/check-links.sh                    # Check all links
#   ./scripts/check-links.sh --skip-external    # Skip external URL checks
#   ./scripts/check-links.sh --fix              # Fix broken links using Claude
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONTENT_DIR="$ROOT_DIR/src/content"

FIX_MODE=false
SKIP_EXTERNAL=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Temp files
BROKEN_FILE=$(mktemp)
trap 'rm -f "$BROKEN_FILE"' EXIT

# Parse arguments
for arg in "$@"; do
    case $arg in
        --fix) FIX_MODE=true ;;
        --skip-external) SKIP_EXTERNAL=true ;;
        -h|--help)
            echo "Usage: $0 [--fix] [--skip-external]"
            echo ""
            echo "Options:"
            echo "  --fix            Fix broken links using Claude"
            echo "  --skip-external  Skip checking external URLs (faster)"
            exit 0
            ;;
    esac
done

# Check if internal path exists
check_internal_path() {
    local url="$1"
    local path="${url%%#*}"  # Remove anchor

    # Handle different path patterns
    if [[ "$path" =~ ^/docs/guides/([^/]+)/([^/]+)$ ]]; then
        local category="${BASH_REMATCH[1]}"
        local slug="${BASH_REMATCH[2]}"
        [[ -f "$CONTENT_DIR/guides/$category/$slug.md" ]] && return 0
    elif [[ "$path" =~ ^/docs/tutorials/([^/]+)$ ]]; then
        local slug="${BASH_REMATCH[1]}"
        [[ -f "$CONTENT_DIR/tutorials/$slug.md" ]] && return 0
    elif [[ "$path" =~ ^/docs/?$ ]]; then
        return 0  # Docs index always exists
    elif [[ "$path" == "/" ]]; then
        return 0  # Home page always exists
    fi

    return 1
}

# Check external URL
check_external_url() {
    local url="$1"
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -L "$url" 2>/dev/null || echo "000")
    [[ "$status" != "000" ]] && [[ "$status" -lt 400 ]]
}

# Process a single markdown file
process_file() {
    local file="$1"
    local relative="${file#$ROOT_DIR/}"
    local has_errors=false

    # Extract all markdown links [text](url)
    while IFS= read -r line; do
        local line_num="${line%%:*}"
        local content="${line#*:}"

        # Extract URL from [text](url)
        local url
        url=$(echo "$content" | sed -E 's/.*\[([^]]*)\]\(([^)]+)\).*/\2/')

        # Skip if extraction failed
        [[ "$url" == "$content" ]] && continue
        [[ -z "$url" ]] && continue

        local status="ok"
        local link_type="internal"

        if [[ "$url" == http://* ]] || [[ "$url" == https://* ]]; then
            link_type="external"
            if [[ "$SKIP_EXTERNAL" == "false" ]]; then
                if ! check_external_url "$url"; then
                    status="broken"
                fi
            else
                continue
            fi
        elif [[ "$url" == mailto:* ]] || [[ "$url" == tel:* ]] || [[ "$url" == "#"* ]]; then
            continue
        elif [[ "$url" == /* ]]; then
            if ! check_internal_path "$url"; then
                status="broken"
            fi
        fi

        if [[ "$status" == "broken" ]]; then
            has_errors=true
            echo -e "  ${RED}✗${NC} Line ${line_num}: ${YELLOW}${url}${NC} (${link_type})"
            echo "${relative}|${line_num}|${url}|${link_type}" >> "$BROKEN_FILE"
        fi
    done < <(/usr/bin/grep -noE '\[[^]]+\]\([^)]+\)' "$file" 2>/dev/null || true)

    $has_errors && return 1 || return 0
}

# Fix broken links using Claude
fix_broken_links() {
    [[ ! -s "$BROKEN_FILE" ]] && return 0

    echo ""
    echo -e "${BLUE}Fixing broken links with Claude...${NC}"
    echo ""

    # Build prompt from broken links
    local prompt="Fix the broken links in this repository's markdown files.

The following broken links were found:

"
    local current_file=""
    while IFS='|' read -r file line url type; do
        if [[ "$file" != "$current_file" ]]; then
            current_file="$file"
            prompt+="
## $file
"
        fi
        prompt+="- Line $line: $url ($type)
"
    done < "$BROKEN_FILE"

    prompt+="
For each broken link:
1. Read the file containing the broken link
2. Search the codebase to find the correct path
3. Use the Edit tool to fix the link

Focus on internal links first. For /docs/guides/X/Y paths, check src/content/guides/X/Y.md exists.
For /docs/tutorials/X paths, check src/content/tutorials/X.md exists."

    cd "$ROOT_DIR"
    echo "$prompt" | claude --dangerously-skip-permissions -p
}

# Main
main() {
    echo "========================================"
    echo "     Markdown Link Checker"
    echo "========================================"
    echo ""

    local files_checked=0
    local files_with_errors=0

    # Process all markdown files
    while IFS= read -r -d '' file; do
        local relative="${file#$ROOT_DIR/}"
        echo -e "${BLUE}Checking:${NC} $relative"

        if ! process_file "$file"; then
            ((files_with_errors++)) || true
        fi
        ((files_checked++)) || true
    done < <(find "$CONTENT_DIR" -name "*.md" -type f -print0 2>/dev/null)

    echo ""
    echo "Checked $files_checked files, $files_with_errors with issues."
    echo ""
    echo "========================================"
    echo "        LINK CHECK SUMMARY"
    echo "========================================"
    echo ""

    if [[ ! -s "$BROKEN_FILE" ]]; then
        echo -e "${GREEN}All links are valid!${NC}"
        return 0
    fi

    local count
    count=$(wc -l < "$BROKEN_FILE" | tr -d ' ')
    echo -e "${RED}Found ${count} broken link(s):${NC}"
    echo ""

    local current_file=""
    while IFS='|' read -r file line url type; do
        if [[ "$file" != "$current_file" ]]; then
            current_file="$file"
            echo -e "${BLUE}$file${NC}"
        fi
        echo "  Line ${line}: ${url} (${type})"
    done < "$BROKEN_FILE"

    echo ""
    if [[ "$FIX_MODE" == "true" ]]; then
        fix_broken_links
    else
        echo "Run with --fix to attempt automatic repair."
    fi

    return 1
}

main

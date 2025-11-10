#!/bin/bash

# ANSI Color codes (using $'...' syntax for compatibility with bash and zsh)
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
BOLD_GREEN=$'\033[1;32m'
BOLD=$'\033[1m'
NC=$'\033[0m' # No Color
CYAN=$'\033[0;36m'
GRAY=$'\033[0;90m'

SESSION_MANAGER_TEMPLATE="${AWS_HELPERS_DIR}/templates/SessionManagerRunShell.json"

# Clear the terminal screen
clear_terminal() {
    reset && clear
}

# Get AWS credentials and account information
get_credentials() {
    local current_region="${AWS_DEFAULT_REGION:-us-east-1}"

    # Get caller identity from AWS STS
    local response
    response=$(aws sts get-caller-identity --region "$current_region" 2>&1)

    # Check if the command was successful
    if [ $? -ne 0 ]; then
        echo "AWS Credentials not available"
        return 1
    fi

    # Return the response
    echo "$response"
}

# Create and display table with AWS information
create_and_display_table() {
    local response="$1"
    local current_region="$2"

    # Extract values from JSON response (requires jq)
    local aws_account_id
    local aws_arn
    local user_id

    aws_account_id=$(echo "$response" | jq -r '.Account')
    aws_arn=$(echo "$response" | jq -r '.Arn')
    user_id=$(echo "$response" | jq -r '.UserId')

    local aws_profile="${AWS_PROFILE:-default}"

    # Format account ID as XXXX-XXXX-XXXX
    local formatted_account_id="${aws_account_id:0:4}-${aws_account_id:4:4}-${aws_account_id:8:4}"

    # Table dimensions
    local col1_width=18
    local col2_width=100
    local total_inner_width=$((col1_width + col2_width + 2))

    # Helper function to create a line of characters
    create_line() {
        local char="$1"
        local width="$2"
        local i=0
        while [ $i -lt "$width" ]; do
            printf "%s" "$char"
            i=$((i + 1))
        done
    }

    # Top border
    printf "%s╭" "${BOLD_GREEN}"
    create_line "─" "$total_inner_width"
    printf "╮%s\n" "${NC}"

    # Header row
    local header_col2_width=$((col2_width - 3))
    printf "%s│%s %-${col1_width}s %s│ %-${header_col2_width}s %s│%s\n" \
        "${BOLD_GREEN}" "${BOLD_GREEN}" "Info" "${BOLD_GREEN}" \
        "Value" "${BOLD_GREEN}" "${NC}"

    # Header separator
    printf "%s├" "${BOLD_GREEN}"
    create_line "─" "$total_inner_width"
    printf "┤%s\n" "${NC}"

    # Data rows
    print_table_row "Account" "$RED$formatted_account_id$NC" "$col1_width" "$col2_width"
    print_table_row "Profile" "$BLUE$aws_profile$NC" "$col1_width" "$col2_width"
    print_table_row "Region" "$CYAN$current_region$NC" "$col1_width" "$col2_width"
    print_table_row "Identity ARN" "$RED$aws_arn$NC" "$col1_width" "$col2_width"
    print_table_row "User ID" "$user_id" "$col1_width" "$col2_width"

    # Bottom border
    printf "%s╰" "${BOLD_GREEN}"
    create_line "─" "$total_inner_width"
    printf "╯%s\n" "${NC}"
}

# Helper function to print table rows
print_table_row() {
    local label="$1"
    local value="$2"
    local col1_width="$3"
    local col2_width="$4"

    # Strip ANSI color codes from value to get true length
    local value_clean=$(echo "$value" | sed 's/\x1b\[[0-9;]*m//g')
    local value_len=${#value_clean}

    # Calculate padding needed for value column
    local padding=$((col2_width - value_len - 2))

    # Ensure minimum padding
    if [ $padding -lt 0 ]; then
        padding=0
    fi

    # Print row with proper alignment
    printf "%s│%s %-${col1_width}s %s│ %s%${padding}s%s│%s\n" \
        "${BOLD_GREEN}" "${BOLD_GREEN}" "$label" "${BOLD_GREEN}" \
        "$value" "" "${BOLD_GREEN}" "${NC}"
}

select_profile() {
    local temp_map="$1"
    local count=0
    local choice_line=""

    # Count profiles
    count=$(wc -l < "$temp_map")

    if [ "$count" -eq 0 ]; then
        printf "%sError: No profiles found in ~/.aws/config%s\n" "${RED}" "${NC}"
        printf "%sDebug: Make sure your AWS config has sso_account_id and region set for each profile%s\n" "${GRAY}" "${NC}"
        printf "%sExample format:%s\n" "${BLUE}" "${NC}"
        printf "[profile my-profile]\n"
        printf "sso_account_id = 123456789012\n"
        printf "region = us-east-1\n"
        return 1
    fi

    printf "\n%sAvailable AWS Profiles:%s\n" "${BOLD_GREEN}" "${NC}"

    local line_num=1
    while IFS=':' read -r account profile region; do
        printf "  %s[%d]%s %s (Account: %s, Region: %s)\n" \
            "${BLUE}" "$line_num" "${NC}" \
            "$profile" "$account" "$region"
        line_num=$((line_num + 1))
    done < "$temp_map"

    printf "\n%sSelect a profile [1-%d]: %s" "${BOLD}" "$count" "${NC}"
    read -r choice

    # Validate choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ]; then
        printf "%sInvalid selection.%s\n" "${RED}" "${NC}"
        return 1
    fi

    # Get the selected line from the temp_map
    choice_line=$(sed -n "${choice}p" "$temp_map")

    # Parse the line
    local account profile region
    IFS=':' read -r account profile region <<< "$choice_line"

    # Export the selected profile and region
    export AWS_PROFILE="$profile"
    export AWS_DEFAULT_PROFILE="$profile"
    export AWS_REGION="$region"
    export AWS_DEFAULT_REGION="$region"
    export AWS_ACCOUNT_ID="$account"

    printf "%sSelected profile: %s%s (Account: %s%s)\n" \
        "${GREEN}" "${BOLD}" "$AWS_PROFILE" "${NC}" "$AWS_ACCOUNT_ID"
}

create_ssm_session_manager() {
    if ! aws ssm describe-document --name "SSM-SessionManagerRunShell" > /dev/null 2>&1; then
        echo "The SSM session manager document does not exist. Creating it..."
        echo "file://${SESSION_MANAGER_TEMPLATE}"
        MESSAGE=$(aws ssm create-document \
            --name SSM-SessionManagerRunShell \
            --content "file://${SESSION_MANAGER_TEMPLATE}" \
            --document-type "Session" \
            --document-format JSON 2>&1 | grep -q "DocumentAlreadyExists")

        if [ $? -eq 0 ] || echo "$MESSAGE" | grep -q "DocumentAlreadyExists"; then
            echo "The SSM session manager document is ready"
        else
            echo "Failed to create the SSM session manager document"
            echo "Error: $MESSAGE"
            exit 1
        fi
    fi
}

aws_session() {
    # Check if jq is installed
    if ! command -v jq > /dev/null 2>&1; then
        printf "%sError: jq is required to parse AWS response. Please install jq.%s\n" "${RED}" "${NC}"
        exit 1
    fi

    # Check if aws cli is installed
    if ! command -v aws > /dev/null 2>&1; then
        printf "%sError: AWS CLI is required. Please install it.%s\n" "${RED}" "${NC}"
        exit 1
    fi

    # Check if config file exists
    if [ ! -f "$HOME/.aws/config" ]; then
        printf "%sError: ~/.aws/config not found%s\n" "${RED}" "${NC}"
        return 1
    fi

    # Build the account ID to profile mapping
    local temp_map=$(mktemp)
    trap "rm -f $temp_map" EXIT

    local current_profile=""
    local current_account=""
    local current_region=""

    while IFS= read -r line; do
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Skip empty lines and comments
        [ -z "$line" ] && continue

        # When we hit a new section header, save the previous profile
        if echo "$line" | grep -q '^\['; then
            if [ -n "$current_account" ]; then
                echo "$current_account:$current_profile:$current_region" >> "$temp_map"
            fi

            # Extract the new profile name
            if echo "$line" | grep -q '^\[profile '; then
                current_profile=$(echo "$line" | sed 's/^\[profile \([^]]*\)\].*/\1/')
            elif echo "$line" | grep -q '^\[default\]'; then
                current_profile="default"
            fi
            current_account=""
            current_region=""
            continue
        fi

        # Extract sso_account_id
        if echo "$line" | grep -q '^sso_account_id'; then
            current_account=$(echo "$line" | sed 's/^sso_account_id[[:space:]]*=[[:space:]]*\([^[:space:]]*\).*/\1/')
        fi

        # Extract region
        if echo "$line" | grep -q '^region'; then
            current_region=$(echo "$line" | sed 's/^region[[:space:]]*=[[:space:]]*\([^[:space:]]*\).*/\1/')
        fi
    done < "$HOME/.aws/config"

    # Don't forget the last profile
    if [ -n "$current_account" ]; then
        echo "$current_account:$current_profile:$current_region" >> "$temp_map"
    fi

    # Ask user to select a profile
    select_profile "$temp_map"
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Check if already authenticated
    local response
    response=$(aws sts get-caller-identity --profile "$AWS_PROFILE" 2>&1)

    if [ $? -ne 0 ]; then
        printf "%s%s%s\n" "${BOLD_GREEN}" "AWS credentials not available. Initiating SSO login..." "${NC}"
        aws sso login --profile "$AWS_PROFILE"

        # Try again after login
        response=$(aws sts get-caller-identity --profile "$AWS_PROFILE" 2>&1)
        if [ $? -ne 0 ]; then
            printf "%s%s%s\n" "${RED}" "Failed to authenticate" "${NC}"
            printf "%s%s%s\n" "${RED}" "$response" "${NC}"
            return 1
        fi
    fi

    printf "%sSuccessfully authenticated with profile: %s%s\n" "${GREEN}" "${BOLD}" "${AWS_PROFILE}${NC}"

    if [ $? -eq 0 ]; then
        create_ssm_session_manager
        clear_terminal
        create_and_display_table "$response" "$AWS_REGION"
    else
        printf "%s%s%s\n" "${RED}" "$response" "${NC}"
        exit 1
    fi

    export PROMPT="%F{green}${LOGNAME}@${AWS_ACCOUNT_ID}:${AWS_PROFILE}:${AWS_DEFAULT_REGION}%f %F{blue}%~%f
> "
}

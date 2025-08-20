#!/bin/bash
# Script: generate-test-data.sh
# Purpose: Generate comprehensive test data for LDAP with full user attributes
# Usage: ./generate-test-data.sh [number_of_users]

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Default values
NUM_USERS=${1:-10}
OUTPUT_FILE="test-users-$(date +%Y%m%d-%H%M%S).ldif"

# Arrays for generating random data
FIRST_NAMES=("John" "Jane" "Michael" "Sarah" "David" "Emma" "Robert" "Lisa" "James" "Mary" "William" "Patricia" "Richard" "Jennifer" "Thomas" "Linda")
LAST_NAMES=("Smith" "Johnson" "Williams" "Brown" "Jones" "Garcia" "Miller" "Davis" "Rodriguez" "Martinez" "Hernandez" "Lopez" "Gonzalez" "Wilson" "Anderson" "Taylor")
DEPARTMENTS=("IT Department" "Sales" "Marketing" "Engineering" "Human Resources" "Finance" "Operations" "Customer Service" "Research" "Legal" "Product Management" "Quality Assurance")
TITLES=("Manager" "Senior Developer" "Developer" "Analyst" "Specialist" "Coordinator" "Administrator" "Engineer" "Consultant" "Director" "Lead" "Architect")
CITIES=("San Francisco" "New York" "Los Angeles" "Chicago" "Houston" "Phoenix" "Philadelphia" "San Antonio" "San Diego" "Dallas" "Austin" "Seattle" "Portland" "Denver" "Boston" "Miami")
STATES=("CA" "NY" "TX" "IL" "AZ" "PA" "FL" "WA" "OR" "CO" "MA")
EMPLOYEE_TYPES=("Full-Time" "Part-Time" "Contractor" "Intern" "Consultant" "Temporary")

# Function to generate random phone number
generate_phone() {
    echo "+1-555-$(printf "%04d" $((RANDOM % 10000)))"
}

# Function to generate random employee number
generate_emp_number() {
    echo "EMP$(printf "%06d" $((RANDOM % 1000000)))"
}

# Function to generate random department number
generate_dept_number() {
    local dept=$1
    case "$dept" in
        "IT Department") echo "IT$(printf "%03d" $((RANDOM % 100)))" ;;
        "Sales") echo "SAL$(printf "%03d" $((RANDOM % 100)))" ;;
        "Marketing") echo "MKT$(printf "%03d" $((RANDOM % 100)))" ;;
        "Engineering") echo "ENG$(printf "%03d" $((RANDOM % 100)))" ;;
        "Human Resources") echo "HR$(printf "%03d" $((RANDOM % 100)))" ;;
        "Finance") echo "FIN$(printf "%03d" $((RANDOM % 100)))" ;;
        *) echo "DEPT$(printf "%03d" $((RANDOM % 100)))" ;;
    esac
}

# Function to generate random address
generate_address() {
    echo "$((RANDOM % 9999)) $(shuf -n1 -e "Main" "Oak" "Pine" "Maple" "Cedar" "Elm" "View" "Park" "Hill" "Lake") $(shuf -n1 -e "Street" "Avenue" "Road" "Boulevard" "Lane" "Drive" "Way" "Place")"
}

# Function to generate a single user LDIF entry
generate_user() {
    local uid=$1
    local base_dn=$2
    
    # Random data selection
    local first_name="${FIRST_NAMES[$((RANDOM % ${#FIRST_NAMES[@]}))]}"
    local last_name="${LAST_NAMES[$((RANDOM % ${#LAST_NAMES[@]}))]}"
    local full_name="$first_name $last_name"
    local email="$(echo ${first_name,,}.${last_name,,} | tr -d ' ')@example.com"
    local department="${DEPARTMENTS[$((RANDOM % ${#DEPARTMENTS[@]}))]}"
    local title="${TITLES[$((RANDOM % ${#TITLES[@]}))]} - $department"
    local city="${CITIES[$((RANDOM % ${#CITIES[@]}))]}"
    local state="${STATES[$((RANDOM % ${#STATES[@]}))]}"
    local emp_type="${EMPLOYEE_TYPES[$((RANDOM % ${#EMPLOYEE_TYPES[@]}))]}"
    
    cat <<EOF
# Test User $uid - $full_name
dn: uid=$uid,ou=users,$base_dn
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: $uid
cn: $full_name
sn: $last_name
givenName: $first_name
displayName: $full_name - $title
mail: $email
telephoneNumber: $(generate_phone)
mobile: $(generate_phone)
title: $title
ou: $department
departmentNumber: $(generate_dept_number "$department")
employeeNumber: $(generate_emp_number)
employeeType: $emp_type
description: Test user account for $full_name in $department
street: $(generate_address)
l: $city
st: $state
postalCode: $(printf "%05d" $((RANDOM % 100000)))
preferredLanguage: en-US
userPassword: TestPass$(printf "%03d" $((RANDOM % 1000)))!

EOF
}

# Main function
main() {
    log "Generating test data for $NUM_USERS users..."
    
    # Get base DN from environment or use default
    if [ -f ".env" ]; then
        # Source .env safely
        set -a
        source .env 2>/dev/null || true
        set +a
        if [ -n "${LDAP_DOMAIN:-}" ]; then
            BASE_DN="dc=${LDAP_DOMAIN%%.*},dc=${LDAP_DOMAIN#*.}"
        else
            BASE_DN="dc=example,dc=com"
        fi
    else
        BASE_DN="dc=example,dc=com"
        warn "No .env file found, using default base DN: $BASE_DN"
    fi
    
    # Create output file
    cat > "$OUTPUT_FILE" <<EOF
# LDAP Test Data Generated on $(date)
# Number of users: $NUM_USERS
# Base DN: $BASE_DN
# 
# Note: This file contains test users with comprehensive attributes
# Each user has a password in the format: TestPassXXX!
# 
# Import with:
# ldapadd -x -H ldap://localhost -D "cn=admin,$BASE_DN" -w <admin_password> -f $OUTPUT_FILE

# Organizational Units (if not already created)
dn: ou=users,$BASE_DN
objectClass: organizationalUnit
ou: users

dn: ou=groups,$BASE_DN
objectClass: organizationalUnit
ou: groups

EOF
    
    # Generate user entries
    for i in $(seq 1 $NUM_USERS); do
        generate_user "test-user-$(printf "%04d" $i)" "$BASE_DN" >> "$OUTPUT_FILE"
    done
    
    # Generate a WiFi users group
    cat >> "$OUTPUT_FILE" <<EOF
# Group for WiFi access
dn: cn=wifi-users,ou=groups,$BASE_DN
objectClass: groupOfNames
cn: wifi-users
EOF
    
    # Add all users to the group
    for i in $(seq 1 $NUM_USERS); do
        echo "member: uid=test-user-$(printf "%04d" $i),ou=users,$BASE_DN" >> "$OUTPUT_FILE"
    done
    
    log "Test data generated successfully!"
    echo
    echo "=== Generation Summary ==="
    echo "Output file: $OUTPUT_FILE"
    echo "Number of users: $NUM_USERS"
    echo "Base DN: $BASE_DN"
    echo
    echo "Each user has:"
    echo "  - Full name, email, phone numbers"
    echo "  - Job title and department"
    echo "  - Employee number and type"
    echo "  - Complete address information"
    echo "  - Password (TestPassXXX!)"
    echo
    echo "To import into LDAP:"
    echo "docker cp $OUTPUT_FILE openldap:/tmp/"
    echo "docker exec openldap ldapadd -x -H ldap://localhost -D \"cn=admin,$BASE_DN\" -w <admin_password> -f /tmp/$OUTPUT_FILE"
    echo
    echo "To generate more users, run:"
    echo "./generate-test-data.sh <number_of_users>"
}

# Run main function
main "$@"
#!/bin/bash

MAIL_DOMAIN="${MAIL_DOMAIN:?MAIL_DOMAIN required}"
MAIL_USER="${MAIL_USER:?MAIL_USER required}"
MAIL_DIR="/var/mail/${MAIL_DOMAIN}/${MAIL_USER}/new"

for mail_file in "$MAIL_DIR"/*; do
    [ -f "$mail_file" ] || continue

    to=$(grep "^To:" "$mail_file" | head -1 | sed 's/To: //')
    subject=$(grep "^Subject:" "$mail_file" | head -1 | sed 's/Subject: //')
    network=$(grep -oP '(?<=font-size:20px;color:#333333;line-height:24px">)[^<]+(?=</div>)' "$mail_file" | head -1)
    password=$(grep -oP '(?<=font-size:20px;color:#333333;line-height:24px">)[^<]+(?=</div>)' "$mail_file" | tail -1)

    echo "To: $to"
    echo "Subject: $subject"
    echo "WiFi Network: $network"
    echo "Password: $password"
    echo "---"
done

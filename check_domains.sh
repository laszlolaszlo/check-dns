#!/bin/bash
# filepath: /home/llaszlo/fam/check_domains.sh
# Check if the "dig" command is available
if ! command -v dig &> /dev/null; then
    echo "Error: 'dig' command not found in PATH."
    echo "Install it as appropriate for your system."
    # Attempt to determine the Linux distribution from /etc/os-release
    if [[ -f /etc/os-release ]]; then
        distro=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
        case "$distro" in
            ubuntu|debian)
                echo "For Debian/Ubuntu: use sudo apt update && sudo apt install dnsutils"
                ;;
            centos|fedora|rhel|opensuse)
                echo "For CentOS/Fedora/RHEL: use sudo yum install bind-utils"
                ;;
            alpine)
                echo "For Alpine Linux: use sudo apk add bind-tools"
                ;;
            arch)
                echo "For Arch Linux: use sudo pacman -S bind-tools"
                ;;
            gentoo)
                echo "For Gentoo: use sudo emerge net-dns/bind-tools"
                ;;
            manjaro)
                echo "For Manjaro: use sudo pacman -S bind-tools"
                ;; 
            *)
                echo "Please install the package that provides the 'dig' command as appropriate for your system."
                ;;
        esac
    else
        echo "Could not determine the distribution. Please install the package that provides the 'dig' command."
    fi
    exit 1
fi

# By default, no DNS server is specified and we do not flush the cache
dns_server=""
flush_cache=0

# Process parameters
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dns)
            if [[ -n "$2" ]]; then
                dns_server="$2"
                shift 2
            else
                echo "Error: The --dns option requires a DNS server value!"
                echo "Example: $0 --dns 8.8.8.8 --file /home/llaszlo/fam/fam-vegpontok.txt"
                exit 1
            fi
            ;;
        --file)
            if [[ -n "$2" ]]; then
                file="$2"
                shift 2
            else
                echo "Error: The --file option requires a file path!"
                echo "Example: $0 --file /home/llaszlo/fam/fam-vegpontok.txt"
                exit 1
            fi
            ;;
        --flush-cache)
            flush_cache=1
            shift
            ;;
        *)
            echo "Usage: $0 [--dns DNS_SERVER] [--flush-cache] --file FILE_PATH"
            exit 1
            ;;
    esac
done

# Check that the --file option was provided
if [[ -z "$file" ]]; then
    echo "Error: The --file option is mandatory!"
    echo "Usage: $0 [--dns DNS_SERVER] [--flush-cache] --file FILE_PATH"
    exit 1
fi

# Check if the file exists
if [[ ! -f "$file" ]]; then
    echo "Error: File not found: $file"
    exit 1
fi

# Color codes for the results
RED="\033[31m"
GREEN="\033[32m"
NC="\033[0m"  # Reset

# Flush DNS cache if possible and if the option was provided
if [[ "$flush_cache" -eq 1 ]] && [[ -f /etc/os-release ]]; then
    distro=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    case "$distro" in
        ubuntu|debian)
            if command -v systemd-resolve &> /dev/null; then
                sudo systemd-resolve --flush-caches
                echo "DNS cache flushed."
            elif command -v resolvectl &> /dev/null; then
                sudo resolvectl flush-caches
                echo "DNS cache flushed."
            fi
            ;;
        centos|fedora|rhel|opensuse)
            if systemctl status nscd &> /dev/null; then
                sudo systemctl restart nscd
                echo "DNS cache flushed."
            fi
            ;;
        arch|manjaro)
            if systemctl is-active systemd-resolved &> /dev/null; then
                sudo systemctl restart systemd-resolved
                echo "DNS cache flushed."
            fi
            ;;
        alpine)
            # Alpine Linux: no standard DNS cache service
            echo "DNS cache was not flushed."
            ;;
    esac
fi

# Read and process each line of the file
while IFS= read -r domain || [ -n "$domain" ]; do
    # Skip empty lines
    if [[ -z "$domain" ]]; then
        continue
    fi

    # Check if the domain contains only valid characters (letters, numbers, dot, hyphen)
    if ! [[ "$domain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        echo -e "${RED}✖${NC} Invalid domain: $domain"
        continue
    fi

    # Check if the domain exists in the /etc/hosts file
    if grep -qw "$domain" /etc/hosts; then
        hosts_note=" (/etc/hosts)"
        hosts_flag=1
    else
        hosts_note=""
        hosts_flag=0
    fi

    # DNS query using the specified or default DNS server
    if [[ -n "$dns_server" ]]; then
        result=$(dig @"$dns_server" "$domain" A +short)
    else
        result=$(dig "$domain" A +short)
    fi

    # Evaluate and display the result
    if [[ -n "$result" ]]; then
        # Concatenate multiple results into one line, separated by commas
        ips=$(echo "$result" | paste -sd, -)
        if [[ $hosts_flag -eq 1 ]]; then
            echo -e "${RED}✔${NC} $domain${hosts_note} ($ips)"
        else
            echo -e "${GREEN}✔${NC} $domain ($ips)"
        fi
    else
        if [[ $hosts_flag -eq 1 ]]; then
            echo -e "${RED}✖${NC} $domain${hosts_note}"
        else
            echo -e "${RED}✖${NC} $domain"
        fi
    fi

    # Wait 1 second to avoid overloading the DNS server
    sleep 1
done < "$file"
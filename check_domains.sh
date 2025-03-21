#!/bin/bash
# filepath: /home/llaszlo/fam/check_domains.sh
# Ellenőrizzük, hogy a "dig" parancs elérhető-e
if ! command -v dig &> /dev/null; then
    echo "Hiba: A 'dig' parancs nem található a PATH-ban."
    echo "Telepítse azt a rendszerének megfelelő módon."
    # Próbáljuk meghatározni a Linux disztribúciót az /etc/os-release alapján
    if [[ -f /etc/os-release ]]; then
        distro=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
        case "$distro" in
            ubuntu|debian)
                echo "Debian/Ubuntu esetén használja: sudo apt update && sudo apt install dnsutils"
                ;;
            centos|fedora|rhel|opensuse)
                echo "CentOS/Fedora/RHEL esetén használja: sudo yum install bind-utils"
                ;;
            alpine)
                echo "Alpine Linux esetén használja: sudo apk add bind-tools"
                ;;
            arch)
                echo "Arch Linux esetén használja: sudo pacman -S bind-tools"
                ;;
            gentoo)
                echo "Gentoo esetén használja: sudo emerge net-dns/bind-tools"
                ;;
            manjaro)
                echo "Manjaro esetén használja: sudo pacman -S bind-tools"
                ;; 
            *)
                echo "Kérem, telepítse a 'dig' parancsot tartalmazó csomagot a rendszerének megfelelő módon."
                ;;
        esac
    else
        echo "Nem sikerült meghatározni a disztribúciót. Kérem, telepítse a 'dig' parancsot tartalmazó csomagot."
    fi
    exit 1
fi

# Alapesetben nincs megadott DNS szerver
dns_server=""

# Paraméterek feldolgozása
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dns)
            if [[ -n "$2" ]]; then
                dns_server="$2"
                shift 2
            else
                echo "Hiba: A --dns kapcsolóhoz DNS szerver érték kell!"
                echo "Példa: $0 --dns 8.8.8.8 --file /home/llaszlo/fam/fam-vegpontok.txt"
                exit 1
            fi
            ;;
        --file)
            if [[ -n "$2" ]]; then
                file="$2"
                shift 2
            else
                echo "Hiba: A --file kapcsolóhoz fájl elérési út szükséges!"
                echo "Példa: $0 --file /home/llaszlo/fam/fam-vegpontok.txt"
                exit 1
            fi
            ;;
        *)
            echo "Használat: $0 [--dns DNS_SERVER] --file FILE_PATH"
            exit 1
            ;;
    esac
done

# Ellenőrizzük, hogy a --file kapcsoló meg lett-e adva
if [[ -z "$file" ]]; then
    echo "Hiba: A --file kapcsoló kötelező!"
    echo "Használat: $0 [--dns DNS_SERVER] --file FILE_PATH"
    exit 1
fi

# Fájl létezésének ellenőrzése
if [[ ! -f "$file" ]]; then
    echo "Hiba: Nem található a fájl: $file"
    exit 1
fi

# Színkódok az eredményekhez
RED="\033[31m"
GREEN="\033[32m"
NC="\033[0m"  # Reset

# Fájl sorainak beolvasása és ellenőrzés
while IFS= read -r domain; do
    # Üres sorok kihagyása
    if [[ -z "$domain" ]]; then
        continue
    fi

    # DNS lekérdezés a megadott vagy alapértelmezett DNS szerverrel
    if [[ -n "$dns_server" ]]; then
        result=$(dig @"$dns_server" "$domain" A +short)
    else
        result=$(dig "$domain" A +short)
    fi

    # Eredmény kiértékelése és megjelenítése
    if [[ -n "$result" ]]; then
        echo -e "${GREEN}✔${NC} $domain"
    else
        echo -e "${RED}✖${NC} $domain"
    fi

    # Várakozás 1 másodpercet, hogy ne terheljük a DNS szervert
    sleep 1
done < "$file"
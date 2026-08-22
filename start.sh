#!/bin/bash

# Kolory dla czytelności
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Uruchamianie serwera Eaglercraft    ${NC}"
echo -e "${BLUE}========================================${NC}"

# Sprawdź czy serwer istnieje
if [ ! -f "server/server.jar" ] || [ ! -f "bungee/bungee.jar" ]; then
    echo -e "${RED}❌ Brak plików serwera!${NC}"
    echo -e "${YELLOW}Upewnij się że jesteś w katalogu z serwerem.${NC}"
    exit 1
fi

# Sprawdź czy serwer już działa
if pgrep -f "server.jar" > /dev/null || pgrep -f "bungee.jar" > /dev/null; then
    echo -e "${YELLOW}⚠️ Serwer już działa!${NC}"
    
    # Pokaż adres serwera jeśli działa
    if [ -n "$CODESPACE_NAME" ]; then
        CODESPACE_URL="wss://${CODESPACE_NAME}-8081.app.github.dev/"
        echo -e "${GREEN}📡 Serwer dostępny pod adresem: ${CODESPACE_URL}${NC}"
    fi
else
    echo -e "${YELLOW}🚀 Uruchamianie serwera...${NC}"

    # Uruchom serwer
    cd server && java -jar server.jar &
    cd bungee && java -jar bungee.jar &

    sleep 30

    # Sprawdź czy serwer działa
    if pgrep -f "server.jar" > /dev/null && pgrep -f "bungee.jar" > /dev/null; then
        echo -e "${GREEN}✅ Serwer uruchomiony pomyślnie!${NC}"
    else
        echo -e "${RED}❌ Problem z uruchomieniem serwera!${NC}"
    fi

    # Wyślij adres do API
    if [ -n "$CODESPACE_NAME" ]; then
        CODESPACE_URL="wss://${CODESPACE_NAME}-8081.app.github.dev/"
        echo -e "${YELLOW}📤 Wysyłanie adresu IP do API...${NC}"
        
        response=$(curl -s -o /dev/null -w "%{http_code}" -X POST https://sp4-smp-api.onrender.com/update-ip \
             -H "Content-Type: application/json" \
             -d "{\"ip\": \"${CODESPACE_URL}\"}")
        
        if [ "$response" = "200" ] || [ "$response" = "201" ]; then
            echo -e "${GREEN}✅ Adres IP wysłany pomyślnie!${NC}"
            echo -e "${GREEN}📡 Adres serwera: ${CODESPACE_URL}${NC}"
        else
            echo -e "${RED}❌ Błąd wysyłania adresu IP (HTTP $response)${NC}"
            echo -e "${GREEN}📡 Adres serwera: ${CODESPACE_URL}${NC}"
        fi
    else
        echo -e "${RED}⚠️ CODESPACE_NAME nie jest ustawiony!${NC}"
        echo -e "${YELLOW}Pomijam wysyłanie adresu do API.${NC}"
    fi
fi

# Funkcja do automatycznego backupu co minutę
auto_push() {
    local commit_count=0
    echo -e "${GREEN}🔄 Automatyczny backup co 1 minutę...${NC}"
    echo -e "${YELLOW}⚠️ UWAGA: Backup co minutę szybko zapełni historię Git!${NC}"
    
    while true; do
        sleep 60  # co 1 minutę
        
        # Sprawdź czy są zmiany
        if git status --porcelain | grep -q .; then
            commit_count=$((commit_count + 1))
            git add .
            
            if git commit -m "Auto Save #${commit_count}: $(date '+%Y-%m-%d %H:%M:%S')" > /dev/null 2>&1; then
                echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ Backup #${commit_count} utworzony${NC}"
                
                # Push używając domyślnego HTTPS
                push_output=$(git push 2>&1)
                if echo "$push_output" | grep -q "denied\|403"; then
                    echo -e "${RED}[$(date '+%H:%M:%S')] ❌ Błąd 403 - brak uprawnień!${NC}"
                    echo -e "${YELLOW}Skonfiguruj Git: https://github.com/settings/tokens${NC}"
                elif echo "$push_output" | grep -q "failed\|Could not read"; then
                    echo -e "${RED}[$(date '+%H:%M:%S')] ❌ Błąd pusha!${NC}"
                else
                    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ Backup #${commit_count} wysłany na GitHub!${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}[$(date '+%H:%M:%S')] 📝 Brak zmian do zapisania${NC}"
        fi
    done
}

# Uruchom auto_push w tle
auto_push &

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Serwer uruchomiony!${NC}"
echo -e "${GREEN}🔄 Backup na GitHub: co 1 minutę${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}📌 TERAZ WYKONAJ TE KROKI W CODESPACES:${NC}"
echo -e "${BLUE}1.${NC} Kliknij na zakładkę ${GREEN}'Ports'${NC} (obok Terminala)"
echo -e "${BLUE}2.${NC} Kliknij ${GREEN}'Add Port'${NC} i wpisz ${YELLOW}25565${NC}"
echo -e "${BLUE}3.${NC} Kliknij ${GREEN}'Add Port'${NC} i wpisz ${YELLOW}8081${NC}"
echo -e "${BLUE}4.${NC} Dla każdego portu zmień widoczność na ${GREEN}'Public'${NC} (kliknij na kłódkę)"
echo -e ""
echo -e "${GREEN}📡 Po udostępnieniu portów:${NC}"
echo -e "   Port 25565 -> adres do gry Minecraft"
if [ -n "$CODESPACE_NAME" ]; then
    echo -e "   Port 8081  -> ${BLUE}wss://${CODESPACE_NAME}-8081.app.github.dev/${NC}"
else
    echo -e "   Port 8081  -> ${BLUE}wss://twoj-adres-8081.app.github.dev/${NC}"
fi
echo -e "${BLUE}========================================${NC}"

# Czekaj na Ctrl+C
wait
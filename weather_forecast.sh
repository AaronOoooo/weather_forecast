#!/bin/bash

export $(grep -v '^#' .env | xargs)

API_KEY="${OWM_API_KEY}" # ← Replace this
UNITS="imperial"  # or "metric"
TEMP_UNIT="°F"

# ANSI colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# Check if zip or "3 <zip>" was passed
if [ -z "$1" ]; then
    echo "❗ Usage: forecast <zip_code>  or  forecast 3 <zip_code>"
    exit 1
fi

echo ""

# Handle 3-day forecast
if [[ "$1" == "3" && -n "$2" ]]; then
    ZIP="$2"

    # First, get lat/lon from zip
    GEO_URL="http://api.openweathermap.org/geo/1.0/zip?zip=$ZIP,US&appid=$API_KEY"
    GEO_RESPONSE=$(curl -s "$GEO_URL")

    LAT=$(echo "$GEO_RESPONSE" | jq -r '.lat')
    LON=$(echo "$GEO_RESPONSE" | jq -r '.lon')
    CITY=$(echo "$GEO_RESPONSE" | jq -r '.name')

    if [ "$LAT" == "null" ]; then
        echo "❌ Could not find location for ZIP $ZIP"
        exit 1
    fi

    # Get 3-day forecast
    ONECALL_URL="https://api.openweathermap.org/data/2.5/onecall?lat=$LAT&lon=$LON&exclude=minutely,hourly,alerts&units=$UNITS&appid=$API_KEY"
    FORECAST=$(curl -s "$ONECALL_URL")

    echo "📍 3-Day Forecast for $CITY ($ZIP)"
    echo "--------------------------------------"

    for i in 0 1 2; do
        DATE=$(date -d "@$(echo "$FORECAST" | jq ".daily[$i].dt")" "+%A, %b %d")
        DESC=$(echo "$FORECAST" | jq -r ".daily[$i].weather[0].description" | sed 's/\b\(.\)/\u\1/')
        TEMP_DAY=$(echo "$FORECAST" | jq ".daily[$i].temp.day")
        TEMP_NIGHT=$(echo "$FORECAST" | jq ".daily[$i].temp.night")
        WIND=$(echo "$FORECAST" | jq ".daily[$i].wind_speed")
        HUMIDITY=$(echo "$FORECAST" | jq ".daily[$i].humidity")

        echo "📅 $DATE"
        echo "   🌤️  $DESC"
        echo "   🌡️  Day: $TEMP_DAY$TEMP_UNIT | Night: $TEMP_NIGHT$TEMP_UNIT"
        echo "   💧 Humidity: $HUMIDITY%   💨 Wind: $WIND mph"
        echo ""
    done

    echo "--------------------------------------"

else
    # Single-day mode
    ZIP="$1"
    API_URL="https://api.openweathermap.org/data/2.5/forecast?zip=$ZIP,us&appid=$API_KEY&units=$UNITS"

    RESPONSE=$(curl -s "$API_URL")
    STATUS=$(echo "$RESPONSE" | jq -r '.cod')

    if [ "$STATUS" = "200" ]; then
        CITY=$(echo "$RESPONSE" | jq -r '.city.name')
        LAT=$(echo "$RESPONSE" | jq -r '.city.coord.lat')
        LON=$(echo "$RESPONSE" | jq -r '.city.coord.lon')

        # Get sunrise/sunset using current weather
        CURRENT_URL="https://api.openweathermap.org/data/2.5/weather?lat=$LAT&lon=$LON&appid=$API_KEY&units=$UNITS"
        CURRENT=$(curl -s "$CURRENT_URL")
        SUNRISE=$(echo "$CURRENT" | jq -r '.sys.sunrise')
        SUNSET=$(echo "$CURRENT" | jq -r '.sys.sunset')

        # Convert to Central Time
        LOCAL_SUNRISE=$(TZ="America/Chicago" date -d "@$SUNRISE" +"%I:%M %p")
        LOCAL_SUNSET=$(TZ="America/Chicago" date -d "@$SUNSET" +"%I:%M %p")

        echo "📍 Forecast for Today – $CITY ($ZIP)"
        echo "🗓️  $(TZ="America/Chicago" date -d "today" "+%A, %B %d")"
        echo "🌅 Sunrise: $LOCAL_SUNRISE  |  🌇 Sunset: $LOCAL_SUNSET"
        echo "-----------------------------------------------------------------"
        printf "%-10s | %-18s | %-10s | %-6s | %s\n" "Time" "Condition" "Temp" "Rain" "What to Wear"
        echo "-----------------------------------------------------------------"

        TODAY_LOCAL=$(echo "$RESPONSE" | jq -r '.list[0].dt_txt' | cut -d' ' -f1)
        DAILY_HIGH=-999
        DAILY_LOW=999


        # Init temp file
        TEMP_LIST_FILE=$(mktemp)

        echo "$RESPONSE" | jq -c ".list[] | select(.dt_txt | startswith(\"$TODAY_LOCAL\"))" | while read -r entry; do
            TIME_RAW=$(echo "$entry" | jq -r '.dt')
            LOCAL_TIME=$(TZ="America/Chicago" date -d "@$TIME_RAW" +"%I:%M %p")
            TEMP=$(echo "$entry" | jq -r '.main.temp')
            FEELS=$(echo "$entry" | jq -r '.main.feels_like')
            RAW_DESC=$(echo "$entry" | jq -r '.weather[0].description' | sed 's/\b\(.\)/\u\1/')
            POP=$(echo "$entry" | jq -r '.pop')
            POP_PERCENT=$(printf "%.0f" "$(echo "$POP * 100" | bc -l)")

            # Save temp for later high/low check
            printf "%.0f\n" "$TEMP" >> "$TEMP_LIST_FILE"

            # Weather icon
            if [[ "$RAW_DESC" == *"clear sky"* ]]; then
                ICON="☀️"
            elif [[ "$RAW_DESC" == *"few clouds"* ]]; then
                ICON="🌤️"
            elif [[ "$RAW_DESC" == *"scattered clouds"* ]]; then
                ICON="⛅"
            elif [[ "$RAW_DESC" == *"broken clouds"* ]]; then
                ICON="☁️"
            elif [[ "$RAW_DESC" == *"overcast clouds"* ]]; then
                ICON="🌥️"
            elif [[ "$RAW_DESC" == *"rain"* ]]; then
                ICON="🌧️"
            elif [[ "$RAW_DESC" == *"thunderstorm"* ]]; then
                ICON="⛈️"
            elif [[ "$RAW_DESC" == *"snow"* ]]; then
                ICON="❄️"
            else
                ICON="🌤️"
            fi

            # Clothing advice
            if (( $(echo "$POP > 0.5" | bc -l) )); then
                OUTFIT="Bring umbrella"
            elif (( $(echo "$FEELS < 40" | bc -l) )); then
                OUTFIT="Bundle up"
            elif (( $(echo "$FEELS < 60" | bc -l) )); then
                OUTFIT="Wear a jacket"
            elif (( $(echo "$FEELS > 85" | bc -l) )); then
                OUTFIT="Dress cool"
            else
                OUTFIT="Dress comfortably"
            fi

            printf "%-10s | %-24s | %3d°F      | ☔ %-3s | %s\n" "$LOCAL_TIME" "$ICON $RAW_DESC" "$(printf "%.0f" "$TEMP")" "$POP_PERCENT%" "$OUTFIT"
        done

        echo "-----------------------------------------------------------------"
        echo ""

        # Compute high/low using sort
        DAILY_HIGH=$(sort -nr "$TEMP_LIST_FILE" | head -n 1)
        DAILY_LOW=$(sort -n "$TEMP_LIST_FILE" | head -n 1)

        echo "🌡️ Daily High: ${DAILY_HIGH}°F   |   🌡️ Low: ${DAILY_LOW}°F"
        echo ""

        # Clean up
        rm "$TEMP_LIST_FILE"

    else
        MESSAGE=$(echo "$RESPONSE" | jq -r '.message')
        echo "❌ Error: $MESSAGE"
    fi
fi

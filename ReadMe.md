# Weather Forecast (Raspberry Pi Bash Script)

This project provides a simple **command-line weather forecast tool** using the [OpenWeatherMap API](https://openweathermap.org/api).
It is written in **Bash** and is designed to run on **Raspberry Pi** or any Linux-based system.

---

## Features

* **Current day forecast** by ZIP code (U.S.)
* **3-day extended forecast** (optional `3 <zip>` command)
* Displays **temperature, weather condition, rain chance, wind speed, humidity**, and **sunrise/sunset** times.
* **Color-coded output** and clothing suggestions based on weather conditions.
* Uses **environment variables** (from `.env`) to securely store your API key.

---

## Requirements

1. **jq** (for JSON parsing)

   ```bash
   sudo apt install jq
   ```
2. **curl** (for API requests)

   ```bash
   sudo apt install curl
   ```
3. **OpenWeatherMap API key** – Get one for free at [https://openweathermap.org/api](https://openweathermap.org/api).

---

## Setup

1. **Clone this repository:**

   ```bash
   git clone https://github.com/YOUR_USERNAME/weather_forecast.git
   cd weather_forecast
   ```

2. **Create a `.env` file** to store your API key:

   ```bash
   nano .env
   ```

   Add:

   ```
   OWM_API_KEY=your_actual_api_key_here
   ```

3. **Make the script executable:**

   ```bash
   chmod +x weather_forecast.sh
   ```

4. **Test the script:**

   ```bash
   ./weather_forecast.sh 60616
   ```

---

## Optional: Create an Alias

For convenience, add an alias to your `~/.bashrc`:

```bash
alias forecast='cd /home/pi/code/weather_forecast && export $(grep -v "^#" .env | xargs) && ./weather_forecast.sh'
```

Then reload:

```bash
source ~/.bashrc
```

Now you can run:

```bash
forecast 60616
```

or for 3-day forecast:

```bash
forecast 3 60616
```

---

## Example Output

```
📍 Forecast for Today – Chicago (60616)
🗓️  Sunday, August 03
🌅 Sunrise: 05:46 am  |  🌇 Sunset: 08:06 pm
-----------------------------------------------------------------
Time       | Condition          | Temp       | Rain   | What to Wear
-----------------------------------------------------------------
01:00 pm   | 🌤️ Clear sky        |  78°F      | ☔ 0%  | Dress comfortably
04:00 pm   | 🌤️ Clear sky        |  78°F      | ☔ 0%  | Dress comfortably
-----------------------------------------------------------------
🌡️ Daily High: 78°F   |   🌡️ Low: 78°F
```

---

## Notes

* `.env` is listed in `.gitignore` and **should never be pushed to GitHub**.
* Adjust `UNITS` in the script for metric (`°C`) or imperial (`°F`).

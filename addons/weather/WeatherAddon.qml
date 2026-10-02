import QtQuick
import Quickshell.Io
import ".."

// The current weather and the next hours' for the city set in the addon's
// options, from Open-Meteo (no key needed), as an island view (see
// WeatherView). The city is looked up once, its first match kept, then its
// conditions are fetched every 30 minutes, again when the unit changes, and
// when the view opens on a reading older than that.
Addon {
  id: weatherAddon
  views: [{ name: "weather", width: 480, padding: 22, component: weatherView }]
  Component {
    id: weatherView
    WeatherView { weather: weatherAddon; active: weatherAddon.host.view === "weather" }
  }

  readonly property string city: String(addon.option("city") || "").trim()
  readonly property bool fahrenheit: !!addon.option("fahrenheit")
  readonly property int refreshMs: 30 * 60 * 1000

  // "missing" (no city), "loading", "ready", "unknown" (no such city),
  // or "offline" (Open-Meteo couldn't be reached).
  property string status: city === "" ? "missing" : "loading"
  property string place: ""
  property real latitude: 0
  property real longitude: 0
  property bool located: false
  property var current: null
  property var hours: []
  readonly property int hourCount: 5
  property real fetchedAt: 0

  onCityChanged: locate()
  onFahrenheitChanged: fetch()
  Component.onCompleted: locate()

  Timer {
    interval: weatherAddon.refreshMs
    repeat: true
    running: weatherAddon.located
    onTriggered: weatherAddon.fetch()
  }
  function viewOpened() { if (located && Date.now() - fetchedAt > refreshMs) fetch() }

  // Each request remembers what it was made for: an answer for a city or
  // unit since changed is dropped, and the request made again once it exits.
  readonly property string forecastKey: located ? latitude + "," + longitude + "," + fahrenheit : ""

  Process {
    id: geocode
    property string city: ""
    onExited: if (city !== weatherAddon.city) weatherAddon.locate()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (geocode.city !== weatherAddon.city) return
        var match = null
        try { match = (JSON.parse(text).results || [])[0] || null } catch (e) {}
        if (!match) { weatherAddon.status = text === "" ? "offline" : "unknown"; return }
        weatherAddon.place = [match.name, match.country || match.country_code]
          .filter(function(part) { return part }).join(", ")
        weatherAddon.latitude = match.latitude
        weatherAddon.longitude = match.longitude
        weatherAddon.located = true
        weatherAddon.fetch()
      }
    }
  }
  function locate() {
    located = false
    current = null
    hours = []
    if (city === "") { status = "missing"; return }
    status = "loading"
    if (geocode.running) return
    geocode.city = city
    geocode.command = ["curl", "-sf", "--max-time", "10", "-G", "https://geocoding-api.open-meteo.com/v1/search",
      "--data-urlencode", "name=" + city, "-d", "count=1", "-d", "format=json"]
    geocode.running = true
  }

  Process {
    id: forecast
    property string key: ""
    onExited: if (key !== weatherAddon.forecastKey) weatherAddon.fetch()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (forecast.key !== weatherAddon.forecastKey) return
        try {
          var reply = JSON.parse(text)
          var now = reply.current
          // The hours after this one, in the city's own time.
          var hourly = reply.hourly, hours = []
          for (var i = 0; i < hourly.time.length && hours.length < weatherAddon.hourCount; i++) {
            if (hourly.time[i] <= now.time) continue
            hours.push({
              hour: Number(hourly.time[i].slice(11, 13)),
              code: hourly.weather_code[i],
              day: !!hourly.is_day[i],
              rain: hourly.precipitation_probability[i] || 0,
              temperature: hourly.temperature_2m[i]
            })
          }
          weatherAddon.hours = hours
          weatherAddon.current = {
            temperature: now.temperature_2m,
            feelsLike: now.apparent_temperature,
            code: now.weather_code,
            day: !!now.is_day,
            fahrenheit: weatherAddon.fahrenheit
          }
          weatherAddon.fetchedAt = Date.now()
          weatherAddon.status = "ready"
        } catch (e) {
          if (!weatherAddon.current) weatherAddon.status = "offline"
        }
      }
    }
  }
  function fetch() {
    if (!located || forecast.running) return
    forecast.key = forecastKey
    forecast.command = ["curl", "-sf", "--max-time", "10", "-G", "https://api.open-meteo.com/v1/forecast",
      "-d", "latitude=" + latitude, "-d", "longitude=" + longitude,
      "-d", "current=temperature_2m,apparent_temperature,weather_code,is_day",
      "-d", "hourly=temperature_2m,weather_code,precipitation_probability,is_day",
      "-d", "forecast_hours=" + (hourCount + 2), "-d", "timezone=auto",
      "-d", "temperature_unit=" + (fahrenheit ? "fahrenheit" : "celsius")]
    forecast.running = true
  }
  function retry() { located ? fetch() : locate() }

  // WMO weather codes, as Open-Meteo reports them (see WeatherIcon too).
  function describe(code) {
    if (code === 0) return "Clear"
    if (code === 1) return "Mainly clear"
    if (code === 2) return "Partly cloudy"
    if (code === 3) return "Overcast"
    if (code === 45 || code === 48) return "Fog"
    if (code >= 51 && code <= 57) return "Drizzle"
    if (code >= 61 && code <= 67) return code >= 65 ? "Heavy rain" : "Rain"
    if (code >= 71 && code <= 77) return "Snow"
    if (code >= 80 && code <= 82) return "Rain showers"
    if (code === 85 || code === 86) return "Snow showers"
    if (code >= 95) return "Thunderstorm"
    return "Unknown"
  }
}

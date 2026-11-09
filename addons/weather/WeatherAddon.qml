import QtQuick
import Quickshell.Io
import ".."

// The current weather and the next hours' for the city set in the addon's
// options, from Open-Meteo (no key needed), as an island view (see
// WeatherView). The city is looked up once, its first match kept, then its
// conditions are fetched every 30 minutes, again when the unit changes, and
// when the view opens on a reading older than that.
// With no city set, and "Detect my location" turned on, the place
// comes from the IP address instead: one request to a keyless service (a
// second one is the fallback), which already gives coordinates, so there is
// no Open-Meteo lookup. It is asked once per session (the answer is kept in
// memory for an hour, never written to disk), not on every refresh.
Addon {
  id: weatherAddon
  views: [{ name: "weather", width: 480, padding: 22, component: weatherView }]
  Component {
    id: weatherView
    WeatherView { weather: weatherAddon; active: weatherAddon.host.view === "weather" }
  }

  readonly property string city: String(addon.option("city") || "").trim()
  readonly property bool detect: !!addon.option("autoLocate")
  // The city is empty and the place comes from the IP address.
  readonly property bool detecting: city === "" && detect
  readonly property bool fahrenheit: !!addon.option("fahrenheit")
  readonly property int refreshMs: 30 * 60 * 1000

  // "missing" (no city, and not detecting), "loading", "ready", "unknown"
  // (no such city), or "offline" (Open-Meteo, or the services that find the
  // user's place, couldn't be reached).
  property string status: city === "" && !detect ? "missing" : "loading"
  property string place: ""
  property real latitude: 0
  property real longitude: 0
  property bool located: false
  property var current: null
  property var hours: []
  readonly property int hourCount: 5
  property real fetchedAt: 0

  // The options arrive one by one when Settings loads (the addon is switched
  // on before its city is read), so locating waits for the dust to settle:
  // with a city set, the empty one seen first must not send the IP address
  // anywhere.
  onCityChanged: Qt.callLater(locate)
  onDetectChanged: Qt.callLater(locate)
  onFahrenheitChanged: fetch()
  Component.onCompleted: Qt.callLater(locate)

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
    if (city === "") {
      if (!detect) { status = "missing"; return }
      status = "loading"
      if (ipPlace && Date.now() - ipAt < ipCacheMs) { useIpPlace(); return }
      if (!asking) lookUp(geoA)
      return
    }
    status = "loading"
    if (geocode.running) return
    geocode.city = city
    geocode.command = ["curl", "-sf", "--max-time", "10", "-G", "https://geocoding-api.open-meteo.com/v1/search",
      "--data-urlencode", "name=" + city, "-d", "count=1", "-d", "format=json"]
    geocode.running = true
  }

  // The place found from the IP address, kept for the session. Two services,
  // the second asked only when the first fails or sends nonsense; both answer
  // { latitude, longitude, city, ... } (geojs.io with the numbers as strings).
  readonly property int ipCacheMs: 60 * 60 * 1000
  readonly property int maxReply: 65536
  property var ipPlace: null
  property real ipAt: 0
  // A lookup is under way. Not Process.running, which only turns true once
  // the process has started: a second locate() right after the first would
  // ask again.
  property bool asking: false

  component GeoLookup: Process {
    id: lookup
    property string url: ""
    property bool last: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: weatherAddon.lookedUp(lookup, weatherAddon.parsePlace(text))
    }
  }
  GeoLookup { id: geoA; url: "https://get.geojs.io/v1/ip/geo.json" }
  GeoLookup { id: geoB; url: "https://ipwho.is/"; last: true }

  function lookUp(lookup) {
    // Only https, and a bounded reply: the URL is fixed, nothing typed goes
    // near the command.
    asking = true
    lookup.command = ["curl", "-sf", "--max-time", "10", "--proto", "=https", "--max-filesize", String(maxReply), lookup.url]
    lookup.running = true
  }
  // null unless the reply holds a usable place.
  function parsePlace(text) {
    if (text === "" || text.length > maxReply) return null
    try {
      var reply = JSON.parse(text)
      var lat = parseFloat(reply.latitude), lon = parseFloat(reply.longitude)
      var name = String(reply.city || reply.region || reply.country || "").trim()
      if (reply.success === false || name === "" || isNaN(lat) || isNaN(lon)
          || Math.abs(lat) > 90 || Math.abs(lon) > 180) return null
      // Two decimals (about a kilometre) is all an IP address knows, and all
      // Open-Meteo needs to be told.
      return {
        name: [name, String(reply.city ? reply.country_code || reply.country || "" : "")]
          .filter(function(part) { return part !== "" }).join(", "),
        latitude: Math.round(lat * 100) / 100,
        longitude: Math.round(lon * 100) / 100
      }
    } catch (e) { return null }
  }
  function lookedUp(lookup, found) {
    asking = false
    // Answered after a city was typed in or detection switched off: the
    // answer isn't wanted any more.
    if (!detecting) return
    if (found) { ipPlace = found; ipAt = Date.now(); useIpPlace(); return }
    if (!lookup.last) lookUp(geoB)
    else status = "offline"
  }
  function useIpPlace() {
    place = ipPlace.name
    latitude = ipPlace.latitude
    longitude = ipPlace.longitude
    located = true
    fetch()
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

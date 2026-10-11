<%@ page import="java.io.*" %>
<%@ page import="java.net.*" %>
<%@ page import="java.util.*" %>
<%@ page import="java.text.*" %>
<%@ page import="org.json.simple.*" %>
<%@ page import="org.json.simple.parser.*" %>
<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" language="java" %>
<%!
/* =========================================================================
   Live Weather Forecasting - helpers
   Java 7/8 compatible so it compiles on any Tomcat 8/9 + JDK 8+ runtime.
   ========================================================================= */

/** HTML-escape untrusted text before echoing it into the page. */
public static String esc(String s) {
    if (s == null) return "";
    StringBuilder b = new StringBuilder(s.length() + 16);
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        switch (c) {
            case '&': b.append("&amp;"); break;
            case '<': b.append("&lt;"); break;
            case '>': b.append("&gt;"); break;
            case '"': b.append("&quot;"); break;
            case '\'': b.append("&#39;"); break;
            default: b.append(c);
        }
    }
    return b.toString();
}

/** Read a whole HTTP response body. */
public static String readAll(InputStream in) throws IOException {
    BufferedReader r = new BufferedReader(new InputStreamReader(in, "UTF-8"));
    StringBuilder sb = new StringBuilder();
    char[] buf = new char[4096];
    int n;
    while ((n = r.read(buf)) != -1) sb.append(buf, 0, n);
    r.close();
    return sb.toString();
}

/** Blocking GET with sane timeouts, returning the body (null on failure). */
public static String httpGet(String urlStr) {
    HttpURLConnection conn = null;
    try {
        conn = (HttpURLConnection) new URL(urlStr).openConnection();
        conn.setRequestMethod("GET");
        conn.setConnectTimeout(8000);
        conn.setReadTimeout(12000);
        conn.setRequestProperty("Accept", "application/json");
        conn.setRequestProperty("User-Agent", "LiveWeatherForecasting/2.0");
        int status = conn.getResponseCode();
        InputStream in = (status >= 200 && status < 300) ? conn.getInputStream() : conn.getErrorStream();
        String body = in == null ? "" : readAll(in);
        if (status < 200 || status >= 300) return null;
        return body;
    } catch (Exception e) {
        return null;
    } finally {
        if (conn != null) conn.disconnect();
    }
}

/** Map an OpenWeather icon code (e.g. "10n") to our internal icon key. */
public static String iconKey(String owm) {
    if (owm == null || owm.length() < 3) return "cloud";
    String num = owm.substring(0, 2);
    boolean night = owm.endsWith("n");
    if ("01".equals(num)) return night ? "clear-night" : "clear-day";
    if ("02".equals(num)) return night ? "partly-night" : "partly-day";
    if ("03".equals(num) || "04".equals(num)) return "cloud";
    if ("09".equals(num)) return "drizzle";
    if ("10".equals(num)) return "rain";
    if ("11".equals(num)) return "thunder";
    if ("13".equals(num)) return "snow";
    if ("50".equals(num)) return "fog";
    return "cloud";
}

/** Broad theme bucket used for background + accent colours. */
public static String themeKey(String owm) {
    String k = iconKey(owm);
    if ("clear-day".equals(k)) return "clear-day";
    if ("clear-night".equals(k)) return "clear-night";
    if ("partly-day".equals(k) || "partly-night".equals(k)) return "cloud";
    if ("drizzle".equals(k) || "rain".equals(k)) return "rain";
    if ("thunder".equals(k)) return "thunder";
    if ("snow".equals(k)) return "snow";
    if ("fog".equals(k)) return "fog";
    return "cloud";
}

/** Inline stroke SVG (feather-style) for a given icon key. */
public static String svgIcon(String key, String cls) {
    String d;
    if ("clear-day".equals(key)) {
        d = "<circle cx=\"12\" cy=\"12\" r=\"4.2\"/><path d=\"M12 2.5v2.2M12 19.3v2.2M4.6 4.6l1.6 1.6M17.8 17.8l1.6 1.6M2.5 12h2.2M19.3 12h2.2M4.6 19.4l1.6-1.6M17.8 6.2l1.6-1.6\"/>";
    } else if ("clear-night".equals(key)) {
        d = "<path d=\"M20.5 13.2A8.4 8.4 0 0 1 10.8 3.5a8.6 8.6 0 1 0 9.7 9.7z\"/>";
    } else if ("partly-day".equals(key)) {
        d = "<circle cx=\"8\" cy=\"8\" r=\"2.6\"/><path d=\"M8 2.4v1.6M2.4 8h1.6M4 4l1.2 1.2M4 12l1.2-1.2M12 4l-1.2 1.2\"/><path d=\"M17 20H9.5a3.5 3.5 0 0 1-.4-6.97A4.7 4.7 0 0 1 18 14.2a3 3 0 0 1-1 5.8z\"/>";
    } else if ("partly-night".equals(key)) {
        d = "<path d=\"M9.5 6.2A4.6 4.6 0 0 1 4.3 1a4.7 4.7 0 1 0 5.2 5.2z\"/><path d=\"M17 20H9.5a3.5 3.5 0 0 1-.4-6.97A4.7 4.7 0 0 1 18 14.2a3 3 0 0 1-1 5.8z\"/>";
    } else if ("cloud".equals(key)) {
        d = "<path d=\"M18 18.5H7a4.5 4.5 0 0 1-.6-8.96A6 6 0 0 1 18 8.6a5 5 0 0 1 0 9.9z\"/>";
    } else if ("drizzle".equals(key)) {
        d = "<path d=\"M18 16.5H7.5a4.3 4.3 0 0 1-.6-8.55A5.8 5.8 0 0 1 18 7a4.8 4.8 0 0 1 0 9.5z\"/><path d=\"M8.5 19.4l-.9 2M12 19.4l-.9 2M15.5 19.4l-.9 2\"/>";
    } else if ("rain".equals(key)) {
        d = "<path d=\"M18 15.5H7.5a4.3 4.3 0 0 1-.6-8.55A5.8 5.8 0 0 1 18 6a4.8 4.8 0 0 1 0 9.5z\"/><path d=\"M8 18.2l-1.2 3M12 18.2l-1.2 3M16 18.2l-1.2 3\"/>";
    } else if ("thunder".equals(key)) {
        d = "<path d=\"M18 15.5H7.5a4.3 4.3 0 0 1-.6-8.55A5.8 5.8 0 0 1 18 6a4.8 4.8 0 0 1 0 9.5z\"/><path d=\"M13 17.5l-3 5.5h4l-1 3\"/>";
    } else if ("snow".equals(key)) {
        d = "<path d=\"M18 15.5H7.5a4.3 4.3 0 0 1-.6-8.55A5.8 5.8 0 0 1 18 6a4.8 4.8 0 0 1 0 9.5z\"/><path d=\"M8.5 19h.01M12 21.5h.01M15.5 19h.01M12 19h.01M9.8 21.5h.01\"/>";
    } else {
        d = "<path d=\"M4 9h12M6 13h14M4 17h11\"/>";
    }
    if (cls == null) cls = "ico";
    return "<svg class=\"" + cls + "\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
         + " stroke-width=\"1.7\" stroke-linecap=\"round\" stroke-linejoin=\"round\""
         + " aria-hidden=\"true\" focusable=\"false\">" + d + "</svg>";
}

/** Escape a value for safe embedding inside a single-quoted JS string. */
public static String jsStr(String s) {
    if (s == null) return "";
    StringBuilder b = new StringBuilder(s.length() + 16);
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        switch (c) {
            case '\\': b.append("\\\\"); break;
            case '\'': b.append("\\'"); break;
            case '"': b.append("\\\""); break;
            case '\n': b.append("\\n"); break;
            case '\r': b.append("\\r"); break;
            case '<': b.append("\\u003c"); break;
            case '>': b.append("\\u003e"); break;
            case '&': b.append("\\u0026"); break;
            default: b.append(c);
        }
    }
    return b.toString();
}

/** Compass point from a wind bearing in degrees. */
public static String compass(double deg) {
    String[] pts = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"};
    int i = (int) Math.round(((deg % 360) + 360) % 360 / 45.0) % 8;
    return pts[i];
}

/** Trim a double to a fixed number of decimals. */
public static String num(double v, int dec) {
    return String.format(Locale.ENGLISH, "%." + dec + "f", v);
}

/** Small value holder for one hourly forecast slot. */
public static class Hour {
    public String time, temp, icon, pop;
}
/** Small value holder for one daily forecast row. */
public static class Day {
    public String name, date, min, max, icon, desc, pop;
}
%>
<%
/* =========================================================================
   CONFIG
   ========================================================================= */
String apiKey = System.getenv("OPENWEATHER_API_KEY");
if (apiKey == null) apiKey = "";
apiKey = apiKey.trim();

String baseUrl = System.getenv("OPENWEATHER_BASE_URL");
if (baseUrl == null || baseUrl.trim().isEmpty()) baseUrl = "https://api.openweathermap.org";
baseUrl = baseUrl.trim();
while (baseUrl.endsWith("/")) baseUrl = baseUrl.substring(0, baseUrl.length() - 1);

/* =========================================================================
   INPUTS
   ========================================================================= */
String city       = request.getParameter("city");
String latParam   = request.getParameter("lat");
String lonParam   = request.getParameter("lon");
String unitParam  = request.getParameter("unit");
String labelParam = request.getParameter("label");

boolean imperial = "imperial".equals(unitParam);
String unitSym   = imperial ? "\u00b0F" : "\u00b0C";
String speedUnit = imperial ? "mph" : "m/s";
String unitQ     = imperial ? "imperial" : "metric";
String otherUnit = imperial ? "metric" : "imperial";
String otherSym  = imperial ? "\u00b0C" : "\u00b0F";

if (city == null) city = "";
city = city.trim();

/* =========================================================================
   MODEL
   ========================================================================= */
boolean setupMode = apiKey.isEmpty();
boolean hasData = false;
String  errorMsg = null;

String cityName = "", country = "", localTimeStr = "", dateStr = "";
String tempStr = "--", feelsStr = "--", descStr = "", mainStr = "", iconK = "cloud", wx = "cloud";
String highStr = "--", lowStr = "--", dailyRangeNote = "";
String humidityStr = "--", windStr = "--", windDirStr = "", pressureStr = "--";
String visStr = "--", cloudsStr = "--", gustStr = "";
String sunriseStr = "--:--", sunsetStr = "--:--", dayLenStr = "";
int    sunProgress = -1;
boolean isNight = false;

String aqiStr = "", aqiLabel = "", aqiClass = "aqi-na", pm25Str = "";
boolean hasAqi = false;

List<Hour> hours = new ArrayList<Hour>();
List<Day>  days  = new ArrayList<Day>();

String displayQuery = !city.isEmpty() ? city : (labelParam != null ? labelParam.trim() : "");

if (!setupMode && (city.length() > 0 || (latParam != null && lonParam != null))) {
    try {
        JSONParser parser = new JSONParser();
        double lat = 0, lon = 0;
        boolean haveCoords = false;

        if (latParam != null && lonParam != null
                && latParam.trim().length() > 0 && lonParam.trim().length() > 0) {
            lat = Double.parseDouble(latParam.trim());
            lon = Double.parseDouble(lonParam.trim());
            haveCoords = true;
            if (labelParam != null && !labelParam.trim().isEmpty()) cityName = labelParam.trim();
        } else {
            /* ---- 1. Geocoding ---- */
            String geoUrl = baseUrl + "/geo/1.0/direct?q=" + URLEncoder.encode(city, "UTF-8")
                          + "&limit=1&appid=" + URLEncoder.encode(apiKey, "UTF-8");
            String geoBody = httpGet(geoUrl);
            if (geoBody == null) throw new IOException("Could not reach the OpenWeather geocoding service.");
            JSONArray geoArr = (JSONArray) parser.parse(geoBody);
            if (geoArr.isEmpty()) {
                errorMsg = "We couldn't find a place called \u201c" + city + "\u201d. Check the spelling or try a nearby larger city.";
            } else {
                JSONObject loc = (JSONObject) geoArr.get(0);
                cityName = String.valueOf(loc.get("name"));
                Object c = loc.get("country");
                country = c != null ? String.valueOf(c) : "";
                Object st = loc.get("state");
                if (st != null && !String.valueOf(st).isEmpty()) country = String.valueOf(st) + (country.isEmpty() ? "" : ", " + country);
                lat = Double.parseDouble(String.valueOf(loc.get("lat")));
                lon = Double.parseDouble(String.valueOf(loc.get("lon")));
                haveCoords = true;
            }
        }

        if (haveCoords && errorMsg == null) {
            /* ---- 2. Current conditions ---- */
            String curUrl = baseUrl + "/data/2.5/weather?lat=" + lat + "&lon=" + lon
                          + "&appid=" + URLEncoder.encode(apiKey, "UTF-8")
                          + "&units=" + unitQ;
            String curBody = httpGet(curUrl);
            if (curBody == null) throw new IOException("The weather service did not return current conditions.");
            JSONObject cur = (JSONObject) parser.parse(curBody);

            int tz = 0;
            Object tzObj = cur.get("timezone");
            if (tzObj != null) tz = ((Number) tzObj).intValue();

            long nowEpoch = System.currentTimeMillis() / 1000L;
            Object dtObj = cur.get("dt");
            long dt = dtObj != null ? ((Number) dtObj).longValue() : nowEpoch;

            SimpleDateFormat hm = new SimpleDateFormat("HH:mm", Locale.ENGLISH);
            hm.setTimeZone(TimeZone.getTimeZone("GMT"));
            SimpleDateFormat dayFmt = new SimpleDateFormat("EEEE, d MMMM", Locale.ENGLISH);
            dayFmt.setTimeZone(TimeZone.getTimeZone("GMT"));
            SimpleDateFormat hourFmt = new SimpleDateFormat("ha", Locale.ENGLISH);
            hourFmt.setTimeZone(TimeZone.getTimeZone("GMT"));
            SimpleDateFormat shortDay = new SimpleDateFormat("EEE", Locale.ENGLISH);
            shortDay.setTimeZone(TimeZone.getTimeZone("GMT"));
            SimpleDateFormat dateKey = new SimpleDateFormat("yyyy-MM-dd", Locale.ENGLISH);
            dateKey.setTimeZone(TimeZone.getTimeZone("GMT"));
            SimpleDateFormat h24 = new SimpleDateFormat("HH", Locale.ENGLISH);
            h24.setTimeZone(TimeZone.getTimeZone("GMT"));

            localTimeStr = hm.format(new Date((dt + tz) * 1000L));
            dateStr = dayFmt.format(new Date((dt + tz) * 1000L));

            JSONObject main = (JSONObject) cur.get("main");
            JSONArray wArr = (JSONArray) cur.get("weather");
            JSONObject w0 = (JSONObject) wArr.get(0);
            String owmIcon = String.valueOf(w0.get("icon"));

            mainStr = String.valueOf(w0.get("main"));
            descStr = String.valueOf(w0.get("description"));
            if (descStr.length() > 0) descStr = Character.toUpperCase(descStr.charAt(0)) + descStr.substring(1);

            double temp     = ((Number) main.get("temp")).doubleValue();
            double feels    = ((Number) main.get("feels_like")).doubleValue();
            int    humidity = ((Number) main.get("humidity")).intValue();
            int    press    = ((Number) main.get("pressure")).intValue();

            tempStr  = num(temp, 0) + "\u00b0";
            feelsStr = num(feels, 0);
            humidityStr = humidity + "%";
            pressureStr = press + " hPa";

            iconK = iconKey(owmIcon);
            wx    = themeKey(owmIcon);
            isNight = iconK.endsWith("-night");

            JSONObject wind = (JSONObject) cur.get("wind");
            if (wind != null) {
                Object ws = wind.get("speed");
                if (ws != null) windStr = num(((Number) ws).doubleValue(), 1) + " " + speedUnit;
                Object wd = wind.get("deg");
                if (wd != null) windDirStr = compass(((Number) wd).doubleValue());
                Object wg = wind.get("gust");
                if (wg != null) gustStr = "gust " + num(((Number) wg).doubleValue(), 1);
            }

            Object vis = cur.get("visibility");
            if (vis != null) {
                double vm = ((Number) vis).doubleValue();
                visStr = imperial ? num(vm / 1609.34, 1) + " mi" : num(vm / 1000.0, 1) + " km";
            }
            JSONObject clouds = (JSONObject) cur.get("clouds");
            if (clouds != null && clouds.get("all") != null) cloudsStr = clouds.get("all") + "%";

            JSONObject sys = (JSONObject) cur.get("sys");
            if (sys != null) {
                Object sr = sys.get("sunrise");
                Object ss = sys.get("sunset");
                if (sr != null && ss != null) {
                    long rise = ((Number) sr).longValue();
                    long set  = ((Number) ss).longValue();
                    sunriseStr = hm.format(new Date((rise + tz) * 1000L));
                    sunsetStr  = hm.format(new Date((set + tz) * 1000L));
                    long span = set - rise;
                    if (span > 0) {
                        dayLenStr = (span / 3600) + "h " + ((span % 3600) / 60) + "m of daylight";
                        double p = (double) (dt - rise) / (double) span;
                        if (p < 0) p = 0;
                        if (p > 1) p = 1;
                        sunProgress = (int) Math.round(p * 100);
                    }
                }
            }

            /* ---- 3. Forecast (hourly + daily) ---- */
            String fcUrl = baseUrl + "/data/2.5/forecast?lat=" + lat + "&lon=" + lon
                         + "&appid=" + URLEncoder.encode(apiKey, "UTF-8")
                         + "&units=" + unitQ;
            String fcBody = httpGet(fcUrl);
            if (fcBody != null) {
                JSONObject fc = (JSONObject) parser.parse(fcBody);
                JSONArray list = (JSONArray) fc.get("list");
                Object ctz = ((JSONObject) fc.get("city")).get("timezone");
                int ftz = ctz != null ? ((Number) ctz).intValue() : tz;

                LinkedHashMap byDate = new LinkedHashMap();

                for (int i = 0; i < list.size(); i++) {
                    JSONObject it = (JSONObject) list.get(i);
                    long e = ((Number) it.get("dt")).longValue();
                    Date local = new Date((e + ftz) * 1000L);
                    double t = ((Number) ((JSONObject) it.get("main")).get("temp")).doubleValue();
                    JSONObject iw = (JSONObject) ((JSONArray) it.get("weather")).get(0);
                    String ico = String.valueOf(iw.get("icon"));
                    Object popObj = it.get("pop");
                    int pop = popObj != null ? (int) Math.round(((Number) popObj).doubleValue() * 100) : 0;

                    if (e >= nowEpoch - 3600 && hours.size() < 8) {
                        Hour h = new Hour();
                        h.time = hourFmt.format(local);
                        h.temp = num(t, 0) + "\u00b0";
                        h.icon = iconKey(ico);
                        h.pop  = pop >= 20 ? pop + "%" : "";
                        hours.add(h);
                    }

                    String key = dateKey.format(local);
                    Day dday = (Day) byDate.get(key);
                    int hh = Integer.parseInt(h24.format(local));
                    if (dday == null) {
                        dday = new Day();
                        dday.name = shortDay.format(local);
                        dday.date = new SimpleDateFormat("d MMM", Locale.ENGLISH).format(local);
                        dday.min = num(t, 0);
                        dday.max = num(t, 0);
                        dday.icon = iconKey(ico);
                        dday.desc = String.valueOf(iw.get("main"));
                        dday.pop = pop >= 20 ? pop + "%" : "";
                        byDate.put(key, dday);
                    } else {
                        double lo = Double.parseDouble(dday.min);
                        double hi = Double.parseDouble(dday.max);
                        if (t < lo) dday.min = num(t, 0);
                        if (t > hi) dday.max = num(t, 0);
                        if (hh >= 12 && hh <= 15) {
                            dday.icon = iconKey(ico);
                            dday.desc = String.valueOf(iw.get("main"));
                            dday.pop = pop >= 20 ? pop + "%" : "";
                        }
                    }
                }

                Iterator it2 = byDate.keySet().iterator();
                int guard = 0;
                while (it2.hasNext() && days.size() < 5 && guard < 10) {
                    days.add((Day) byDate.get(it2.next()));
                    guard++;
                }
                if (!days.isEmpty()) {
                    highStr = days.get(0).max + "\u00b0";
                    lowStr  = days.get(0).min + "\u00b0";
                }
            }

            /* ---- 4. Air quality (optional - never fatal) ---- */
            try {
                String aqUrl = baseUrl + "/data/2.5/air_pollution?lat=" + lat + "&lon=" + lon
                             + "&appid=" + URLEncoder.encode(apiKey, "UTF-8");
                String aqBody = httpGet(aqUrl);
                if (aqBody != null) {
                    JSONObject aq = (JSONObject) parser.parse(aqBody);
                    JSONArray al = (JSONArray) aq.get("list");
                    if (al != null && !al.isEmpty()) {
                        JSONObject entry = (JSONObject) al.get(0);
                        int aqi = ((Number) ((JSONObject) entry.get("main")).get("aqi")).intValue();
                        hasAqi = true;
                        aqiStr = String.valueOf(aqi);
                        if (aqi == 1)      { aqiLabel = "Good";        aqiClass = "aqi-1"; }
                        else if (aqi == 2) { aqiLabel = "Fair";        aqiClass = "aqi-2"; }
                        else if (aqi == 3) { aqiLabel = "Moderate";    aqiClass = "aqi-3"; }
                        else if (aqi == 4) { aqiLabel = "Poor";        aqiClass = "aqi-4"; }
                        else               { aqiLabel = "Very poor";   aqiClass = "aqi-5"; }
                        JSONObject comp = (JSONObject) entry.get("components");
                        if (comp != null && comp.get("pm2_5") != null) {
                            pm25Str = num(((Number) comp.get("pm2_5")).doubleValue(), 1) + " \u00b5g/m\u00b3 PM2.5";
                        }
                    }
                }
            } catch (Exception ignore) { /* air quality is a nice-to-have */ }

            hasData = true;
        }
    } catch (Exception ex) {
        errorMsg = ex.getMessage() != null ? ex.getMessage() : ex.toString();
    }
}

if (hasData && displayQuery.isEmpty()) displayQuery = cityName;

/* "Carry my location" query suffix, so switching units keeps the same result. */
String carry = "";
if (city.length() > 0) {
    carry = "&city=" + URLEncoder.encode(city, "UTF-8");
} else if (latParam != null && lonParam != null
           && latParam.trim().length() > 0 && lonParam.trim().length() > 0) {
    carry = "&lat=" + URLEncoder.encode(latParam.trim(), "UTF-8")
          + "&lon=" + URLEncoder.encode(lonParam.trim(), "UTF-8")
          + "&label=" + URLEncoder.encode(labelParam != null ? labelParam.trim() : "My location", "UTF-8");
}
%>
<!DOCTYPE html>
<html lang="en" data-wx="<%= esc(wx) %>" data-hasdata="<%= hasData ? "1" : "0" %>">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
<meta name="color-scheme" content="dark light" />
<meta name="theme-color" content="#0a0f1c" />
<meta name="description" content="Live weather forecasting for any city in the world - current conditions, hourly outlook, 5-day forecast and air quality." />
<title><%= hasData ? esc(cityName) + " - " : "" %>Live Weather Forecasting</title>

<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300..800&family=Inter:wght@400;500;600&display=swap" rel="stylesheet" />
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'%3E%3Ctext y='.9em' font-size='90'%3E%E2%9B%85%3C/text%3E%3C/svg%3E" />

<script>
/* Set the theme before first paint so there is no flash of the wrong mode. */
(function () {
  try {
    var saved = localStorage.getItem('lwf-theme');
    var sys = window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
    document.documentElement.dataset.theme = saved || sys;
  } catch (e) { document.documentElement.dataset.theme = 'dark'; }
})();
</script>

<style>
@layer reset, tokens, base, layout, components, motion;

/* ---------------------------------------------------------------- tokens */
@layer tokens {
  :root {
    --font-display: 'Outfit', 'Segoe UI', system-ui, sans-serif;
    --font-body: 'Inter', 'Segoe UI', system-ui, sans-serif;

    --r-xs: 10px;
    --r-sm: 14px;
    --r-md: 20px;
    --r-lg: 28px;
    --r-xl: 34px;

    --gap: clamp(0.7rem, 0.4rem + 1vw, 1.15rem);
    --pad: clamp(1rem, 0.6rem + 1.4vw, 1.6rem);

    --ease-spring: cubic-bezier(0.22, 1.4, 0.36, 1);
    --ease-out: cubic-bezier(0.22, 1, 0.36, 1);

    /* Weather-reactive accent, overridden by [data-wx] below. */
    --accent: #7aa2ff;
    --accent-2: #a78bfa;
  }

  html[data-theme='dark'] {
    --bg: #070b16;
    --ink: #eef3ff;
    --ink-2: #b9c6e4;
    --ink-3: #8291b4;
    --glass: rgba(255, 255, 255, 0.055);
    --glass-strong: rgba(255, 255, 255, 0.085);
    --stroke: rgba(255, 255, 255, 0.10);
    --specular: rgba(255, 255, 255, 0.55);
    --shadow: 0 24px 60px -20px rgba(0, 0, 0, 0.75);
    --ring: rgba(255, 255, 255, 0.06);
    --blob-a: 0.55;
  }

  html[data-theme='light'] {
    --bg: #eef2fb;
    --ink: #0b1224;
    --ink-2: #3c4a66;
    --ink-3: #6b7a99;
    --glass: rgba(255, 255, 255, 0.62);
    --glass-strong: rgba(255, 255, 255, 0.82);
    --stroke: rgba(255, 255, 255, 0.9);
    --specular: rgba(255, 255, 255, 0.95);
    --shadow: 0 22px 55px -26px rgba(28, 44, 92, 0.45);
    --ring: rgba(12, 22, 48, 0.05);
    --blob-a: 0.42;
  }

  html[data-wx='clear-day'] { --accent: #ffb020; --accent-2: #ff7a45; }
  html[data-wx='clear-night'] { --accent: #8fa8ff; --accent-2: #6f6df0; }
  html[data-wx='cloud'] { --accent: #9fb6d6; --accent-2: #6f8dbb; }
  html[data-wx='rain'] { --accent: #4fb0f0; --accent-2: #3b6fe0; }
  html[data-wx='thunder'] { --accent: #b78bff; --accent-2: #7a5cf0; }
  html[data-wx='snow'] { --accent: #9fe3ff; --accent-2: #6fc3f0; }
  html[data-wx='fog'] { --accent: #b9c6d6; --accent-2: #8d9db2; }
}

/* ----------------------------------------------------------------- reset */
@layer reset {
  *, *::before, *::after { box-sizing: border-box; }
  html, body, h1, h2, h3, p, ul, li, form, figure { margin: 0; padding: 0; }
  ul { list-style: none; }
  button, input { font: inherit; color: inherit; }
  img, svg { display: block; max-width: 100%; }
}

/* ------------------------------------------------------------------ base */
@layer base {
  html {
    -webkit-text-size-adjust: 100%;
    scroll-behavior: smooth;
  }
  body {
    min-height: 100svh;
    background: var(--bg);
    color: var(--ink);
    font-family: var(--font-body);
    font-size: clamp(0.94rem, 0.9rem + 0.18vw, 1.02rem);
    line-height: 1.55;
    -webkit-font-smoothing: antialiased;
    overflow-x: hidden;
    transition: background 0.6s var(--ease-out), color 0.4s var(--ease-out);
  }
  h1, h2, h3 {
    font-family: var(--font-display);
    font-weight: 600;
    line-height: 1.1;
    letter-spacing: -0.02em;
    text-wrap: balance;
  }
  a { color: inherit; }

  :focus-visible {
    outline: 2.5px solid var(--accent);
    outline-offset: 3px;
    border-radius: 6px;
  }

  .sr-only {
    position: absolute; width: 1px; height: 1px;
    padding: 0; margin: -1px; overflow: hidden;
    clip: rect(0 0 0 0); white-space: nowrap; border: 0;
  }

  .skip-link {
    position: absolute; left: 50%; translate: -50% -140%;
    z-index: 100; padding: 0.7rem 1.4rem;
    background: var(--accent); color: #080d18;
    border-radius: 0 0 14px 14px; font-weight: 600;
    text-decoration: none; transition: translate 0.25s var(--ease-spring);
  }
  .skip-link:focus { translate: -50% 0; }
}

/* ---------------------------------------------------------------- layout */
@layer layout {
  /* Aurora mesh background */
  .aurora {
    position: fixed; inset: -25vmax;
    z-index: -1; pointer-events: none;
    filter: blur(90px) saturate(150%);
    opacity: var(--blob-a);
  }
  .aurora span {
    position: absolute; display: block;
    width: 46vmax; height: 46vmax; border-radius: 50%;
    mix-blend-mode: screen;
    animation: float 26s ease-in-out infinite alternate;
  }
  html[data-theme='light'] .aurora span { mix-blend-mode: multiply; opacity: 0.55; }
  .aurora .b1 { background: radial-gradient(circle, var(--accent), transparent 68%); top: 4%;  left: 2%;  }
  .aurora .b2 { background: radial-gradient(circle, var(--accent-2), transparent 68%); top: 38%; left: 46%; animation-delay: -8s; }
  .aurora .b3 { background: radial-gradient(circle, #22d3ee, transparent 70%);        top: 8%;  left: 62%; animation-delay: -15s; }
  html[data-wx='clear-day'] .aurora .b3 { background: radial-gradient(circle, #ff5f6d, transparent 70%); }

  @keyframes float {
    0%   { transform: translate3d(0, 0, 0) scale(1); }
    50%  { transform: translate3d(4vmax, -3vmax, 0) scale(1.12); }
    100% { transform: translate3d(-3vmax, 4vmax, 0) scale(0.95); }
  }

  .shell {
    width: min(1240px, 100% - 2 * clamp(0.8rem, 3vw, 2.2rem));
    margin-inline: auto;
    padding-block: clamp(1rem, 2.5vw, 2rem) 3rem;
    display: flex; flex-direction: column; gap: var(--gap);
  }

  .topbar {
    display: flex; align-items: center; gap: 1rem;
    justify-content: space-between; flex-wrap: wrap;
  }

  .bento {
    display: grid;
    grid-template-columns: repeat(12, minmax(0, 1fr));
    gap: var(--gap);
    align-items: stretch;
  }
  .col-3  { grid-column: span 3; }
  .col-4  { grid-column: span 4; }
  .col-6  { grid-column: span 6; }
  .col-8  { grid-column: span 8; }
  .col-12 { grid-column: span 12; }

  @media (max-width: 1080px) {
    .col-3 { grid-column: span 6; }
    .col-8 { grid-column: span 12; }
  }
  @media (max-width: 760px) {
    .col-3, .col-4, .col-6, .col-8 { grid-column: span 12; }
  }
}

/* ------------------------------------------------------------ components */
@layer components {

  /* -------- Liquid glass surface -------- */
  .glass {
    position: relative;
    background: var(--glass);
    border-radius: var(--r-lg);
    border: 1px solid var(--stroke);
    box-shadow: var(--shadow), inset 0 1px 0 var(--ring);
    backdrop-filter: blur(22px) saturate(180%);
    -webkit-backdrop-filter: blur(22px) saturate(180%);
    padding: var(--pad);
    isolation: isolate;
    transition: transform 0.4s var(--ease-spring), box-shadow 0.4s var(--ease-out),
                background 0.4s var(--ease-out);
  }
  /* specular gradient edge - the "liquid glass" highlight */
  .glass::before {
    content: '';
    position: absolute; inset: 0;
    border-radius: inherit;
    padding: 1px;
    background: linear-gradient(145deg, var(--specular), transparent 38%, transparent 62%, var(--specular));
    -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
    mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
    -webkit-mask-composite: xor;
    mask-composite: exclude;
    opacity: 0.5;
    pointer-events: none;
    z-index: 2;
  }
  .glass:hover { background: var(--glass-strong); }

  /* -------- Brand -------- */
  .brand { display: flex; align-items: center; gap: 0.75rem; min-width: 0; }
  .brand-mark {
    display: grid; place-items: center;
    width: 46px; height: 46px; flex: none;
    border-radius: 15px;
    color: #08101f;
    background: linear-gradient(140deg, var(--accent), var(--accent-2));
    box-shadow: 0 10px 26px -10px var(--accent);
  }
  .brand-mark svg { width: 25px; height: 25px; }
  .brand-text h1 { font-size: clamp(1.02rem, 0.9rem + 0.6vw, 1.3rem); }
  .brand-text p {
    font-size: 0.76rem; color: var(--ink-3);
    letter-spacing: 0.06em; text-transform: uppercase; font-weight: 500;
  }

  .topbar-actions { display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; }

  /* -------- Segmented / icon controls -------- */
  .seg {
    display: inline-flex; align-items: center; gap: 2px;
    padding: 4px; border-radius: 999px;
    background: var(--glass); border: 1px solid var(--stroke);
    backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px);
  }
  .seg a, .seg button, .icon-btn {
    display: inline-grid; place-items: center;
    min-width: 42px; height: 36px; padding-inline: 0.85rem;
    border: 0; border-radius: 999px;
    background: transparent; color: var(--ink-2);
    font-size: 0.86rem; font-weight: 600;
    text-decoration: none; cursor: pointer;
    transition: color 0.25s, background 0.25s var(--ease-out), transform 0.3s var(--ease-spring);
  }
  .seg a:hover, .seg button:hover, .icon-btn:hover {
    color: var(--ink); background: var(--glass-strong); transform: translateY(-1px);
  }
  .seg [aria-current='true'], .seg .is-active {
    background: linear-gradient(140deg, var(--accent), var(--accent-2));
    color: #08101f;
    box-shadow: 0 8px 20px -10px var(--accent);
  }
  .icon-btn { width: 44px; height: 44px; padding: 0; border-radius: 999px;
    background: var(--glass); border: 1px solid var(--stroke);
    backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); }
  .icon-btn svg { width: 21px; height: 21px; }
  html[data-theme='light'] .moon-only,
  html[data-theme='dark']  .sun-only { display: none; }

  /* -------- Search -------- */
  .search { padding: clamp(0.9rem, 0.6rem + 1vw, 1.35rem); }
  .search-row { display: flex; gap: 0.55rem; align-items: stretch; }
  .field {
    position: relative; flex: 1 1 auto; min-width: 0;
    display: flex; align-items: center; gap: 0.65rem;
    padding: 0 1.05rem;
    border-radius: var(--r-md);
    background: var(--glass-strong);
    border: 1px solid var(--stroke);
    transition: border-color 0.3s, box-shadow 0.3s;
  }
  .field:focus-within {
    border-color: color-mix(in srgb, var(--accent) 65%, transparent);
    box-shadow: 0 0 0 4px color-mix(in srgb, var(--accent) 18%, transparent);
  }
  .field svg { width: 19px; height: 19px; color: var(--ink-3); flex: none; }
  .field input {
    flex: 1 1 auto; min-width: 0;
    border: 0; background: transparent; outline: none;
    padding: 0.85rem 0;
    font-size: clamp(0.98rem, 0.9rem + 0.3vw, 1.08rem);
  }
  .field input::placeholder { color: var(--ink-3); }
  .kbd {
    flex: none; display: none;
    padding: 0.14rem 0.45rem; border-radius: 7px;
    border: 1px solid var(--stroke);
    font-size: 0.7rem; font-weight: 600; color: var(--ink-3);
    font-family: var(--font-body);
  }
  @media (min-width: 700px) { .kbd { display: inline-block; } }

  .btn {
    display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem;
    padding: 0 1.5rem; min-height: 50px;
    border: 0; border-radius: var(--r-md);
    background: linear-gradient(140deg, var(--accent), var(--accent-2));
    color: #08101f; font-weight: 650;
    cursor: pointer; white-space: nowrap;
    box-shadow: 0 16px 34px -16px var(--accent);
    transition: transform 0.35s var(--ease-spring), box-shadow 0.35s var(--ease-out), filter 0.25s;
  }
  .btn:hover { transform: translateY(-2px); box-shadow: 0 22px 42px -16px var(--accent); filter: brightness(1.05); }
  .btn:active { transform: translateY(0) scale(0.985); }
  .btn svg { width: 18px; height: 18px; }

  .btn-ghost {
    display: inline-flex; align-items: center; gap: 0.5rem;
    padding: 0 1.05rem; min-height: 50px;
    border-radius: var(--r-md);
    background: var(--glass-strong);
    border: 1px solid var(--stroke);
    color: var(--ink-2); font-weight: 600; cursor: pointer;
    transition: color 0.25s, transform 0.35s var(--ease-spring), background 0.25s;
  }
  .btn-ghost:hover { color: var(--ink); transform: translateY(-2px); }
  .btn-ghost svg { width: 18px; height: 18px; }

  @media (max-width: 640px) {
    .search-row { flex-direction: column; }
    .btn, .btn-ghost { width: 100%; }
  }

  /* -------- Chips -------- */
  .chips { display: flex; flex-wrap: wrap; gap: 0.45rem; margin-top: 0.9rem; }
  .chip {
    display: inline-flex; align-items: center; gap: 0.4rem;
    padding: 0.36rem 0.85rem;
    border-radius: 999px;
    background: var(--glass-strong);
    border: 1px solid var(--stroke);
    color: var(--ink-2);
    font-size: 0.82rem; font-weight: 500;
    text-decoration: none; cursor: pointer;
    transition: transform 0.3s var(--ease-spring), color 0.25s, border-color 0.25s;
  }
  .chip:hover { color: var(--ink); transform: translateY(-2px); border-color: color-mix(in srgb, var(--accent) 50%, transparent); }
  .chip svg { width: 13px; height: 13px; opacity: 0.6; }
  .chip-label { font-size: 0.72rem; letter-spacing: 0.1em; text-transform: uppercase; color: var(--ink-3); font-weight: 600; }

  /* -------- Card headers -------- */
  .card-head {
    display: flex; align-items: center; justify-content: space-between;
    gap: 0.6rem; margin-bottom: 0.9rem;
  }
  .card-head h2, .card-head h3 {
    font-size: 0.76rem; font-weight: 600;
    letter-spacing: 0.12em; text-transform: uppercase; color: var(--ink-3);
  }
  .card-head svg { width: 17px; height: 17px; color: var(--ink-3); }

  /* -------- Hero "now" card -------- */
  .now { display: flex; flex-direction: column; gap: 1rem; overflow: hidden; }
  .now-top { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; }
  .place h2 {
    font-size: clamp(1.35rem, 1rem + 1.6vw, 2rem);
    letter-spacing: -0.03em; color: var(--ink);
    display: flex; align-items: center; gap: 0.4rem; flex-wrap: wrap;
  }
  .place .meta {
    margin-top: 0.2rem; color: var(--ink-3); font-size: 0.86rem;
    display: flex; align-items: center; gap: 0.45rem; flex-wrap: wrap;
  }
  .dot { width: 3px; height: 3px; border-radius: 50%; background: currentColor; opacity: 0.6; }

  .hero-icon {
    width: clamp(74px, 12vw, 108px); height: clamp(74px, 12vw, 108px);
    flex: none; color: var(--accent);
    filter: drop-shadow(0 12px 30px color-mix(in srgb, var(--accent) 45%, transparent));
    animation: bob 6s ease-in-out infinite;
  }
  @keyframes bob {
    0%, 100% { transform: translateY(0) rotate(0deg); }
    50%      { transform: translateY(-7px) rotate(2deg); }
  }

  .temp-row { display: flex; align-items: center; gap: 1rem; flex-wrap: wrap; }
  .temp {
    font-family: var(--font-display);
    font-size: clamp(4rem, 2.4rem + 8vw, 7rem);
    font-weight: 300; line-height: 0.86; letter-spacing: -0.055em;
    font-variant-numeric: tabular-nums;
    background: linear-gradient(160deg, var(--ink), color-mix(in srgb, var(--accent) 75%, var(--ink)));
    -webkit-background-clip: text; background-clip: text;
    -webkit-text-fill-color: transparent; color: transparent;
  }
  .temp-side { display: flex; flex-direction: column; gap: 0.15rem; padding-bottom: 0.5rem; }
  .cond { font-weight: 600; font-size: clamp(1rem, 0.9rem + 0.5vw, 1.18rem); }
  .range { color: var(--ink-3); font-size: 0.88rem; font-variant-numeric: tabular-nums; }

  .quick { display: flex; flex-wrap: wrap; gap: 0.5rem 1.5rem; color: var(--ink-2); font-size: 0.88rem; }
  .quick b { font-weight: 600; color: var(--ink); font-variant-numeric: tabular-nums; }

  /* -------- Metric tiles -------- */
  .tile {
    display: flex; flex-direction: column; justify-content: space-between; gap: 0.85rem;
    min-height: 128px;
  }
  .tile-top { display: flex; align-items: center; justify-content: space-between; gap: 0.5rem; }
  .tile-label { font-size: 0.72rem; letter-spacing: 0.1em; text-transform: uppercase; color: var(--ink-3); font-weight: 600; }
  .tile-top svg { width: 18px; height: 18px; color: var(--accent); opacity: 0.85; }
  .tile-value {
    font-family: var(--font-display);
    font-size: clamp(1.5rem, 1.2rem + 1.1vw, 1.95rem);
    font-weight: 500; letter-spacing: -0.03em;
    font-variant-numeric: tabular-nums;
  }
  .tile-sub { font-size: 0.78rem; color: var(--ink-3); }

  /* -------- Sun arc -------- */
  .arc { position: relative; height: 110px; display: grid; place-items: end center; }
  .arc-svg { width: 100%; height: 100%; overflow: visible; }
  .arc-track { fill: none; stroke: var(--stroke); stroke-width: 2; stroke-dasharray: 4 6; stroke-linecap: round; }
  .arc-done { fill: none; stroke: var(--accent); stroke-width: 2.5; stroke-linecap: round; }
  .arc-sun {
    fill: var(--accent);
    filter: drop-shadow(0 0 10px color-mix(in srgb, var(--accent) 80%, transparent));
  }
  .arc-legend { display: flex; justify-content: space-between; margin-top: 0.6rem; font-size: 0.82rem; color: var(--ink-2); font-variant-numeric: tabular-nums; }
  .arc-legend small { display: block; color: var(--ink-3); font-size: 0.7rem; letter-spacing: 0.08em; text-transform: uppercase; font-weight: 600; }

  /* -------- AQI -------- */
  .aqi-badge {
    display: inline-grid; place-items: center;
    width: 62px; height: 62px; border-radius: 50%;
    font-family: var(--font-display); font-size: 1.6rem; font-weight: 600;
    border: 2px solid currentColor;
    background: color-mix(in srgb, currentColor 14%, transparent);
  }
  .aqi-1 { color: #34d399; } .aqi-2 { color: #a3e635; } .aqi-3 { color: #fbbf24; }
  .aqi-4 { color: #fb923c; } .aqi-5 { color: #f87171; } .aqi-na { color: var(--ink-3); }

  /* -------- Scroll rows -------- */
  .scroller {
    display: grid; grid-auto-flow: column;
    grid-auto-columns: minmax(76px, 1fr);
    gap: 0.5rem;
    overflow-x: auto;
    padding-bottom: 0.5rem;
    scroll-snap-type: x mandatory;
    scrollbar-width: thin;
    scrollbar-color: color-mix(in srgb, var(--ink-3) 45%, transparent) transparent;
  }
  .scroller::-webkit-scrollbar { height: 6px; }
  .scroller::-webkit-scrollbar-thumb { background: color-mix(in srgb, var(--ink-3) 40%, transparent); border-radius: 99px; }
  .scroller::-webkit-scrollbar-track { background: transparent; }

  .hour {
    scroll-snap-align: start;
    display: flex; flex-direction: column; align-items: center; gap: 0.45rem;
    padding: 0.8rem 0.4rem;
    border-radius: var(--r-sm);
    background: linear-gradient(180deg, transparent, color-mix(in srgb, var(--accent) 12%, transparent));
    border: 1px solid transparent;
    transition: transform 0.35s var(--ease-spring), border-color 0.3s, background 0.3s;
  }
  .hour:hover { transform: translateY(-4px); border-color: color-mix(in srgb, var(--accent) 40%, transparent); }
  .hour time { font-size: 0.75rem; color: var(--ink-3); font-weight: 600; letter-spacing: 0.02em; }
  .hour .ico { width: 26px; height: 26px; color: var(--accent); }
  .hour .t { font-family: var(--font-display); font-weight: 600; font-size: 1.02rem; font-variant-numeric: tabular-nums; }
  .hour .p { font-size: 0.7rem; color: #6fc3f0; font-weight: 600; min-height: 1em; }

  /* -------- Daily forecast -------- */
  .days { display: flex; flex-direction: column; }
  .day {
    display: grid;
    grid-template-columns: 3.2rem 1.7rem 1fr auto;
    align-items: center; gap: 0.7rem;
    padding: 0.62rem 0.5rem;
    border-radius: var(--r-sm);
    transition: background 0.3s var(--ease-out), transform 0.3s var(--ease-spring);
  }
  .day + .day { border-top: 1px solid var(--ring); }
  .day:hover { background: var(--glass-strong); transform: translateX(4px); }
  .day .dname { font-weight: 600; font-size: 0.9rem; }
  .day .ddesc { color: var(--ink-3); font-size: 0.82rem; }
  .day .ico { width: 24px; height: 24px; color: var(--accent); }
  .day .range-bar {
    display: flex; align-items: center; gap: 0.5rem;
    font-variant-numeric: tabular-nums; font-size: 0.88rem;
  }
  .day .range-bar .min { color: var(--ink-3); }
  .track { position: relative; width: clamp(52px, 10vw, 96px); height: 5px; border-radius: 99px; background: var(--ring); overflow: hidden; }
  .track i {
    position: absolute; inset-block: 0; border-radius: 99px;
    background: linear-gradient(90deg, #6fc3f0, var(--accent));
  }
  @media (max-width: 520px) {
    .day { grid-template-columns: 2.6rem 1.5rem 1fr; }
    .day .track { display: none; }
    .day .ddesc { display: none; }
  }

  /* -------- States -------- */
  .notice {
    display: flex; gap: 0.85rem; align-items: flex-start;
    padding: 1rem 1.15rem;
    border-radius: var(--r-md);
    border: 1px solid color-mix(in srgb, #f87171 40%, transparent);
    background: color-mix(in srgb, #f87171 12%, transparent);
    color: var(--ink-2);
  }
  .notice svg { width: 20px; height: 20px; color: #f87171; flex: none; margin-top: 2px; }
  .notice b { color: var(--ink); display: block; margin-bottom: 0.15rem; }

  .setup { display: grid; gap: 1rem; }
  .setup h2 { font-size: clamp(1.15rem, 1rem + 0.7vw, 1.45rem); }
  .setup p { color: var(--ink-2); max-width: 62ch; }
  .steps { display: grid; gap: 0.6rem; counter-reset: s; margin-top: 0.2rem; }
  .steps li {
    counter-increment: s;
    display: grid; grid-template-columns: 1.7rem 1fr; gap: 0.7rem;
    align-items: start;
    color: var(--ink-2); font-size: 0.92rem;
  }
  .steps li::before {
    content: counter(s);
    display: grid; place-items: center;
    width: 1.7rem; height: 1.7rem; border-radius: 50%;
    background: color-mix(in srgb, var(--accent) 20%, transparent);
    color: var(--accent); font-weight: 700; font-size: 0.78rem;
  }
  .steps code, .code {
    font-family: ui-monospace, 'Cascadia Code', Menlo, Consolas, monospace;
    font-size: 0.86em;
    padding: 0.15rem 0.45rem;
    border-radius: 7px;
    background: var(--glass-strong);
    border: 1px solid var(--stroke);
    color: var(--ink);
  }
  .steps a { color: var(--accent); text-underline-offset: 3px; }

  .empty {
    display: grid; place-items: center; text-align: center;
    gap: 0.7rem; padding: clamp(1.5rem, 4vw, 3rem) 1rem;
  }
  .empty .art {
    width: 92px; height: 92px; color: var(--accent);
    animation: bob 7s ease-in-out infinite;
  }
  .empty h2 { font-size: clamp(1.2rem, 1rem + 0.9vw, 1.6rem); }
  .empty p { color: var(--ink-2); max-width: 46ch; }

  /* -------- Footer -------- */
  .foot {
    margin-top: 0.5rem; text-align: center;
    color: var(--ink-3); font-size: 0.82rem;
    display: flex; align-items: center; justify-content: center;
    gap: 0.5rem; flex-wrap: wrap;
  }
  .foot a { color: var(--ink-2); text-underline-offset: 3px; }
  .foot a:hover { color: var(--accent); }

  /* -------- Progress bar -------- */
  .progress {
    position: fixed; inset-inline: 0; top: 0; height: 2px; z-index: 60;
    background: linear-gradient(90deg, var(--accent), var(--accent-2));
    transform: scaleX(0); transform-origin: 0 50%;
    opacity: 0; transition: transform 0.4s var(--ease-out), opacity 0.3s;
  }
  .progress.on { opacity: 1; transform: scaleX(0.75); transition: transform 8s cubic-bezier(0.1, 0.7, 0.3, 1), opacity 0.2s; }
}

/* --------------------------------------------------------------- motion */
@layer motion {
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after {
      animation-duration: 0.001ms !important;
      animation-iteration-count: 1 !important;
      transition-duration: 0.001ms !important;
      scroll-behavior: auto !important;
    }
    .aurora span { animation: none; }
  }

  /* Cross-document view transitions (Chromium 126+) */
  @view-transition { navigation: auto; }
  ::view-transition-old(root) { animation: fade-out 0.18s ease both; }
  ::view-transition-new(root) { animation: fade-in 0.28s ease both; }
  @keyframes fade-out { to { opacity: 0; } }
  @keyframes fade-in { from { opacity: 0; } }

  @media (prefers-reduced-motion: reduce) {
    ::view-transition-old(root), ::view-transition-new(root) { animation: none; }
  }
}
</style>
</head>

<body>
<a class="skip-link" href="#main">Skip to content</a>
<div class="progress" id="progress" aria-hidden="true"></div>

<div class="aurora" aria-hidden="true">
  <span class="b1"></span><span class="b2"></span><span class="b3"></span>
</div>

<div class="shell">

  <!-- ============================== top bar ============================== -->
  <header class="topbar">
    <div class="brand">
      <span class="brand-mark" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="3.4"/>
          <path d="M12 3v1.6M12 19.4V21M4.6 4.6l1.1 1.1M18.3 18.3l1.1 1.1M3 12h1.6M19.4 12H21M4.6 19.4l1.1-1.1M18.3 5.7l1.1-1.1"/>
        </svg>
      </span>
      <div class="brand-text">
        <h1>Live Weather</h1>
        <p>Powered by OpenWeather</p>
      </div>
    </div>

    <div class="topbar-actions">
      <div class="seg" role="group" aria-label="Temperature unit">
        <a href="?unit=metric<%= carry %>" <%= !imperial ? "aria-current=\"true\"" : "" %>>°C</a>
        <a href="?unit=imperial<%= carry %>" <%= imperial ? "aria-current=\"true\"" : "" %>>°F</a>
      </div>
      <button class="icon-btn" id="themeBtn" type="button"
              aria-label="Switch colour theme">
        <svg class="moon-only" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>
        </svg>
        <svg class="sun-only" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M4.2 4.2l1.5 1.5M18.3 18.3l1.5 1.5M2.5 12h2M19.5 12h2M4.2 19.8l1.5-1.5M18.3 5.7l1.5-1.5"/>
        </svg>
      </button>
    </div>
  </header>

  <!-- =============================== search ============================== -->
  <section class="glass search" aria-label="Search for a city">
    <form method="post" id="searchForm" autocomplete="off">
      <input type="hidden" name="lat" id="latField" />
      <input type="hidden" name="lon" id="lonField" />
      <input type="hidden" name="label" id="labelField" />
      <input type="hidden" name="unit" value="<%= unitQ %>" />
      <div class="search-row">
        <label class="field" for="cityInput">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="11" cy="11" r="7"/><path d="m20 20-3.4-3.4"/>
          </svg>
          <input id="cityInput" type="text" name="city" enterkeyhint="search"
                 placeholder="Search any city, e.g. Mumbai, London, São Paulo"
                 value="<%= esc(city) %>" autocomplete="off" />
          <kbd class="kbd" aria-hidden="true">/</kbd>
        </label>
        <button class="btn-ghost" type="button" id="geoBtn" title="Use my current location">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="3.2"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>
            <circle cx="12" cy="12" r="8.4" opacity=".45"/>
          </svg>
          My location
        </button>
        <button class="btn" type="submit">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="11" cy="11" r="7"/><path d="m20 20-3.4-3.4"/>
          </svg>
          Forecast
        </button>
      </div>
    </form>

    <div class="chips" id="suggestChips" hidden>
      <span class="chip-label">Recent</span>
      <span id="recentList" style="display:contents"></span>
    </div>
    <div class="chips">
      <span class="chip-label">Try</span>
      <% String[][] quick = {
           {"Mumbai, IN", "Mumbai"}, {"Guwahati, IN", "Guwahati"},
           {"London, GB", "London"},  {"New York, US", "New York"},
           {"Tokyo, JP", "Tokyo"},    {"São Paulo, BR", "Sao Paulo"},
           {"Dubai, AE", "Dubai"},    {"Singapore", "Singapore"} };
         for (int qi = 0; qi < quick.length; qi++) { %>
        <a class="chip" href="?city=<%= URLEncoder.encode(quick[qi][1], "UTF-8") %>&amp;unit=<%= unitQ %>"><%= esc(quick[qi][0]) %></a>
      <% } %>
    </div>
  </section>

  <main class="bento" id="main">

<% if (setupMode) { %>
  <!-- ============================ setup guide =========================== -->
  <section class="glass col-12 setup">
    <div class="card-head"><h2>Finish setup</h2></div>
    <h2>Add your OpenWeather API key to go live</h2>
    <p>The app is deployed and running — it just needs a free API key before it can pull live conditions.
       The key stays on the server (read from the <code>OPENWEATHER_API_KEY</code> environment variable),
       so it is never exposed to visitors.</p>

    <ol class="steps">
      <li><span>Create a free account at <a href="https://home.openweathermap.org/users/sign_up" target="_blank" rel="noopener">home.openweathermap.org/users/sign_up</a>.</span></li>
      <li><span>Confirm your email, then open <a href="https://home.openweathermap.org/api_keys" target="_blank" rel="noopener">API keys</a>.
               A default key is generated for you — or create a new one named <code>live-weather</code>.</span></li>
      <li><span>Copy the key (a 32-character string of letters and numbers).</span></li>
      <li><span>In the Render dashboard, open your service → <b>Environment</b> → add
               <code>OPENWEATHER_API_KEY</code> = your key → <b>Save changes</b>.</span></li>
      <li><span>Render redeploys automatically. A brand-new key can take up to ~2 hours to activate;
               you may briefly see <i>401 Invalid API key</i> until it does.</span></li>
    </ol>

    <p class="tile-sub">Running locally instead? Start Tomcat with
      <code>OPENWEATHER_API_KEY=your_key</code> in the environment, or set it in
      <code>docker-compose.yml</code>.</p>
  </section>
<% } else if (errorMsg != null) { %>
  <!-- ============================== error =============================== -->
  <div class="glass col-12 notice" role="alert">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 9v4.2M12 17h.01"/><circle cx="12" cy="12" r="9.2" opacity=".4"/>
    </svg>
    <div>
      <b>We couldn't load that forecast</b>
      <%= esc(errorMsg) %>
    </div>
  </div>
<% } %>

<% if (hasData) { %>

  <!-- ============================== the now ============================ -->
  <section class="glass col-6 now">
    <div class="now-top">
      <div class="place">
        <h2><%= esc(cityName.isEmpty() ? displayQuery : cityName) %>
          <% if (!country.isEmpty()) { %><span class="tile-sub">· <%= esc(country) %></span><% } %>
        </h2>
        <div class="meta">
          <span><%= esc(dateStr) %></span>
          <span class="dot" aria-hidden="true"></span>
          <span><%= esc(localTimeStr) %> local</span>
        </div>
      </div>
      <%= svgIcon(iconK, "hero-icon") %>
    </div>

    <div class="temp-row">
      <div class="temp"><%= esc(tempStr) %><span style="font-size:.42em;font-weight:400"><%= unitSym %></span></div>
      <div class="temp-side">
        <div class="cond"><%= esc(mainStr) %></div>
        <div class="range"><%= esc(descStr) %></div>
        <div class="range">H <%= esc(highStr) %> &nbsp; L <%= esc(lowStr) %></div>
      </div>
    </div>

    <div class="quick">
      <span>Feels like <b><%= esc(feelsStr) %>°</b></span>
      <span>Humidity <b><%= esc(humidityStr) %></b></span>
      <% if (windStr.length() > 0 && !"--".equals(windStr)) { %>
        <span>Wind <b><%= esc(windStr) %><%= windDirStr.isEmpty() ? "" : " " + esc(windDirStr) %></b></span>
      <% } %>
    </div>
  </section>

  <!-- ============================== sun arc ============================ -->
  <section class="glass col-3">
    <div class="card-head">
      <h2>Sun</h2>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
        <path d="M17 18a5 5 0 0 0-10 0"/><path d="M12 2v4M4.9 7.9l2.8 2.8M19.1 7.9l-2.8 2.8M1 18h22"/>
      </svg>
    </div>
    <div class="arc">
      <svg class="arc-svg" viewBox="0 0 200 110" aria-hidden="true">
        <% int sp = sunProgress < 0 ? 0 : sunProgress;
           double ang = Math.PI * sp / 100.0;
           double cx = 100 - 88 * Math.cos(ang);
           double cy = 100 - 88 * Math.sin(ang);
           double dash = Math.PI * 88.0; %>
        <path class="arc-track" d="M12 100 A88 88 0 0 1 188 100"/>
        <path class="arc-done" d="M12 100 A88 88 0 0 1 188 100"
              stroke-dasharray="<%= num(dash * sp / 100.0, 1) %> 1000"/>
        <circle class="arc-sun" cx="<%= num(cx, 1) %>" cy="<%= num(cy, 1) %>" r="<%= sunProgress < 0 ? 0 : 6 %>"/>
      </svg>
    </div>
    <div class="arc-legend">
      <div><small>Sunrise</small><%= esc(sunriseStr) %></div>
      <div style="text-align:right"><small>Sunset</small><%= esc(sunsetStr) %></div>
    </div>
    <% if (!dayLenStr.isEmpty()) { %>
      <p class="tile-sub" style="margin-top:.5rem;text-align:center"><%= esc(dayLenStr) %></p>
    <% } %>
  </section>

  <!-- ================================ air ============================== -->
  <section class="glass col-3">
    <div class="card-head">
      <h2>Air quality</h2>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
        <path d="M3 8h11a3 3 0 1 0-3-3"/><path d="M3 12.5h14a3 3 0 1 1-3 3"/><path d="M3 17h7"/>
      </svg>
    </div>
    <% if (hasAqi) { %>
      <div style="display:flex;align-items:center;gap:1rem">
        <div class="aqi-badge <%= esc(aqiClass) %>"><%= esc(aqiStr) %></div>
        <div>
          <div class="tile-value" style="font-size:1.25rem"><%= esc(aqiLabel) %></div>
          <% if (!pm25Str.isEmpty()) { %><div class="tile-sub"><%= esc(pm25Str) %></div><% } %>
          <div class="tile-sub">OpenWeather index, 1 (best) – 5 (worst)</div>
        </div>
      </div>
    <% } else { %>
      <p class="tile-sub">Air-quality data isn't available for this location right now.</p>
    <% } %>
  </section>

  <!-- =============================== tiles ============================= -->
  <%
    String[][] tiles = {
      {"Feels like", feelsStr + "°", "Matches your body's sense of " + (imperial ? "°F" : "°C")},
      {"Humidity", humidityStr, "Relative humidity"},
      {"Wind", windStr.equals("--") ? "--" : windStr, gustStr.isEmpty() ? (windDirStr.isEmpty() ? "Steady breeze" : "From the " + windDirStr) : (windDirStr.isEmpty() ? gustStr :"From the " + windDirStr + " · " + gustStr)},
      {"Pressure", pressureStr, "Atmospheric pressure"},
      {"Visibility", visStr, "Horizontal visibility"},
      {"Cloud cover", cloudsStr, "Sky coverage"}
    };
    String[] tileIcons = {
      "<path d=\"M14 14.8V5a2 2 0 0 0-4 0v9.8a4 4 0 1 0 4 0z\"/>",
      "<path d=\"M12 3s5.5 5.9 5.5 9.6A5.5 5.5 0 0 1 6.5 12.6C6.5 8.9 12 3 12 3z\"/>",
      "<path d=\"M3 8h11a3 3 0 1 0-3-3\"/><path d=\"M3 12.5h14a3 3 0 1 1-3 3\"/><path d=\"M3 17h7\"/>",
      "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M12 12l4-2\"/><path d=\"M12 3.5v2M20.5 12h-2M12 20.5v-2M3.5 12h2\"/>",
      "<path d=\"M2.5 12s3.6-6 9.5-6 9.5 6 9.5 6-3.6 6-9.5 6-9.5-6-9.5-6z\"/><circle cx=\"12\" cy=\"12\" r=\"2.6\"/>",
      "<path d=\"M18 18.5H7a4.5 4.5 0 0 1-.6-8.96A6 6 0 0 1 18 8.6a5 5 0 0 1 0 9.9z\"/>"
    };
    for (int i = 0; i < tiles.length; i++) {
  %>
    <article class="glass col-4 tile">
      <div class="tile-top">
        <span class="tile-label"><%= esc(tiles[i][0]) %></span>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><%= tileIcons[i] %></svg>
      </div>
      <div>
        <div class="tile-value"><%= esc(tiles[i][1]) %></div>
        <div class="tile-sub"><%= esc(tiles[i][2]) %></div>
      </div>
    </article>
  <% } %>

  <!-- ============================== hourly ============================= -->
  <% if (!hours.isEmpty()) { %>
  <section class="glass col-12">
    <div class="card-head">
      <h2>Next hours</h2>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>
      </svg>
    </div>
    <div class="scroller" tabindex="0" role="group" aria-label="Hourly forecast">
      <% for (int i = 0; i < hours.size(); i++) { Hour h = hours.get(i); %>
        <div class="hour">
          <time datetime="<%= esc(h.time) %>"><%= esc(h.time) %></time>
          <%= svgIcon(h.icon, "ico") %>
          <span class="t"><%= esc(h.temp) %></span>
          <span class="p"><%= esc(h.pop) %></span>
        </div>
      <% } %>
    </div>
  </section>
  <% } %>

  <!-- ============================= 5-day =============================== -->
  <% if (!days.isEmpty()) {
       double dmin = 1e9, dmax = -1e9;
       for (int i = 0; i < days.size(); i++) {
         Day d = days.get(i);
         double lo = Double.parseDouble(d.min), hi = Double.parseDouble(d.max);
         if (lo < dmin) dmin = lo;
         if (hi > dmax) dmax = hi;
       }
       double span = (dmax - dmin) <= 0 ? 1 : (dmax - dmin);
  %>
  <section class="glass col-12">
    <div class="card-head">
      <h2>5-day outlook</h2>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
        <rect x="3" y="5" width="18" height="16" rx="3"/><path d="M8 3v4M16 3v4M3 10h18"/>
      </svg>
    </div>
    <div class="days">
      <% for (int i = 0; i < days.size(); i++) {
           Day d = days.get(i);
           double lo = Double.parseDouble(d.min), hi = Double.parseDouble(d.max);
           double left = (lo - dmin) / span * 100.0;
           double width = (hi - lo) / span * 100.0;
           if (width < 6) width = 6;
           if (left + width > 100) left = 100 - width;
      %>
        <div class="day">
          <span class="dname"><%= i == 0 ? "Today" : esc(d.name) %></span>
          <%= svgIcon(d.icon, "ico") %>
          <span class="ddesc"><%= esc(d.desc) %><%= d.pop.isEmpty() ? "" : " · " + esc(d.pop) %></span>
          <span class="range-bar">
            <span class="min"><%= esc(d.min) %>°</span>
            <span class="track" aria-hidden="true"><i style="left:<%= num(left, 1) %>%;width:<%= num(width, 1) %>%"></i></span>
            <b><%= esc(d.max) %>°</b>
          </span>
        </div>
      <% } %>
    </div>
  </section>
  <% } %>

<% } else if (!setupMode && errorMsg == null) { %>

  <!-- ============================== empty ============================== -->
  <section class="glass col-12 empty">
    <svg class="art" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="8.5" cy="8" r="3.2"/>
      <path d="M8.5 2.6v1.3M2.9 8H4.2M4.5 4l.9.9M12.5 4l-.9.9"/>
      <path d="M17.5 20.5H9a3.9 3.9 0 0 1-.5-7.8 5.4 5.4 0 0 1 10.1.9 3.4 3.4 0 0 1-1.1 6.9z"/>
    </svg>
    <h2>Search for your sky</h2>
    <p>Type any city in the world, or tap <strong>My location</strong> to use where you are right now.
       You'll get live conditions, an hourly outlook, a 5-day trend and air quality.</p>
  </section>

<% } %>

  </main>

  <footer class="foot">
    <span>© <%= new SimpleDateFormat("yyyy", Locale.ENGLISH).format(new Date()) %> Live Weather Forecasting</span>
    <span class="dot" aria-hidden="true"></span>
    <span>Data from <a href="https://openweathermap.org/api" target="_blank" rel="noopener">OpenWeather</a></span>
    <span class="dot" aria-hidden="true"></span>
    <a href="https://github.com/V1PU1LXRD" target="_blank" rel="noopener">Vipul Kanhere</a>
  </footer>
</div>

<script>
(function () {
  'use strict';
  var root = document.documentElement;

  /* --------------------------- theme toggle --------------------------- */
  var themeBtn = document.getElementById('themeBtn');
  if (themeBtn) {
    themeBtn.addEventListener('click', function () {
      var next = root.dataset.theme === 'dark' ? 'light' : 'dark';
      var apply = function () { root.dataset.theme = next; };
      try { localStorage.setItem('lwf-theme', next); } catch (e) {}
      var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      if (document.startViewTransition && !reduce) {
        document.startViewTransition(apply);
      } else {
        apply();
      }
    });
  }

  /* ---------------------------- progress ----------------------------- */
  var bar = document.getElementById('progress');
  var form = document.getElementById('searchForm');
  if (form && bar) {
    form.addEventListener('submit', function () {
      bar.classList.add('on');
      var btn = form.querySelector('.btn');
      if (btn) { btn.disabled = true; btn.style.opacity = '.75'; }
    });
  }

  /* -------------------------- keyboard focus ------------------------- */
  document.addEventListener('keydown', function (e) {
    if (e.key === '/' && !/^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement.tagName)) {
      e.preventDefault();
      var input = document.getElementById('cityInput');
      if (input) input.focus();
    }
  });

  /* -------------------------- recent searches ------------------------ */
  var KEY = 'lwf-recent';
  function readRecent() {
    try { return JSON.parse(localStorage.getItem(KEY) || '[]'); } catch (e) { return []; }
  }
  function writeRecent(list) {
    try { localStorage.setItem(KEY, JSON.stringify(list.slice(0, 6))); } catch (e) {}
  }
  function paintRecent() {
    var wrap = document.getElementById('suggestChips');
    var host = document.getElementById('recentList');
    if (!wrap || !host) return;
    var list = readRecent();
    if (!list.length) { wrap.hidden = true; return; }
    wrap.hidden = false;
    host.innerHTML = '';
    list.forEach(function (name) {
      var a = document.createElement('a');
      a.className = 'chip';
      a.href = '?city=' + encodeURIComponent(name) + '&unit=' + encodeURIComponent('<%= unitQ %>');
      a.textContent = name;
      host.appendChild(a);
    });
  }
  paintRecent();

  var current = '<%= jsStr(!city.isEmpty() ? city : (hasData ? cityName : "")) %>';
  if (current) {
    var list = readRecent().filter(function (x) { return x.toLowerCase() !== current.toLowerCase(); });
    list.unshift(current);
    writeRecent(list);
    paintRecent();
  }

  /* --------------------------- geolocation --------------------------- */
  var geoBtn = document.getElementById('geoBtn');
  if (geoBtn) {
    geoBtn.addEventListener('click', function () {
      if (!navigator.geolocation) {
        alert('Your browser does not support location lookup. Please type a city instead.');
        return;
      }
      var original = geoBtn.innerHTML;
      geoBtn.disabled = true;
      geoBtn.textContent = 'Locating…';
      navigator.geolocation.getCurrentPosition(function (pos) {
        document.getElementById('latField').value = pos.coords.latitude.toFixed(4);
        document.getElementById('lonField').value = pos.coords.longitude.toFixed(4);
        document.getElementById('labelField').value = 'My location';
        form.submit();
      }, function (err) {
        geoBtn.disabled = false;
        geoBtn.innerHTML = original;
        alert('Could not get your location: ' + (err && err.message ? err.message : 'permission denied') +
              '. Please type a city instead.');
      }, { timeout: 10000, maximumAge: 300000 });
    });
  }
})();
</script>
</body>
</html>

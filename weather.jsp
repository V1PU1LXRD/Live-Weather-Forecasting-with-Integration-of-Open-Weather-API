<%@ page import="java.io.*" %>
<%@ page import="java.net.*" %>
<%@ page import="org.json.simple.*" %>
<%@ page import="org.json.simple.parser.*" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
<title>Live Weather Forecasting</title>
<meta name="viewport" content="width=device-width, initial-scale=1" />
<style>
    body {
        background: linear-gradient(135deg, #0f2027, #203a43, #2c5364);
        color: #e0e6f0;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        margin: 0; padding: 0; min-height: 100vh;
        display: flex; justify-content: center; align-items: center;
    }
    .container {
        background: rgba(255,255,255,0.1);
        padding: 2rem 3rem;
        border-radius: 18px;
        box-shadow: 0 10px 25px rgba(0,0,0,0.6);
        max-width: 480px;
        width: 90%;
        text-align: center;
    }
    h2 {
        color: #89c9ff;
        margin-bottom: 1rem;
        font-weight: 700;
    }
    form input[type="text"] {
        width: 75%;
        padding: 0.6rem 1rem;
        border-radius: 30px 0 0 30px;
        border: none;
        font-size: 1.1rem;
        outline: none;
        border: 2px solid #89c9ff;
        background: transparent;
        color: #eef6fc;
    }
    form button {
        padding: 0.6rem 1.6rem;
        border-radius: 0 30px 30px 0;
        border: none;
        background: #89c9ff;
        color: #0f2027;
        font-weight: 700;
        font-size: 1.1rem;
        cursor: pointer;
        box-shadow: 0 5px 12px rgba(137,201,255,0.7);
        transition: background 0.3s ease, transform 0.2s ease;
        outline: none;
    }
    form button:hover {
        background: #6ca9ff;
        transform: scale(1.05);
        box-shadow: 0 7px 17px rgba(108,169,255,0.9);
    }
    .weather-info {
        margin-top: 2rem;
    }
    .city-name {
        font-size: 1.5rem;
        font-weight: 700;
        color: #bbdefb;
        margin-bottom: 0.3rem;
    }
    .coordinates {
        font-size: 0.9rem;
        color: #a1c4fd;
        margin-bottom: 1rem;
    }
    .weather-desc {
        font-size: 1.2rem;
        font-weight: 600;
        margin-bottom: 0.7rem;
        text-transform: capitalize;
    }
    .temperature {
        font-size: 3.8rem;
        font-weight: 900;
        margin-bottom: 1rem;
        color: #d0e6ff;
    }
    .metrics {
        font-size: 1.1rem;
        display: flex;
        justify-content: space-around;
        color: #a3bbff;
    }
    .metric-item {
        text-align: center;
        flex-basis: 40%;
    }

    /* Weather Animation Container */
    .animation-container {
        position: relative;
        height: 90px;
        margin: 0 auto 1.5rem;
        width: 120px;
    }

    /* Sun */
    .sun {
        width: 80px;
        height: 80px;
        margin: 0 auto;
        background: radial-gradient(circle at center, #ffec73 45%, #ffa500 95%);
        border-radius: 50%;
        box-shadow:
            0 0 20px 4px #ffec7399,
            0 0 45px 14px #ffca0c66;
        animation: spin 20s linear infinite;
        position: absolute;
        left: 50%;
        top: 50%;
        transform: translate(-50%, -50%);
    }
    @keyframes spin {
        100% { transform: translate(-50%, -50%) rotate(360deg); }
    }

    /* Cloud */
    .cloud {
        position: absolute;
        top: 40%;
        left: 15%;
        width: 90px;
        height: 50px;
        background: #f8fafb;
        border-radius: 50px / 30px;
        box-shadow: 35px 20px 0 #f0f5f7, 66px 10px 0 #d5dfe5;
        animation: drift 12s ease-in-out infinite alternate;
    }
    @keyframes drift {
        100% { transform: translateX(20px); }
    }

    /* Rain */
    .rain-drop {
        position: absolute;
        bottom: -3px;
        width: 8px;
        height: 22px;
        background: linear-gradient(180deg, #5cbaff 30%, transparent 80%);
        border-radius: 20% / 55%;
        animation: rainFall 1.3s linear infinite;
        opacity: 0.7;
    }
    .rain-drop:nth-child(1) { left: 20px; animation-delay: 0s; }
    .rain-drop:nth-child(2) { left: 40px; animation-delay: 0.4s; }
    .rain-drop:nth-child(3) { left: 62px; animation-delay: 0.8s; }
    @keyframes rainFall {
        0% { opacity: 0; transform: translateY(0); }
        50% { opacity: 1; }
        100% { opacity: 0; transform: translateY(25px); }
    }

    /* Snow */
    .snow-flake {
        position: absolute;
        bottom: 5px;
        width: 15px;
        height: 15px;
        background: radial-gradient(circle, #fff 60%, transparent 90%);
        border-radius: 50%;
        animation: snowFall 3s linear infinite;
        box-shadow: 0 0 10px 4px #a0c9ff88;
    }
    .snow-flake:nth-child(1) { left: 22px; animation-delay: 0s; }
    .snow-flake:nth-child(2) { left: 48px; animation-delay: 1.5s; }
    .snow-flake:nth-child(3) { left: 70px; animation-delay: 2.9s; }
    @keyframes snowFall {
        0% { transform: translateY(0) rotate(0deg); opacity: 1; }
        100% { transform: translateY(30px) rotate(360deg); opacity: 0; }
    }

    /* Error message styling */
    .error-msg {
        color: #ff6f6f;
        margin-top: 1rem;
        font-weight: 700;
    }
</style>
</head>
<body>
<div class="container">
    <h2>Live Weather Forecasting with Integration of Open Weather API</h2>
    <form method="post">
        <input type="text" name="city" placeholder="Enter city name"
               value="<%= request.getParameter("city") != null ? request.getParameter("city") : "" %>" required />
        <button type="submit">Search</button>
    </form>
    <hr/>
<%
String apiKey = [Your Open-Weather API Key]; // Replace with your own API key
String city = request.getParameter("city");
if(city != null && !city.trim().isEmpty()) {
    try {
        // Build Geocoding API URL (use HTTP or HTTPS according to your Java version)
        String geoUrlStr = "http://api.openweathermap.org/geo/1.0/direct?q="
                + URLEncoder.encode(city, "UTF-8")
                + "&limit=1&appid=" + apiKey;
        URL geoUrl = new URL(geoUrlStr);
        HttpURLConnection geoConn = (HttpURLConnection) geoUrl.openConnection();
        geoConn.setRequestMethod("GET");
        BufferedReader geoReader = new BufferedReader(new InputStreamReader(geoConn.getInputStream()));
        StringBuilder geoResp = new StringBuilder();
        String geoLine;
        while ((geoLine = geoReader.readLine()) != null) geoResp.append(geoLine);
        geoReader.close();
        JSONParser parser = new JSONParser();
        JSONArray geoArr = (JSONArray) parser.parse(geoResp.toString());
        if (geoArr.size() == 0) {
%>
        <p class="error-msg">No location found for "<%= city %>".</p>
<%
        } else {
            JSONObject loc = (JSONObject) geoArr.get(0);
            String cityName = loc.get("name").toString();
            String country = loc.get("country") != null ? loc.get("country").toString() : "";
            double lat = Double.parseDouble(loc.get("lat").toString());
            double lon = Double.parseDouble(loc.get("lon").toString());

            // Weather API URL by lat/lon
            String weatherUrlStr = "http://api.openweathermap.org/data/2.5/weather?lat="
                    + lat + "&lon=" + lon + "&appid=" + apiKey + "&units=metric";
            URL weatherUrl = new URL(weatherUrlStr);
            HttpURLConnection weatherConn = (HttpURLConnection) weatherUrl.openConnection();
            weatherConn.setRequestMethod("GET");
            BufferedReader weatherReader = new BufferedReader(new InputStreamReader(weatherConn.getInputStream()));
            StringBuilder weatherResp = new StringBuilder();
            String weatherLine;
            while ((weatherLine = weatherReader.readLine()) != null) weatherResp.append(weatherLine);
            weatherReader.close();
            JSONObject weatherObj = (JSONObject) parser.parse(weatherResp.toString());
            JSONObject main = (JSONObject) weatherObj.get("main");
            JSONArray weatherArr = (JSONArray) weatherObj.get("weather");
            JSONObject weatherDescObj = (JSONObject) weatherArr.get(0);
            String weatherMain = weatherDescObj.get("main").toString();
            String weatherDescription = weatherDescObj.get("description").toString();
            double temperature = ((Number) main.get("temp")).doubleValue();
            double feelsLike = ((Number) main.get("feels_like")).doubleValue();
            int humidity = ((Number) main.get("humidity")).intValue();

            // Determine animation type
            String animType = "sun";
            String cond = (weatherMain + weatherDescription).toLowerCase();
            if (cond.contains("rain") || cond.contains("storm") || cond.contains("thunder")) animType = "rain";
            else if (cond.contains("cloud")) animType = "cloud";
            else if (cond.contains("snow")) animType = "snow";
%>
    <div class="weather-info">
        <div class="city-name"><%= cityName %><% if(!country.equals("")) { %>, <%= country %><% } %></div>
        <div class="animation-container">
            <% if("sun".equals(animType)) { %>
                <div class="sun"></div>
            <% } else if ("cloud".equals(animType)) { %>
                <div class="cloud"></div>
            <% } else if ("rain".equals(animType)) { %>
                <div class="cloud"></div>
                <div class="rain-drop"></div>
                <div class="rain-drop"></div>
                <div class="rain-drop"></div>
            <% } else if ("snow".equals(animType)) { %>
                <div class="cloud"></div>
                <div class="snow-flake"></div>
                <div class="snow-flake"></div>
                <div class="snow-flake"></div>
            <% } %>
        </div>
        <div class="weather-desc"><%= weatherMain %> - <%= weatherDescription %></div>
        <div class="temperature"><%= String.format("%.1f", temperature) %> °C</div>
        <div class="metrics">
            <div class="metric-item">Feels like<br><b><%= String.format("%.1f", feelsLike) %> °C</b></div>
            <div class="metric-item">Humidity<br><b><%= humidity %>%</b></div>
        </div>
    </div>
<%
        }
    } catch (Exception e) {
%>
    <p class="error-msg">Error fetching data: <%= e.getMessage() %></p>
<%
    }
} else {
%>
    <p>Please enter a city name.</p>
<%
}
%>
</div>
</body>
</html>

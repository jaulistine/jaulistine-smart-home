// JAULISTINE SMART HOME CONTROLLER
// Place this script in the cube prim that displays the webpage on Face 1.
// It requests a fresh HTTPS HTTP-in URL and passes it to the webpage.
// The page sends simple GET beacon commands; no CORS response headers are needed.

integer SCREEN_FACE = 1;
string PAGE_URL = "https://jaulistine.github.io/jaulistine-smart-home/";

string bridgeURL = "";
float indoorTemperature = 72.0;
integer targetTemperature = 72;
integer humidity = 48;
string airQuality = "GOOD";
string weatherState = "SUNNY";
string fanSetting = "AUTO";
string environmentMode = "DAY";

string enc(string value)
{
    return llEscapeURL(value);
}

string displayURL()
{
    return PAGE_URL
        + "?bridge=" + enc(bridgeURL)
        + "&indoor=" + enc((string)indoorTemperature)
        + "&target=" + (string)targetTemperature
        + "&humidity=" + (string)humidity
        + "&air=" + enc(airQuality)
        + "&weather=" + enc(weatherState)
        + "&fan=" + enc(fanSetting)
        + "&mode=" + enc(environmentMode);
}

updateScreen()
{
    if (bridgeURL == "") return;
    integer result = llSetPrimMediaParams(SCREEN_FACE, [
        PRIM_MEDIA_AUTO_PLAY, TRUE,
        PRIM_MEDIA_AUTO_SCALE, TRUE,
        PRIM_MEDIA_CONTROLS, PRIM_MEDIA_CONTROLS_MINI,
        PRIM_MEDIA_WIDTH_PIXELS, 1280,
        PRIM_MEDIA_HEIGHT_PIXELS, 800,
        PRIM_MEDIA_CURRENT_URL, displayURL(),
        PRIM_MEDIA_HOME_URL, PAGE_URL,
        PRIM_MEDIA_PERMS_INTERACT, PRIM_MEDIA_PERM_OWNER,
        PRIM_MEDIA_PERMS_CONTROL, PRIM_MEDIA_PERM_OWNER
    ]);
    if (result != STATUS_OK)
        llOwnerSay("Jaulistine: Media update returned status " + (string)result);
}

string queryValue(string query, string wanted)
{
    list pairs = llParseStringKeepNulls(query, ["&"], []);
    integer i;
    for (i = 0; i < llGetListLength(pairs); ++i)
    {
        string pair = llList2String(pairs, i);
        integer splitAt = llSubStringIndex(pair, "=");
        if (splitAt >= 0)
        {
            string keyName = llUnescapeURL(llGetSubString(pair, 0, splitAt - 1));
            if (keyName == wanted)
                return llUnescapeURL(llGetSubString(pair, splitAt + 1, -1));
        }
    }
    return "";
}

integer isOneOf(string value, list choices)
{
    return (llListFindList(choices, [value]) != -1);
}

applyCommand(string cmd, string value)
{
    if (cmd == "target")
    {
        integer v = (integer)value;
        if (v < 50) v = 50;
        if (v > 90) v = 90;
        targetTemperature = v;
    }
    else if (cmd == "humidity")
    {
        integer h = (integer)value;
        if (h < 30) h = 30;
        if (h > 70) h = 70;
        humidity = h;
    }
    else if (cmd == "air" && isOneOf(value, ["GOOD", "MODERATE", "POOR", "UNHEALTHY"]))
        airQuality = value;
    else if (cmd == "weather" && isOneOf(value, ["SUNNY", "CLOUDY", "RAINY", "WINDY", "FOGGY", "SNOWY"]))
        weatherState = value;
    else if (cmd == "fan" && isOneOf(value, ["AUTO", "ON", "OFF"]))
        fanSetting = value;
    else if (cmd == "mode" && isOneOf(value, ["MORNING", "DAY", "EVENING", "NIGHT"]))
        environmentMode = value;
}

default
{
    state_entry()
    {
        llOwnerSay("Jaulistine: requesting secure touchscreen connection...");
        llRequestSecureURL();
        llSetTimerEvent(60.0);
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }

    changed(integer change)
    {
        if (change & (CHANGED_OWNER | CHANGED_REGION_START))
            llResetScript();
    }

    http_request(key request_id, string method, string body)
    {
        if (method == URL_REQUEST_GRANTED)
        {
            bridgeURL = body;
            if (bridgeURL == "")
                llOwnerSay("Jaulistine: Second Life did not grant an HTTPS connection URL.");
            else
            {
                llOwnerSay("Jaulistine: secure connection ready.");
                updateScreen();
            }
        }
        else if (method == URL_REQUEST_DENIED)
        {
            llOwnerSay("Jaulistine: unable to obtain an HTTP-in URL. Check script permissions and available URLs.");
        }
        else if (method == "GET")
        {
            string query = llGetHTTPHeader(request_id, "x-query-string");
            string cmd = queryValue(query, "cmd");
            string value = queryValue(query, "value");

            if (cmd != "")
            {
                applyCommand(cmd, value);
                llHTTPResponse(request_id, 200, "OK");
                updateScreen();
            }
            else
                llHTTPResponse(request_id, 400, "Missing command");
        }
        else
        {
            llHTTPResponse(request_id, 405, "Method not allowed");
        }
    }

    timer()
    {
        // Simulated room temperature moves 0.1°F per minute toward the target.
        if (indoorTemperature < (float)targetTemperature)
        {
            indoorTemperature += 0.1;
            if (indoorTemperature > (float)targetTemperature)
                indoorTemperature = (float)targetTemperature;
        }
        else if (indoorTemperature > (float)targetTemperature)
        {
            indoorTemperature -= 0.1;
            if (indoorTemperature < (float)targetTemperature)
                indoorTemperature = (float)targetTemperature;
        }
        indoorTemperature = (float)llRound(indoorTemperature * 10.0) / 10.0;
        updateScreen();
    }
}

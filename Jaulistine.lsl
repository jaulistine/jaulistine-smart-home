// JAULISTINE SMART HOME CONTROLLER
// New, independent controller. Do not place this in the original thermostat.
// Place this script in the screen prim. Set SCREEN_FACE and PAGE_URL below.
//
// Touch zones are mapped to the 1280x800 design:
// temperature -/+ buttons, environment tiles, and six mode buttons.
// The HTML is a display surface; the LSL script owns and stores the state.

integer SCREEN_FACE = 0;
string PAGE_URL = "https://jaulistine.github.io/jaulistine-smart-home/";
integer REFRESH_SECONDS = 60;

float indoorTemperature = 72.0;
integer targetTemperature = 72;
integer humidity = 48;
string airQuality = "GOOD";
string weatherState = "SUNNY";
string fanSetting = "AUTO";
string environmentMode = "DAY";

integer lastTick;
integer mediaReady = FALSE;

string enc(string s) { return llEscapeURL(s); }

string makeURL()
{
    return PAGE_URL
        + "?indoor=" + enc((string)indoorTemperature)
        + "&target=" + (string)targetTemperature
        + "&humidity=" + (string)humidity
        + "&air=" + enc(airQuality)
        + "&weather=" + enc(weatherState)
        + "&fan=" + enc(fanSetting)
        + "&mode=" + enc(environmentMode);
}

refreshScreen()
{
    // Updating CURRENT_URL reloads the display with the controller's latest state.
    llSetPrimMediaParams(SCREEN_FACE, [
        PRIM_MEDIA_CURRENT_URL, makeURL()
    ]);
}

setMedia()
{
    llSetPrimMediaParams(SCREEN_FACE, [
        PRIM_MEDIA_AUTO_PLAY, TRUE,
        PRIM_MEDIA_AUTO_SCALE, TRUE,
        PRIM_MEDIA_CONTROLS, PRIM_MEDIA_CONTROLS_MINI,
        PRIM_MEDIA_CURRENT_URL, makeURL(),
        PRIM_MEDIA_HOME_URL, PAGE_URL,
        PRIM_MEDIA_PERMS_INTERACT, PRIM_MEDIA_PERM_ANYONE,
        PRIM_MEDIA_PERMS_CONTROL, PRIM_MEDIA_PERM_OWNER
    ]);
    mediaReady = TRUE;
}

integer between(float v, float low, float high)
{
    return (v >= low && v <= high);
}

handleTouch(float x, float y)
{
    // Touch ST coordinates use 0..1, origin at the lower-left.
    // Main temperature +/- controls are at the right side of the left panel.
    if (between(x, 0.365, 0.425) && between(y, 0.485, 0.565))
    {
        targetTemperature = targetTemperature - 1;
        if (targetTemperature < 50) targetTemperature = 50;
    }
    else if (between(x, 0.435, 0.495) && between(y, 0.485, 0.565))
    {
        targetTemperature = targetTemperature + 1;
        if (targetTemperature > 90) targetTemperature = 90;
    }
    // Environment tiles: humidity, air, weather, fan.
    else if (between(x, 0.535, 0.745) && between(y, 0.615, 0.785))
    {
        humidity = humidity + 5;
        if (humidity > 70) humidity = 30;
    }
    else if (between(x, 0.755, 0.965) && between(y, 0.615, 0.785))
    {
        if (airQuality == "GOOD") airQuality = "MODERATE";
        else if (airQuality == "MODERATE") airQuality = "POOR";
        else if (airQuality == "POOR") airQuality = "UNHEALTHY";
        else airQuality = "GOOD";
    }
    else if (between(x, 0.535, 0.745) && between(y, 0.445, 0.605))
    {
        if (weatherState == "SUNNY") weatherState = "CLOUDY";
        else if (weatherState == "CLOUDY") weatherState = "RAINY";
        else if (weatherState == "RAINY") weatherState = "WINDY";
        else if (weatherState == "WINDY") weatherState = "FOGGY";
        else if (weatherState == "FOGGY") weatherState = "SNOWY";
        else weatherState = "SUNNY";
    }
    else if (between(x, 0.755, 0.965) && between(y, 0.445, 0.605))
    {
        if (fanSetting == "AUTO") fanSetting = "ON";
        else if (fanSetting == "ON") fanSetting = "OFF";
        else fanSetting = "AUTO";
    }
    // Single time-of-day selector near the lower center.
    // First tap on selector cycles to the next mode. Popup selection areas
    // are reserved for future media-to-script bridge validation.
    else if (between(x, 0.315, 0.685) && between(y, 0.17, 0.27))
    {
        if (environmentMode == "MORNING") environmentMode = "DAY";
        else if (environmentMode == "DAY") environmentMode = "EVENING";
        else if (environmentMode == "EVENING") environmentMode = "NIGHT";
        else environmentMode = "MORNING";
    }
    refreshScreen();
}

default
{
    state_entry()
    {
        lastTick = llGetUnixTime();
        setMedia();
        llSetTimerEvent(60.0);
        llOwnerSay("Jaulistine Smart Home controller started. Touch the screen to change settings.");
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }

    changed(integer change)
    {
        if (change & CHANGED_OWNER) llResetScript();
    }

    touch_start(integer total_number)
    {
        integer face = llDetectedTouchFace(0);
        vector st = llDetectedTouchST(0);
        if (face == SCREEN_FACE && st != TOUCH_INVALID_TEXCOORD)
        {
            handleTouch(st.x, st.y);
        }
    }

    timer()
    {
        // Gradual room-temperature movement: 0.1°F per minute toward the setpoint.
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
        refreshScreen();
    }
}

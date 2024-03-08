load("http.star", "http")
load("re.star", "re")
load("render.star", "render")
load("time.star", "time")

ICS_URL = "https://calendar.google.com/calendar/ical/5a70268a5f91e1ba7a144a1cb66c9fe73012694752419e0e8c982e1af640af09%40group.calendar.google.com/public/basic.ics"


def main(config):

    # Fetch ICS data
    resp = http.get(ICS_URL)
    if resp.status_code != 200:
        return []

    ics_data = resp.body()
    # print("ICS Data:", ics_data)

    # Extract events from ICS data using regular expressions
    events = re.findall(r"BEGIN:VEVENT([\s\S]*?)END:VEVENT", ics_data)

    # Get current time
    # TO DO: Add offset if user selects different timezone in Tidbyt Schema

    DEFAULT_TIMEZONE = "US/Central"
    tz = DEFAULT_TIMEZONE

    current_time = time.now().in_location("UTC")
    # print(current_time)

    def pad(value):
        return "0" + str(value) if len(str(value)) == 1 else str(value)

    current_time_string = str(current_time.year) + \
        pad(current_time.month) + \
        pad(current_time.day) + "T" + \
        pad(current_time.hour) + \
        pad(current_time.minute) + \
        pad(current_time.second)

    # Process each event to find the current event
    for eventblock in events:
        event = []
        # Extract event details
        summary_match = re.findall(r"SUMMARY:(.*)", eventblock)
        description_match = re.findall(r"DESCRIPTION:(.*)", eventblock)
        dtstart_match = re.findall(r"DTSTART(.*)", eventblock)
        dtend_match = re.findall(r"DTEND(.*)", eventblock)

        hasDescription = False

        if summary_match and dtstart_match and dtend_match:

            for summary in summary_match:
                summary = summary[8:].rstrip('\r')
                event.append(summary)
                # print(summary)

            for dtstart in dtstart_match:
                if "DATE" in dtstart:
                    dtstart = dtstart[19:].rstrip('\r')
                else:
                    dtstart = dtstart[8:-2]
                event.append(dtstart)
                # print(dtstart)

            for dtend in dtend_match:
                if "DATE" in dtend:
                    dtend = dtend[17:].rstrip('\r')
                else:
                    dtend = dtend[6:-2]
                event.append(dtend)
                # print(dtend)

        if description_match:
            hasDescription = True
            for description in description_match:
                description = description[12:].rstrip('\r')
                event.append(description)
                # print(description)
        else:
            description = None

        # Check if there's a current event, print if yes
        # TO DO: Add check for All-Day event if no current event
        if dtstart <= current_time_string and current_time_string <= dtend:
            print("Current Event Found:", summary, description)
            # Return event details if a current event is found
            return render.Root(
                child=render.Box(
                    color="333366",
                    child=render.WrappedText(
                        content=summary,
                        width=60,
                        align="center",
                        color="#ffcc33",
                        font="tom-thumb",
                    )
                )
            )

    # Skip this app if there's no current event
    return []

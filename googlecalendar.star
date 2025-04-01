load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

def render_error(message):
    return render.Root(
        child=render.Column(
            children=[
                render.Text("ERROR", color="#DB4437"),
                render.Text(message, color="#DB4437"),
            ],
            main_align="center",
            expanded=True,
        ),
    )

def main(config):
    # Get configuration
    calendar_link = config.get("calendar_link", "")
    timezone = config.get("timezone", "America/New_York")
    text_only = config.bool("text_only", False)
    
    # Get color configuration with defaults
    time_bg_color = config.get("time_bg_color", "#1a73e8")  # Google blue
    time_text_color = config.get("time_text_color", "#ffffff")  # White
    event_bg_color = config.get("event_bg_color", "#000000")  # Black
    event_text_color = config.get("event_text_color", "#7FFF7F")  # Light green
    
    # Get font configuration (default to tom-thumb as it's the most readable for small text)
    font = config.get("font", "tom-thumb")
    
    # If no calendar link provided, show instructions
    if not calendar_link:
        return render.Root(
            child=render.Column(
                children=[
                    # Time display
                    render.Box(
                        width=64,
                        height=10,
                        color=time_bg_color,
                        child=render.Padding(
                            pad=(0, 2, 0, 0),
                            child=render.Text(
                                "5-6PM",
                                color=time_text_color,
                                font=font,
                            ),
                        ),
                    ),
                    # Event title
                    render.Box(
                        width=64,
                        height=22,
                        color=event_bg_color,
                        child=render.Column(
                            expanded=True,
                            main_align="center",
                            cross_align="center",
                            children=[
                                render.WrappedText(
                                    content="Enter Calendar Link to Get Started",
                                    color=event_text_color,
                                    font=font,
                                    width=62,
                                    align="center",
                                ),
                            ],
                        ),
                    ),
                ],
                main_align="center",
                expanded=True,
            ),
        )
    
    # Fetch calendar data
    resp = http.get(calendar_link)
    if resp.status_code != 200:
        return render_error("Failed to fetch: {}".format(resp.status_code))
    
    # Extract calendar data
    ics_data = resp.body()
    
    # Extract events
    events = []
    current_event = {}
    in_event = False
    event_timezone = ""
    
    lines = ics_data.split("\n")
    
    for line in lines:
        line = line.strip()
        
        # Start of an event
        if line == "BEGIN:VEVENT":
            current_event = {
                "title": "",
                "start_time": "",
                "end_time": "",
                "time_display": "No time info",
                "is_all_day": False,
            }
            in_event = True
            
        # End of an event
        elif line == "END:VEVENT" and in_event:
            if current_event["title"]:
                # If there are start and end times, use them
                if current_event["start_time"] and current_event["end_time"]:
                    current_event["time_display"] = "{} - {}".format(
                        current_event["start_time"], 
                        current_event["end_time"]
                    )
                # If it's an all-day event, display "ALL DAY"
                elif current_event["is_all_day"]:
                    current_event["time_display"] = "ALL DAY"
                
                events.append(current_event)
            in_event = False
            
        # Event title
        elif line.startswith("SUMMARY:") and in_event:
            current_event["title"] = line[8:].strip()
            
        # Start date (for all-day events)
        elif line.startswith("DTSTART;VALUE=DATE:") and in_event:
            # This is an all-day event
            current_event["is_all_day"] = True
            
        # Start time
        elif line.startswith("DTSTART") and in_event and not current_event["is_all_day"]:
            # Look for timezone in this line
            if "TZID=" in line:
                # Extract timezone
                tzid_parts = line.split("TZID=")
                if len(tzid_parts) > 1:
                    event_timezone = tzid_parts[1].split(":")[0].strip()
            
            # Extract time
            parts = line.split(":")
            if len(parts) > 1:
                date_time = parts[-1].strip()
                if "T" in date_time:
                    time_part = date_time.split("T")[1]
                    if len(time_part) >= 4:
                        hours = int(time_part[0:2]) 
                        # Account for timezone difference - convert to local time
                        # This is a very basic approximation
                        if date_time.endswith("Z"):  # UTC time
                            # Get current timezone offset
                            now = time.now().in_location(timezone)
                            offset_hours = now.hour - time.now().in_location("UTC").hour
                            hours = (hours + offset_hours) % 24
                            
                        minutes = int(time_part[2:4])
                        
                        # Format in 12 hour time
                        am_pm = "AM" 
                        if hours >= 12:
                            am_pm = "PM"
                            if hours > 12:
                                hours -= 12
                        elif hours == 0:
                            hours = 12
                            
                        # Format with or without minutes
                        if minutes == 0:
                            # For times on the hour (no minutes)
                            current_event["start_time"] = "{}{}".format(hours, am_pm)
                        else:
                            # Add a leading zero to minutes if needed
                            min_str = str(minutes)
                            if minutes < 10:
                                min_str = "0" + min_str
                            
                            # For times with minutes
                            current_event["start_time"] = "{}:{}{}".format(hours, min_str, am_pm)
            
        # End time
        elif line.startswith("DTEND") and in_event and not current_event["is_all_day"]:
            # Extract time
            parts = line.split(":")
            if len(parts) > 1:
                date_time = parts[-1].strip()
                if "T" in date_time:
                    time_part = date_time.split("T")[1]
                    if len(time_part) >= 4:
                        hours = int(time_part[0:2])
                        # Account for timezone difference - convert to local time
                        # This is a very basic approximation
                        if date_time.endswith("Z"):  # UTC time
                            # Get current timezone offset
                            now = time.now().in_location(timezone)
                            offset_hours = now.hour - time.now().in_location("UTC").hour
                            hours = (hours + offset_hours) % 24
                            
                        minutes = int(time_part[2:4])
                        
                        # Format in 12 hour time
                        am_pm = "AM"
                        if hours >= 12:
                            am_pm = "PM" 
                            if hours > 12:
                                hours -= 12
                        elif hours == 0:
                            hours = 12
                            
                        # Format with or without minutes
                        if minutes == 0:
                            # For times on the hour (no minutes)
                            current_event["end_time"] = "{}{}".format(hours, am_pm)
                        else:
                            # Add a leading zero to minutes if needed
                            min_str = str(minutes)
                            if minutes < 10:
                                min_str = "0" + min_str
                                
                            # For times with minutes
                            current_event["end_time"] = "{}:{}{}".format(hours, min_str, am_pm)
    
    # If no events found
    if len(events) == 0:
        return render.Root(
            child=render.Column(
                children=[
                    render.Text("No events found", color="#DB4437", font=font),
                    render.Text("Check calendar", font=font),
                ],
                main_align="center",
                expanded=True,
            ),
        )
    
    # Select the most recent event (last in the list)
    selected_event = events[-1]
    
    # Display based on configuration
    if text_only:
        # Text-only display with vertical scrolling for long event titles - vertically centered
        # Determine if we need scrolling based on text length (rough estimate)
        title = selected_event["title"]
        estimated_height = (len(title) // 10 + 1) * 6  # Rough estimate of text height
        needs_scrolling = estimated_height > 30
        
        if needs_scrolling:
            # Create a vertical repeating marquee with direct text
            # (no column nesting that might add extra space)
            return render.Root(
                child=render.Box(
                    width=64,
                    height=32,
                    color=event_bg_color,
                    child=render.Marquee(
                        width=64,
                        height=32,
                        scroll_direction="vertical",
                        child=render.WrappedText(
                            content=selected_event["title"],
                            color=event_text_color,
                            font=font,
                            width=62,
                            align="center",
                        ),
                    ),
                ),
            )
        else:
            # If text doesn't need scrolling, just center it
            return render.Root(
                child=render.Box(
                    width=64,
                    height=32,
                    color=event_bg_color,
                    child=render.Column(
                        expanded=True,
                        main_align="center",
                        cross_align="center",
                        children=[
                            render.WrappedText(
                                content=selected_event["title"],
                                color=event_text_color,
                                font=font,
                                width=62,
                                align="center",
                            ),
                        ],
                    ),
                ),
            )
    else:
        # Full display with time and event title
        # Determine if we need scrolling based on text length (rough estimate)
        title = selected_event["title"]
        estimated_height = (len(title) // 10 + 1) * 6  # Rough estimate of text height
        needs_scrolling = estimated_height > 20
        
        # Title display - either scrolling or static
        title_display = None
        if needs_scrolling:
            title_display = render.Marquee(
                width=64,
                height=22,
                scroll_direction="vertical",
                child=render.WrappedText(
                    content=selected_event["title"],
                    color=event_text_color,
                    font=font,
                    width=62,
                    align="center",
                ),
            )
        else:
            title_display = render.Column(
                expanded=True,
                main_align="center",
                cross_align="center",
                children=[
                    render.WrappedText(
                        content=selected_event["title"],
                        color=event_text_color,
                        font=font,
                        width=62,
                        align="center",
                    ),
                ],
            )
            
        return render.Root(
            child=render.Column(
                children=[
                    # Time display
                    render.Box(
                        width=64,
                        height=10,
                        color=time_bg_color,
                        child=render.Padding(
                            pad=(0, 2, 0, 0),
                            child=render.Text(
                                selected_event["time_display"],
                                color=time_text_color,
                                font=font,
                            ),
                        ),
                    ),
                    # Event title - either with scrolling or static
                    render.Box(
                        width=64,
                        height=22,
                        color=event_bg_color,
                        child=title_display,
                    ),
                ],
                main_align="center",
                expanded=True,
            ),
        )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "calendar_link",
                name = "Calendar Link",
                desc = "Paste an iCal URL (ending in .ics) from Google Calendar",
                icon = "calendar",
            ),
            schema.Text(
                id = "timezone",
                name = "Timezone",
                desc = "Your timezone (e.g. America/New_York)",
                icon = "clock",
                default = "America/New_York",
            ),
            schema.Toggle(
                id = "text_only",
                name = "Text Only",
                desc = "Show only the event text without time",
                icon = "textHeight",
                default = False,
            ),
            schema.Color(
                id = "time_bg_color",
                name = "Time Background Color",
                desc = "Background color for the time display",
                icon = "brush",
                default = "#1a73e8",  # Google blue
            ),
            schema.Color(
                id = "time_text_color",
                name = "Time Text Color",
                desc = "Text color for the time display",
                icon = "font",
                default = "#ffffff",  # White
            ),
            schema.Color(
                id = "event_bg_color",
                name = "Event Background Color",
                desc = "Background color for the event display",
                icon = "brush",
                default = "#000000",  # Black
            ),
            schema.Color(
                id = "event_text_color",
                name = "Event Text Color",
                desc = "Text color for the event display",
                icon = "font",
                default = "#7FFF7F",  # Light green
            ),
            schema.Dropdown(
                id = "font",
                name = "Font",
                desc = "Select the font to use throughout the app",
                icon = "font",
                default = "tom-thumb",
                options = [
                    schema.Option(
                        display = "Tom Thumb",
                        value = "tom-thumb",
                    ),
                    schema.Option(
                        display = "TB-8",
                        value = "tb-8",
                    ),
                    schema.Option(
                        display = "5x8",
                        value = "5x8",
                    ),
                ],
            ),
        ],
    )
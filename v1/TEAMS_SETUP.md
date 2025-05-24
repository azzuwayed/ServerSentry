# Setting up Microsoft Teams Integration for ServerSentry

This guide will help you properly configure the integration between ServerSentry and Microsoft Teams using Power Automate (formerly Microsoft Flow).

## Overview

ServerSentry sends rich notifications to Microsoft Teams when system resources exceed thresholds or when processes fail. These notifications include:

- System resource alerts (CPU, memory, disk)
- Process monitoring alerts
- Detailed system information
- Interactive Adaptive Cards for better visualization

## Setup Instructions (Power Automate Method)

### 1. Create a Power Automate Flow

1. Go to [Power Automate](https://make.powerautomate.com/)
2. Sign in with your Microsoft account
3. Click on "Create" from the left sidebar
4. Select "Automated cloud flow"
5. Give your flow a name (e.g., "ServerSentry Alerts")
6. Search for "When a HTTP request is received" trigger and select it
7. Click "Create"

### 2. Configure the HTTP Request Trigger

1. In the HTTP Request trigger, you may define a JSON schema if you wish, but it's not strictly necessary
2. ServerSentry now sends comprehensive data in this format:

```json
{
  "title": "Alert Title",
  "message": "Alert message with details",
  "hostname": "your-server-name",
  "ip": "192.168.1.2",
  "timestamp": "2023-06-01T12:34:56Z",
  "source": "ServerSentry",
  "os": "macOS 14.0",
  "kernel": "23.1.0",
  "uptime": "4 days, 2:15",
  "loadavg": "1.52, 1.42, 1.30",
  "cpu": "Intel Core i9 (8 cores)",
  "cpu_usage": "45%",
  "memory": "8192MB Used / 16384MB Total",
  "memory_usage": "50%",
  "disk": "100GB Used / 500GB Total (20%)",
  "disk_usage": "20%",
  "status": "alert",
  "content": {
    "type": "AdaptiveCard",
    "body": [ ... ],
    "version": "1.2",
    "$schema": "http://adaptivecards.io/schemas/adaptive-card.json"
  },
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "content": {
        "type": "AdaptiveCard",
        "body": [ ... ]
      }
    }
  ]
}
```

3. After saving the flow, you'll get an HTTP POST URL. Copy this URL - you'll need it for ServerSentry.

### 3. Add Adaptive Card to Teams (Method 1 - Using "For each" loop - RECOMMENDED)

The most reliable approach for Teams integration is to use a "For each" loop with the attachments array:

1. Add a "For each" action after the HTTP trigger with this value:

   ```
   @triggerOutputs()?['body']?['attachments']
   ```

2. Inside the "For each" loop, add a "Post a message in a chat or channel" action:
   - **Team**: Select your team
   - **Channel**: Select your channel
   - **Message body**: `@item()?['content']`

This approach works best with the ServerSentry webhook format and ensures proper rendering of the adaptive card in Teams.

### 4. Alternative Method - Direct Adaptive Card Posting

Alternatively, you can try using the direct Adaptive Card approach:

1. Add a "Post adaptive card in a chat or channel" action
2. Configure:
   - **Card**: `@{triggerBody()?['content']}`
   - **Team**: Your selected team
   - **Channel**: Your selected channel

### 5. Simple HTML Method

For a simpler approach:

1. Add a "Post a message in a chat or channel" action
2. Configure message body with:

```html
<p><b>@{triggerBody()?['title']}</b></p>
<p>@{triggerBody()?['message']}</p>
<p>
  <b>Server:</b> @{triggerBody()?['hostname']} (@{triggerBody()?['ip']})<br />
  <b>CPU Usage:</b> @{triggerBody()?['cpu_usage']}<br />
  <b>Memory Usage:</b> @{triggerBody()?['memory_usage']}<br />
  <b>Disk Usage:</b> @{triggerBody()?['disk_usage']}<br />
  <b>Uptime:</b> @{triggerBody()?['uptime']}<br />
  <b>Time:</b> @{triggerBody()?['timestamp']}<br />
</p>
```

### 6. Configure ServerSentry

1. Add the webhook URL to ServerSentry:

```bash
./serversentry.sh --add-webhook "your-flow-url-here"
```

2. Test the integration:

```bash
./serversentry.sh --test-webhook
```

3. Verify the messages appear in your Teams channel with proper formatting

## Troubleshooting

If your Teams messages are empty or not appearing:

1. **Check the flow run history** in Power Automate to see the detailed information about each run
2. **Inspect the JSON payload** to ensure all fields are correctly formatted
3. **Try the simpler HTML format** before using the Adaptive Card
4. **Look at the ServerSentry logs** (sysmon.log) for webhook responses
5. **Run with --test-webhook** to manually verify the connection

If your adaptive cards aren't displaying correctly:

1. Make sure your Teams supports Adaptive Cards (most modern Teams clients do)
2. Try using the HTML format option instead
3. Check the Power Automate run history for any card parsing errors

For "For each" loop errors:

1. Make sure you're using the correct path: `@triggerOutputs()?['body']?['attachments']`
2. Check if the ServerSentry webhook includes the attachments array
3. Try running a test webhook and examine the flow run history

## Advanced Configuration

You can enhance your Teams integration with:

1. **Color coding based on alert type**:

   - Use Compose action to set a variable based on message type
   - Use a Switch action to handle different alert types differently

2. **Add action buttons** to your messages:

   - Link to documentation
   - Run remediation scripts via Power Automate actions

3. **Create scheduled summaries**:
   - Set up a Scheduled Flow that queries your monitoring data
   - Send daily/weekly summaries to Teams

## Example JSON Card Definition

If you'd like to create your own custom card, here's a template:

```json
{
  "type": "AdaptiveCard",
  "body": [
    {
      "type": "TextBlock",
      "text": "@{triggerBody()?['title']}",
      "weight": "Bolder",
      "size": "Large",
      "color": "attention"
    },
    {
      "type": "TextBlock",
      "text": "@{triggerBody()?['message']}",
      "wrap": true
    },
    {
      "type": "FactSet",
      "facts": [
        { "title": "Server", "value": "@{triggerBody()?['hostname']}" },
        { "title": "IP", "value": "@{triggerBody()?['ip']}" },
        { "title": "CPU", "value": "@{triggerBody()?['cpu_usage']}" },
        { "title": "Memory", "value": "@{triggerBody()?['memory_usage']}" },
        { "title": "Disk", "value": "@{triggerBody()?['disk_usage']}" },
        { "title": "Uptime", "value": "@{triggerBody()?['uptime']}" },
        { "title": "Time", "value": "@{triggerBody()?['timestamp']}" }
      ]
    }
  ],
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "version": "1.2"
}
```

# Plan for Implementing Mock Calendar Tool in Chapter 7

This plan outlines the conceptual steps to add a simulated "Google Calendar event setup" tool to the Chapter 7 multimodal chat application. This tool will demonstrate function calling, specifically how the model handles required parameters.

**Tool Purpose:** To simulate setting up a calendar event.

**Required Parameters:** The tool needs both `Time` and `Location`.

**Success Condition:** The tool should only indicate success if *both* `Time` and `Location` are provided by Gemini in the tool call.

**Success Response:** If successful, the tool should return a specific confirmation message to Gemini, like 'Great, a date has been set up on [Time] at [Location].'

**Implementation:** This will be a *mockup* tool, meaning it won't actually interact with a real Google Calendar API, but will simulate the process within the existing application's function calling framework.

## Conceptual Steps:

1.  **Define the Function Declaration:**
    *   Modify the `functionDeclarations` array in the WebSocket setup message within [`part_2_dev_api/chapter_07/index.html`](part_2_dev_api/chapter_07/index.html:103).
    *   Add a new object to this array that describes the "create_calendar_event" tool.
    *   This declaration will include the tool's `name` (e.g., "create_calendar_event"), a `description` (e.g., "Creates a new Google Calendar event"), and the `parameters`.
    *   The `parameters` object will define `type: "OBJECT"` and list the required properties: `time` and `location`, both with `type: "STRING"` and appropriate descriptions. Crucially, the `required` array within the parameters will list both "time" and "location".

    ```javascript
    // Example structure for the new function declaration
    {
      name: "create_calendar_event",
      description: "Creates a new Google Calendar event",
      parameters: {
        type: "OBJECT",
        properties: {
          time: {
            type: "STRING",
            description: "The time of the event (e.g., 'tomorrow at 3 PM', 'May 5th at 10:00')"
          },
          location: {
            type: "STRING",
            description: "The location of the event (e.g., 'Conference Room A', 'online')"
          }
        },
        required: ["time", "location"] // Both parameters are required
      }
    }
    ```

2.  **Implement the Client-Side Function:**
    *   Add a new JavaScript function in the `<script type="module">` block in [`part_2_dev_api/chapter_07/index.html`](part_2_dev_api/chapter_07/index.html). Let's call this function `createCalendarEvent`.
    *   This function will accept the arguments passed by Gemini (an object containing `time` and `location`).
    *   Inside this function, check if both `time` and `location` properties exist and are not empty.
    *   If both are present, construct the success message: `'Great, a date has been set up on ${time} at ${location}.'`
    *   If either is missing, return a message indicating missing parameters.
    *   The function should return an object that will be sent back to Gemini as the tool response result.

    ```javascript
    // Example client-side function
    function createCalendarEvent(args) {
      const time = args.time;
      const location = args.location;

      if (time && location) {
        const confirmationMessage = `Great, a date has been set up on ${time} at ${location}.`;
        console.log("Mock Calendar Tool Success:", confirmationMessage);
        return { success: true, message: confirmationMessage }; // Return a structured result
      } else {
        console.log("Mock Calendar Tool Failed: Missing parameters");
        return { success: false, message: "Missing required parameters (time or location)." };
      }
    }
    ```

3.  **Integrate the Function into the `onToolCall` Handler:**
    *   Modify the `geminiAPI.onToolCall` handler in [`part_2_dev_api/chapter_07/index.html`](part_2_dev_api/chapter_07/index.html:271).
    *   Add an `else if` block to handle the "create_calendar_event" tool call.
    *   Inside this block, call the `createCalendarEvent` function with the `call.args`.
    *   Format the return value of `createCalendarEvent` into the `functionResponses` array, similar to how the other tool responses are formatted. The key is to put the result of your `createCalendarEvent` function into the `object_value`.

    ```javascript
    // Example modification within onToolCall
    geminiAPI.onToolCall = async (toolCall) => {
      const functionCalls = toolCall.functionCalls;
      const functionResponses = [];

      for (const call of functionCalls) {
        if (call.name === 'get_weather') {
          // ... existing weather handling ...
        } else if (call.name === 'get_stock_price') {
          // ... existing stock handling ...
        } else if (call.name === 'create_calendar_event') { // Add this block
          logMessage(`Function: ${call.name}`);
          logMessage(`Parameters: time = "${call.args.time}", location = "${call.args.location}"`);

          const result = createCalendarEvent(call.args); // Call your new function

          logMessage(`Tool Response Result: ${JSON.stringify(result)}`); // Log the result

          functionResponses.push({
            id: call.id,
            name: call.name,
            response: {
              result: {
                object_value: result // Include the result object here
              }
            }
          });
        } else {
           // Handle unknown tool calls if necessary
           console.warn(`Unknown tool call: ${call.name}`);
           functionResponses.push({
             id: call.id,
             name: call.name,
             response: {
               error: {
                 message: `Tool '${call.name}' not found.`
               }
             }
           });
        }
      }
      // Send tool response back using the API
      geminiAPI.sendToolResponse(functionResponses);
    };
    ```

4.  **Update System Instructions:**
    *   Modify the [`system-instructions.txt`](part_2_dev_api/chapter_07/system-instructions.txt) file to include clear instructions for Gemini on when and how to use the new "create_calendar_event" tool.
    *   Instruct Gemini to use this tool when the user expresses intent to schedule, set up a meeting, or create an event.
    *   Emphasize that both the time and location are required parameters for this tool and that Gemini should ask the user for any missing required information before attempting the tool call.
    *   Guide Gemini on how to interpret the tool's success response and confirm the event creation to the user.

    ```text
    # Existing instructions...

    - When the user asks to schedule, set up a meeting, or create an event, use the 'create_calendar_event' tool.
    - The 'create_calendar_event' tool requires both the time and location of the event.
    - If the user does not provide both the time and location in their initial request, ask clarifying questions to get the missing information before calling the tool.
    - Once the 'create_calendar_event' tool is successfully called and returns a confirmation message, inform the user that the event has been set up, including the time and location from the confirmation message.
    ```

This plan provides a clear roadmap for adding the mockup calendar tool and ensuring Gemini can effectively use it within the application's function calling framework.
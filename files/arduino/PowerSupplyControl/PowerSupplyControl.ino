// Pin Definitions
const int powerControlPin = 4;  // Control the power supply (active low)
const int powerStatePin = 7;    // Monitor power supply state (external pull-down or other circuit logic)
const int ledPin = 6;           // LED indicating power state
const int buttonPin = 5;        // Button for toggling power
const int remoteControlPin = 3; // Input from remote control (active high)
const int outputStatePin = 2;   // Output to remote control

// Timing Constants
const unsigned long holdDuration = 5000; // 5 seconds for turning off (button only)

// State Variables
bool powerState = false;           // Tracks the state of the power supply
unsigned long buttonPressTime = 0; // Tracks the button hold duration
bool buttonHeld = false;           // Indicates if button is being held
bool remoteControlPreviouslyActive = false; // Tracks previous state of remote control input
bool buttonPreviouslyPressed = false;       // Tracks previous state of the button
bool ignoreRemoteControlInput = false;      // Ensures remote control events are ignored until a state change

void setup() {
  // Pin Modes
  pinMode(powerControlPin, INPUT_PULLUP); // Default to high (off state)
  pinMode(powerStatePin, INPUT);          // External pull-down or proper external circuit
  pinMode(ledPin, OUTPUT);
  pinMode(buttonPin, INPUT_PULLUP);       // Internal pull-up resistor enabled
  pinMode(remoteControlPin, INPUT);       // External signal, active high
  pinMode(outputStatePin, OUTPUT);

  // Initial States
  digitalWrite(ledPin, LOW);           // Ensure LED is off initially
  digitalWrite(outputStatePin, LOW);   // Ensure output state is off initially
}

void loop() {
  // Read inputs
  bool buttonState = digitalRead(buttonPin) == LOW;        // Button pressed = LOW
  bool remoteControlState = digitalRead(remoteControlPin) == HIGH; // Remote control active = HIGH
  bool currentPowerState = digitalRead(powerStatePin) == HIGH; // Power supply active = HIGH

  // Ignore remote control input until the signal is deactivated and reactivated
  if (ignoreRemoteControlInput && !remoteControlState) {
    ignoreRemoteControlInput = false; // Reset remote control input ignore flag once the signal is deactivated
  }

  // Check if the power supply should turn on
  if (!currentPowerState) {
    // Turn on only if button or remote control signal is newly pressed/activated
    if ((buttonState && !buttonPreviouslyPressed) || (remoteControlState && !remoteControlPreviouslyActive && !ignoreRemoteControlInput)) {
      powerState = true;
      pinMode(powerControlPin, OUTPUT);  // Set as output
      digitalWrite(powerControlPin, LOW); // Pull low to turn power on
      buttonHeld = false;       // Reset the hold state after turning on
      buttonPressTime = 0;      // Reset button press time
      ignoreRemoteControlInput = true;  // Ignore further remote control input until the signal is deactivated
    }
  } else {
    // Handle turning the power supply off
    if (remoteControlState && !ignoreRemoteControlInput) {
      // Immediately turn off if remote control signal is active
      powerState = false;
      pinMode(powerControlPin, INPUT_PULLUP); // Revert to input pull-up to turn power off
      buttonHeld = false;       // Reset hold state
      buttonPressTime = 0;      // Reset button press time
      ignoreRemoteControlInput = true;  // Ignore further remote control input until the signal is deactivated
    } else if (buttonState) {
      // Apply hold time only for the button
      if (!buttonHeld) {
        buttonPressTime = millis(); // Start timing button press
        buttonHeld = true;
      } else if (millis() - buttonPressTime >= holdDuration) {
        powerState = false;
        pinMode(powerControlPin, INPUT_PULLUP); // Revert to input pull-up to turn power off
        buttonHeld = false;       // Reset hold state
        buttonPressTime = 0;      // Reset button press time
      }
    } else {
      buttonHeld = false; // Reset hold state if button is released
    }
  }

  // Update LED and output state
  if (currentPowerState) {
    digitalWrite(ledPin, HIGH);       // Turn LED on
    digitalWrite(outputStatePin, HIGH); // Output power state as on
  } else {
    digitalWrite(ledPin, LOW);        // Turn LED off
    digitalWrite(outputStatePin, LOW); // Output power state as off
  }

  // Update previous states
  buttonPreviouslyPressed = buttonState;
  remoteControlPreviouslyActive = remoteControlState;

  delay(100); // Small delay for stability
}

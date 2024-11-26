// Pin and Timing Definitions
const int SENSORPIN = 4;   // Sensor input pin
const int TTL_PIN = 13;    // TTL output pin
const int PAUSE = 5000;    // Pause duration (ms)
const int ITI = 1000;      // Inter-trial interval (ms)
const int STEADY_TIME = 500; // Time (ms) the state must remain stable

// Variables
int incomingByte = 0;      // Byte received from serial port

void setup() {
  Serial.begin(9600);        // Initialize serial communication
  pinMode(TTL_PIN, OUTPUT);  // Set TTL pin as output
  pinMode(SENSORPIN, INPUT); // Set sensor pin as input
  digitalWrite(SENSORPIN, HIGH); // Enable pull-up resistor
}

void loop() {
  // Check for serial input
  if (Serial.available() > 0) {
    incomingByte = Serial.read();

    if (incomingByte == 49) { // If '1' is received
      digitalWrite(TTL_PIN, HIGH); // Turn on TTL
      delay(PAUSE);                // Pause
      digitalWrite(TTL_PIN, LOW);  // Turn off TTL
      delay(ITI);                  // Inter-trial interval              // Trigger the TTL output
    } 
    else if (incomingByte == 115) { // If 's' is received
      monitorSensorSteadyChange(); // Monitor sensor state with steady detection
    }
  }
}

void monitorSensorSteadyChange() {
  int lastState = digitalRead(SENSORPIN); // Initial sensor state
  int currentState = lastState;
  unsigned long stableStart = millis();  // Start of stable state

  while (true) {
    currentState = digitalRead(SENSORPIN);

    // Check if the state has changed
    if (currentState != lastState) {
      // Reset stable timer on state change
      stableStart = millis();
      lastState = currentState;
    } else {
      // Check if the state has remained stable for the required time
      if (millis() - stableStart >= STEADY_TIME) {
        Serial.println(currentState == HIGH ? "Unbroken" : "Broken");
        break; // Exit the loop once a steady state is detected
      }
    }

    delay(50); // Short delay to debounce and reduce CPU usage
  }
}
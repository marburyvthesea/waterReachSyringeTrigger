// some setup variables
int SENSORPIN = 4;  // PIN definition { new }
int TTL_PIN = 13; // pull high to output
int BUZZER = 9; // buzzzer to arduino pin 9
int PAUSE_trigger = 100; // pause after output
int PAUSE_buzzer = 9000; // pause after output
int ITI = 1000; // pause between outputs 
int run = 0; // state variable

// incoming byte on serial port
int incomingByte = 0; 

// the setup function runs once when you press reset or power the board
void setup() {
 
  Serial.begin(9600);  // open serial port
  
  pinMode(TTL_PIN, OUTPUT); // initialize digital pin LED_BUILTIN as an output.
  pinMode(BUZZER, OUTPUT); // buzzer pin to output
  pinMode(SENSORPIN, INPUT);    // initialize sensor pin as input
  digitalWrite(SENSORPIN, HIGH); // turn on the pullup

}

// the loop function runs over and over again forever
void loop() {
  // wait for signal from serial port then begin sequence 

  if (run == 0) 
  {
    if (Serial.available() > 0) 
    {
      //read incoming byte
      incomingByte = Serial.read();
      // display byte read
      //Serial.print("I received: ");
      //Serial.println(incomingByte);
      

      if (incomingByte == 49) // ASCII 49 is 1
      {
        Serial.write(incomingByte);
        if (run == 0) // start running if not previosly running
        {
          digitalWrite(TTL_PIN, HIGH);   // turn the LED on (HIGH is the voltage level)
          tone(BUZZER, 8000);
          delay(PAUSE_trigger);                       // wait
          digitalWrite(TTL_PIN, LOW);    // turn the LED off by making the voltage LOW
          tone(BUZZER, 8000);
          delay(PAUSE_buzzer);
          noTone(BUZZER);              // Turn off buzzer
          
          // Send "1" back to serial after the PAUSE interval
          delay(ITI); 
          //Serial.println("1");
          
          delay(ITI);                       // wait for a second
        }
        else
        {
          digitalWrite(TTL_PIN, LOW); 
          delay(PAUSE_trigger); 
        }
      }
      else if (incomingByte == 115) // ASCII 115 is 's'
      {
        int initiateLoop = 0; // variable controlling loop 
        int sensorState = 0, lastState = 0;

        while (initiateLoop == 0) {
          sensorState = digitalRead(SENSORPIN);

          if (sensorState && !lastState) {
            Serial.println("Unbroken");
            initiateLoop = 1;  //sets to break loop
          } 
          else
          {
            Serial.println("Broken");
            initiateLoop = 1;
          }
          lastState = sensorState;
        }
      }
      else
      {
        digitalWrite(TTL_PIN, LOW);
      }
    }
  }
}


// some setup variables
int SENSORPIN = 4;  // PIN definition { new }
int TTL_PIN = 12; // pull high to output
int PAUSE = 5000; // pause after output
int ITI = 1000; // pause between outputs 
int run = 0; // state variable

// incoming byte on serial port
int incomingByte = 0; 

// the setup function runs once when you press reset or power the board
void setup() {
 
  Serial.begin(9600);  // open serial port
  
  pinMode(TTL_PIN, OUTPUT); // initialize digital pin LED_BUILTIN as an output.
  
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
          run = 1 ;
          digitalWrite(TTL_PIN, HIGH);   // turn the LED on (HIGH is the voltage level)
          delay(PAUSE);                       // wait
          digitalWrite(TTL_PIN, LOW);    // turn the LED off by making the voltage LOW
          
          // Send "1" back to serial after the PAUSE interval
          delay(ITI); 
          Serial.println("1");
          
          delay(ITI);                       // wait for a second
          run = 0;
        }
        else
        {
          digitalWrite(TTL_PIN, LOW); 
          delay(PAUSE); 
          run = 0; // remain in 0 if no signal 
        }
      }
      else if (incomingByte == 115) // ASCII 115 is 's'
      {
        int initiateLoop = 0;
        int sensorState = 0, lastState = 0;

        while (initiateLoop == 0) {
          sensorState = digitalRead(SENSORPIN);

          if (sensorState && !lastState) {
            Serial.write("Unbroken");
            initiateLoop = 1;  //sets to break loop
          } 
          if (!sensorState && lastState) 
          {
            Serial.println("Broken");
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


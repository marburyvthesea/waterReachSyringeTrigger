

// some setup variables

int TTL_PIN = 13; // pull high to output
int PAUSE = 10000; // pause after output
int ITI = 10000; // pause between outputs 
int run = 0; // state variable

// incoming byte on serial port
int incomingByte = 0; 

// the setup function runs once when you press reset or power the board
void setup() {
  // open serial port
  Serial.begin(9600); 
  
  // initialize digital pin LED_BUILTIN as an output.
  pinMode(TTL_PIN, OUTPUT);

}

// the loop function runs over and over again forever
void loop() {
  // wait for signal from serial port then begin sequence 

  if (run == 0) {
    if (Serial.available() > 0) {
      //read incoming byte
      incomingByte = Serial.read();
      // display byte read
      Serial.print("I received: ");
      Serial.println(incomingByte, DEC);
      Serial.write(incomingByte);

      if (incomingByte == 49) // ASCII 49 is 1
      {
        if (run == 0) // start running if not previosly running
        {
          run = 1 ;
          digitalWrite(TTL_PIN, HIGH);   // turn the LED on (HIGH is the voltage level)
          delay(PAUSE);                       // wait
          digitalWrite(TTL_PIN, LOW);    // turn the LED off by making the voltage LOW
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
      else
      {
      digitalWrite(TTL_PIN, LOW);
   
     }

      
    }

  }

}


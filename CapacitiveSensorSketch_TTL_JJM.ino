#include <CapacitiveSensor.h>

/*
 * CapitiveSense Library Demo Sketch
 * Paul Badger 2008
 * Uses a high value resistor e.g. 10M between send pin and receive pin
 * Resistor effects sensitivity, experiment with values, 50K - 50M. Larger resistor values yield larger sensor values.
 * Receive pin is the sensor pin - try different amounts of foil/metal on this pin
 */

int TTL_PIN = 11; // pull high to output
int TTL_PW = 500; // length of TTL pulse
int CAP_threshold = 10000; 

CapacitiveSensor   cs_9_2 = CapacitiveSensor(9,2);        // 10M resistor between pins 4 & 2, pin 2 is sensor pin, add a wire and or foil if desired
//CapacitiveSensor   cs_4_6 = CapacitiveSensor(4,6);        // 10M resistor between pins 4 & 6, pin 6 is sensor pin, add a wire and or foil
//CapacitiveSensor   cs_4_8 = CapacitiveSensor(4,8);        // 10M resistor between pins 4 & 8, pin 8 is sensor pin, add a wire and or foil

void setup()                    
{
   cs_9_2.set_CS_AutocaL_Millis(0xFFFFFFFF);     // turn off autocalibrate on channel 1 - just as an example
   Serial.begin(9600);
   pinMode(LED_BUILTIN, OUTPUT); // use builting LED to monitor TTL pulse condition
   pinMode(TTL_PIN, OUTPUT);
}

void loop()                    
{
    digitalWrite(LED_BUILTIN, LOW);    // turn the LED off by making the voltage LOW
    digitalWrite(TTL_PIN, LOW);
    
    long start = millis();
    long total1 =  cs_9_2.capacitiveSensor(30);
    //long total2 =  cs_4_6.capacitiveSensor(30);
    //long total3 =  cs_4_8.capacitiveSensor(30);

    //Serial.print(millis() - start);        // check on performance in milliseconds
    Serial.print("\t");                    // tab character for debug windown spacing

    Serial.print(total1);                  // print sensor output 1
    Serial.print("\t");
    
    if (total1 > CAP_threshold)
      digitalWrite(LED_BUILTIN, HIGH);   // turn the LED on (HIGH is the voltage level)
      digitalWrite(TTL_PIN, HIGH);
      delay(TTL_PW);
      digitalWrite(TTL_PIN, LOW);
      digitalWrite(LED_BUILTIN, LOW);    // turn the LED off by making the voltage LOW
    //else
    //  digitalWrite(TTL_PIN, LOW);
    //  digitalWrite(LED_BUILTIN, LOW);
    
      
    //Serial.print(total2);                  // print sensor output 2
    //Serial.print("\t");
    //Serial.println(total3);                // print sensor output 3

    delay(10);                             // arbitrary delay to limit data to serial port 
}

/*
 * OneBox
 * readdata.ino
 * Wolf Honore
 *
 * Read data from sensors and send to SuperCollider over serial.
 */

const byte syncVal = 13; // Special value to mark start of send
const byte del = 1; // msec to wait between sending data
const byte nfxs = 4; // Number of active fxs
const byte nctrls = 5; // Max number of controls

// Pins
const byte analogs[6] = {A0, A1, A2, A3, A4, A5};
const byte mute = 2;
const byte left = 3;
const byte right = 4;
const byte idxs[nfxs] = {5, 6, 7, 8};

void setup() {
  pinMode(mute, INPUT_PULLUP);
  pinMode(left, INPUT);
  pinMode(right, INPUT);
  for (byte i = 0; i < nfxs; i++) {
    pinMode(idxs[i], INPUT);
  }

  Serial.begin(9600);
  while (!Serial) {}
}

void loop() {
  byte muteVal;
  byte leftVal;
  byte rightVal;
  byte idxsVal[nfxs];

  // Read values
  muteVal = digitalRead(mute);
  leftVal = digitalRead(left);
  rightVal = digitalRead(right);
  for (byte i = 0; i < nfxs; i++) {
    idxsVal[i] = digitalRead(idxs[i]);
  }

  // Begin send
  Serial.write(syncVal);

  Serial.write(!muteVal);
  Serial.write(leftVal);
  Serial.write(rightVal);
  for (byte i = 0; i < nfxs; i++) {
    Serial.write(idxsVal[i]);
  }

  for (byte i = 0; i < nctrls; i++) {
    word val = analogRead(analogs[i]);

    // Shift val if it equals syncVal
    if (val == syncVal) {
      val = val - 1;
    }

    Serial.write(lowByte(val));
    Serial.write(highByte(val));
  }

  delay(del);
}

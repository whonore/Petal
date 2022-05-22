/*
 * Petal
 * readdata.ino
 * Wolf Honore
 *
 * Read data from sensors and send to SuperCollider over serial.
 */

const uint32_t DELAY = 1; // msec to wait between sending data
const byte SYNC = 128; // Special value to mark start of send

struct button_t {
    const byte pin;
    byte last;
};
#define BUTTON(p) { .pin = p, .last = LOW }

struct encoder_t {
    const byte A;
    const byte B;
    struct button_t button;
    byte Alast;
};
#define ENCODER(a, b, but) { \
    .A = (a), .B = (b), .button = BUTTON(but), \
    .Alast = LOW, \
}

struct encoder_t encoders[] = {
    ENCODER(38, 39, 40),
    ENCODER(34, 35, 36),
    ENCODER(30, 31, 32),
    ENCODER(26, 27, 28),
    ENCODER(22, 23, 24)
};
#define NENCODERS (sizeof(encoders) / sizeof(encoders[0]))

struct button_t buttons[] = {
    BUTTON(37),  // Idx1
    BUTTON(33),  // Idx2
    BUTTON(29),  // Idx3
    BUTTON(25),  // Idx4
    BUTTON(42),  // Left
    BUTTON(43),  // Right
    BUTTON(41)   // Stomp
};
#define NBUTTONS (sizeof(buttons) / sizeof(buttons[0]))

void setup() {
    for (byte i = 0; i < NENCODERS; i++) {
        pinMode(encoders[i].A, INPUT);
        pinMode(encoders[i].B, INPUT);
        pinMode(encoders[i].button.pin, INPUT);
    }
    for (byte i = 0; i < NBUTTONS; i++) {
        pinMode(buttons[i].pin, INPUT);
    }

    Serial.begin(19200);
    while (!Serial) {}
}

void loop() {
    int8_t offset[NENCODERS];
    bool pressed[NENCODERS + NBUTTONS];

    for (byte i = 0; i < NENCODERS; i++) {
        offset[i] = readEncoder(&encoders[i]);
        pressed[i] = wasPressed(&encoders[i].button);
    }
    for (byte i = 0; i < NBUTTONS; i++) {
        pressed[NENCODERS + i] = wasPressed(&buttons[i]);
    }

    // TODO: Write an entire packet as a single buffer
    // TODO: Use a bitarray for pressed
    Serial.write(SYNC);
    for (byte i = 0; i < NENCODERS; i++) {
        Serial.write(offset[i]);
    }
    for (byte i = 0; i < NENCODERS + NBUTTONS; i++) {
        Serial.write(pressed[i]);
    }

    delay(DELAY);
}

static int8_t readEncoder(struct encoder_t *encoder) {
    int8_t off = 0;
    byte Acur = digitalRead(encoder->A);
    if ((encoder->Alast == HIGH) && (Acur == LOW)) {
        off = (digitalRead(encoder->B) == HIGH ? 1 : -1);
    }
    encoder->Alast = Acur;
    return off;
}

static bool wasPressed(struct button_t *button) {
    byte st = digitalRead(button->pin);
    byte last = button->last;
    button->last = st;
    return (st == HIGH && last == LOW);
}

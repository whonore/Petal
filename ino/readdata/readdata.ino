/*
 * Petal
 * readdata.ino
 * Wolf Honore
 *
 * Read data from sensors and send to SuperCollider over serial.
 */

const uint32_t DELAY = 1; // msec to wait between sending data
const byte ENCODER_MAX = 128;
const byte SYNC = ENCODER_MAX; // Special value to mark start of send

struct button_t {
    const byte pin;
    byte last;
};
#define BUTTON(p) { .pin = p, .last = LOW }

struct encoder_t {
    const byte A;
    const byte B;
    struct button_t button;
    byte pos;
    byte Alast;
};
#define ENCODER(a, b, but) { \
    .A = (a), .B = (b), .button = BUTTON(but), \
    .pos = 10, .Alast = LOW, \
}

struct encoder_t encoders[] = {
    ENCODER(22, 23, 24),
    ENCODER(26, 27, 28),
    ENCODER(30, 31, 32),
    ENCODER(34, 35, 36),
    ENCODER(38, 39, 40)
};
#define NENCODERS (sizeof(encoders) / sizeof(encoders[0]))

struct button_t buttons[] = {
    BUTTON(25),
    BUTTON(29),
    BUTTON(33),
    BUTTON(37),
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
    bool pressed[NENCODERS + NBUTTONS];

    for (byte i = 0; i < NENCODERS; i++) {
        readEncoder(&encoders[i]);
        pressed[i] = wasPressed(&encoders[i].button);
    }
    for (byte i = 0; i < NBUTTONS; i++) {
        pressed[NENCODERS + i] = wasPressed(&buttons[i]);
    }

    Serial.write(SYNC);
    for (byte i = 0; i < NENCODERS; i++) {
        Serial.write(encoders[i].pos - 1); // Shift to [0, ENCODER_MAX - 1]
    }
    for (byte i = 0; i < NENCODERS + NBUTTONS; i++) {
        Serial.write(pressed[i]);
    }

    delay(DELAY);
}

static void readEncoder(struct encoder_t *encoder) {
    byte Acur = digitalRead(encoder->A);
    if ((encoder->Alast == HIGH) && (Acur == LOW)) {
        encoder->pos = encoder->pos + (digitalRead(encoder->B) == HIGH ? 1 : -1);
        encoder->pos = constrain(encoder->pos, 1, ENCODER_MAX);
    }
    encoder->Alast = Acur;
}

static bool wasPressed(struct button_t *button) {
    byte st = digitalRead(button->pin);
    byte last = button->last;
    button->last = st;
    return (st == HIGH && last == LOW);
}

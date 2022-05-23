/*
 * Petal
 * readdata.ino
 * Wolf Honore
 *
 * Read data from sensors and send to SuperCollider over serial.
 */

// Number of bytes needed to fit nbits bits
#define NBYTES(nbits) ((nbits) / 8) + ((nbits) % 8 != 0)

const uint32_t DELAY = 1; // msec to wait between sending data
const byte SYNC = 255; // Special value to mark start of send

enum Dir {
    NONE,
    LEFT,
    RIGHT,
};

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

static struct encoder_t encoders[] = {
    ENCODER(38, 39, 40),
    ENCODER(34, 35, 36),
    ENCODER(30, 31, 32),
    ENCODER(26, 27, 28),
    ENCODER(22, 23, 24)
};
#define NENCODERS (sizeof(encoders) / sizeof(encoders[0]))

static struct button_t buttons[] = {
    BUTTON(37),  // Idx1
    BUTTON(33),  // Idx2
    BUTTON(29),  // Idx3
    BUTTON(25),  // Idx4
    BUTTON(42),  // Left
    BUTTON(43),  // Right
    BUTTON(41)   // Stomp
};
#define NBUTTONS (sizeof(buttons) / sizeof(buttons[0]))

//                     Sync       Encoder Offs    Encoder Btns Btns
const byte PKT_BYTES = 1 + NBYTES(2 * NENCODERS + NENCODERS +  NBUTTONS);

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
    enum Dir offset[NENCODERS];
    bool pressed[NENCODERS + NBUTTONS];
    byte pkt[PKT_BYTES];

    // Read encoder and button states
    for (byte i = 0; i < NENCODERS; i++) {
        offset[i] = readEncoder(&encoders[i]);
        pressed[i] = isPressed(&encoders[i].button);
    }
    for (byte i = 0; i < NBUTTONS; i++) {
        pressed[NENCODERS + i] = wasPressed(&buttons[i]);
    }

    // Build a packet
    memset(pkt, 0, PKT_BYTES);
    pkt[0] = SYNC;
    byte bit_off = 8;
    // Two bits per encoder (00 = no change, 10 = left, 01 = right)
    for (byte i = 0; i < NENCODERS; i++, bit_off += 2) {
        byte idx = bit_off / 8;
        byte bit_idx = bit_off % 8;
        switch (offset[i]) {
        case NONE:
            bitWrite(pkt[idx], bit_idx, 0);
            bitWrite(pkt[idx], bit_idx + 1, 0);
            break;
        case LEFT:
            bitWrite(pkt[idx], bit_idx, 0);
            bitWrite(pkt[idx], bit_idx + 1, 1);
            break;
        case RIGHT:
            bitWrite(pkt[idx], bit_idx, 1);
            bitWrite(pkt[idx], bit_idx + 1, 0);
            break;
        }
    }
    // One bit per button (0 = unpressed, 1 = pressed)
    for (byte i = 0; i < NENCODERS + NBUTTONS; i++, bit_off += 1) {
        byte idx = bit_off / 8;
        byte bit_idx = bit_off % 8;
        bitWrite(pkt[idx], bit_idx, pressed[i]);
    }

    // Only send up to the last non-zero byte
    byte last_non_zero = PKT_BYTES - 1;
    while (0 < last_non_zero && pkt[last_non_zero] == 0) {
        last_non_zero -= 1;
    }
    if (last_non_zero != 0) {
        Serial.write(pkt, last_non_zero + 1);
    }

    delay(DELAY);
}

static enum Dir readEncoder(struct encoder_t *encoder) {
    enum Dir off = NONE;
    byte Acur = digitalRead(encoder->A);
    if ((encoder->Alast == HIGH) && (Acur == LOW)) {
        off = (digitalRead(encoder->B) == HIGH ? RIGHT : LEFT);
    }
    encoder->Alast = Acur;
    return off;
}

static byte readButton(struct button_t *button) {
    byte st = digitalRead(button->pin);
    button->last = st;
    return st;
}

static bool isPressed(struct button_t *button) {
    return readButton(button) == LOW;
}

static bool wasPressed(struct button_t *button) {
    byte last = button->last;
    byte st = readButton(button);
    return st == LOW && last == HIGH;
}

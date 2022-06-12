/*
 * Petal
 * readdata.ino
 * Wolf Honore
 *
 * Read data from sensors and send to SuperCollider over serial.
 */

#include <Adafruit_seesaw.h>

// Number of bytes needed to fit nbits bits
#define NBYTES(nbits) ((nbits) / 8) + ((nbits) % 8 != 0)

const uint32_t DELAY_MS = 10; // msec to wait between sending data
const uint32_t TIMEOUT_MS = 500; // maximum time (msec) to send no data
const uint32_t TIMEOUT_LOOPS = TIMEOUT_MS / DELAY_MS;
const byte SYNC = 255; // Special value to mark end of send

struct button_t {
    const byte pin;
    byte last;
};
#define BUTTON(p) { .pin = p, .last = HIGH }

struct encoder_t {
    Adafruit_seesaw encoder;
    byte last;
};
#define ENCODER(enc) { .encoder = enc, .last = HIGH }

const byte SS_SWITCH = 24;
const byte SEESAW_BASE_ADDR = 0x36;
static struct encoder_t encoders[] = {
    ENCODER(Adafruit_seesaw()),
    ENCODER(Adafruit_seesaw()),
    ENCODER(Adafruit_seesaw()),
    ENCODER(Adafruit_seesaw()),
    ENCODER(Adafruit_seesaw()),
};
#define NENCODERS (sizeof(encoders) / sizeof(encoders[0]))

static struct button_t buttons[] = {
    BUTTON(8),   // Idx1
    BUTTON(9),   // Idx2
    BUTTON(10),  // Idx3
    BUTTON(11),  // Idx4
    BUTTON(6),   // Left
    BUTTON(7),   // Right
    BUTTON(12)   // Stomp
};
#define NBUTTONS (sizeof(buttons) / sizeof(buttons[0]))

//                     Sync       Encoder Offs        Encoder Btns Btns
const byte PKT_BYTES = 1 + NBYTES(8 * NENCODERS + NENCODERS +  NBUTTONS);

static uint32_t timer = 0;

void setup() {
    for (byte i = 0; i < NENCODERS; i++) {
        // Reverse encoder order to go left-right
        encoders[i].encoder.begin(SEESAW_BASE_ADDR + (NENCODERS - i - 1));
        encoders[i].encoder.pinMode(SS_SWITCH, INPUT_PULLUP);
        encoders[i].encoder.setGPIOInterrupts(((uint32_t) 1) << SS_SWITCH, true);
        encoders[i].encoder.enableEncoderInterrupt();
    }
    for (byte i = 0; i < NBUTTONS; i++) {
        pinMode(buttons[i].pin, INPUT_PULLUP);
    }

    Serial.begin(115200);
    while (!Serial) {}
}

void loop() {
    int8_t offset[NENCODERS];
    bool pressed[NENCODERS + NBUTTONS];
    byte pkt[PKT_BYTES];

    timer += 1;

    // Read encoder and button states
    for (byte i = 0; i < NENCODERS; i++) {
        offset[i] = readEncoderOff(&encoders[i]);
        pressed[i] = isEncoderPressed(&encoders[i]);
    }
    for (byte i = 0; i < NBUTTONS; i++) {
        pressed[NENCODERS + i] = wasPressed(&buttons[i]);
    }

    // Build a packet
    memset(pkt, 0, PKT_BYTES);
    byte bit_off = 0;
    // One byte per encoder (signed 8-bit offset)
    memcpy(pkt, offset, NENCODERS);
    bit_off += 8 * NENCODERS;
    // One bit per button (0 = unpressed, 1 = pressed)
    for (byte i = 0; i < NENCODERS + NBUTTONS; i++, bit_off += 1) {
        byte idx = bit_off / 8;
        byte bit_idx = bit_off % 8;
        bitWrite(pkt[idx], bit_idx, pressed[i]);
    }

    // Only send up to the last non-zero byte
    byte last_non_zero = PKT_BYTES - 2;
    while (last_non_zero < PKT_BYTES && pkt[last_non_zero] == 0) {
        last_non_zero -= 1;
    }
    if (last_non_zero < PKT_BYTES) {
        timer = 0;
        pkt[last_non_zero + 1] = SYNC;
        Serial.write(pkt, last_non_zero + 2);
    } else if (timer == TIMEOUT_LOOPS) {
        timer = 0;
        Serial.write(SYNC);
    }

    yield();
    delay(DELAY_MS);
}

static uint8_t readEncoderOff(struct encoder_t *encoder) {
    int32_t off = -encoder->encoder.getEncoderDelta();
    // Shift negatives by 1 to avoid clash with -1 and SYNC
    off = (off < 0) ? off - 1 : off;
    return (uint8_t) constrain(off, INT8_MIN, INT8_MAX);
}

static byte readEncoderButton(struct encoder_t *encoder) {
    byte st = encoder->encoder.digitalRead(SS_SWITCH);
    encoder->last = st;
    return st;
}

static bool isEncoderPressed(struct encoder_t *encoder) {
    return readEncoderButton(encoder) == LOW;
}

static byte readButton(struct button_t *button) {
    byte st = digitalRead(button->pin);
    button->last = st;
    return st;
}

static bool wasPressed(struct button_t *button) {
    byte last = button->last;
    byte st = readButton(button);
    return st == LOW && last == HIGH;
}

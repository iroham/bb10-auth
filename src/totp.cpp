#include "totp.h"
#include <QUrl>
#include <QFile>
#include <QDir>
#include <QTimer>
#include <bb/system/Clipboard>
#include <QStringList>
#include <string>
#include <vector>
#include <stdint.h>
#include <time.h>

// ---- SHA-1 (RFC 3174), self-contained ----
namespace {
struct Sha1 {
    uint32_t h[5];
    uint64_t len;
    unsigned char buf[64];
    size_t n;
    Sha1() { reset(); }
    void reset() { h[0]=0x67452301; h[1]=0xEFCDAB89; h[2]=0x98BADCFE; h[3]=0x10325476; h[4]=0xC3D2E1F0; len=0; n=0; }
    static uint32_t rol(uint32_t v, int b) { return (v << b) | (v >> (32 - b)); }
    void block(const unsigned char *p) {
        uint32_t w[80];
        for (int i = 0; i < 16; i++) w[i] = (p[i*4]<<24)|(p[i*4+1]<<16)|(p[i*4+2]<<8)|p[i*4+3];
        for (int i = 16; i < 80; i++) w[i] = rol(w[i-3]^w[i-8]^w[i-14]^w[i-16], 1);
        uint32_t a=h[0],b=h[1],c=h[2],d=h[3],e=h[4];
        for (int i = 0; i < 80; i++) {
            uint32_t f, k;
            if (i < 20) { f = (b & c) | ((~b) & d); k = 0x5A827999; }
            else if (i < 40) { f = b ^ c ^ d; k = 0x6ED9EBA1; }
            else if (i < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDC; }
            else { f = b ^ c ^ d; k = 0xCA62C1D6; }
            uint32_t t = rol(a,5) + f + e + k + w[i];
            e=d; d=c; c=rol(b,30); b=a; a=t;
        }
        h[0]+=a; h[1]+=b; h[2]+=c; h[3]+=d; h[4]+=e;
    }
    void update(const unsigned char *p, size_t l) {
        len += (uint64_t)l * 8;
        while (l) { buf[n++] = *p++; l--; if (n == 64) { block(buf); n = 0; } }
    }
    void final(unsigned char out[20]) {
        uint64_t total = len;                                   // bit length BEFORE padding (padding must not change it)
        buf[n++] = 0x80; if (n == 64) { block(buf); n = 0; }
        while (n != 56) { buf[n++] = 0; if (n == 64) { block(buf); n = 0; } }
        for (int i = 0; i < 8; i++) buf[n++] = (unsigned char)(total >> (56 - 8*i));
        block(buf);
        for (int i = 0; i < 5; i++) { out[i*4]=h[i]>>24; out[i*4+1]=h[i]>>16; out[i*4+2]=h[i]>>8; out[i*4+3]=h[i]; }
    }
};

void hmac_sha1(const unsigned char *key, size_t kl, const unsigned char *msg, size_t ml, unsigned char out[20]) {
    unsigned char k[64]; memset(k, 0, 64);
    if (kl > 64) { Sha1 s; s.update(key, kl); s.final(k); } else memcpy(k, key, kl);
    unsigned char ipad[64], opad[64];
    for (int i = 0; i < 64; i++) { ipad[i] = k[i] ^ 0x36; opad[i] = k[i] ^ 0x5c; }
    unsigned char inner[20];
    { Sha1 s; s.update(ipad, 64); s.update(msg, ml); s.final(inner); }
    { Sha1 s; s.update(opad, 64); s.update(inner, 20); s.final(out); }
}

// RFC 4648 base32 decode (A-Z2-7, case-insensitive, ignores spaces and '=' padding). Returns false on a bad char.
bool base32decode(const QString &in, std::vector<unsigned char> &out) {
    out.clear();
    uint32_t buf = 0; int bits = 0;
    for (int i = 0; i < in.size(); i++) {
        QChar ch = in.at(i).toUpper();
        char c = ch.toLatin1();
        if (c == ' ' || c == '-' || c == '=') continue;
        int v;
        if (c >= 'A' && c <= 'Z') v = c - 'A';
        else if (c >= '2' && c <= '7') v = c - '2' + 26;
        else return false;
        buf = (buf << 5) | v; bits += 5;
        if (bits >= 8) { bits -= 8; out.push_back((unsigned char)((buf >> bits) & 0xff)); }
    }
    return !out.empty();
}

// HOTP (RFC 4226): counter -> digits-length decimal string, zero-padded.
QString hotp(const std::vector<unsigned char> &key, uint64_t counter, int digits) {
    unsigned char msg[8];
    for (int i = 7; i >= 0; i--) { msg[i] = (unsigned char)(counter & 0xff); counter >>= 8; }
    unsigned char mac[20];
    hmac_sha1(key.empty() ? (const unsigned char *)"" : &key[0], key.size(), msg, 8, mac);
    int off = mac[19] & 0x0f;
    uint32_t bin = ((mac[off] & 0x7f) << 24) | (mac[off+1] << 16) | (mac[off+2] << 8) | mac[off+3];
    uint32_t mod = 1; for (int i = 0; i < digits; i++) mod *= 10;
    QString s = QString::number(bin % mod);
    while (s.size() < digits) s.prepend('0');
    return s;
}
} // namespace

Totp::Totp(const QString &dataDir, QObject *parent) : QObject(parent) {
    QDir().mkpath(dataDir);
    m_file = dataDir + "/accounts.json";
    QTimer *t = new QTimer(this);
    connect(t, SIGNAL(timeout()), this, SIGNAL(tick()));   // drive QML 'now' bindings once a second
    t->start(1000);
}

int Totp::now() const { return (int)time(0); }

void Totp::copy(const QString &text) const {
    bb::system::Clipboard clip;
    clip.clear();
    clip.insert("text/plain", text.toUtf8());
}

QString Totp::generate(const QString &secretBase32, int digits, int period) const {
    std::vector<unsigned char> key;
    if (!base32decode(secretBase32, key)) return QString();
    if (digits < 6 || digits > 8) digits = 6;
    if (period <= 0) period = 30;
    uint64_t counter = (uint64_t)time(0) / (uint64_t)period;
    return hotp(key, counter, digits);
}

QString Totp::codeFmt(const QString &secretBase32, int digits, int period) const {
    QString c = generate(secretBase32, digits, period);
    if (c.isEmpty()) return QString::fromUtf8("••• •••");   // "••• •••" placeholder
    int half = c.size() / 2;
    return c.left(half) + " " + c.mid(half);
}

int Totp::remaining(int period) const {
    if (period <= 0) period = 30;
    return period - (int)((uint64_t)time(0) % (uint64_t)period);
}

bool Totp::validSecret(const QString &secretBase32) const {
    std::vector<unsigned char> key;
    return base32decode(secretBase32, key);
}

static QString jesc(const QString &s) { QString o = s; o.replace("\\", "\\\\").replace("\"", "\\\""); return o; }

QString Totp::parseUri(const QString &uri) const {
    // otpauth://totp/LABEL?secret=...&issuer=...&digits=6&period=30&algorithm=SHA1
    QUrl u(uri);
    if (u.scheme() != "otpauth" || u.host().toLower() != "totp")
        return "{\"ok\":false}";
    QString label = u.path(); if (label.startsWith('/')) label = label.mid(1);
    QString issuer, account = label;
    int colon = label.indexOf(':');
    if (colon >= 0) { issuer = label.left(colon); account = label.mid(colon + 1).trimmed(); }
    QString secret = u.queryItemValue("secret");
    QString qIssuer = u.queryItemValue("issuer"); if (!qIssuer.isEmpty()) issuer = qIssuer;
    int digits = u.queryItemValue("digits").toInt(); if (digits < 6 || digits > 8) digits = 6;
    int period = u.queryItemValue("period").toInt(); if (period <= 0) period = 30;
    QString algo = u.queryItemValue("algorithm").toUpper(); if (algo.isEmpty()) algo = "SHA1";
    std::vector<unsigned char> k;
    if (secret.isEmpty() || !base32decode(secret, k)) return "{\"ok\":false}";
    return QString("{\"ok\":true,\"issuer\":\"%1\",\"account\":\"%2\",\"secret\":\"%3\",\"digits\":%4,\"period\":%5,\"algo\":\"%6\"}")
        .arg(jesc(issuer), jesc(account), jesc(secret)).arg(digits).arg(period).arg(jesc(algo));
}

QString Totp::load() const {
    QFile f(m_file);
    if (!f.open(QIODevice::ReadOnly)) return "[]";
    QByteArray b = f.readAll(); f.close();
    QString s = QString::fromUtf8(b);
    return s.trimmed().isEmpty() ? "[]" : s;
}

void Totp::save(const QString &jsonArray) const {
    QFile f(m_file);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    f.write(jsonArray.toUtf8()); f.close();
    f.setPermissions(QFile::ReadOwner | QFile::WriteOwner);   // keep it owner-only
}

bool Totp::selftest() const {
    // RFC 4226 Appendix D: secret "12345678901234567890", HOTP(0)=755224, HOTP(1)=287082, HOTP(9)=520489.
    std::vector<unsigned char> key((const unsigned char *)"12345678901234567890", (const unsigned char *)"12345678901234567890" + 20);
    return hotp(key, 0, 6) == "755224" && hotp(key, 1, 6) == "287082" && hotp(key, 9, 6) == "520489";
}

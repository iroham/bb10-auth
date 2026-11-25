// Self-contained TOTP (RFC 6238 / HOTP RFC 4226, HMAC-SHA1) with no external crypto dependency. Exposed to QML.
// SHA1 is what essentially every TOTP service uses (Google, GitHub, Microsoft, AWS, …). SHA256/512 not yet supported.
#ifndef AUTH_TOTP_H
#define AUTH_TOTP_H
#include <QObject>
#include <QString>
class QTimer;

class Totp : public QObject {
    Q_OBJECT
    // Re-read each second so QML code/countdown bindings refresh. Value is the current unix time.
    Q_PROPERTY(int now READ now NOTIFY tick)
public:
    explicit Totp(const QString &dataDir, QObject *parent = 0);
    int now() const;

    // Current code for a base32 secret. Returns "" on an invalid secret.
    Q_INVOKABLE QString generate(const QString &secretBase32, int digits = 6, int period = 30) const;
    // Current code grouped for display ("123 456"), or a dash placeholder if the secret is invalid.
    Q_INVOKABLE QString codeFmt(const QString &secretBase32, int digits = 6, int period = 30) const;
    // Seconds left in the current window (for the countdown ring).
    Q_INVOKABLE int remaining(int period = 30) const;
    // Parse an otpauth:// URI. Returns a JSON object string {ok,issuer,account,secret,digits,period,algo} (ok=false on failure).
    Q_INVOKABLE QString parseUri(const QString &uri) const;
    // Validate a base32 secret (non-empty, decodes). For the manual-add form.
    Q_INVOKABLE bool validSecret(const QString &secretBase32) const;

    // Persistence of the account list (JSON array string) in the app sandbox.
    Q_INVOKABLE QString load() const;
    Q_INVOKABLE void save(const QString &jsonArray) const;

    // Put text on the system clipboard (so a code can be pasted into a login form).
    Q_INVOKABLE void copy(const QString &text) const;
    // RFC 4226 known-answer check of the HMAC-SHA1/HOTP path (true = crypto is correct).
    Q_INVOKABLE bool selftest() const;

Q_SIGNALS:
    void tick();

private:
    QString m_file;
};

#endif

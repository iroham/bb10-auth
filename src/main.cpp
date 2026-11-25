// Auth: a native BB10 TOTP authenticator. Cascades UI (assets/main.qml) over a self-contained TOTP engine (totp.*).
// No network, no permissions — codes are computed on-device from secrets stored in the app sandbox.
#include <bb/cascades/Application>
#include <bb/cascades/QmlDocument>
#include <bb/cascades/AbstractPane>
#include <QDir>
#include <QtDeclarative/QDeclarativeContext>
#include <stdio.h>
#include "totp.h"

using namespace bb::cascades;

static void logHandler(QtMsgType, const char *m) { fprintf(stderr, "%s\n", m); }

Q_DECL_EXPORT int main(int argc, char **argv) {
    Application app(argc, argv);
    QString root = QDir::currentPath();                         // the app sandbox root
    QByteArray log = (root + "/data/app.log").toUtf8();
    if (freopen(log.constData(), "w", stderr)) setvbuf(stderr, NULL, _IOLBF, 0);
    qInstallMsgHandler(logHandler);

    Totp *totp = new Totp(root + "/data", &app);

    QmlDocument *qml = QmlDocument::create("asset:///main.qml");
    QDeclarativeContext *ctx = qml->documentContext();
    ctx->setContextProperty("totp", totp);
    if (qml->hasErrors()) {
        foreach (const QDeclarativeError &e, qml->errors()) fprintf(stderr, "qml: %s\n", e.toString().toUtf8().constData());
        return 1;
    }
    AbstractPane *pane = qml->createRootObject<AbstractPane>();
    if (!pane) { fprintf(stderr, "no root pane\n"); return 1; }
    Application::instance()->setScene(pane);
    return Application::exec();
}

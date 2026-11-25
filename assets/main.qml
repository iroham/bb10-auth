import bb.cascades 1.3

// Authenticator UI. Design: Swiss-minimal, "vault" dark palette (navy bg, card rows, emerald codes, muted labels),
// strong hierarchy, and a countdown shown BOTH as a shrinking bar and a number (never colour alone). Codes are
// computed on-device by the `totp` engine. Tap a row to copy its code; long-press to delete.
NavigationPane {
    id: nav

    Page {
        id: main
        property variant accts: []     // source of truth; mirrored into acctModel and persisted as JSON
        property int count: 0
        property int toastUntil: 0     // show the "copied" toast while totp.now < this

        titleBar: TitleBar { title: "Authenticator" }
        actions: [
            ActionItem { title: "Add"; ActionBar.placement: ActionBarPlacement.OnBar; imageSource: "asset:///images/add.png"
                onTriggered: { main.clearForm(); addSheet.open(); } }
        ]

        // --- palette ---
        property string cBg: "#0f172a"
        property string cCard: "#192134"
        property string cText: "#f8fafc"
        property string cMuted: "#94a3b8"
        property string cAccent: "#34d399"
        property string cDanger: "#f87171"

        // --- data helpers ---
        function persist() { totp.save(JSON.stringify(main.accts)); }
        function chipColor(s) {
            var pal = ["#6366f1", "#0891b2", "#059669", "#d97706", "#dc2626", "#7c3aed", "#db2777", "#0d9488", "#4f46e5", "#ca8a04"];
            var t = (s && s.length) ? s : "?"; var h = 0;
            for (var i = 0; i < t.length; i++) h = (h + t.charCodeAt(i) * 31) % pal.length;
            return pal[h];
        }
        function initialOf(issuer, account) {
            var s = (issuer && ("" + issuer).length) ? ("" + issuer) : ("" + (account || "?"));
            return s.substring(0, 1).toUpperCase();
        }
        function rebuild() {
            acctModel.clear();
            for (var i = 0; i < main.accts.length; i++) {
                var a = main.accts[i];
                acctModel.append({ issuer: "" + (a.issuer || ""), account: "" + (a.account || ""), secret: "" + a.secret,
                                   digits: a.digits || 6, period: a.period || 30,
                                   color: main.chipColor(a.issuer || a.account), initial: main.initialOf(a.issuer, a.account) });
            }
            main.count = main.accts.length;
        }
        function addAccount(o) { var a = main.accts; a.push(o); main.accts = a; persist(); rebuild(); }
        function removeAt(i) { var a = main.accts; if (i < 0 || i >= a.length) return; a.splice(i, 1); main.accts = a; persist(); rebuild(); }
        function loadAll() { var a; try { a = JSON.parse(totp.load()); } catch (e) { a = []; } main.accts = (a && a.length !== undefined) ? a : []; rebuild(); }

        function clearForm() { uriField.text = ""; issuerField.text = ""; accountField.text = ""; secretField.text = ""; formErr.text = ""; }
        function addFromUri() {
            var s = uriField.text.replace(/^\s+|\s+$/g, "");
            if (s.length === 0) { formErr.text = "Paste a setup link first."; return; }
            var r; try { r = JSON.parse(totp.parseUri(s)); } catch (e) { r = { ok: false }; }
            if (!r.ok) { formErr.text = "That isn't a valid otpauth:// setup link."; return; }
            main.addAccount({ issuer: "" + r.issuer, account: "" + r.account, secret: "" + r.secret, digits: r.digits || 6, period: r.period || 30 });
            addSheet.close();
        }
        function addManual() {
            var sec = secretField.text.replace(/\s/g, "");
            if (!totp.validSecret(sec)) { formErr.text = "The secret must be a valid base32 key."; return; }
            main.addAccount({ issuer: issuerField.text, account: accountField.text, secret: sec, digits: 6, period: 30 });
            addSheet.close();
        }

        Container {
            background: Color.create(main.cBg)
            horizontalAlignment: HorizontalAlignment.Fill
            verticalAlignment: VerticalAlignment.Fill
            layout: DockLayout {}

            ListView {
                id: acctList
                visible: main.count > 0
                horizontalAlignment: HorizontalAlignment.Fill
                verticalAlignment: VerticalAlignment.Fill
                dataModel: ArrayDataModel { id: acctModel }
                function del(ip) { main.removeAt(ip[0]); }
                // tap a row → copy its current code to the clipboard
                onTriggered: {
                    var d = acctModel.data(indexPath);
                    if (d) { totp.copy(totp.generate(d.secret, d.digits, d.period)); main.toastUntil = totp.now + 2; }
                }
                listItemComponents: [
                    ListItemComponent {
                        Container {
                            id: row
                            horizontalAlignment: HorizontalAlignment.Fill
                            leftPadding: ui.du(2); rightPadding: ui.du(2); topPadding: ui.du(1); bottomPadding: ui.du(0)
                            contextActions: [ ActionSet {
                                DeleteActionItem { onTriggered: row.ListItem.view.del(row.ListItem.indexPath) }
                            } ]
                            // card
                            Container {
                                horizontalAlignment: HorizontalAlignment.Fill
                                background: Color.create("#192134")
                                leftPadding: ui.du(2); rightPadding: ui.du(2); topPadding: ui.du(2); bottomPadding: ui.du(2)
                                // header: chip + issuer/account
                                Container {
                                    layout: StackLayout { orientation: LayoutOrientation.LeftToRight }
                                    verticalAlignment: VerticalAlignment.Center
                                    Container {
                                        layout: DockLayout {}
                                        preferredWidth: ui.du(11); preferredHeight: ui.du(11); minWidth: ui.du(11)
                                        background: Color.create("" + ListItemData.color)
                                        Label { horizontalAlignment: HorizontalAlignment.Center; verticalAlignment: VerticalAlignment.Center
                                                text: ListItemData.initial
                                                textStyle { base: SystemDefaults.TextStyles.BigText; color: Color.White; fontWeight: FontWeight.Bold } }
                                    }
                                    Container {
                                        leftPadding: ui.du(2); verticalAlignment: VerticalAlignment.Center
                                        layoutProperties: StackLayoutProperties { spaceQuota: 1 }
                                        Label { text: (("" + ListItemData.issuer).length > 0 ? ListItemData.issuer : ListItemData.account)
                                                textStyle { base: SystemDefaults.TextStyles.BodyText; color: Color.create("#f8fafc"); fontWeight: FontWeight.Bold } }
                                        Label { visible: ("" + ListItemData.issuer).length > 0 && ("" + ListItemData.account).length > 0
                                                text: ListItemData.account
                                                textStyle { base: SystemDefaults.TextStyles.SmallText; color: Color.create("#94a3b8") } }
                                    }
                                }
                                // the code (focal element) + seconds
                                Container {
                                    layout: StackLayout { orientation: LayoutOrientation.LeftToRight }
                                    topMargin: ui.du(1.5); verticalAlignment: VerticalAlignment.Center
                                    Label {
                                        layoutProperties: StackLayoutProperties { spaceQuota: 1 }
                                        text: totp.now >= 0 ? totp.codeFmt(ListItemData.secret, ListItemData.digits, ListItemData.period) : ""
                                        textStyle { base: SystemDefaults.TextStyles.BigText; fontSize: FontSize.XXLarge; fontWeight: FontWeight.Bold
                                                    color: Color.create((totp.now >= 0 && totp.remaining(ListItemData.period) <= 5) ? "#f87171" : "#34d399") }
                                    }
                                    Label {
                                        verticalAlignment: VerticalAlignment.Bottom; bottomMargin: ui.du(0.6)
                                        text: (totp.now >= 0 ? totp.remaining(ListItemData.period) : 0) + "s"
                                        textStyle { base: SystemDefaults.TextStyles.BodyText
                                                    color: Color.create((totp.now >= 0 && totp.remaining(ListItemData.period) <= 5) ? "#f87171" : "#94a3b8") }
                                    }
                                }
                                // depleting countdown bar (non-colour cue, paired with the number above)
                                ProgressIndicator {
                                    topMargin: ui.du(1); horizontalAlignment: HorizontalAlignment.Fill
                                    fromValue: 0; toValue: ListItemData.period
                                    value: totp.now >= 0 ? totp.remaining(ListItemData.period) : ListItemData.period
                                }
                            }
                        }
                    }
                ]
            }

            // empty state
            Container {
                visible: main.count === 0
                horizontalAlignment: HorizontalAlignment.Center; verticalAlignment: VerticalAlignment.Center
                maxWidth: ui.du(80); leftPadding: ui.du(4); rightPadding: ui.du(4)
                ImageView { horizontalAlignment: HorizontalAlignment.Center; preferredWidth: ui.du(22); preferredHeight: ui.du(22)
                            imageSource: "asset:///images/lock.png"; opacity: 0.9 }
                Label { horizontalAlignment: HorizontalAlignment.Center; topMargin: ui.du(2); text: "No accounts yet"
                        textStyle { base: SystemDefaults.TextStyles.BigText; color: Color.create("#f8fafc"); fontWeight: FontWeight.Bold } }
                Label { horizontalAlignment: HorizontalAlignment.Center; multiline: true; topMargin: ui.du(1)
                        text: "Add a service, then paste its otpauth:// setup link or type the secret key by hand."
                        textStyle { base: SystemDefaults.TextStyles.SmallText; color: Color.create("#94a3b8") } }
                // primary CTA (custom so it carries the accent colour)
                Container {
                    horizontalAlignment: HorizontalAlignment.Center; topMargin: ui.du(3)
                    background: Color.create("#34d399"); leftPadding: ui.du(5); rightPadding: ui.du(5); topPadding: ui.du(1.5); bottomPadding: ui.du(1.5)
                    gestureHandlers: [ TapHandler { onTapped: { main.clearForm(); addSheet.open(); } } ]
                    Label { text: "Add account"; textStyle { base: SystemDefaults.TextStyles.BodyText; color: Color.create("#07241a"); fontWeight: FontWeight.Bold } }
                }
            }

            // transient "copied" toast — auto-hides via the 1s tick (no separate timer)
            Container {
                visible: totp.now < main.toastUntil
                horizontalAlignment: HorizontalAlignment.Center; verticalAlignment: VerticalAlignment.Bottom
                bottomMargin: ui.du(5); background: Color.create("#e634d399"); topPadding: ui.du(1); bottomPadding: ui.du(1); leftPadding: ui.du(3); rightPadding: ui.du(3)
                Label { text: "Code copied"; textStyle { base: SystemDefaults.TextStyles.SmallText; color: Color.create("#07241a"); fontWeight: FontWeight.Bold } }
            }
        }

        onCreationCompleted: {
            if (!totp.selftest()) console.log("WARNING: TOTP selftest failed — codes would be wrong");
            main.loadAll();
        }
    }

    attachedObjects: [
        Sheet {
            id: addSheet
            Page {
                titleBar: TitleBar {
                    title: "Add account"
                    dismissAction: ActionItem { title: "Cancel"; onTriggered: addSheet.close() }
                }
                ScrollView {
                    Container {
                        background: Color.create("#0f172a")
                        horizontalAlignment: HorizontalAlignment.Fill
                        leftPadding: ui.du(3); rightPadding: ui.du(3); topPadding: ui.du(3); bottomPadding: ui.du(3)

                        Label { text: "FROM A SETUP LINK"; textStyle { base: SystemDefaults.TextStyles.SmallText; color: Color.create("#94a3b8"); fontWeight: FontWeight.Bold } }
                        TextField { id: uriField; topMargin: ui.du(1); hintText: "otpauth://totp/…"
                                    input { flags: TextInputFlag.AutoCapitalizationOff | TextInputFlag.AutoCorrectionOff | TextInputFlag.PredictionOff } }
                        Container { horizontalAlignment: HorizontalAlignment.Fill; topMargin: ui.du(1.5)
                            background: Color.create("#34d399"); topPadding: ui.du(1.5); bottomPadding: ui.du(1.5)
                            gestureHandlers: [ TapHandler { onTapped: main.addFromUri() } ]
                            Label { horizontalAlignment: HorizontalAlignment.Center; text: "Add from link"
                                    textStyle { base: SystemDefaults.TextStyles.BodyText; color: Color.create("#07241a"); fontWeight: FontWeight.Bold } }
                        }

                        Divider { topMargin: ui.du(3); bottomMargin: ui.du(2) }

                        Label { text: "OR ENTER MANUALLY"; textStyle { base: SystemDefaults.TextStyles.SmallText; color: Color.create("#94a3b8"); fontWeight: FontWeight.Bold } }
                        TextField { id: issuerField; topMargin: ui.du(1); hintText: "Service (e.g. GitHub)" }
                        TextField { id: accountField; hintText: "Account (e.g. you@email)"
                                    input { flags: TextInputFlag.AutoCapitalizationOff | TextInputFlag.AutoCorrectionOff } }
                        TextField { id: secretField; hintText: "Secret key (base32)"
                                    input { flags: TextInputFlag.AutoCapitalizationOff | TextInputFlag.AutoCorrectionOff | TextInputFlag.PredictionOff } }
                        Container { horizontalAlignment: HorizontalAlignment.Fill; topMargin: ui.du(1.5)
                            background: Color.create("#334155"); topPadding: ui.du(1.5); bottomPadding: ui.du(1.5)
                            gestureHandlers: [ TapHandler { onTapped: main.addManual() } ]
                            Label { horizontalAlignment: HorizontalAlignment.Center; text: "Add manually"
                                    textStyle { base: SystemDefaults.TextStyles.BodyText; color: Color.create("#f8fafc"); fontWeight: FontWeight.Bold } }
                        }

                        Label { id: formErr; visible: text.length > 0; multiline: true; topMargin: ui.du(2); text: ""
                                textStyle { base: SystemDefaults.TextStyles.SmallText; color: Color.create("#f87171") } }
                    }
                }
            }
        }
    ]
}

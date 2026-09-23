#Requires AutoHotkey v2.0
#SingleInstance Force
; ---------------------------------------------------------------------------
; Harnais de test du BÉPO hybride — à lancer APRÈS bepo-belge.ahk.
;
;   "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" test-clavier.ahk
;
; Il tape lui-même chaque touche physique (par code de scan) dans sa propre
; zone de texte, lit ce qui en sort et compare à l'attendu. Aucune frappe
; humaine nécessaire : l'agent peut lancer ça et lire le rapport.
;
; Résultat : une fenêtre récapitulative + un fichier resultat-test.txt
; à côté de ce script.
;
; SendLevel 1 est indispensable : sans lui, les frappes simulées sont
; ignorées par les raccourcis de bepo-belge.ahk (protection anti-boucle).
; ---------------------------------------------------------------------------

SendLevel 1
SetKeyDelay 15, 15
rapport := []
echecs := 0

; --- Zone de saisie qui recevra les caractères ------------------------------
fenetre := Gui("+AlwaysOnTop", "Test BÉPO hybride")
fenetre.SetFont("s10", "Consolas")
zone := fenetre.AddEdit("w700 r3")
journal := fenetre.AddEdit("w700 r22 ReadOnly -Wrap")
fenetre.Show()
zone.Focus()
Sleep 400

; --- Les cas de test --------------------------------------------------------
; [ description, suite de touches, texte attendu ]
; « > » sépare les frappes ; « ^ » devant un code = AltGr ; « ^+ » = AltGr+Shift ;
; « + » = Shift.
cas := [
    ["lettres, rangée du haut", "010>011>012>013>014", "bépoè"],
    ["lettres, rangée du haut (suite)", "016>017>018>019>01A>01B", "vdljzw"],
    ["lettres, rangée de repos", "01E>01F>020>021>023>024>025>026>027>028", "auiectsrnm"],
    ["virgule et cédille", "022>02B", ",ç"],
    ["lettres, rangée du bas", "056>02C>02D>02E>030>032>033>034>035", "êàyxkqghf"],
    ["point et apostrophe", "02F>031", ".'"],
    ["majuscules", "+01E>+021>+025", "AES"],
    ["ponctuation BÉPO (Shift)", "+022>+02F>+031>+015", ";:?!"],
    ["accent circonflexe mort", "015>01E", "â"],
    ["circonflexe seul (espace)", "015>039", "^"],
    ["tréma mort (AltGr+Shift)", "^+01A>021", "ë"],
    ["symbole rendu : $", "^+01B", "$"],
    ["symbole rendu : ù", "^028", "ù"],
    ["symbole rendu : %", "^+028", "%"],
    ["symbole rendu : µ", "^+02B", "µ"],
    ["symbole rendu : <", "^056", "<"],
    ["symbole rendu : >", "^+056", ">"],
    ["symbole rendu : =", "^+035", "="],
    ["symbole rendu : /", "^+034", "/"],
    ["symbole rendu : ;", "^+033", ";"],
    ["symbole rendu : ?", "^+032", "?"],
    ["chiffres, position BÉPO : +", "^+008", "+"],
    ["chiffres, position BÉPO : /", "^+00A", "/"],
    ["chiffres, position BÉPO : *", "^+00B", "*"],
    ["chiffres, position BÉPO : =", "^+00C", "="],
    ["chiffres, position BÉPO : %", "^+00D", "%"],
    ["intact : crochet [", "^01A", "["],
    ["intact : crochet ]", "^01B", "]"],
    ["intact : tilde ~ (mort)", "^035>039", "~"],
    ["intact : arobase", "^003", "@"],
    ["intact : euro", "^012", "€"],
    ["intact : accolades", "^00A>^00B", "{}"],
    ["intact : antislash", "^00C", "\"],
    ["intact : dièse", "^004", "#"],
    ["intact : chiffres (Shift)", "+002>+003>+004", "123"],
    ["intact : rangée du haut", "002>003>005>006", "&é'("],
    ["intact : tiret et souligné", "00D>+00D", "-_"]
]

for element in cas {
    zone.Value := ""
    zone.Focus()
    Sleep 60
    frappe(element[2])
    Sleep 180
    obtenu := zone.Value
    ok := (obtenu == element[3])
    if (!ok)
        echecs++
    ligne := Format("{1}  {2}`n     attendu « {3} »   obtenu « {4} »",
        ok ? "[ OK ]" : "[ÉCHEC]", element[1], element[3], obtenu)
    rapport.Push(ligne)
    journal.Value := journal.Value . ligne . "`n"
}

; --- Rapport ----------------------------------------------------------------
resume := Format("{1} cas · {2} réussis · {3} en échec", cas.Length, cas.Length - echecs, echecs)
entete := "Test du BÉPO hybride — " . FormatTime(, "yyyy-MM-dd HH:mm") . "`n" . resume . "`n"
fichier := A_ScriptDir . "\resultat-test.txt"
try FileDelete fichier
FileAppend entete . "`n" . Join(rapport) . "`n", fichier, "UTF-8"

journal.Value := journal.Value . "`n" . resume . "`nRapport écrit dans " . fichier
fenetre.Title := "Test BÉPO hybride — " . resume
zone.Value := ""

Join(liste) {
    texte := ""
    for ligne in liste
        texte .= ligne . "`n"
    return texte
}

; Envoie une suite de touches décrite comme "^+01A>021".
frappe(suite) {
    for morceau in StrSplit(suite, ">") {
        altgr := InStr(morceau, "^") == 1
        if (altgr)
            morceau := SubStr(morceau, 2)
        maj := InStr(morceau, "+") == 1
        if (maj)
            morceau := SubStr(morceau, 2)

        prefixe := ""
        suffixe := ""
        if (altgr) {
            prefixe .= "{LCtrl down}{RAlt down}"
            suffixe := "{RAlt up}{LCtrl up}" . suffixe
        }
        if (maj) {
            prefixe .= "{Shift down}"
            suffixe := "{Shift up}" . suffixe
        }
        ; SendEvent et non Send : le mode « Event » produit de vraies frappes
        ; que le hook de bepo-belge.ahk voit à coup sûr (SendInput les groupe
        ; et peut passer sous le radar des autres scripts).
        SendEvent prefixe . "{SC" . morceau . "}" . suffixe
        Sleep 40
    }
}

Esc:: ExitApp

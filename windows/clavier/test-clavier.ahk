#Requires AutoHotkey v2.0
#SingleInstance Force
; ---------------------------------------------------------------------------
; Harnais de test de la BÉPO Windows (+ bepo-correctifs.ahk, qui doit tourner).
;
;   AutoHotkey64.exe test-clavier.ahk [--quitter]
;
; Passe sa propre fenêtre en BÉPO, tape chaque touche physique par code de
; scan, lit ce qui sort et compare à la BÉPO Linux (fr bepo). Aucune frappe
; humaine. Rapport : la fenêtre + resultat-test.txt à côté du script.
;
; SendLevel 1 : sans lui, bepo-correctifs.ahk ignorerait les frappes simulées.
; ---------------------------------------------------------------------------

SendLevel 1
SetKeyDelay 10, 10
rapport := []
echecs := 0

fenetre := Gui("+AlwaysOnTop", "Test BÉPO")
fenetre.SetFont("s10", "Consolas")
zone := fenetre.AddEdit("w700 r3")
journal := fenetre.AddEdit("w700 r26 ReadOnly -Wrap")
fenetre.Show()

; La fenêtre de test passe en BÉPO (la disposition est propre à chaque fil).
bepo := DllCall("LoadKeyboardLayout", "Str", "0002040C", "UInt", 0, "Ptr")
if !bepo {
    MsgBox "Disposition BÉPO (0002040C) introuvable : lance installer.ps1."
    ExitApp 2
}
DllCall("ActivateKeyboardLayout", "Ptr", bepo, "UInt", 0)
zone.Focus()
Sleep 400

; [ description, frappes, attendu ]
; frappes : codes de scan séparés par « > » ; préfixes « + » Shift,
; « ^ » AltGr, « ^+ » AltGr+Shift.
cas := [
    ["lettres, rangée du haut", "010>011>012>013>014>016>017>018>019>01A>01B", "bépoèvdljzw"],
    ["lettres, rangée de repos", "01E>01F>020>021>022>023>024>025>026>027>028>02B", "auie,ctsrnmç"],
    ["lettres, rangée du bas", "056>02C>02D>02E>02F>030>032>033>034>035", "êàyx.kqghf"],
    ["majuscules accentuées", "+011>+014>+02C>+02B>+056", "ÉÈÀÇÊ"],
    ["rangée des chiffres", "029>002>003>004>005>006>007>008>009>00A>00B>00C>00D", "$`"«»()@+-/*=%"],
    ["chiffres (Shift)", "+002>+003>+004>+005>+006>+007>+008>+009>+00A>+00B", "1234567890"],
    ["ponctuation (Shift)", "+022>+02F>+031>+015>+00C>+00D", ";:?!°``"],
    ["apostrophe droite (correctif)", "031", "'"],
    ["apostrophe typographique AltGr+, (correctif)", "^022", "’"],
    ["crochets et accolades", "^005>^006>^02D>^02E", "[]{}"],
    ["< > \ / |", "^003>^004>^02C>^056>^010", "<>\/|"],
    ["& ~ ^ _", "^012>^030>^007>^039", "&~^_"],
    ["… € œ æ ù", "^02F>^021>^013>^01E>^01F", "…€œæù"],
    ["circonflexe mort", "015>01E>015>021>015>020", "âêî"],
    ["circonflexe seul (espace)", "015>039", "^"],
    ["tréma mort (AltGr+i)", "^020>021>^020>020", "ëï"],
    ["accent grave mort (AltGr+è)", "^014>01E", "à"],
    ["backtick direct (AltGr+Shift+è)", "^+014", "``"],
]

for c in cas {
    zone.Value := ""
    zone.Focus()
    for frappe in StrSplit(c[2], ">")
        taper(frappe)
    Sleep 80
    obtenu := zone.Value
    ok := (obtenu == c[3])
    if !ok
        echecs++
    rapport.Push(Format("{1}  {2}`r`n     attendu « {3} »   obtenu « {4} »",
        ok ? "[ OK ]" : "[ÉCHEC]", c[1], c[3], obtenu))
}

; Raccourcis : Ctrl suit la lettre BÉPO (comme sous Linux) si la touche porte
; le code virtuel de sa lettre. GetKeyVK lit la disposition de ce fil (BÉPO).
raccourcis := [["c", "023"], ["v", "016"], ["s", "025"], ["w", "01B"], ["z", "01A"], ["d", "017"], ["u", "01F"]]
for r in raccourcis {
    vk := GetKeyVK("SC" . r[2])
    ok := (vk = Ord(StrUpper(r[1])))
    if !ok
        echecs++
    rapport.Push(Format("{1}  Ctrl+{2} sur la touche BÉPO « {2} »`r`n     VK attendu {3:X}   obtenu {4:X}",
        ok ? "[ OK ]" : "[ÉCHEC]", r[1], Ord(StrUpper(r[1])), vk))
}

total := cas.Length + raccourcis.Length
entete := Format("Test BÉPO Windows — {1}`r`n{2} cas · {3} réussis · {4} en échec`r`n",
    FormatTime(, "yyyy-MM-dd HH:mm"), total, total - echecs, echecs)
texte := entete . "`r`n"
for ligne in rapport
    texte .= ligne . "`r`n"
journal.Value := texte
try FileDelete A_ScriptDir "\resultat-test.txt"
FileAppend texte, A_ScriptDir "\resultat-test.txt", "UTF-8"
fenetre.Title := echecs ? "Test BÉPO — " echecs " échec(s)" : "Test BÉPO — tout est bon"

if A_Args.Length && A_Args[1] = "--quitter"
    ExitApp echecs ? 1 : 0
Escape::ExitApp

; Une frappe : préfixes éventuels + code de scan.
taper(frappe) {
    if SubStr(frappe, 1, 2) = "^+" {
        avant := "{LCtrl down}{RAlt down}{LShift down}", apres := "{LShift up}{RAlt up}{LCtrl up}"
        code := SubStr(frappe, 3)
    } else if SubStr(frappe, 1, 1) = "^" {
        avant := "{LCtrl down}{RAlt down}", apres := "{RAlt up}{LCtrl up}"
        code := SubStr(frappe, 2)
    } else if SubStr(frappe, 1, 1) = "+" {
        avant := "{LShift down}", apres := "{LShift up}"
        code := SubStr(frappe, 2)
    } else {
        avant := "", apres := "", code := frappe
    }
    SendEvent avant "{SC" code "}" apres
}

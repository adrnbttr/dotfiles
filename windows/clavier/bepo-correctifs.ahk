#Requires AutoHotkey v2.0
#SingleInstance Force
; ---------------------------------------------------------------------------
; Correctifs de la BÉPO native de Windows, pour taper comme sous Linux.
;
; Windows fournit « Français (Standard, BÉPO) », qui suit la norme AFNOR
; (NF Z71-300). Linux utilise par défaut « fr bepo » : lettres, chiffres et
; symboles de programmation identiques, sauf l'apostrophe :
;
;                              Linux (fr bepo)   Windows (AFNOR)   ici
;   touche à droite du K       '                 ’                 '
;   AltGr + virgule            ’                 '                 ’
;
; Pour du code, « ’ » en accès direct est rédhibitoire ('texte' devient
; ’texte’). On remet donc l'apostrophe droite à sa place Linux.
;
; AltGr+Espace donne bien « _ » dans la disposition, mais sous Windows AltGr
; vaut Ctrl+Alt : des applications prennent Ctrl+Alt+Espace en raccourci
; global (Claude Desktop : saisie rapide) et l'underscore n'arrive jamais.
; Le crochet clavier passe avant ces raccourcis : on écrit « _ » nous-mêmes.
; Ctrl gauche + Alt gauche + Espace reste libre pour ces applications.
;
; Le script n'agit que si la fenêtre au premier plan est en BÉPO : la
; disposition belge (AZERTY imprimé) n'est jamais touchée.
; ---------------------------------------------------------------------------

InstallKeybdHook
KeyHistory 0
TraySetIcon "shell32.dll", 45
A_IconTip := "BÉPO : correctifs Linux (apostrophe, underscore)"

; Identifiant de la disposition BÉPO : mot haut du HKL (0xF000 | Layout Id),
; indépendant de la langue à laquelle elle est rattachée. Lu dans le registre :
; LoadKeyboardLayout ajouterait un clavier à la session (liste de la barre
; des tâches).
BEPO_ID := 0xF000 | Integer("0x" RegRead("HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\0002040C", "Layout Id"))

bepoActive() {
    hwnd := WinExist("A")
    if !hwnd
        return false
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    hkl := DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
    return ((hkl >> 16) & 0xFFFF) = BEPO_ID
}

; Écrit un caractère depuis un raccourci AltGr. AltGr (Ctrl+Alt) est relâché
; le temps de l'envoi : sinon les terminaux (WezTerm) lisent Ctrl+Alt+_ comme
; une combinaison et n'écrivent rien. Il est remis si le doigt est toujours
; dessus, pour que les symboles AltGr suivants partent normalement.
ecrireAltGr(caractere) {
    Send "{LCtrl up}{RAlt up}"
    SendText caractere
    if GetKeyState("RAlt", "P")
        Send "{LCtrl down}{RAlt down}"
}

#HotIf bepoActive()
SC031:: SendText "'"                  ; apostrophe droite, comme sous Linux
<^>!SC022:: ecrireAltGr("’")          ; AltGr+virgule : apostrophe typographique
<^>!SC039:: ecrireAltGr("_")          ; AltGr+Espace, avant les raccourcis globaux
#HotIf

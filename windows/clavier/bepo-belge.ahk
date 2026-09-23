#Requires AutoHotkey v2.0
#SingleInstance Force
; ---------------------------------------------------------------------------
; BÉPO hybride sur clavier AZERTY belge (ThinkPad T14 gen 3)
;
; Remplace UNIQUEMENT les trois rangées de lettres par la disposition BÉPO.
; Tout le reste continue de se comporter comme c'est imprimé sur les touches :
; rangée des chiffres, AltGr (@ # { } [ ] | € ~ …), ponctuation de droite,
; touches de fonction, Ctrl/Alt et tous les raccourcis.
;
; Prérequis : disposition Windows réglée sur « Français (Belgique) ».
;
; Raccourcis :
;   Ctrl+Alt+Shift+B   active / désactive le BÉPO (bulle de notification)
;   Ctrl+Alt+Shift+Q   quitte complètement le script
; ---------------------------------------------------------------------------

InstallKeybdHook
KeyHistory 0
TraySetIcon "shell32.dll", 45
A_IconTip := "BÉPO hybride (clavier belge)"

; --- Disposition BÉPO, par touche physique (code de scan) -------------------
; Rangée du haut des lettres (positions AZERTY : A Z E R T Y U I O P ^ $)
; Rangée de repos          (positions AZERTY : Q S D F G H J K L M ù µ)
; Rangée du bas            (positions AZERTY : < W X C V B N ? ; / +)
;
; « ^ » = accent circonflexe mort (^ puis a → â) ; Shift donne « ! ».
keys := Map(
    ; --- rangée du haut ---
    "010", ["b", "B"],  "011", ["é", "É"],  "012", ["p", "P"],  "013", ["o", "O"],
    "014", ["è", "È"],  "015", ["^", "!"],  "016", ["v", "V"],  "017", ["d", "D"],
    "018", ["l", "L"],  "019", ["j", "J"],  "01A", ["z", "Z"],  "01B", ["w", "W"],
    ; --- rangée de repos ---
    "01E", ["a", "A"],  "01F", ["u", "U"],  "020", ["i", "I"],  "021", ["e", "E"],
    "022", [",", ";"],  "023", ["c", "C"],  "024", ["t", "T"],  "025", ["s", "S"],
    "026", ["r", "R"],  "027", ["n", "N"],  "028", ["m", "M"],  "02B", ["ç", "Ç"],
    ; --- rangée du bas ---
    "056", ["ê", "Ê"],  "02C", ["à", "À"],  "02D", ["y", "Y"],  "02E", ["x", "X"],
    "02F", [".", ":"],  "030", ["k", "K"],  "031", ["'", "?"],  "032", ["q", "Q"],
    "033", ["g", "G"],  "034", ["h", "H"],  "035", ["f", "F"]
)

; Circonflexe mort : caractère composé attendu après « ^ ».
circonflexe := Map(
    "a", "â", "A", "Â", "e", "ê", "E", "Ê", "i", "î", "I", "Î",
    "o", "ô", "O", "Ô", "u", "û", "U", "Û"
)
enAttenteCirconflexe := false

; --- Enregistrement des touches --------------------------------------------
for scanCode, paire in keys {
    Hotkey("SC" . scanCode, frappe(paire[1], paire[2]))     ; sans Shift
    Hotkey("+SC" . scanCode, frappe(paire[2], paire[2]))    ; avec Shift
}

; Dernière instruction avant les raccourcis : au-delà, plus rien ne s'exécute
; au démarrage (fin de la section automatique).
TrayTip "Ctrl+Alt+Shift+B pour désactiver.", "BÉPO hybride actif", 1

; Fabrique le gestionnaire d'une touche (minuscule / majuscule).
frappe(bas, haut) {
    return (*) => envoyer(bas, haut)
}

envoyer(bas, haut) {
    global enAttenteCirconflexe, circonflexe

    ; Verr. Maj inverse la casse, comme sur une disposition normale.
    caractere := (GetKeyState("CapsLock", "T") && bas != haut) ? haut : bas

    ; Touche « ^ » : on attend la voyelle suivante.
    if (caractere = "^" && !enAttenteCirconflexe) {
        enAttenteCirconflexe := true
        return
    }

    if (enAttenteCirconflexe) {
        enAttenteCirconflexe := false
        if (circonflexe.Has(caractere)) {
            Send "{Text}" circonflexe[caractere]
            return
        }
        Send "{Text}^"          ; pas une voyelle : on écrit l'accent puis la touche
    }

    Send "{Text}" caractere
}

; Espace après « ^ » : écrit l'accent seul, comme une disposition classique.
SC039:: {
    global enAttenteCirconflexe
    if (enAttenteCirconflexe) {
        enAttenteCirconflexe := false
        Send "{Text}^"
        return
    }
    Send "{Space}"
}

; --- Activation / désactivation --------------------------------------------
^!+b:: {
    Suspend -1
    if (A_IsSuspended) {
        A_IconTip := "BÉPO hybride — désactivé (clavier belge normal)"
        TrayTip "Le clavier redevient un AZERTY belge.", "BÉPO désactivé", 1
    } else {
        A_IconTip := "BÉPO hybride (clavier belge)"
        TrayTip "Lettres en BÉPO, caractères spéciaux inchangés.", "BÉPO activé", 1
    }
}

^!+q:: ExitApp

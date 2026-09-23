#Requires AutoHotkey v2.0
#SingleInstance Force
; ---------------------------------------------------------------------------
; BÉPO hybride sur clavier AZERTY belge (ThinkPad T14 gen 3)
;
; Principe : les lettres sont en BÉPO, les caractères spéciaux restent ceux
; qui sont imprimés sur les touches.
;
; Le BÉPO a 35 lettres pour 26 touches marquées A-Z : neuf lettres débordent
; sur les touches à symboles qui entourent le bloc (^ $ ù µ < ?, ;. :/ +=).
; Les symboles de ces touches ne disparaissent pas pour autant : ils reviennent
; avec AltGr et AltGr+Shift, sur la touche où ils sont imprimés.
;
;   Rangée des chiffres, AltGr (@ # { } [ | \ ^ €…)     : inchangés
;   AltGr sur une touche remappée                       : légende du bas-droite
;   AltGr+Shift sur une touche remappée                 : légende manquante
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

; --- Symboles imprimés rendus aux touches remappées ------------------------
; AltGr : on ne remplace que deux légendes, parce qu'elles existent ailleurs
; sur le clavier belge (l'accent aigu est aussi sur AltGr+M, la barre oblique
; inverse est aussi sur AltGr+« ) »). Tout le reste du niveau AltGr est intact.
symbolesAltGr := Map(
    "028", "ù",     ; touche « ù % »  (AltGr+M garde l'accent aigu)
    "056", "<"      ; touche « < > \ » (AltGr+« ) » garde le \)
)

; AltGr+Shift : niveau resté libre sur le clavier belge (¼, ⅜, °, ™…).
; On y remet les légendes que le BÉPO a recouvertes, sur leur propre touche ;
; et, sur la rangée des chiffres, les symboles BÉPO les plus fréquents, à leur
; position BÉPO habituelle (7 + · 9 / · 0 * · ) = · - %).
symbolesAltGrMaj := Map(
    "01A", "¨",     ; touche « ^ ¨ [ »   (tréma, accent mort)
    "01B", "$",     ; touche « $ * ] »
    "028", "%",     ; touche « ù % »
    "02B", "µ",     ; touche « µ £ »     (£ reste sur AltGr+Shift+3, d'origine)
    "056", ">",     ; touche « < > \ »
    "032", "?",     ; touche « ? , »
    "033", ";",     ; touche « ; . »
    "034", "/",     ; touche « : / »
    "035", "=",     ; touche « = + ~ »   (~ reste sur AltGr, d'origine)
    ; --- rangée des chiffres, aux positions BÉPO ---
    "008", "+",     ; 7
    "00A", "/",     ; 9
    "00B", "*",     ; 0
    "00C", "=",     ; )
    "00D", "%"      ; -
)

; --- Accents morts ----------------------------------------------------------
accents := Map(
    "^", Map("a", "â", "A", "Â", "e", "ê", "E", "Ê", "i", "î", "I", "Î",
             "o", "ô", "O", "Ô", "u", "û", "U", "Û"),
    "¨", Map("a", "ä", "A", "Ä", "e", "ë", "E", "Ë", "i", "ï", "I", "Ï",
             "o", "ö", "O", "Ö", "u", "ü", "U", "Ü", "y", "ÿ", "Y", "Ÿ")
)
accentEnAttente := ""

; --- Enregistrement des touches --------------------------------------------
for scanCode, paire in keys {
    Hotkey("SC" . scanCode, frappe(paire[1], paire[2]))     ; sans Shift
    Hotkey("+SC" . scanCode, frappe(paire[2], paire[2]))    ; avec Shift
}
for scanCode, caractere in symbolesAltGr
    Hotkey("<^>!SC" . scanCode, symbole(caractere))         ; AltGr
for scanCode, caractere in symbolesAltGrMaj
    Hotkey("<^>!+SC" . scanCode, symbole(caractere))        ; AltGr+Shift

; Dernière instruction avant les raccourcis : au-delà, plus rien ne s'exécute
; au démarrage (fin de la section automatique).
TrayTip "Ctrl+Alt+Shift+B pour désactiver.", "BÉPO hybride actif", 1

; Fabrique le gestionnaire d'une touche (minuscule / majuscule).
frappe(bas, haut) {
    return (*) => envoyer(bas, haut)
}

; Fabrique le gestionnaire d'un symbole (AltGr / AltGr+Shift).
symbole(caractere) {
    return (*) => ecrire(caractere)
}

envoyer(bas, haut) {
    ; Verr. Maj inverse la casse, comme sur une disposition normale.
    ecrire((GetKeyState("CapsLock", "T") && bas != haut) ? haut : bas)
}

; Écrit un caractère en tenant compte de l'accent mort en attente.
ecrire(caractere) {
    global accentEnAttente, accents

    if (accentEnAttente != "") {
        accent := accentEnAttente
        accentEnAttente := ""
        if (accents[accent].Has(caractere)) {
            SendText accents[accent][caractere]
            return
        }
        SendText accent            ; pas une voyelle : on écrit l'accent seul
    }

    if (accents.Has(caractere)) {  ; « ^ » et « ¨ » attendent la voyelle
        accentEnAttente := caractere
        return
    }

    SendText caractere
}

; Espace après un accent mort : écrit l'accent seul, comme ailleurs sous Windows.
SC039:: {
    global accentEnAttente
    if (accentEnAttente != "") {
        accent := accentEnAttente
        accentEnAttente := ""
        SendText accent
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
        TrayTip "Lettres en BÉPO, symboles imprimés sur AltGr.", "BÉPO activé", 1
    }
}

^!+q:: ExitApp

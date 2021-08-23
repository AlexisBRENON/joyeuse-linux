# 🎙️ Joyeuse Linux 🐧
> Tutoriels pour l'utilisation d'une compteuse merveilleuse de la marque Joyeuse sous Linux.

J'ai acheté ma compteuse en juillet 2021, livrée en version 4.04, mise à jour en 5.07 dès la reception (via un laptop Lenovo sous Windows 7 Professionnal (voir le [log](logs/windows_flash_success.log)))
Je l'utilise sur un système ArchLinux:

```shell
$ uname -a
Linux brenon 5.13.9-arch1-1 #1 SMP PREEMPT Sun, 08 Aug 2021 11:25:35 +0000 x86_64 GNU/Linux
```

Il est possible que les choses évoluent depuis.
J'essaierai de maintenir ce fichier au fur et à mesure de mes avancées.

## Contenus

A priori, RAS de ce côté.
La compteuse utilise un système de fichier FAT16 de 128Mo.
Dès branchement sur un ordinateur, un device `/dev/sd*` doit-être créé par le système.
Le montage automatique semble fonctionner (sinon, une commande `mount` doit être suffisante).

## Moulinette

J'avoue ne pas avoir pas testé la moulinette en ligne sur leur site.
Mais comme l'entreprise a la gentillesse de fournir les spécifications du format lu par la compteuse, on peut automatiser la transcription.
Un [script dédié](moulinette.sh) basé sur `ffmpeg` converti à peu près n'importe quel fichier d'entrée (audio ou video) en un fichier MP3 compatible.

## Versionneuse

La versionneuse est disponible sur le site en version Window ou Mac, mais pas Linux.


### Wine

Première idée (et sur conseil du service après-vente), quelques essais avec Wine.
Aucun souci pour l'installation, mais impossible de détecter la compteuse (voir le [log](logs/wine_detect_failure.log)) ...
Ceci était dû à un problème de droits sous Linux.
Après avoir branché la compteuse et monté le système de fichier, celui-ci doit apparaitre dans la liste des lecteurs dans la configuration de Wine.
```shell
$ winecfg
```
Ouvrez l'onglet "Lecteurs".
Il doit y avoir une entrée pointant sur le point de montage de la compteuse.
Si `winecfg` affiche des erreurs dans le terminal ressemblant au message ci-dessous, c'est que l'utilisateur de wine n'a pas accès au périphérique (pas au point de montage mais au périphérique dans `/dev`).
```
wine: Read access denied for device [...], FS volume label and serial are not available.
```

Pour corriger le problème, il faut vérifier les droits du noeud `/dev/sd*` utilisé pour la compteuse.
Dans mon cas, le groupe `disk` a accès au périphérique. Suffit donc d'ajouter mon utilisateur dans ce groupe.
```shell
$ ls -l /dev/sda
brw-rw---- 1 root disk 8, 0 14 août  14:44 /dev/sda

$ sudo usermod -a -G disk alexis
```

Cette fois, la compteuse est détectée par la versionneuse.
La sauvegarde de données se fait sans souci, mais problème au moment du formatage (voir le [log](logs/wine_format_failure.log))
Cette fois ça à l'air d'être la commande `format` qui n'est pas disponible.
Cette commande est appelée par le script `win_format.bat`.

La gestion de partition depuis Wine ne semble pas être une solution viable.
D'une part, les utilitaires censés être nativement présents (`format`, `diskpart`) ne le sont pas.
D'autre part, l'utilisation de ces utilitaires requiert généralement des droits d'administrateur, ce qui n'est pas possible avec wine.
https://forum.winehq.org/viewtopic.php?t=30236

J'ai essayé de modifier le script pour supprimer l'appel à la commande `format`.
Mais le processus de mise à jour est quand échoue quand même, avec une erreur 006 (voir le [log](logs/wine_no_format_failure.log)).
Cette erreur doit venir d'une vérification faite après le formatage (système de fichier vide, label de la partition, autre chose ?) qui échoue, puisque le formatage n'a pas vraiment eu lieu.

En supprimant manuellement la totalité du contenu de la conteuse, l'étape de formatage fonctionne.
Il doit donc être possible de remplacer l'appel à `format` par une commande similaire à la commande UNIX `rm` (`rmdir` a priori).

Suite à ce formattage, un fichier vide `upgrade.txt` est créé à la racine du système de fichier.
Je suppose que ce fichier permet de passer en mode "bootloader".

Après cette étape, la versionneuse demande de débrancher puis rebrancher la conteuse.
Après rebranchement, `dmesg` détecte la connexion du périphérique en mode bootloader, puis plus rien...
```
[10558.732861] usb 1-1: new full-speed USB device number 6 using xhci_hcd
[10558.880798] usb 1-1: New USB device found, idVendor=0483, idProduct=df11, bcdDevice=22.00
[10558.880812] usb 1-1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[10558.880818] usb 1-1: Product: STM32  BOOTLOADER
[10558.880822] usb 1-1: Manufacturer: STMicroelectronics
[10558.880826] usb 1-1: SerialNumber: 2056316B5652
```
En ajoutant une règle udev, on peut alors créer un périphérique pour la programmation: `SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="df11", SYMLINK+="joyeuse/bootloader%n", MODE="0666"`
Malgré la création d'un lien symbolique de `~/.wine/dosdevices/com1` vers `/dev/joyeuse/bootloader1`, la détection du bootloader par la versionneuse échoue:
```
[Warning](,0,default) No valid bootloder USB device detected
[Debug](,0,default) Progress: "UPD_OP_SEARCH" : -1
[Debug](,0,default) Stop:  "UPD_OP_SEARCH"
[Critical](,0,default) Boot dev detection timeout expired
[Debug](,0,default) Select page: "Error"
[Critical](,0,default) Error: "009"
```
En revanche, la détection via `dfu-util` ou `stm32CubeProg` sous Linux fonctionne !!!
J'ai même réussi à flasher avec `stm32CubeProg`.
```
$ dfu-util -l
dfu-util 0.10

Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
Copyright 2010-2020 Tormod Volden and Stefan Schmidt
This program is Free Software and has ABSOLUTELY NO WARRANTY
Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

Found DFU: [0483:df11] ver=2200, devnum=6, cfg=1, intf=0, path="1-1", alt=3, name="@Device Feature/0xFFFF0000/01*004 e", serial="2056316B5652"
Found DFU: [0483:df11] ver=2200, devnum=6, cfg=1, intf=0, path="1-1", alt=2, name="@OTP Memory /0x1FFF7000/01*0001Ke", serial="2056316B5652"
Found DFU: [0483:df11] ver=2200, devnum=6, cfg=1, intf=0, path="1-1", alt=1, name="@Option Bytes  /0x1FFF7800/01*040 e", serial="2056316B5652"
Found DFU: [0483:df11] ver=2200, devnum=6, cfg=1, intf=0, path="1-1", alt=0, name="@Internal Flash  /0x08000000/0256*0002Kg", serial="2056316B5652"
```

Problème, après flashage, j'ai débranché la conteuse (en espérant qu'elle redémarre), mais maintenant, plus rien...
Même quand je la branche, dmesg n'affiche rien...

### Native Linux

Aux vues du [fichier de log](logs/windows_flash_success.log) obtenu après la mise à jour via un ordinateur Windows, le processus semble assez simple :
 1. Détection de la compteuse en mode "Stockage de masse" (`DRIVE_OP_SEARCH`)
 2. Création d'une sauvegarde (`DRIVE_OP_SAVE`)
 3. Formatage de la compteuse (`DRIVE_OP_FORMAT`)
 4. Passage en mode bootloader (`UPD_OP_GO_BOOT_MODE`)
    Ceci semble être fait en créant un fichier `upgrade.txt` sur la compteuse.
 5. Détection de la compteuse en mode "bootloader" (`UPD_OP_SEARCH`)
 6. Mise à jour du firmware (`UPD_OP_UPDATE`)
    Utilisation de l'utilitaire `STM32CubeProgrammer` pour un périphérique `STM32L45x/L46x`
 7. Retour au mode "Stockage de masse" et détection de la compteuse (`DRIVE_OP_WAIT_CONN`)
 8. Restauration de la sauvegarde (`DRIVE_OP_RESTORE`)

Les étapes 1 à 4 semblent facilement réalisable sous Linux, puisqu'il s'agit principalement de manipulation de fichiers.
L'étape 5 semble assez simple et peut être simplifiée avec une règle udev adéquate
L'étape 6 utilise un [logiciel tiers](https://www.st.com/en/development-tools/stm32cubeprog.html).
Celui-ci semble disponible pour Linux, mais il existe également une [alternative](http://dfu-util.sourceforge.net/).
En revanche il faut avoir accès au nouveau firmware (`cube_fw_vX.XX.hex`).
Celui-ci est disponible après installation de la versionneuse via wine, mais un lien de téléchargement direct (avec ou sans identification) permettrait une meilleure intégration.
L'étape 7 semble assez simple aussi
Finalement, pour l'étape 8 nous sommes de retour sur de la manipulation de fichiers assez simple.

J'ai donc commencé à implémenter un [script](update.sh) pour réaliser ces différentes étapes.
Il n'est pas encore complet, et les fonctions complètes n'ont pas encore été testées.
Les avis et commentaires sont les bienvenus.







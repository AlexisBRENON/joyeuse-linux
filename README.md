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


## Versionneuse

La versionneuse est disponible sur le site en version Window ou Mac, mais pas Linux.

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

Je vois plusieurs solutions pour corriger ça :
 - rendre la commande `format` disponible
 - modifier le script pour éviter l'appel à `format` (remplacer par `rm` ?)

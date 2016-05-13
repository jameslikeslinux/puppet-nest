## Generate custom console and GRUB keymaps

See: https://wiki.archlinux.org/index.php/Talk:GRUB#Custom_keyboard_layout
See: http://www.kaufmann.no/roland/dvorak/linux.html

```
./ckbcomp -layout us -option ctrl:nocaps | gzip > us-nocaps.map.gz
gzip -dc us-nocaps.map.gz | grub2-mklayout -o us-nocaps.gkb
./ckbcomp -layout us -variant dvorak -option ctrl:nocaps | gzip > dvorak-nocaps.map.gz
gzip -dc dvorak-nocaps.map.gz | grub2-mklayout -o dvorak-nocaps.gkb
```

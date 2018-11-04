Disabling Hyperthreading
========================

To [disable hyperthreading in BIOS][disable hyperthreading in BIOS] with
[libsmbios][libsmbios]:

```sh
# get value of CPU_Hyperthreading_Enable
isCmosTokenActive 0x00d1
[...] Type 0x00d1  Location 0x46 AND(fe) OR(0)  BITFIELD: 1
# get value of CPU_Hyperthreading_Disable
isCmosTokenActive 0x00d2
[....] Type 0x00d2  Location 0x46 AND(fe) OR(1)  BITFIELD: 0
# activate CPU_Hyperthreading_Disable
activateCmosToken 0x00d2
[...] Type 0x00d2  Location 0x46 AND(fe) OR(1)  BITFIELD: 1
# get value of CPU_Hyperthreading_Enable
isCmosTokenActive 0x00d1
[...] Type 0x00d1  Location 0x46 AND(fe) OR(0)  BITFIELD: 0
# get value of CPU_Hyperthreading_Disable
isCmosTokenActive 0x00d2
[...] Type 0x00d2  Location 0x46 AND(fe) OR(1)  BITFIELD: 1
```

Not all modern machines allow disabling hyperthreading in this way.

To [disable hyperthreading at boot][disable hyperthreading at boot]:

```sh
#!/bin/bash
for _cpu in /sys/devices/system/cpu/cpu[0-9]*; do
  _cpuid="$(basename "$_cpu" | cut -b4-)"
  echo -en "_cpu: $_cpuid\t"
  [[ -e "$_cpu/online" ]] && echo '1' > "$_cpu/online"
  _thread1="$(cat "$_cpu/topology/thread_siblings_list" | cut -f1 -d,)"
  if [[ "$_cpuid" == "$_thread1" ]]; then
    echo "-> enable"
    [[ -e "$_cpu/online" ]] \
      && echo '1' > "$_cpu/online"
  else
    echo '-> disable'
    echo '0' > "$_cpu/online"
  fi
done
```

See Also
--------

- https://github.com/atweiden/toggle-ht
- https://github.com/damentz/ht-manager
- https://github.com/jhoblitt/hyperctl


[disable hyperthreading in BIOS]: https://www.mail-archive.com/source-changes@openbsd.org/msg99141.html
[disable hyperthreading at boot]: https://serverfault.com/questions/235825/disable-hyperthreading-from-within-linux-no-access-to-bios/797534#797534
[libsmbios]: https://serverfault.com/questions/235825/disable-hyperthreading-from-within-linux-no-access-to-bios/412832#412832

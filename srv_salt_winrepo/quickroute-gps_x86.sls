quickroute-gps_x86:
  '2.4':
    installer: salt://win/repo-ng/QuickRoute_2.4_Setup.msi
    full_name: 'QuickRoute 2.4 (x86)'
    reboot: False
    install_flags: '/q'
    uninstaller: '{BDF3D53A-78E0-416D-B03E-A360355FDD6D}'
    uninstall_flags: '/qn'
    msiexec: True


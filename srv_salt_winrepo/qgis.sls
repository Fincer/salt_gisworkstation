qgis:
  '2.18':
    installer: salt://win/repo-ng/installers/QGIS-OSGeo4W-2.18.19-1-Setup-x86_64.exe
    full_name: 'QGIS 2.18.19 Las Palmas'
    reboot: False
    install_flags: '/S'
    uninstaller: '%ProgramFiles%/QGIS 2.18/uninstall.exe'
    uninstall_flags: '/S'
